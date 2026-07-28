# TASK-260728-7ii1xz — macOS system-extension credential transport decision

Revision **2026-07-28.r2**. Status: **ready for review**.
Decision reached; **no** Stop-The-Line condition, **no** portal mutation, **no**
product source or spec file changed by this task.

r2 closes reviewer verdict 01 (F1, F2, F3). **The selected transport is
unchanged** — candidate D still wins, and for the same reasons. What changed is
the lifecycle contract around it: r1 declared revocation asynchronous on the
strength of an inference the published API reference contradicts, and r1 pinned
the System-keychain path as a literal. Both are corrected below, and the
correction is physically verified rather than argued. See §11 for the full
revision log.

Machine of record for every physical check: this Apple-silicon Mac,
macOS **26.5 (25F71)**, `arm64`, Xcode 26.5 SDK, uid 502.

Evidence logs (reproducible, no secret value anywhere):

| log | what it proves |
| --- | --- |
| `TASK-260728-7ii1xz_physical-evidence-03.log` | P1–P4: sysex runs as root; shipping sysex entitlements; the App Sandbox rule that grants `/Library/Keychains`; keychain file layout |
| `TASK-260728-7ii1xz_keychain-context-probe-01.log` | E0–E6: GUI vs non-GUI keychain reachability, System-keychain write refusal |
| `TASK-260728-7ii1xz_sandbox-and-systemkeychain-02.log` | E7 and the sandbox/`SystemKey` excerpts |
| `TASK-260728-7ii1xz_system-domain-and-lifecycle-04.log` | **r2.** E8–E10: system-domain keychain resolution, the `SecItem` key split, and a scoped negative control; plus the verbatim `sendProviderMessage` / `handleAppMessage` lifecycle text |

Harnesses: `TASK-260728-7ii1xz_kcprobe.swift`,
`TASK-260728-7ii1xz_run-probe.sh`, `TASK-260728-7ii1xz_collect-evidence.sh`,
`TASK-260728-7ii1xz_kcdomain.swift` (r2).

---

## 1. The open question, stated verbatim

> **By what mechanism does a root-context macOS `NEPacketTunnelProvider` obtain
> SSH private-key material and an optional passphrase that the user-context
> containing app holds, without placing secrets in `providerConfiguration`, App
> Group data, logs, or board resources?**

`.spec/security-privacy.md` "Client credentials" answers this for iOS and
answers it wrongly for macOS:

> "Private keys and passphrases live in the Data Protection Keychain and are
> shared only through the minimum keychain access group required by the app and
> its packet tunnel extension."

## 2. The two Apple-sourced facts that create the question

**Fact 1 — a macOS NE system extension runs as root, outside a user context.**

> "System extensions are effectively `launchd` daemons and, as such, the System
> keychain is the default option."
> — Apple DTS (Quinn), <https://developer.apple.com/forums/thread/721674>

> "The problem here is that your app and your sysex run as two different users
> (the currently logged in use and root, respectively)."
> — Apple DTS (Quinn), <https://developer.apple.com/forums/thread/133933>

Physically confirmed on this Mac (`physical-evidence-03.log` P1). Tailscale's
shipping packet-tunnel system extension is running at **uid 0**:

```
$ ps -axo user,uid,pid,comm | grep 'network-extension'
root  0  2702  /Library/SystemExtensions/279BAB77-…/io.tailscale.ipn.macsys.network-extension.systemextension/Contents/MacOS/io.tailscale.ipn.macsys.network-extension
exit=0
```

**Fact 2 — the Data Protection Keychain is user-context only, and its access
groups share between programs running as the same user.**

