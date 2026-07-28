# TASK-260728-7ii1xz — handoff evidence

Revision **2026-07-28.r2**. Status: **ready for review**. Decision reached, not
blocked. No portal mutation, no matrix edit, no spec or product source change.

r2 closes reviewer verdict 01 (F1, F2, F3). **The transport selection and the
entitlement verdict are unchanged**; the lifecycle contract around them is
corrected. Full revision log in §11 of the artifact.

Full artifact: `TASK-260728-7ii1xz_macos-credential-transport-decision.md`.

## Decision in one line

The macOS packet-tunnel provider owns a **file-based system-domain keychain**
item, seeded from the containing app over the **NE app-message channel**
(`sendProviderMessage` → `handleAppMessage`), which is documented to **launch a
stopped provider** to handle the message. The provider needs **no keychain
entitlement at all**.

## Amendment verdict (AC4)

`keychain-access-groups` on `works.relux.tunnel.mac.tunnel` — **KEEP
PROHIBITED**, upgraded from `prohibited-pending-decision` to settled
`prohibited`. The file-based keychain is ACL-controlled (`SecAccess`), not
access-group-controlled, so the entitlement is inapplicable, not merely unused.
**Applying owner: `TASK-260715-ypo7yo`** (matrix §11 amendment rule). Closes
**OC-1**; downgrades **OC-4** to "verify only if XPC is ever selected".
Consequential items **M1–M7** are listed in §7 of the artifact, including a
field-by-field table requiring the deletion of the row's now-stale
`resolutionOwner` and `amendmentRule` (r2 / F3).

## Acceptance criteria

| AC | status | evidence |
| --- | --- | --- |
| 1 — open question verbatim + the two Apple-sourced facts | met | artifact §1–§2. TN3137 quoted verbatim; DTS threads 721674, 133933, 656239, 759976, 775935. Fact 1 physically confirmed: a shipping NE sysex running at **uid 0** |
| 2 — ≥3 candidates on all five dimensions, each with what it cannot guarantee | met | §4: five candidates (A shared DP keychain, B memory-only IPC seed, C custom XPC, D System keychain + IPC seed, E root-owned encrypted file), each with an explicit "cannot guarantee" row |
| 3 — one transport selected with rationale | met | §5, candidate D, five ordered reasons; lifecycle in §5.0, contract in §5.1, revocation states in §5.2 |
| 4 — explicit amendment verdict naming ypo7yo as applying owner | met | §7 — verdict, a field-by-field amendment table, and M1–M7 |
| 5 — privacy-safe physical check with commands and exit codes, limitations named | met | §3.1 (**13** confirmed checks; E8–E10 added in r2), §3.3 (four named limitations, including that **no code was run as root** — `sudo -n true` exit 1) plus the §5.0 limitation that launch-on-message is documented but not locally executed → V4 |
| 6 — five downstream tasks with the specific assumption each must revise | met | §8, one row each for 379cpk, 1o9wjz, 29ws8l, 2hhh7x, 3f4lxy, plus 9yp8to and ypo7yo |

## The decisive physical finding

`/System/Library/Sandbox/Profiles/application.sb` on macOS 26.5 (25F71),
sha256 `2e711078a64627c860ff35daa74c4c97a6e8471f99a6c8669650afbe84089218`:

```
792:(when (entitlement "com.apple.developer.networking.networkextension")
793-      (allow file-read* file-write* (subpath "/Library/Keychains")))
```

An NE-entitled process already has read+write to the System keychain from the
base App Sandbox. This is why the selected transport costs zero entitlements,
and it shows that Surfshark's shipping `/Library/Keychains/` temporary exception
is redundant on current macOS — presence in a shipping bundle is not proof of
requirement.

## Gates

| gate | result |
| --- | --- |
| `zsh run-probe.sh` (E0–E6, 24 commands) | exit 0; every step's own exit code recorded in the log |
| `zsh collect-evidence.sh` (P1–P4) | exit 0; the single non-zero step is the intended `ls: /private/var/root/Library/Group Containers: Permission denied`, exit 1 |
| `swiftc -O kcprobe.swift` | exit 0 |
| **`swiftc -O kcdomain.swift`** (r2) | exit 0; deprecation warnings only, expected — the whole `SecKeychain` surface is deprecated and has no replacement for daemons |
| **`./kcdomain`** (r2, E8–E10) | exit 0; system-domain resolution `OSStatus=0` → `/Library/Keychains/System.keychain`, search list count 1, contract round-trip all `OSStatus=0`, negative control `-25300` as required |
| `swift test` (r2) | **exit 0** — 335 tests in 29 suites passed. Re-run as the verdict required; no product source was touched by this task, so this confirms no regression rather than proving the decision |
| `task-board validate` (r2) | **exit 0** — *"Board is valid. No issues found."* The `PARENT_STATUS_MISMATCH` verdict 01 saw was an artefact of validating while this leaf sat at `reviewing` under a hard-blocked parent still at `analysis`; it does not reproduce now |

## How verdict 01 was closed (r2)

Each finding was re-verified before being accepted, not taken on trust.

| # | finding | outcome | evidence |
| --- | --- | --- | --- |
| **F1** | provider-stopped revocation wrongly declared asynchronous | **CONFIRMED, corrected** | Apple's API reference for `sendProviderMessage(_:responseHandler:)`: *"If the extension is not running, it should be launched to handle the message."* r1's contrary claim misread the `handleAppMessage:` SDK header, which describes who *sends* a message, not a liveness precondition. New §5.0 (launch contract, and the non-reciprocal direction that keeps candidate B rejected), new §5.2 (five-state revocation table keyed to the SDK's documented `NEVPNErrorConfigurationInvalid` / `…Disabled` set). Seeding moved out of `startTunnel`; `startTunnel` is now read-only and fails fast; the sweep is demoted to crash-recovery defence. Flowed into `379cpk`, `29ws8l`, `2hhh7x` |
| **F2** | contract hard-coded a deprecated System-keychain path | **CONFIRMED, corrected — plus one further defect found** | §5.1.2 now resolves via `SecKeychainCopyDomainDefault(kSecPreferencesDomainSystem, …)`, physically verified (E8/E9: `OSStatus=0`, resolves to exactly the literal r1 hard-coded, system-domain search list count 1) so the fix is behaviour-preserving. **Not in the verdict:** r1 also specified `kSecUseKeychain` for the *query*, but `SecItem.h` defines that key for `SecItemAdd` only — scoping a search takes `kSecMatchSearchList`. Contract now splits them by operation; E10 exercises the whole shape with a negative control |
| **F3** | ypo7yo amendment incomplete | **CONFIRMED, corrected** | Re-read the live matrix JSON: the row does carry `resolutionOwner` and an `amendmentRule` whose antecedent this decision makes *true* while its consequent is *false* — a live instruction to re-grant the row on the reasoning the decision refutes. §7 now has a field-by-field table over all five keys on the row; M1 requires both stale fields deleted; M5 is promoted from "consider" to the required replacement rule with a narrow reopening condition; new M7 covers `revision` / `revisionLog` / the exhaustive validator assertions |

## Reviewer focus

1. **§5.0 rests on a documentation sentence, not a local execution.** Apple says
   the extension "should be launched" to handle an app message; no signed,
   approved provider exists before Ceremony C1, so this was **not** run here.
   The contract is deliberately designed to be correct either way — the keychain
   item, not the message, is the provider's source of truth at start — so a
   negative result degrades to r1's behaviour rather than breaking. Confirming it
   is **V4** on `TASK-260715-9yp8to`. If the reviewer thinks a design may not
   rest on a documented-but-unexecuted contract even with that fallback, say so;
   the alternative is to ship r1's weaker guarantee deliberately.
2. **§5.2 case 4 residue.** If the system extension is uninstalled, macOS removes
   its container but the system-domain keychain item is not in that container and
   survives. `TASK-260715-29ws8l` is told to specify this. Flagged because it is
   a real "secret outlives the app" path and it is easy to miss.
3. **§5.1.2 uses a deprecated API surface deliberately.** The whole file-based
   `SecKeychain` / `SecAccess` path is `API_DEPRECATED(… macos(10.2, 10.10))` yet
   still present in the macOS 26.5 SDK and is Apple's documented option for
   daemons, which have no alternative. Recorded rather than hidden; physical V1
   is the release gate.
4. §6 — the App Group container divergence is a secondary finding outside the
   literal question. It is reported rather than dropped because
   `TASK-260715-3f4lxy` is blocked on this task and would otherwise build on a
   channel that does not exist on macOS. It is corroborated, not directly
   observed; §3.3 says so.
5. §7 M4 — the `macos.host` keychain row is left granted with a narrowed
   purpose. That is a recommendation, not a verdict; AC4 scopes the verdict to
   the provider row only.

## Scope and safety

No board element created, renamed, deleted, or re-linked. Notes were set on the
five affected downstream tasks and appended on `TASK-260715-9yp8to` recording
the revised assumption and pointing at this artifact. No secret value, key
material, passphrase, key path, key ID, issuer ID, or account credential appears
anywhere. The only value written to a keychain during the experiments was the
fixed literal `PROBE-NOT-A-SECRET` — in r1 into the user's own login keychain,
deleted afterwards with `OSStatus=0`; in r2 into a **throwaway keychain created
under `TMPDIR` and deleted in the same run** (`SecKeychainDelete` →
`OSStatus=0`), whose unlock password was 32 bytes from `SecRandomCopyBytes`,
never printed and never persisted. The real System keychain was read for a
**path** only and never written.

Disclosed side effect: the E7 check (`security dump-keychain -d
/Library/Keychains/System.keychain` as uid 502) raised a macOS authorization
prompt before being killed at the 120-second timeout, exit 143. That refusal is
the recorded result; no secret was read.

Autonomous architecture work. No human decision was required; this is not a
Stop-The-Line condition.