Primary Apple documentation, TN3137 *On Mac keychain APIs and implementations*
(<https://developer.apple.com/documentation/technotes/tn3137-on-mac-keychains>):

> "Programs that run outside of a user context, like a `launchd` daemon, must
> target the file-based keychain. The data protection keychain is only available
> to programs running in a user context, like an app or an app extension."

> "The data protection keychain is only available in a user login context. You
> can't use it, for example, from a `launchd` daemon."

> "Each user gets exactly one data protection keychain. The system selects the
> correct keychain based on the context of the caller. That's why the data
> protection keychain is only available in a user login context."

> "The file-based keychain uses access control lists (`SecAccess`). The data
> protection keychain uses keychain access groups, supplemented by an optional
> access control object."

And the access-group half, stated by DTS in the exact shape this project needs:

> "Keychain access groups allow you to share items between two programs running
> as the same user, not across users."
> — <https://developer.apple.com/forums/thread/133933>

> "The problem with using the iOS-style keychain is that you have various
> components running as different users and each user gets their own iOS-style
> keychain. So you can share items between, say, an app and an appex, but you
> won't be able to share items between an app and a daemon."
> — <https://developer.apple.com/forums/thread/656239>

Physically corroborated (`physical-evidence-03.log` P4): the data protection
keychain is stored **per `$HOME`**, and root's home is not reachable by the
logged-in user.

```
$ ls -d $HOME/Library/Keychains/*/keychain-2.db
/Users/iv/Library/Keychains/5B8CB751-…/keychain-2.db
/Users/iv/Library/Keychains/896DDC91-…/keychain-2.db
exit=0
$ ls -ld /private/var/root
drwxr-x---  5 root  wheel  160 Jan 17  2025 /private/var/root
exit=0
```

The sandbox even denies direct file access to that per-user directory, so it is
reachable only through `securityd`, which selects it by caller context
(`application.sb:543`):

```
(deny file-read* file-write* (home-subpath "/Library/Keychains/${ANY_UUID}"))
```

**Conclusion.** The `.spec/security-privacy.md` design is sound on iOS (appex
and host are the same user) and cannot work on macOS. This is matrix
constraint **OC-1**, and this task owns it.

---

## 3. What the physical checks established, and what they did not

### 3.1 Confirmed

| # | check | command → result | conclusion |
| --- | --- | --- | --- |
| P1 | sysex uid | `ps -axo user,uid,…` → `root 0 2702`, exit 0 | Fact 1 holds on shipping code, not just in docs |
| P3 | sandbox rule | `grep` `application.sb:792-793`, exit 0 | **an NE-entitled process gets `/Library/Keychains` read+write from the base App Sandbox, with no temporary exception** |
| P3 | sandbox rule | `application.sb:655-656`, exit 0 | `com.apple.SecurityServer` and `com.apple.securityd.xpc` Mach lookups are allowed to every sandboxed process |
| P3 | sandbox rule | `application.sb:544-546`, exit 0 | MDS read is allowed to all; MDS **write** is allowed when `_UID == 0` |
| P4 | unlock key | `ls -l /private/var/db/SystemKey` → `-r-------- root wheel`, exit 0 | the System keychain unlocks at boot for root with **no user interaction** — the property that makes unattended start possible, and the reason its blast radius is root-wide |
| E0 | session class | `launchctl managername` → `Aqua`; over `ssh localhost` → `Background`, exit 0 | a real, separable "user login context" axis exists on this machine |
| E3/E4 | file-based keychain, same uid | GUI: `SecItemAdd`/`SecItemCopyMatching` → **OSStatus=0**. Non-GUI (`ssh localhost`, uid 502): → **OSStatus=-25308 errSecInteractionNotAllowed** | a non-GUI context **cannot** reach the logged-in user's login keychain unattended, even at the same uid |
| E5 | System keychain write as the user | `security add-generic-password … /Library/Keychains/System.keychain` → `Write permissions error`, **exit 195** | the containing app, running as the user, **cannot** seed the System keychain. Confirms DTS: *"the System keychain file is only writable by root"* (<https://developer.apple.com/forums/thread/759976>) |
| E5 | System keychain metadata read as the user | `security dump-keychain /Library/Keychains/System.keychain` → exit 0, **192 items**' attributes printed | System keychain **attributes are world-readable**. Item service/account values must therefore be non-identifying |
| E7 | System keychain **data** read as the user | `security dump-keychain -d …` → no output, blocked on an interactive authorization prompt, killed at the 120 s timeout (**exit 143**) | item *data* is ACL-gated and cannot be harvested silently by another local user. No secret was read or printed |
| **E8** | system-domain keychain resolution (**r2**) | `SecKeychainCopyDomainDefault(kSecPreferencesDomainSystem, &kc)` → `OSStatus=0`, `SecKeychainGetPath` → `/Library/Keychains/System.keychain`; `.user` → `/Users/iv/Library/Keychains/login.keychain-db` | the **supported** resolution returns exactly the literal r1 hard-coded, so removing the hard-coded path (F2) is behaviour-preserving, not a redesign. It also resolves correctly from an ordinary user context, so the host and provider can share one code path |
| **E9** | system-domain search list (**r2**) | `SecKeychainCopyDomainSearchList(kSecPreferencesDomainSystem, &list)` → `OSStatus=0`, `count=1`, `/Library/Keychains/System.keychain` | physically confirms TN3137's *"In the system context the search list includes just the System keychain"*. The system domain has exactly one member, so a search-list-scoped query cannot silently widen |
| **E10** | the r2 contract shape, end to end (**r2**) | against a throwaway keychain under `TMPDIR`: `SecKeychainCreate`→0, `SecItemAdd` with `kSecUseKeychain`→0, `SecItemCopyMatching` with `kSecMatchSearchList`→0 (`bytes=18 matchesPlaceholder=true`), **negative control** with the search list pointed at the user default→`-25300 errSecItemNotFound`, `SecItemDelete`→0, `SecKeychainDelete`→0 | the selected transport's `SecItem` layer is exercisable **without root and without touching the System keychain**, and the negative control proves the search list genuinely scopes the query rather than being ignored. This is the concrete test seam promised to `TASK-260715-379cpk` / `TASK-260715-1o9wjz` |

### 3.2 Shipping-product corroboration (`physical-evidence-03.log` P2)

Three Developer ID packet-tunnel system extensions are installed here. Their
entitlements are public code-signing metadata. **All three chose a different
transport, and none of them uses a shared Data Protection Keychain group.**

| product | provider entitlements of interest | transport it implies |
| --- | --- | --- |
| Tailscale `io.tailscale.ipn.macsys.network-extension` | `temporary-exception.files.absolute-path.read-write` = `/Library/Tailscale/`, `/private/var/root/Library/Group Containers/`, `/private/var/db/mds/` | provider-owned root-context file store (candidate **E**) |
| Surfshark `…PacketTunnel-WireGuard` | `temporary-exception.files.absolute-path.read-write` = `/private/var/db/mds/`, `/Library/Keychains/`, `/private/var/root/Library/Group Containers/YHUG37CKN8.com.surfshark.vpn.direct/`; **no** `keychain-access-groups` | file-based System keychain (candidate **D**) |
| PureVPN `com.purevpn.mac.packet-tunnel` and `…wireguard-packet-tunnel` | `keychain-access-groups` = `["4H849Z7V2K.com.purevpn.app.mac"]`, `application-groups`, no exceptions | carries the group; per Facts 1–2 it cannot bridge to the user's keychain |

Three things this evidence adds, recorded rather than smoothed over:

1. **Surfshark's `/Library/Keychains/` exception is redundant on macOS 26.5.**
   `application.sb:792-793` already grants it to anything holding
   `com.apple.developer.networking.networkextension`. This is the single most
   consequential finding for entitlement cost — see §5.
2. **The `/private/var/db/mds/` exceptions are legacy.** They date to the
   Catalina-era sandboxed-sysex keychain bug
   (<https://developer.apple.com/forums/thread/660123>, reported fixed in Big Sur
   Beta 5); `application.sb:544-546` already allows uid 0 to write MDS.
3. **PureVPN carrying `keychain-access-groups` is not evidence that it works.**
   Two shipping products carry entitlements the current system makes
   unnecessary; a third carries one the documented model says cannot function
   across the user boundary. Presence in a shipping bundle is not proof of
   requirement — the same correction `TASK-260715-ypo7yo` made for Tailscale's
   Sparkle exception.

### 3.3 What was NOT proven — named, not assumed away

| gap | why | who closes it |
| --- | --- | --- |
| **No code was run as root.** `sudo -n true` → `sudo: a password is required`, exit 1. This session is non-interactive, so no privileged execution was possible. Every root-context claim rests on Apple documentation, DTS statements, the readable system sandbox profile, file modes, and shipping-product metadata — not on a local root experiment. | environment | `TASK-260715-9yp8to` |
| **The positive Data Protection Keychain case was not demonstrated.** E1/E2 both returned `OSStatus=-34018 errSecMissingEntitlement`, in the `Aqua` session as well as over ssh, because the probe is an ad-hoc-signed CLI with no provisioning profile. TN3137: *"These entitlements must be authorized by a provisioning profile."* Ceremony C1 has not run, so no profile exists. **E1/E2 therefore do not discriminate the user-context axis for the DP keychain**; the discriminating result is E3/E4 on the file-based keychain. | no provisioning profile before C1 | `TASK-260728-q5kjta` → `TASK-260715-9yp8to` |
| **`SecItemAdd` into the System keychain from a sandboxed root NE sysex was not executed here.** The three sandbox rules above make it reachable, and DTS states *"In general, the App Sandbox prevents you from writing to the System keychain (unless you're an NE sysex)"* (<https://developer.apple.com/forums/thread/759976>) — but "reachable per profile" is not "verified in the real provider". | needs the signed provider | `TASK-260715-9yp8to` (see §7 V1) |
| **The `/private/var/root/Library/Group Containers/` container path for a root sysex is corroborated, not directly observed.** `ls` on it returns `Permission denied`, exit 1 — which itself proves the tree is root-private. Two shipping providers naming that exact path in a temporary exception is the corroboration. | cannot read root's home | `TASK-260715-9yp8to` (see §7 V2) |

---

## 4. Candidate transports

Five candidates. **A** is the spec's current design, carried as the null
candidate so its failure is on the record rather than assumed.

Common ground for the "secret lifetime and zeroization" column, stated once
because it is true of every candidate: **no candidate can guarantee
zeroization.** Swift `Data`/`String` are copy-on-write heap buffers with no
guaranteed wipe; any payload crossing NE XPC or `SecItem*` is copied into
framework, `nesessionmanager`, and kernel buffers this project does not own and
cannot overwrite. The honest claim is *best-effort clearing of buffers we
allocate* (`[UInt8]` + `memset_s` inside a bounded scope, never `String`), and
`.spec/security-privacy.md` must not be read as promising more.

### A — Shared Data Protection Keychain access group (`.spec` as written)

| dimension | assessment |
| --- | --- |
| unattended start, app not running | **N/A — never works at all**, attended or not |
| secret lifetime / zeroization | n/a |
| blast radius | n/a |
| entitlement / portal cost | would need `keychain-access-groups` on the provider; inert |
| testability | fails identically in every context, so a green iOS test proves nothing about macOS — the actively dangerous property |
| **cannot guarantee** | **anything.** Contradicted by TN3137 and by two DTS statements; the provider and host are different users with different keychains |

**Rejected.** Not a tradeoff, a contradiction.

### B — App-message IPC seed, provider holds the secret in memory only

Host reads the secret in its user context and sends it to the running provider
over `NETunnelProviderSession.sendProviderMessage(_:returnError:responseHandler:)`
→ `NETunnelProvider.handleAppMessage(_:completionHandler:)`. Nothing is
persisted in root context.

| dimension | assessment |
| --- | --- |
| unattended start, app not running | **fails**, but not for the reason r1 gave. r1 argued from the SDK header that `handleAppMessage:` "requires a live containing app"; that is a misreading — the header describes who sends the message, not a liveness precondition, and §5.0 shows the app→provider direction actually launches the provider. B fails on the **reverse** dependency, which Apple states outright for `handleAppMessage(_:completionHandler:)`: *"The Tunnel Provider's containing app may not always be running at the same time as the Tunnel Provider extension. For example, the Tunnel Provider extension may have been started manually from the system's network settings app or via Connect On Demand. Therefore, you should not rely on this communication channel with the containing app for basic Tunnel Provider operation (start, stop, etc.)."* A memory-only provider has nothing at rest, so a System-Settings or NE-initiated start finds no secret and no one to ask for it. The accepted M1 contract already models that host-less start (`TASK-260715-1q4qhw`: *"Nil options (system start) use the stored reference"*) under a hard 60-second deadline |
| secret lifetime / zeroization | **best of all candidates** — secret exists only while the tunnel runs; nothing at rest in root context |
| blast radius | smallest. Provider compromised while stopped yields nothing |
| entitlement / portal cost | **zero.** Uses the NE channel already in the accepted contract; `keychain-access-groups` stays off the provider; OC-4 stays dormant |
| testability | good for the message contract; the failure mode (system start) is the hard one to test |
| **cannot guarantee** | **unattended or system-initiated start.** Also cannot survive a provider restart that NE performs on its own (crash recovery, wake), because the host may not be running then |

### C — Custom XPC Mach service seed, provider persists

Sysex publishes an `NSXPCListener` via `NEMachServiceName`; the host connects
with `NSXPCConnection(machServiceName:)`.

| dimension | assessment |
| --- | --- |
| unattended start | same as B for the *seed*; if paired with provider-side persistence it inherits D's answer |
| secret lifetime / zeroization | same as B/D |
| blast radius | adds a permanently registered, connectable root endpoint whose peer authentication this project must implement correctly (audit token → code-signing requirement). A new attack surface for a strictly worse reason than D |
| entitlement / portal cost | **highest.** For a sandboxed pair the Mach name must be prefixed by an entitled App Group or the targets need `com.apple.security.temporary-exception.mach-register.global-name` / `…mach-lookup.global-name`. `TASK-260715-ypo7yo` rule **X1** requires any exception entitlement to enter a reviewed-exception register. It also makes **OC-4** live: no Apple source confirms an iOS-style `group.` ID is accepted as a Mach service name prefix, and this project registered iOS-style groups on both platforms |
| testability | worst — needs the installed, approved sysex before any round trip |
| **cannot guarantee** | that the registered iOS-style App Group works as a Mach prefix (OC-4). Buys nothing over B that D does not already provide |

### D — Provider-owned file-based **System keychain**, seeded over the NE app-message channel — **SELECTED**

The provider, as root, owns a System-keychain item. The host never writes it —
it hands the secret to the provider once, over the channel from B, and the
provider persists it.

First, a correction the scope's wording invites: **"the file-based System
keychain with an access group" is a category error.** TN3137: *"The file-based
keychain uses access control lists (`SecAccess`). The data protection keychain
uses keychain access groups."* Access on this path is per-item ACL, not group.
This is the single fact that decides the entitlement verdict in §5.

| dimension | assessment |
| --- | --- |
| unattended start, app not running | **works.** TN3137: *"In the system context the search list includes just the System keychain, which is also the default keychain."* DTS: *"The only keychain available to your daemon is the System keychain. That is a file-based keychain."* (<https://developer.apple.com/forums/thread/775935>). It is unlocked at boot from `/private/var/db/SystemKey` (root-only, physically verified) with no user interaction, so a system start reads it and connects |
| secret lifetime / zeroization | secret is at rest in root context indefinitely. Best-effort clearing only (see common ground). Weaker than B by design; that is the price of unattended start |
| blast radius | provider compromise ⇒ the SSH private key. Root compromise ⇒ the same, since `SystemKey` is root-readable — the System keychain is **not** protected by the user's login password. Item *attributes* are world-readable (E5: 192 items dumped as uid 502), so attributes must carry no hostname, account, or profile name. Item *data* is ACL-gated (E7 blocked on an authorization prompt) |
| entitlement / portal cost | **zero.** `application.sb:792-793` grants `/Library/Keychains` read+write to any process holding `com.apple.developer.networking.networkextension`; `application.sb:655-656` grants the `securityd`/`SecurityServer` Mach lookups to every sandboxed process. No `keychain-access-groups`, no temporary exception, no new portal capability, no new App ID, no C1 change |
| testability | best. The `SecItem` file-based path is exercisable in unit tests against a throwaway keychain file under `.temp/` via `kSecUseKeychain`, giving `TASK-260715-379cpk` / `TASK-260715-1o9wjz` a real test seam without a signed sysex; the root-context leg is one focused check inside `TASK-260715-9yp8to` |
| **cannot guarantee** | (a) that the user's login password protects the secret — it does not; (b) synchronous revocation **in every provider state**. It *is* available whenever the NE configuration is installed and enabled, because an app-originated message launches a non-running provider (§5.0); it is **not** available when the configuration is disabled, unapproved, or removed, or when no host is running (§5.2); (c) that the `SecItem`→file-based shim exposes everything needed — TN3137 warns *"when you use it to target the file-based keychain it operates through a shim. That shim has limitations"*, so the restrictive `SecAccess` must be verified, not assumed; (d) the root-context write itself is not locally proven (§3.3) |

This is also precisely what Apple DTS recommends for this exact architecture:

> "My recommendation here is to share state with your daemon via IPC, most
> commonly XPC. If your daemon wants to save its secrets to the System keychain,
> it can do that because it's running as root."
> — <https://developer.apple.com/forums/thread/759976>

> "> Perhaps using IPC from app to provider and having the provider write to
> keychain?
> Yes."
> — <https://developer.apple.com/forums/thread/133933>

### E — Provider-owned encrypted blob in a root-only directory (Tailscale's pattern)

| dimension | assessment |
| --- | --- |
| unattended start | works, same as D |
| secret lifetime / zeroization | same as D |
| blast radius | same as D, plus project-owned key wrapping. Whatever wraps the blob must itself be readable by root at boot with no user present, so it reduces to the same root-equals-everything property with a hand-rolled implementation in front of it |
| entitlement / portal cost | needs `com.apple.security.temporary-exception.files.absolute-path.read-write` for a path outside the container — exactly what Tailscale ships. That trips `TASK-260715-ypo7yo` rule **X1** and the `.spec/platform-distribution.md` ban on unreviewed exception entitlements |
| testability | good (plain files) |
| **cannot guarantee** | that the project's own at-rest crypto is as good as `securityd`'s. Strictly dominated by D: same security properties, more code, more entitlements, more review surface |

---

## 5. Selection

**Selected: candidate D — the provider owns a file-based System keychain item,
seeded once from the containing app over the NE app-message channel.**

Rationale, in decision order:

1. **Unattended start is a real requirement even though On Demand is off.** The
   accepted M1 contract sets `onDemandEnabled = false` with no On Demand rules,
   which makes B *look* survivable — but the same contract already handles
   `startTunnel` with nil options as a system start, and macOS surfaces an
   NE-backed VPN configuration in System Settings and the menu bar, where the
   user can start it with the app not running. NE also restarts a provider on
   its own after a crash or wake. Any of those paths kills B.
2. **D is the only candidate that adds no entitlement.** Physically verified on
   this Mac: the App Sandbox already grants an NE-entitled process read/write to
   `/Library/Keychains`. C and E both require exception entitlements that rule
   X1 puts under review; A requires an entitlement that cannot work.
3. **The security cost is real and is accepted explicitly.** Moving the secret
   from the user's password-protected DP keychain to the root-unlocked System
   keychain removes the login-password gate. It is not free, it is not hidden,
   and it is the unavoidable price of a root provider that must connect without
   a user. `.spec/security-claims.md` and `.spec/threat-model.md` M-02 must be
   amended to say this on macOS rather than continue to imply the iOS property.
4. **It matches Apple's own recommendation for this exact shape** (two DTS
   quotes above) and matches the one shipping product on this machine that
   solved it with the keychain rather than with a hand-rolled file store.
5. **It keeps OC-4 dormant.** No Mach service name, no App Group prefix
   question, no unregistrable macOS-style identifier.

### 5.0 The app-message channel launches a stopped provider — r1 got this wrong

r1 asserted that the seed channel needs a *running* provider and therefore made
both seeding and revocation depend on tunnel lifecycle. Apple's published API
reference for the exact method this design uses says otherwise:

> "Send a message to the Tunnel Provider extension. **If the extension is not
> running, it should be launched to handle the message.** If this method can't
> start sending the message it reports an error in the `error` parameter."
> — `NETunnelProviderSession.sendProviderMessage(_:responseHandler:)`,
> <https://developer.apple.com/documentation/networkextension/netunnelprovidersession/sendprovidermessage(_:responsehandler:)>

Two consequences, and one non-consequence that matters just as much:

1. **Seeding does not have to happen inside `startTunnel`.** The host can seed a
   provider that is installed and enabled but not running, without first
   establishing a tunnel. This removes the r1 `awaitingCredential` state from
   the 60-second startup budget entirely.
2. **Revocation is synchronous in the ordinary case.** The app can send
   `RevokeCredential(ref)` and have a stopped provider launched to service it.
   r1's "deletion is only eventually consistent" is wrong as a blanket claim.
3. **The reverse dependency is still forbidden**, which is why candidate B is
   still rejected and why the start-time path still reads from the keychain
   first. Apple, on `handleAppMessage(_:completionHandler:)`: *"you should not
   rely on this communication channel with the containing app for basic Tunnel
   Provider operation (start, stop, etc.)."* App→provider may launch;
   provider→app may not be assumed.

The SDK header pins the documented failure set for the send:
`NEVPNErrorConfigurationInvalid` and `NEVPNErrorConfigurationDisabled`. That is
what makes §5.2's state split precise rather than hand-waved.

**Honest limitation.** Apple's wording is "should be launched", and this was
**not executed here** — no signed, approved provider exists before Ceremony C1.
The contract below is therefore designed to be *correct either way*: the
keychain item, not the message, is the provider's source of truth at start, so
if launch-on-message turns out not to fire in practice the design degrades to
r1's eventual-consistency behaviour rather than breaking. Confirming it is
verification **V4** on `TASK-260715-9yp8to` (§7).

### 5.1 Transport contract, at contract level

Owned for formalization by `TASK-260715-29ws8l`; this task fixes the shape only.

1. Non-secret profile data and one opaque `credentialRef` (UUID) reach the
   provider through `providerConfiguration` (already bounded to 4 KiB by
   `TASK-260715-1q4qhw`), **not** through the App Group — see §6.

2. **Keychain resolution — never a hard-coded path.** Every provider-side
   keychain operation resolves the system-domain keychain through the supported
   API and passes it explicitly, so the provider never depends on a mutable
   search list *and* never embeds a path literal:

   ```
   SecKeychainCopyDomainDefault(kSecPreferencesDomainSystem, &systemKeychain)
   ```

   Verified on this Mac (E8/E9): returns `OSStatus=0` and resolves to
   `/Library/Keychains/System.keychain`, and the system domain's search list has
   exactly one member. r1 hard-coded that literal; Apple DTS advises against it
   (<https://developer.apple.com/forums/thread/738542>,
   <https://developer.apple.com/forums/thread/704034>).

   The `SecItem` keys differ by operation, and r1 got this wrong too — it
   specified `kSecUseKeychain` for the *query*. Per `SecItem.h`, `kSecUseKeychain`
   is defined for `SecItemAdd` only ("a value of type `SecKeychainRef` to which
   **`SecItemAdd`** will add the provided item(s)"); scoping a search takes
   `kSecMatchSearchList` ("the search will be limited to the keychains contained
   in this list"). The contract is therefore:

   | operation | required key | value |
   | --- | --- | --- |
   | `SecItemAdd` | `kSecUseKeychain` | the resolved system-domain `SecKeychainRef` |
   | `SecItemCopyMatching` / `SecItemUpdate` / `SecItemDelete` | `kSecMatchSearchList` | `[` that same ref `]` |

   All operations additionally set `kSecUseDataProtectionKeychain: false`. No
   `kSecAttrAccessGroup` and no `kSecAttrAccessible` — both are Data Protection
   Keychain concepts and are meaningless on this path. E10 exercised exactly this
   shape end to end, including a negative control proving the search list really
   scopes the query.

   Recorded plainly: the whole file-based `SecKeychain` / `SecAccess` surface is
   **deprecated** (`API_DEPRECATED("SecKeychain is deprecated", macos(10.2,
   10.10))`) yet remains present in the macOS 26.5 SDK and is Apple's documented
   option for daemons, which have no alternative. Physical **V1** stays the
   release gate for it.

3. **Seeding is a standalone operation, not a start-time one.** On a
   user-initiated save or connect the host sends one bounded, versioned
   `SeedCredential{v, ref, key, passphrase?}` app message. The provider stores it
   under a fixed non-identifying service constant with `account = credentialRef`
   and a restrictive `SecAccess` naming its own designated requirement, replies
   `{v, stored}`, and the host then clears its buffers and drops any staging
   item. Because this can launch a stopped provider (§5.0), the credential is
   normally already at rest before any tunnel start.

4. **`startTunnel` reads only.** The provider queries the system-domain keychain
   as in (2).
   * hit → continue bootstrap;
   * miss → fail immediately with a distinct privacy-safe
     `credentialNotProvisioned`. The provider does **not** wait on a host that
     the documentation says may not exist. This is a deliberate change from r1,
     which spent the 60-second startup budget waiting for a seed message.

5. **Revocation and replacement are provider operations with a state-dependent
   guarantee** — see §5.2 for the exact split. `RevokeCredential(ref)` and
   re-seed both travel the same app-message channel.

6. **A start-time reconciliation sweep is retained as crash-recovery defence
   only, not as the deletion path.** On each provider start, items whose `ref` is
   absent from the current profile set are deleted. This closes the residue left
   by the §5.2 cases where a synchronous revoke could not be delivered; it is no
   longer the primary mechanism, and the contract must not present it as one.

7. Attributes carry no hostname, account, profile name, or any user-identifying
   value — System keychain attributes are world-readable (E5).

### 5.2 Revocation guarantee, by provider state

The property `TASK-260715-379cpk` AC4 needs ("deletion makes lookups fail") is
not one guarantee on macOS; it is three. Stating it as a single yes/no is what
produced the r1 error.

| # | provider state | app-originated revoke | guarantee |
| --- | --- | --- | --- |
| 1 | installed **and enabled**, not currently running | `sendProviderMessage` is documented to launch it to handle the message | **synchronous.** The item is gone when the response arrives |
| 2 | installed and enabled, **already running** | delivered to the live provider | **synchronous** |
| 3 | configuration **disabled** | send fails with `NEVPNErrorConfigurationDisabled` | **not available.** Deferred to the §5.1.6 sweep on next start |
| 4 | configuration **missing/invalid**, or the system extension is unapproved, superseded, or failed to activate | send fails with `NEVPNErrorConfigurationInvalid`, or there is no manager to send through | **not available.** Deferred to the sweep. If the extension is *uninstalled*, macOS removes its container but the System-keychain item is **not** owned by that container and will survive — deletion then requires reinstall-and-sweep or an explicit root cleanup step, which `TASK-260715-29ws8l` must specify |
| 5 | **no host running** (user never opens the app) | nothing is originated at all | **not available.** No app-side actor exists |

The UI consequence, owned by `TASK-260715-2hhh7x`: in states 3–5 the app must
report revocation as *pending*, not as done. Reporting a deletion that has not
happened is worse than reporting a delay.

---

## 6. Secondary finding: the App Group channel is broken on macOS too

Not the question this task was asked, found while answering it, and material
enough that hiding it would be worse than reporting it.

`.spec/architecture.md:111` — *"Shared mutable state is limited to an App Group
configuration snapshot and Keychain references."* The App Group half fails on
macOS for the same reason as the keychain half:
`containerURL(forSecurityApplicationGroupIdentifier:)` resolves relative to the
caller's home, and the root provider's home is `/private/var/root`. The
sandbox's group-container rules are `home-subpath`-relative and keyed off
`com.apple.security.application-groups` (`application.sb:302-303`, `459-460`).
`ls -ld '/private/var/root/Library/Group
Containers'` → `Permission denied`, exit 1: the tree is root-private. Two of the
three shipping providers name that exact path in a temporary exception, which is
what you do when you need to cross that boundary.

So on macOS the host and the provider do **not** share an App Group container.
The non-secret snapshot must travel through `providerConfiguration` — which the
accepted M1 lifecycle contract already does — not through an App Group file.
This is the assumption `TASK-260715-3f4lxy` must revise, and it is why
`TASK-260715-ypo7yo` already recorded 3f4lxy as blocked on this task.

Corroborated, not directly observed (§3.3). `TASK-260715-9yp8to` closes it.

---

## 7. Entitlement amendment for the `TASK-260715-ypo7yo` matrix

### Verdict

> **`keychain-access-groups` on `works.relux.tunnel.mac.tunnel` (`macos.provider`)
> — KEEP PROHIBITED.**
>
> Status changes from **`prohibited-pending-decision`** to a settled
> **`prohibited`**. The selected transport is the file-based System keychain,
> whose access control model is per-item `SecAccess` ACLs, not access groups
> (TN3137). The entitlement is therefore not merely unnecessary — it is
> **inapplicable to the mechanism actually used**. The provider needs no
> keychain entitlement at all: `/System/Library/Sandbox/Profiles/application.sb`
> lines 792–793 on macOS 26.5 (25F71) already grant read+write to
> `/Library/Keychains` to any process holding
> `com.apple.developer.networking.networkextension`, and lines 655–656 grant the
> `securityd` Mach lookups to every sandboxed process.
>
> **No new entitlement, no new App ID, no new portal capability, no change to
> Ceremony C1.**
>
> The row must also be **cleared of the fields that exist only to keep it open**:
> `resolutionOwner` and the current `amendmentRule` are both removed, because
> this task is the resolution and because that rule's antecedent is now true
> while its consequent is false. Field-level detail immediately below.
>
> **Applying owner: `TASK-260715-ypo7yo`.** Per that matrix's §11 amendment rule,
> ypo7yo updates the JSON, bumps `revision`, appends to `revisionLog`, keeps
> `validate_matrix.py` passing, and records that **OC-1 is closed**. This task
> does not touch the matrix.

### Consequential items for the applying owner

The row is settled by this decision, so **every field on it that exists only to
keep it open must go with it.** The current
`targets[key="macos.provider"].entitlements["keychain-access-groups"]` object
carries five keys; r1 named two of them and left the other three in place, which
would have left a settled row still advertising an owner and a reopening rule.
The full field-level instruction:

| field | now | required after amendment | why |
| --- | --- | --- | --- |
| `status` | `"prohibited-pending-decision"` | `"prohibited"` | the decision is made |
| `rationale` | D-2 text, "withheld pending the macOS credential transport decision" | the settled reason: the selected transport is the file-based System keychain, whose access model is per-item `SecAccess` ACL, not access groups (TN3137), so the entitlement is **inapplicable to the mechanism used**, not merely unnecessary; the provider needs no keychain entitlement at all because `application.sb:792-793` already grants `/Library/Keychains` read+write to any `com.apple.developer.networking.networkextension` holder. Cite `TASK-260728-7ii1xz` | the old text describes a question that no longer exists |
| `evidence` | "Observed 2026-07-28 … via `codesign -d --entitlements :-`" | keep, and add the `application.sb:792-793` / E8–E10 evidence from this task | the shipping-bundle observation is still true and still relevant |
| **`resolutionOwner`** | `"TASK-260728-7ii1xz"` | **removed** | this task *is* the resolution. A settled row naming a pending resolver is self-contradictory and will read to the next round as still-open |
| **`amendmentRule`** | *"If the resolved macOS credential transport gives the provider direct keychain access, this row is amended to `required` with the same group literal…"* | **removed and replaced by rule M5 below** | its antecedent is now **true** — the selected transport *does* give the provider direct keychain access — while its consequent is **false**, because the file-based keychain has no access groups. Left in place it is a live instruction to re-grant the row on exactly the reasoning this decision refutes. This is the single most dangerous leftover on the row |

| # | item | requested action |
| --- | --- | --- |
| M1 | `macos.provider` `keychain-access-groups` row | apply the field table above **in full** — status, rationale, evidence, **and the deletion of `resolutionOwner` and `amendmentRule`** |
| M2 | **OC-1** | close, naming `TASK-260728-7ii1xz` as the resolver |
| M3 | **OC-4** | keep open but downgrade to *"verify only if XPC is ever selected"*; candidate C was rejected, so no iOS-style Mach prefix is needed today |
| M4 | `macos.host` `keychain-access-groups` | **no change requested — recommend keep granted.** Purpose narrows from *system of record* to *iOS system of record plus a macOS pre-seed staging item* held across system-extension approval, which is a multi-step flow the user can interrupt. §4.4's "granted only where functional" is still satisfied. Flagged explicitly so the owner does not have to infer it; this is a recommendation, not a verdict — AC4 scopes the verdict to the provider row |
| M5 | **replacement rule for the deleted `amendmentRule`** — not optional | record, at contract level: *"On macOS the file-based (system-domain) keychain is controlled by per-item `SecAccess` ACLs. `keychain-access-groups` applies only to the Data Protection Keychain, which is unavailable outside a user context. A root-context provider targeting the system-domain keychain therefore never needs this entitlement, and the presence of the key in a shipping third-party provider is not evidence that it functions."* This is what the removed `amendmentRule` must be replaced *with*: the row still needs a stated reopening condition, and the correct one is narrow — the row reopens only if the provider is ever moved into a user context, not merely because it touches a keychain. Without this, the next round re-grants the row by analogy with PureVPN's bundle, which is the exact reasoning M1 deletes |
| M7 | `revision`, `revisionLog`, and the validator | bump `revision`, append a `revisionLog` entry naming `TASK-260728-7ii1xz_reviewer-verdict-01.md` → this decision as the closing evidence, and keep `TASK-260715-ypo7yo_validate-matrix.py` at exit 0. Because r3's containment assertions are exhaustive, **check that deleting `resolutionOwner` / `amendmentRule` does not trip an assertion that requires them** — if one does, that assertion encoded the open state and must be updated in the same revision, not worked around. Consider a negative gate that fails closed if a `prohibited` row still carries a `resolutionOwner`, since that is the defect class M1 is fixing |
| M6 | **`com.apple.security.application-groups`** on both macOS targets | **no value change requested.** What must change is the *stated purpose*. The matrix §10 traceability row *"host↔provider state is an App Group snapshot + Keychain refs → `.spec/architecture.md:111`"*, and any G2 purpose text implying a shared container on macOS, are **false on macOS** (§6): the two targets resolve different containers. The macOS host↔provider channel is `providerConfiguration` plus the app-message seed. The entitlement is left granted because a private root-context container may still have uses this task did not survey; whether it survives least privilege is a separate review under ypo7yo's ownership, not a verdict this task is competent to issue |

### Verifications this decision hands to `TASK-260715-9yp8to`

| # | check | pass condition |
| --- | --- | --- |
| **V1** | From the signed, sandboxed, approved provider running as root: resolve the keychain with `SecKeychainCopyDomainDefault(kSecPreferencesDomainSystem, …)`, log the **resolved path only**, then `SecItemAdd` (`kSecUseKeychain`) + `SecItemCopyMatching` (`kSecMatchSearchList`) of a placeholder generic password with a restrictive `SecAccess`, **with no `keychain-access-groups` and no temporary exception on the provider** | resolution `OSStatus=0` and the path is the system-domain keychain; add and read both `OSStatus=0`; no sandbox denial in the unified log; a second read after provider restart still returns 0 with no prompt |
| **V2** | In the same root context, log the resolved `containerURL(forSecurityApplicationGroupIdentifier:)` **path only** | path is under `/private/var/root/...` and differs from the host's, confirming §6 |
| **V3** | Start the tunnel from System Settings with the containing app not running, after V1 seeded the item | provider reads its item and reaches `.connected` without the host |
| **V4** (r2) | **The §5.0 launch-on-message claim, which documentation alone cannot settle.** With the provider installed, enabled, and *not running*, and the tunnel *not* started, send a bounded no-op app message from the host via `NETunnelProviderSession.sendProviderMessage`. Record whether the provider process starts, whether `handleAppMessage` is reached, and the round-trip outcome | the provider is launched and responds **without the tunnel being started**. If it does **not**, §5.1.3 seeding and §5.2 cases 1–2 collapse to r1's eventual-consistency behaviour and `TASK-260715-29ws8l` must restate the revocation guarantee accordingly. Either result is a valid outcome; the design must not ship on the assumption |
| **V5** (r2) | The §5.2 negative states. With the configuration **disabled**, attempt the same send | the send fails, and the returned error is `NEVPNErrorConfigurationDisabled` as the SDK header documents — confirming that the app can *detect* the deferred-revocation case rather than silently believing it succeeded |

Privacy rule for all five: placeholder values only, paths and `OSStatus` /
`NEVPNError` values only, never a secret. V4 and V5 send a **no-op** message
carrying no credential.

---

## 8. Downstream tasks and the exact assumption each must revise

All five are already hard-blocked by this task on the board
(`blockedBy` contains `TASK-260728-7ii1xz`), verified this session.

| task | assumption today | revised assumption |
| --- | --- | --- |
| **`TASK-260715-379cpk`** — implement the Keychain credential vault | AC1: secrets stored "only under the approved Data Protection Keychain class and exact shared access group", readable by both app and extension | **Platform-split vault.** iOS keeps the DP keychain + access group unchanged. macOS: the app-side vault is a *staging* store only; the system of record is the provider's system-domain keychain item, written by the provider. AC4 ("deletion makes both app and extension lookups fail") **is synchronously satisfiable on macOS in the ordinary case** — an app-originated revoke launches a stopped-but-enabled provider (§5.0) — but **not in every provider state**. AC4 must be restated against the five states in §5.2: synchronous in states 1–2, deferred to the start-time sweep in states 3–5, and the vault API must surface which one happened rather than returning a bare success. AC5's "rejected wrong-group access" test does not apply to the macOS path; substitute an ACL/designated-requirement test. The macOS `SecItem` layer is unit-testable today against a throwaway keychain with `kSecUseKeychain` / `kSecMatchSearchList` — E10 is a working template, negative control included |
| **`TASK-260715-1o9wjz`** — extension Keychain credential resolver | whole task is written against "the shared Data Protection Keychain access group" with an "approved access group and accessibility class from M0 identifiers" | **Resolver targets the system-domain file-based keychain**: `kSecUseDataProtectionKeychain: false`, keychain resolved via `SecKeychainCopyDomainDefault(kSecPreferencesDomainSystem, …)` and **never a hard-coded path**, `kSecUseKeychain` on add, `kSecMatchSearchList` on query/update/delete (§5.1.2), no access group, no accessibility class. AC1's "queries only the approved shared access group" becomes "queries only the fixed service constant and the exact `credentialRef`, scoped by an explicit search list to the resolved system-domain keychain, never the ambient search list". **`startTunnel` is read-only** (§5.1.4): the r1 `awaitingCredential` wait is removed, a miss fails fast with `credentialNotProvisioned`, and seeding is a separate app-message operation. AC2 gains `credentialNotProvisioned`. AC4's zeroization language must drop to best-effort per §4 common ground |
| **`TASK-260715-29ws8l`** — profile, trust, and credential boundary contract | AC2: "App Group and providerConfiguration data contain only non-secret profile data and opaque Keychain references"; AC4 specifies "Keychain accessibility, access group" | **Owns the §5.1 transport contract**: the `SeedCredential` / `RevokeCredential` message schemas and size bounds, the keychain-resolution rule (system-domain API, no path literal, `kSecUseKeychain` vs `kSecMatchSearchList`), the read-only `startTunnel` rule, the start-time sweep **as crash-recovery defence only**, the non-identifying attribute rule (System keychain attributes are world-readable), and per-platform credential-location language. AC4's "Keychain accessibility, access group" is macOS-inapplicable and becomes "`SecAccess` designated-requirement ACL". Must state the **§5.2 five-state revocation table** rather than a single yes/no, must specify the uninstall residue case (state 4 — the item outlives the extension's container), and must state the one property macOS genuinely **cannot** offer: login-password protection of the secret at rest |
| **`TASK-260715-2hhh7x`** — profile, key, and ownership contract | AC2 requires a matrix proving "raw keys and passphrases exist only in the approved Data Protection Keychain access group" | That proof is **false on macOS**. The least-privilege matrix becomes per-platform: iOS → DP keychain + access group; macOS → provider-owned system-domain keychain item + host staging item with a bounded lifetime. The editor lifecycle gains a state the contract has no concept of today: *key imported but not yet seeded*, because the system extension may not be approved yet. Deletion and key-replacement transitions must model **both** revocation outcomes from §5.2 — completed (states 1–2) and *pending* (states 3–5) — and the UI must show pending as pending. r1 told this task to model revocation as always-asynchronous; that was wrong and would have produced a permanently vague "will be removed soon" affordance where a definite confirmation is normally available |
| **`TASK-260715-3f4lxy`** — versioned profile snapshot loader | reads "atomically published **App Group** SSH profile snapshots" | **The App Group container is not shared on macOS** (§6): host and root provider resolve different containers. The snapshot must arrive through `providerConfiguration` (already the accepted M1 channel, 4 KiB bounded), not through an App Group file. AC3's "snapshot reads are atomic" is then satisfied by NE's configuration delivery rather than by file-level atomicity, and the size-bound tests must target the 4 KiB `providerConfiguration` limit rather than an arbitrary file bound |

Also affected, recorded here rather than left implicit:

* **`TASK-260715-9yp8to`** gains V1–V5 (§7). V4/V5 are r2 additions and are the
  physical settlement of the launch-on-message lifecycle.
* **`TASK-260715-ypo7yo`** gains M1–M7 (§7), including the field-level deletion
  of `resolutionOwner` and `amendmentRule`.
* **`.spec/security-privacy.md`**, **`.spec/security-claims.md`**, and
  **`.spec/threat-model.md` M-02** state a credential property that is true on
  iOS and false on macOS. Amending the spec is outside this task's scope; it is
  named here so the goal owner can route it.

---

## 9. Decomposition: why no board element was created

This is a decision task, not a decomposition task, and the smallest correct
board change here is **none**. Recorded explicitly so the reviewer does not have
to infer it.

* **No story or task was created, renamed, deleted, or re-parented.** Every
  obligation this decision produces landed on an element that already exists and
  already owns that kind of work.
* **The one element I considered creating**, and did not: a task for the
  root-context verifications V1–V3. Out-of-scope checks performed before
  deciding — `TASK-260715-9yp8to` ("Verify Gate P0 on a physical Apple-silicon
  Mac") already scopes *"development-signed host and embedded provider; nested
  signature and entitlement inspection; system VPN approval; ... launch,
  message, stop, host termination"*, which is exactly where V1–V3 belong; and
  ADR-028(a) rejects spreading one physical sitting across several nodes. A new
  task would have duplicated the only physical-Mac node on the board. V1–V3 were
  therefore appended to 9yp8to's notes instead.
* **Dependencies were verified, not added.** `TASK-260728-7ii1xz.blocks` already
  contains all five downstream tasks plus `TASK-260715-ypo7yo`, and each of the
  five carries `TASK-260728-7ii1xz` in `blockedBy`. Checked this session; no link
  mutation was needed. `task-board validate` → *Board is valid. No issues
  found.*, exit 0.
* **The research question this task answers is the one the spec genuinely leaves
  open** — quoted verbatim in §1, with the spec sentence it contradicts.
* **Artifacts produced** are attached as task-scoped outcome resources: this
  decision, `TASK-260728-7ii1xz_results.md`, **four** evidence logs, and **four**
  harness files (r2 adds `…_system-domain-and-lifecycle-04.log` and
  `…_kcdomain.swift`). No diagram was produced; none was needed to state a
  transport choice and an entitlement verdict.
* **r2 created no board element either**, and the same reasoning holds: V4 and V5
  are physical checks on the one physical-Mac node, and the three corrected
  assumptions landed on tasks that already own them. The one thing r2 *did*
  reconsider was whether the launch-on-message uncertainty deserves its own
  research task — it does not: it is a single pass/fail observation inside a
  sitting `TASK-260715-9yp8to` already scopes, and the contract is designed to be
  correct under either outcome.

## 10. Scope discipline

No board element was created, renamed, deleted, or re-linked. No product source,
spec file, generated project, or the ypo7yo matrix was modified. No portal
mutation was performed or authorized. Notes were added to the affected tasks
recording the revised assumption and pointing here.

No secret value, key material, passphrase, key path, key ID, issuer ID, or
account credential appears in any artifact. The only value written to any
keychain during these experiments was the fixed literal `PROBE-NOT-A-SECRET`,
in the user's own login keychain, deleted afterwards (`OSStatus=0`). Third-party
bundle identifiers and Team IDs quoted as evidence are public code-signing
metadata readable from any installed copy of those products.

r2 added one experiment (E8–E10, `kcdomain.swift`) and one documentation
retrieval. The only value written to any keychain in r2 was the same fixed
literal `PROBE-NOT-A-SECRET`, into a **throwaway keychain created under
`TMPDIR` and deleted in the same run** (`SecKeychainDelete` → `OSStatus=0`).
That keychain's unlock password was 32 random bytes from
`SecRandomCopyBytes`, never printed and never persisted. The real System
keychain was **read for resolution metadata only** — a path — and never
written.

One side effect worth disclosing: the E7 check
(`security dump-keychain -d /Library/Keychains/System.keychain`) raised a macOS
authorization prompt on the console before being killed at the 120-second
timeout. That refusal-to-proceed **is** the recorded result. No secret was read.

This was autonomous architecture work. It required no human decision and is not
a Stop-The-Line condition.

---

## 11. Revision log

### r2 — 2026-07-28 — closes `TASK-260728-7ii1xz_reviewer-verdict-01.md`

The selected transport (candidate **D**) and the entitlement verdict (**keep
prohibited**) are unchanged. All three findings were independently re-checked
before being accepted, and one of them turned up a defect the reviewer had not
named.

**F1 — provider-stopped revocation was wrongly declared asynchronous. CONFIRMED,
corrected.** Verified against Apple's published API reference, not taken on
trust: `sendProviderMessage(_:responseHandler:)` states *"If the extension is not
running, it should be launched to handle the message."* r1's contrary claim came
from misreading the SDK header for `handleAppMessage:` — that header describes
*who sends* the message, not a liveness precondition. Corrections: new §5.0
states the launch contract and the non-reciprocal direction; new §5.2 replaces
the single yes/no guarantee with a five-state table keyed to the SDK's documented
error set (`NEVPNErrorConfigurationInvalid` / `NEVPNErrorConfigurationDisabled`);
§5.1.3 moves seeding out of `startTunnel` so the credential is normally at rest
before any start; §5.1.4 makes `startTunnel` read-only and fail fast, deleting
the r1 `awaitingCredential` wait inside the 60-second budget; §5.1.6 keeps the
sweep but demotes it to crash-recovery defence. Flowed into `379cpk`, `29ws8l`,
and `2hhh7x` per the verdict. Candidate B stays rejected — its failure was never
the seed direction, it is that a memory-only provider has nothing to read on a
System-Settings or NE-initiated start.

**F2 — the contract hard-coded a deprecated System-keychain path. CONFIRMED,
corrected, and one further defect found.** §5.1.2 now resolves the keychain with
`SecKeychainCopyDomainDefault(kSecPreferencesDomainSystem, …)`. Physically
verified (E8/E9): it returns `OSStatus=0`, resolves to exactly the literal r1
hard-coded, and the system domain's search list has exactly one member — so the
fix is behaviour-preserving. **Additional defect not in the verdict:** r1
specified `kSecUseKeychain` for the *query*, but `SecItem.h` defines that key for
`SecItemAdd` only; scoping a search takes `kSecMatchSearchList`. The contract now
splits the two by operation, and E10 exercised the whole shape end to end with a
negative control proving the search list really scopes the query. The deprecation
of the entire `SecKeychain` surface is recorded rather than hidden, with physical
V1 kept as the release gate.

**F3 — the ypo7yo amendment was incomplete. CONFIRMED, corrected.** Re-read the
live matrix JSON: the row does carry `resolutionOwner: "TASK-260728-7ii1xz"` and
an `amendmentRule` whose antecedent this decision makes **true** while its
consequent is **false** — a live instruction to re-grant the row on the exact
reasoning the decision refutes. §7 now carries a field-by-field table covering
all five keys on the row, M1 requires both stale fields deleted, M5 is promoted
from "consider" to the required replacement rule with a correctly narrow
reopening condition, and new M7 covers `revision` / `revisionLog` / the
exhaustive validator assertions.

**Evidence.** New log `TASK-260728-7ii1xz_system-domain-and-lifecycle-04.log`,
new harness `TASK-260728-7ii1xz_kcdomain.swift`. New verifications **V4** and
**V5** handed to `TASK-260715-9yp8to` for the one claim documentation cannot
settle. `LOGBOOK.md` 0822 corrected.

### r1 — 2026-07-28

Initial decision: candidate D selected from five, entitlement verdict issued,
downstream mapping produced, physical evidence P1–P4 / E0–E7 recorded.
