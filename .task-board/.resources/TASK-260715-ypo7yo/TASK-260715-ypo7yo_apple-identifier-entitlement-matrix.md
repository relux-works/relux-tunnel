# Apple identifier and entitlement matrix

`TASK-260715-ypo7yo` — decision artifact, revision **2026-07-28.r12**. Produced on
macOS 26.5 (25F71), Xcode 26.5 (17F42). Status: **pending independent architecture
review**; no portal mutation may begin until that review is accepted.

The machine-readable form of this document is
`TASK-260715-ypo7yo_apple-identifier-entitlement-matrix.json`. **The JSON is
authoritative**; this file is its rationale. Generated targets, portal
provisioning, archives, and entitlement checks consume the JSON, not this prose.

> **r12 changes.** This revision closes the single blocking finding of
> `TASK-260715-ypo7yo_reviewer-verdict-10.md` and its required rework items 1–3.
> **No entitlement decision, identifier, target row, profile row, record,
> assertion, assertion scope, open constraint, dependency edge or Ceremony C1
> mutation set changes.** One gate gets harder.
>
> **F1 — membership in the issued revision set is not provenance.** r11 required
> `reviewedIn` to equal *some* revision this contract had issued. Its own
> derivation contract already said that was not enough — pointing `reviewedIn` at
> an older revision implies a review that did not happen — and r11 wrote that gap
> down under a *Stated bound* heading instead of closing it. The reviewer moved
> `X1-C1.reviewedIn` from `r10` to `r2`, a revision that predates the conditional
> register entirely, and `validate-matrix.py` reported **PASS** and exited **0**,
> where a negative control must exit 1. Reproduced against the unmodified r11
> artifact before the finding was accepted. **Writing a gap down is not closing
> it.**
>
> **`reviewedIn` is now derived from evidence older than the claim.** New rule
> **X1-P** (`exceptionReviewProvenance`, §4.5) derives the revision each register
> entry first entered this contract in. The strong evidence class is
> **snapshot-proven**: the per-revision baselines attached to this task are
> digest-pinned and are immutable inputs to the preservation harnesses, so
> `X1-C1`'s introducing revision is *computed* — absent from the `r8` and `r9`
> snapshots, present in `r10` — from files no edit to this JSON can reach. The
> weaker class, **summary-attested**, is available only for an entry older than
> the oldest attached snapshot, and the gate **refuses** it wherever the chain can
> decide. Both are cross-checked against `revisionLog[].introduces`. The chain
> cannot be narrowed either: it must run contiguously to the revision this contract
> supersedes, and every baseline sitting beside the contract must be declared in
> it. It closes here: gate **R39** now stands on **64** negative mutations,
> including three that corrupt a *baseline* rather than a claim about one.
>
> **The active register was the worse half, and no verdict had reported it.**
> `reviewedExceptions[].reviewedIn` was required only to be **non-empty**, so it
> accepted `2026-07-28.r99` — a revision that has never existed, the exact case the
> conditional register had gated since r11 — and the active register is the one
> whose entries authorise an exception that **is** in a signed bundle. Both
> registers are gated here, each under the rule that already owns it: **R26** for
> the active register, **R39** for the conditional one, so verdict 10's own control
> fails under the rule it named.
>
> **What did not change.** Every identifier, every entitlement decision, every
> profile row, `X1-C1`'s own fields, and **Ceremony C1's authorized entries** are
> byte-for-byte what r11 left — asserted by `preserve-r12.py`, not claimed.

> **r11 changes.** This revision closes the single blocking finding of
> `TASK-260715-ypo7yo_reviewer-verdict-09.md` and its required rework items 2–5.
> **No entitlement decision, target row, profile row, record, assertion, assertion
> scope, open constraint or Ceremony C1 mutation set changes.** Two gates get
> harder.
>
> **F1 — an equality between two copies of a value is not a review.** r10 modelled
> the macOS 15.0 sandbox question correctly and pre-authorized exactly one
> exception, `X1-C1`. But `R39` established that exception by requiring the
> register entry and its row to *agree*, so a **coordinated** edit of both copies
> passed: the reviewer widened the path from `/Library/Keychains/` to `/`, dropped
> `developer-id` from the armed channels, and moved the arming owner to an
> unrelated task — and `validate-matrix.py` exited **0** on all three, where a
> negative control must exit 1. What makes `X1-C1` pre-authorized is that this
> contract reviewed one *exact* exception; a field that can move without failing a
> gate is not the field that was reviewed, so the pre-authorization would launder
> whatever the field became.
>
> **Every field is now derived, and each derivation bottoms out on something a
> coordinated edit cannot restate.** Rule **X1** gains
> `conditionalExceptionDerivation` (§4.5): the *target* from the unique row
> carrying the K3 version scope; the *key* pinned and cross-checked against K3's
> own arming instruction; the *value set* by a **path-subtree bound** — no value
> may be an ancestor of the reviewed path, which fails on `/` however many copies
> agree; the *channel set* from the target's own channels **in full**, because a
> base sandbox profile does not vary by signing channel; the *arming owner* from
> K3's resolution owner, cross-checked against the declared consumers rule **D1**
> requires to exist on the live board; the *review revision* from the revision log;
> and the *scope sentence* as a rendered clause. It closed there at
> **39 negative mutations behind R39** — including the two the
> sweep found that the verdict had not named, a coordinated **target** move and a
> `reviewedIn` naming a revision that never existed. The *review revision* is the
> one r11 left bounded to membership, which is what verdict 10 then found.
>
> **The stale count was invisible twice over.** r10's summary said one number for
> `R39`'s mutations and §13 said another. Rule **N1** could see neither: the shape
> it scans for was `<n> keys`, and both sentences sat in regions the scan skipped —
> §13 by exclusion, the preamble *wholesale*. So N1 gains the **harness-count**
> shape, the count is derived by the harness itself (`mutate.py` fails if its own
> entries disagree with the declared number), and **the preamble is scanned**. A
> historical figure that must stay as it was is now a named `excludedPhrases` entry
> with a reason, the way §9.1's is — not a switched-off region. Closing that class
> immediately surfaced a third stale number one paragraph away: §9.2 claimed the
> validator applied 36 rules over R1–R36 while it gated R2–R39. It is derived now
> too.
>
> **What did not change.** Every identifier, every entitlement decision, every
> profile row, `X1-C1` itself, and **Ceremony C1's authorized entries** are
> byte-for-byte what r10 left — asserted by `preserve-r11.py`, not claimed.

> **r10 changes.** This revision closes the single blocking finding of
> `TASK-260715-ypo7yo_reviewer-verdict-08.md`. **No entitlement is granted, no
> target row moves into an allowlist, no record, profile row or C1 mutation
> changes, and no count moves.**
>
> **F1 — the decision was right for the OS it was taken on, and silent about every
> other one.** r4 settled `macos.provider` with no keychain row *and* no file
> exception, because `application.sb:792-793` already grants `/Library/Keychains`
> read/write to any Network Extension process. Every observation behind that was
> read on **macOS 26.5 (25F71)**. The binding deployment floor for generated
> targets is **macOS 15.0**. A base sandbox grant is a property of the *running
> system*, not an invariant of this contract — so the contract was asserting, for
> the floor, something it had never read there. Because this matrix is the source
> for generated entitlements *and* for the automated allowlist checks, a file
> exception genuinely required at the floor would have been rejected as an
> **unreviewed relaxation** under rule X1 and assertion A10a, on a supported OS.
>
> **The floor could not be read here, and r10 does not pretend otherwise.** This
> environment has no macOS 15 host, virtual machine, installer, or SDK-resident
> sandbox profile — only Xcode 26.5 and macOS 26 SDKs — and Apple does not document
> `application.sb` contents. So the gap is **modelled** rather than closed: new
> **rule K3** (§4.4) states the version scope, names **`TASK-260715-1uxx3i`** —
> which already owns the `macos-15` minimum lane and already reaches this contract
> — as the owner that closes it, and **pre-authorizes** the exception an absent
> floor grant would require. Rule **K1** gains an `osFloorScope` clause, rule **X1**
> gains a `conditionalExceptions` register **disjoint from its active one**, the
> provider keychain row gains `osVersionScope` and a floor clause in its reopening
> condition, **OC-5** tracks the gap, and assertion **A19** makes the unarmed state
> machine-checkable. Gate **R39** and assertion **A19** make every part of it fail
> closed. *(r10 stated a mutation count here that disagreed with the harness; the
> live count is derived, and now lives in the r11 summary above.)*
>
> **What did not change.** `keychain-access-groups` stays `prohibited` on
> `macos.provider` for the reason **K1** already gives — that half of the decision
> rests on the access-control model of the file-based keychain and is
> version-independent. A temporary file exception is **not** an App ID capability,
> so **Ceremony C1's authorized entries are untouched** in either direction.

> **r9 changes.** This revision was **not requested by a reviewer verdict** — it is
> a self-audit run after the r8 handoff, and it reports what the audit found. **No
> entitlement decision changed, no target row moved, no record, profile row,
> assertion or C1 mutation set changed.** Two contract-versus-board rules.
>
> **Rule D1** (`consumerDependencyContract`, §12) — every board element this
> contract names as an obligation owner is a **declared consumer**, and a declared
> consumer must appear in `consumers` **and transitively depend on this task on the
> live board**. Three declared consumers had **no dependency path to this task at
> all**: `TASK-260715-1o9wjz`, `TASK-260715-3f4lxy` and `TASK-260715-29ws8l`. A
> `max_parallel=1` scheduler could have run all three while this matrix was still in
> `analysis` under its eighth changes-requested verdict, authoring the macOS
> credential resolver, the snapshot loader and the profile-trust contract against a
> matrix nobody had accepted. Four more elements carrying obligations were missing
> from `consumers` entirely. This is the **verdict-05 F2 class one field over**:
> verdict 05 checked what a consumer *says*, rules A1 and P1 check which *revision*
> it names, and nothing checked *when it runs*. **One board edge** —
> `TASK-260715-29ws8l` blocked by this task — closes all three reachability gaps,
> because 29ws8l already blocks the other two; gate **R37** plus a new **D1 block**
> in `check-portal-consumer.py` make a missing edge fail closed.
>
> **Rule N1** (`numericClaimContract`, §9.4) — entitlement-allowlist counts and the
> rendered key list are now **derived** from the rows in both artifacts. §9.1 records
> this class biting once already: r3's prose said *"exactly seven keys"* over a list
> of **ten**, r4 corrected it by hand to **nine**, and r5 moved it again to **eight**
> when rule K2 withdrew the keychain group. Three revisions, three numbers, three
> hand corrections. r6 built a count scan for App Group **record** counts after
> verdict 05 exposed a stale one and stopped there, so the other live count class
> stayed unchecked for three more revisions. Both surviving numbers were
> **recomputed** here and are correct — but nothing was checking them.

> **r8 changes.** This revision closes both blocking findings of
> `TASK-260715-ypo7yo_reviewer-verdict-07.md`. **No entitlement decision changed,
> no target row moved, no record changed, and the C1 mutation set is identical to
> r7** — both findings are assertions that had gone stale against rows they are
> supposed to project. **F1:** **A5** claimed `application-groups` is present on
> *every* iOS bundle, which r5 made false for the two iOS probe rows and which
> **A18** directly contradicted; an entitlement check that followed A5 would have
> over-entitled both disposable probes, and one that followed A18 would have
> violated A5. **F2:** **A9** claimed *every* development profile carries this
> Mac, while all four iOS development profiles declare their devices **deferred
> under ADR-024**. A5 is rescoped to the two production iOS rows; A9 is split into
> **A9a** (macOS, four Mac Development profiles), **A9b** (iOS, deferred, not
> created at C1) and **A9c** (the two Developer ID profiles).
>
> Neither fix is left as a corrected string. r6 closed exactly this defect class
> for the cross-platform **summary** (rule **S1**) and left the **assertion list**
> — the other prose projection of the same rows — unchecked, which is why two
> assertions could sit stale under a 1024-check validator. New **rule S2**
> (`assertionScopeContract`, §9.3) gives every scope-bearing assertion a scope
> **derived three ways** from the authoritative rows, new gates **R35**/**R36**
> recompute and compare them, and the **partition** check that A5 and A18 were
> violating now runs for **every** registered entitlement key. Registering the
> existing assertions found a **third** instance of the same class that no verdict
> had reported — this document's own A6 row still granting `macos.host` the
> Keychain group r5 removed; see §13. Assertion scope clauses are now rendered
> here under gate control, so the prose cannot drift from the contract again.

> **r7 changes.** This revision closes the single blocking finding of
> `TASK-260715-ypo7yo_reviewer-verdict-06.md`. **No entitlement decision changed,
> no target row moved, and the authorized mutation set is identical to r6** — this
> is an authorization-contract correction. **F1:** Ceremony C1's board scope named
> the **superseded** revision `2026-07-28.r5` — the revision verdict 05 had
> *rejected* — while enumerating r6's mutations correctly. The human authorization
> node named by AC5 was asking the operator to approve a rejected revision. The
> scope now names the current revision, and **the class is closed rather than the
> label patched**: new **rule A1** (`authorizationNodeContract`, §6) pins the
> authorization edge the way **rule P1** pins the mutation edge; its
> `revisionPinRule` **derives** the banned superseded set from `revisionLog` so it
> cannot fall behind a bump; the r6 board gate is extended from **one** live
> consumer to **both** consumers this contract names; new gate **R34** checks the
> A1 pin and the revision bookkeeping itself; and **`amendmentRule` now requires
> every future amendment to re-point both pinned board consumers** — the reason
> this happened is that r6 bumped the revision and re-pointed only one. The board
> gate also gains **negative gates** for the first time (§9.2): r6's gate was only
> ever run in the passing direction, so nothing proved it would fail closed. The
> class was **swept** rather than assumed bounded — all 402 live board elements
> were scanned, which found one instance the reviewer did not report; see §13.
> The stale `check-portal-consumer.sh` reference is corrected to `.py`.

> **r6 changes.** This revision closes both blocking findings of
> `TASK-260715-ypo7yo_reviewer-verdict-05.md`. **No entitlement decision changed
> and no target row moved** — both findings are contract-consistency defects.
> **F1:** `crossPlatformRules[2]` still asserted the superseded r4 Keychain
> contract (the shared access group granted to the macOS host) while the rows,
> K2, the record's `consumedByTargets`, A6/A17 and the r5 revision log all said
> iOS-only. The sentence is corrected (§7) and **the class is closed rather than
> the string patched**: new **rule S1** (`crossPlatformSharingContract`) gives
> every cross-platform sentence a structured rule, new gate **R32** derives each
> grant set from the rows and checks the prose against it, and **R33** requires
> the same grant clauses in this document so the two artifacts cannot drift
> either. R32's count scan then found a **third** stale summary neither the
> reviewer nor r5 had spotted — `appGroupLeastPrivilegeRule` still counted r4's
> two App Group records — and `appGroupStyleRule`'s "one record per family" is
> rewritten (§4.3). **F2:** `TASK-260715-3jloqy`, the unattended task that
> *spends* the C1 authorization, still carried the pre-r5 capability contract, and
> its AC2 ("packet-tunnel entitlement **only on provider identifiers**") was a
> material defect independent of r5 — Apple requires the entitlement on the
> containing app too. Its description, scope, AC and checklist are corrected on
> the board, pinned here as **rule P1** (`portalMutationTaskContract`), and gated
> by `TASK-260715-ypo7yo_check-portal-consumer.py` (§6, §9.2). See §13.
>
> **r5 changes.** This revision closes all three blocking findings of
> `TASK-260715-ypo7yo_reviewer-verdict-04.md`. **F1:**
> `keychain-access-groups` is now **prohibited on `macos.host`**, and therefore
> on all four macOS targets. New **rule K2** (§4.4) states the test **K1 never
> covered** — the entitlement's only function is *sharing*, and the macOS host
> has no second member to share with, because K1 excludes the root/system-domain
> provider and neither probe touches the Data Protection Keychain. The host keeps
> full access to its own items through the **default access group** the injected
> `com.apple.application-identifier` provides, which is Apple's documented
> behaviour, not an inference (§4.4, **D-8**). K2 also records the one real
> consequence: **the macOS default group moves** from the shared literal to the
> app-ID literal, which `TASK-260715-379cpk` must be authored against. **F3:**
> `com.apple.security.application-groups` is now **prohibited on the iOS probe
> pair** (§4.3, **D-9**) — `TASK-260715-1jckn0` scopes the probe to the
> `NETunnelProviderManager` lifecycle and versioned app messaging and names no
> shared container, so **rule G4 gains a `probeRule`**: a probe inherits
> identifiers and profile classes, never entitlements. That left
> `group.works.relux.tunnel.probe` with no consumer, so **the record is deleted**
> and **rule G3** is restated as the stronger property that no probe carries a
> group at all. One App Group record remains. **F2:** `TASK-260728-q5kjta`'s
> scope and AC4 were corrected **on the board** to match `c1AuthorizationScope`
> exactly (§6). New gate **R31**, new assertions **A17** and **A18**. Every r2/r3/r4
> decision the reviewer listed as acceptable is preserved; see §13 for how both
> findings were re-verified before being accepted.
>
> **r4 changes.** This revision closes the single blocking finding of
> `TASK-260715-ypo7yo_reviewer-verdict-03.md` and applies the
> `TASK-260728-7ii1xz` amendment packet (M1–M7), which arrived after verdict 03
> was written. **`com.apple.security.application-groups` is now prohibited on all
> four macOS targets and granted on iOS only** — new **rule G4** (§4.3), decided
> on a grant-by-grant survey of the system App Sandbox profile rather than on a
> future transport (§4.3, **D-7**). **Ceremony C1 shrinks**: it creates no App
> Group record and enables the App Groups capability on no App ID (§6).
> `keychain-access-groups` on the macOS provider moves from
> `prohibited-pending-decision` to a **settled** `prohibited` and loses the two
> fields that existed only to keep it open; **rule K1** (§4.4) replaces the
> deleted `amendmentRule` with the correct, narrow reopening condition. **OC-1 is
> closed**; **OC-4** is dormant (§8). New gates **R28**, **R29**, **R30** and
> assertion **A16**. §9.1's key count is corrected — and the list itself is one
> shorter, because the host no longer authors an App Group. Every accepted r2/r3
> decision is preserved; see §13 for how the finding was re-verified before it was
> accepted.
>
> **r3 changes.** This revision closes the single blocking finding of
> `TASK-260715-ypo7yo_reviewer-verdict-02.md`. The sandboxed macOS host now
> carries `com.apple.security.temporary-exception.mach-lookup.global-name` with
> Sparkle's `-spks` / `-spki` endpoints (§4.2, **D-6**), and the same spec clause
> that mandates it also bans unreviewed exceptions — so **rule X1** (§4.5) adds a
> reviewed-exception register and an explicit prohibited set for Hardened Runtime
> relaxations. Assertions **A10e**, **A14** and **A15** make all of it checkable
> against a signed bundle, and the assertion set itself is now pinned so it cannot
> silently shrink again (**R27**). Every r2 decision is preserved unchanged; the
> finding was re-verified against the spec, this repo's own Sparkle research, and
> six shipping applications on this Mac before being accepted — see §13.
>
> **r2 changes.** This revision closes the four blocking findings of
> `TASK-260715-ypo7yo_reviewer-verdict-01.md`. Network Extension values are now
> keyed by **signing channel** (F1, §4.1); App Group identifiers moved to the
> **iOS style on both platforms** (F2, §4.3); the blanket "no key outside the
> matrix union" assertion is replaced with **explicit authored vs
> signing-generated allowlists** (F3, §9.1); App Sandbox rationale is
> **attributed per requirement source** (F4, §4.2). Identity, legacy, probe,
> environment, and dependency decisions from r1 are preserved unchanged. All four
> findings were independently re-verified against Apple sources and against three
> shipping products on this Mac before being accepted — see §13.

---

## 1. Team

| field | value |
| --- | --- |
| Organization | Relux Works, LLC |
| Team ID | `262RZ595FP` |
| Expected App ID Prefix | `262RZ595FP` |
| Development identity | `Apple Development: Ivan Oparin (FSPBF3QRXT)`, OU `262RZ595FP`, valid to 2027-07-27 |
| Distribution identity | `Developer ID Application: Relux Works, LLC (262RZ595FP)` |

The Team ID is **not a secret** — it is embedded in every signed binary and in
every provisioning profile. It is recorded here so entitlement checks have an
expected value. No certificate content, private key, key ID, issuer ID, or
account credential appears in this artifact.

**Rule T1.** Entitlement files, `Info.plist`s, and source MUST use
`$(AppIdentifierPrefix)` and `$(TeamIdentifierPrefix)`. The literal `262RZ595FP`
appears only in this contract and in verification expectations.

**Rule T2.** `AppIdentifierPrefix == TeamIdentifierPrefix == "262RZ595FP."` is an
**assumption**, not an observation. Teams created before ~2011 can have an App ID
Prefix that differs from the Team ID. `TASK-260715-3jloqy` MUST record the prefix
the portal actually shows and raise a blocker on mismatch. Silently adapting the
literals is prohibited.

---

## 2. Bundle identifiers

Four production identifiers, plus a disposable probe family. **Unchanged from r1.**

| key | platform | role | target name | bundle identifier | packaging | provisioned |
| --- | --- | --- | --- | --- | --- | --- |
| `macos.host` | macOS | host | `ReluxProxyMac` | `works.relux.tunnel.mac` | app | yes |
| `macos.provider` | macOS | provider | `ReluxProxyMacTunnel` | `works.relux.tunnel.mac.tunnel` | **system extension** | yes |
| `ios.host` | iOS | host | `ReluxProxyIOS` | `works.relux.tunnel.ios` | app | no — ADR-024 |
| `ios.provider` | iOS | provider | `ReluxProxyIOSTunnel` | `works.relux.tunnel.ios.tunnel` | appex | no — ADR-024 |
| `macos.probe.host` | macOS | host | `ReluxTunnelProbeMac` | `works.relux.tunnel.probe.mac` | app | yes |
| `macos.probe.provider` | macOS | provider | `ReluxTunnelProbeMacTunnel` | `works.relux.tunnel.probe.mac.tunnel` | system extension | yes |
| `ios.probe.host` | iOS | host | `ReluxTunnelProbeIOS` | `works.relux.tunnel.probe.ios` | app | no — ADR-024 |
| `ios.probe.provider` | iOS | provider | `ReluxTunnelProbeIOSTunnel` | `works.relux.tunnel.probe.ios.tunnel` | appex | no — ADR-024 |

### Containment

**Rule B1.** `provider bundle identifier == host bundle identifier + ".tunnel"`,
exactly. Apple requires an embedded extension's bundle identifier to be prefixed
by its containing app's; the fixed `.tunnel` suffix makes the relationship
derivable in both directions by a checker with no lookup table.

**Rule B2.** Embedding is one host to exactly one provider:

- macOS: `works.relux.tunnel.mac.app/Contents/Library/SystemExtensions/works.relux.tunnel.mac.tunnel.systemextension`
- iOS: `works.relux.tunnel.ios.app/PlugIns/works.relux.tunnel.ios.tunnel.appex`

### Why the probe identifiers are in this matrix

`.spec/goal-macos-v1.md` states that Hold H2 approves the system VPN for the real
app "whose bundle identifier differs from the probe's", and Ceremony C1
(`TASK-260728-q5kjta`) authorizes creation of **exactly** the macOS entries this
matrix names. `TASK-260715-1r0fxv` builds the probe from "approved Gate P0
identifiers and profiles". If the probe identifiers were absent here, the probe
could not be provisioned without a second human authorization sitting — precisely
what ADR-028 forbids. They are in scope by consumption, not an invention.
`TASK-260715-1jckn0`'s iOS probe identifiers are defined for the same reason and
deferred for the same reason as the rest of iOS.

---

## 3. Legacy identity — no collision, no repurposing

The shipped macOS product is `works.relux.proxy` (`ReluxProxy`, the SwiftPM
menu-bar SOCKS app), pinned by `scripts/check-legacy-preservation.sh:176`.

**Rule L1.** `works.relux.tunnel.*` is a new namespace. `works.relux.proxy` and
everything under it stays with the legacy lane. This matrix does **not** claim,
extend, rename, reuse, or retire it, and it prescribes no migration. The
coexist / replace / retire decision is owner decision D2 (`TASK-260715-35nc5m`);
the release-side identity and migration contract is `TASK-260715-1tzaed`. If D2
later chooses replacement, the migration is authored there and this matrix is
amended, never reinterpreted.

**Rule L2 — the concrete collision hazard.** The generated target *names* are
`ReluxProxyMac` and `ReluxProxyIOS`. A generator that derives a bundle identifier
from a target name produces `works.relux.proxy.mac` — inside the legacy identity
namespace. **Target name and bundle identifier are decoupled by this contract**;
`TASK-260715-uyju7n` and `TASK-260715-33oofa` must set identifiers explicitly
from the JSON. Assertion A11 and validator R4 reject it.

---

## 4. Entitlement matrix

Statuses: `required` (grant), `prohibited` (**settled** — never grant, with a
stated reopening condition), `prohibited-pending-decision` (withheld now,
amendable by a named task, and therefore obliged to name one),
`not-applicable` (the entitlement does not exist on that platform),
`required-adjacent` (needed to build/run but owned by another task and requiring
no portal record). `required` and `required-adjacent` are the **authored**
statuses — see §9.1.

After r4 **no row is `prohibited-pending-decision`**; the status stays in the
vocabulary because it is the correct shape for a future withheld-and-owned row.
A settled row may carry neither a `resolutionOwner` nor a row-level
`amendmentRule` — both exist only to hold a row open, and leaving them on a
settled row is what verdict-03's amendment packet caught (D-2). Validator **R13**
enforces both directions.

### 4.0 Signing channels

Everything below that varies by build configuration varies by **channel**, never
by identifier.

| channel | platforms | profile class | signing identity class | NE suffix | `get-task-allow` | C1 |
| --- | --- | --- | --- | --- | --- | --- |
| `development` | macOS, iOS | Mac Development / iOS App Development | Apple Development | **no** | yes | macOS only |
| `developer-id` | macOS | Developer ID Application | Developer ID Application | **yes** | no | no — `3gkwn0` |
| `app-store` | iOS | App Store Distribution | Apple Distribution | **no** | no | no — `3661ps` |

### 4.1 Network Extension entitlement — rule NE1

> **NE1.** `com.apple.developer.networking.networkextension` is carried by **both**
> the containing app and the embedded provider. Its value depends on the **signing
> channel**, not on the role and not on packaging alone: direct Developer ID
> signing uses the values with the `-systemextension` suffix; every other channel —
> App Store distribution **and development signing** — uses the values without it.

Apple DTS, verbatim:

> "When you build an app with an embedded NE extension, both the app and the
> extension must be signed with the `com.apple.developer.networking.networkextension`
> entitlement. This is a restricted entitlement, that is, it must be authorised by
> a provisioning profile."
>
> "The value of this entitlement is an array, and the values in that array differ
> depend on your distribution channel: If you distribute your app directly with
> Developer ID signing, use the values with the `-systemextension` suffix.
> Otherwise — including when you distribute the app on the App Store and when
> signing for development — use the values without that suffix."
>
> "Make sure you authorise these values with your provisioning profile. If, for
> example, you use an App Store distribution profile with a Developer ID signed
> app, things won't work because the profile doesn't authorise the right values."
>
> — <https://developer.apple.com/forums/thread/800887>

**This is what r1 got wrong.** r1 assigned `packet-tunnel-provider-systemextension`
to every macOS target unconditionally while authorizing Mac **Development**
profiles for all four macOS App IDs. Ceremony C1 would have provisioned
development profiles against a value development signing never uses.

Resulting values:

| target | `development` | `developer-id` | `app-store` |
| --- | --- | --- | --- |
| `macos.host` | `["packet-tunnel-provider"]` | `["packet-tunnel-provider-systemextension"]` | — |
| `macos.provider` | `["packet-tunnel-provider"]` | `["packet-tunnel-provider-systemextension"]` | — |
| `macos.probe.host` | `["packet-tunnel-provider"]` | — (never Developer ID signed, rule E3) | — |
| `macos.probe.provider` | `["packet-tunnel-provider"]` | — | — |
| `ios.host` | `["packet-tunnel-provider"]` | — | `["packet-tunnel-provider"]` |
| `ios.provider` | `["packet-tunnel-provider"]` | — | `["packet-tunnel-provider"]` |
| `ios.probe.*` | `["packet-tunnel-provider"]` | — | — |

No other provider value is granted anywhere. `app-proxy-provider`,
`content-filter-provider`, `dns-proxy-provider`, `dns-settings`, `relay` and
their `-systemextension` forms are listed as `forbiddenNetworkExtensionValues`
and rejected by assertion A13 / validator R24.

**Consequence for the probe.** Because the probe family is development-signed
only, it can prove the **development** entitlement shape and nothing else. The
Developer ID shape is first exercised under `TASK-260715-3gkwn0`. r1 implied the
probe proved the production entitlement shape; it does not.

**Consequence for Ceremony C1.** C1 enables the **Network Extensions capability
by name** on the four macOS App IDs and generates Mac Development profiles. The
values C1 puts in circulation are therefore the unsuffixed ones. The operator is
never asked to pick an entitlement value. See §6.

### 4.2 Other entitlements, and every host↔provider difference

| entitlement | macOS host | macOS provider | iOS host | iOS provider |
| --- | --- | --- | --- | --- |
| `com.apple.developer.system-extension.install` | `true` | **prohibited** | n/a | n/a |
| `com.apple.security.application-groups` | **prohibited** (G4) | **prohibited** (G4) | `["group.works.relux.tunnel"]` | same |
| `keychain-access-groups` | **prohibited** (K2, r5) | **prohibited** (K1, settled r4) | `["$(AppIdentifierPrefix)works.relux.tunnel.shared"]` | same |
| `com.apple.security.app-sandbox` | `true` (project) | `true` (**Apple**) | n/a | n/a |
| `com.apple.security.network.client` | `true` | `true` | n/a | n/a |
| `com.apple.security.network.server` | — | `true` | — | — |
| `com.apple.security.temporary-exception.mach-lookup.global-name` | `["$(PRODUCT_BUNDLE_IDENTIFIER)-spks", "$(PRODUCT_BUNDLE_IDENTIFIER)-spki"]` | — | — | — |

**D-1 — `system-extension.install`, macOS host only.** Only the containing app
calls `OSSystemExtensionManager` to activate and replace the embedded provider
(ADR-018's update flow). The provider never installs anything; granting it would
be privilege with no function. Confirmed against three shipping Developer ID
products on this Mac: every host carries it, no provider does.

**D-2 — `keychain-access-groups`, withheld from the macOS provider. Settled in
r4.** Two distinct facts, which r1 conflated:

1. The `.spec/security-privacy.md` design — secrets in the **Data Protection**
   Keychain shared host→provider through one access group — **cannot work here**.
   That keychain is available only to code running in a user context, and access
   groups share items between programs running as the **same user**. The macOS
   provider is a system extension running as **root**; the host runs as the
   logged-in user. iOS is unaffected: its appex runs as the same user as its host.
2. The entitlement itself **is** grantable to a root system extension and is used
   in production. On this Mac, PureVPN's packet-tunnel system extensions carry
   `keychain-access-groups` outright, and Surfshark's instead carries a
   temporary-exception path for `/Library/Keychains/` — both pointing at the
   **file-based System keychain**, not the Data Protection Keychain.

r3 withheld the row **because the purpose was undetermined**, pending
`TASK-260728-7ii1xz`.

**r4 settles it: `prohibited`, permanently, on a stronger reason than r3 had.**
That task selected the **file-based system-domain keychain**, seeded once from
the host over `NETunnelProviderSession.sendProviderMessage`. Apple TN3137: *"The
file-based keychain uses access control lists (`SecAccess`). The data protection
keychain uses keychain access groups."* Access on the selected path is a per-item
ACL. The entitlement is therefore **inapplicable to the mechanism actually used**,
not merely unnecessary — and the provider needs no keychain entitlement at all,
because the sandbox already grants what it needs. Verified independently for r4
by reading `/System/Library/Sandbox/Profiles/application.sb` on macOS 26.5
(25F71):

```
application.sb:792-793   (when (entitlement "com.apple.developer.networking.networkextension")
                               (allow file-read* file-write* (subpath "/Library/Keychains")))
application.sb:655-656   (global-name "com.apple.securityd.xpc")
                         (global-name "com.apple.SecurityServer")   ; every sandboxed process
```

The two fields that existed only to hold the row **open** are deleted with it:
`resolutionOwner` (this task *is* the resolution) and the old `amendmentRule`.
That rule said the row would be re-granted *"if the resolved transport gives the
provider direct keychain access"* — its antecedent is now **true** and its
consequent is **false**, so left in place it was a live instruction to re-grant
the row on exactly the reasoning the decision refutes. **Rule K1** (§4.4) is what
replaces it. Validator **R13** now rejects any settled row that keeps either
field; **R29** requires the settled row to state its reopening condition instead.
OC-1 is closed.

**D-3 — `network.server`, macOS provider only.** The internal HEV SOCKS boundary
binds a loopback listener inside the provider; a sandboxed process cannot bind
without it. It is an internal boundary, not a user-reachable proxy. The host
binds nothing.

**D-4 — App Sandbox: same value on both, different reason.** This is the F4
correction. Apple requires the **NE provider system extension** to be sandboxed.
Apple does **not** require the containing app to be sandboxed for direct
Developer ID distribution. Verified on this Mac:

| product (Developer ID, direct) | host `app-sandbox` | provider `app-sandbox` |
| --- | --- | --- |
| Tailscale `io.tailscale.ipn.macsys` | **false** | **true** |
| PureVPN `com.purevpn.app.mac` | **false** | **true** |
| Surfshark `com.surfshark.vpnclient.macos.direct` | **false** | **true** |

The sandboxed host is therefore **this project's own architecture decision**, from
`.spec/platform-distribution.md` ("Link and embed Sparkle only in the sandboxed,
hardened-runtime `ReluxProxyMac` host", `SUEnableInstallerLauncherService`, the
`-spks`/`-spki` Mach lookup exceptions) and ADR-018 — not an Apple rule. The JSON
records this as `requirementSource`: `apple-requirement` on providers,
`project-architecture` on hosts, `sandbox-consequence` for the network
client/server rows that only exist because their target is sandboxed, and
`platform-inherent` on iOS. Validator R21 rejects any host row that claims an
Apple requirement.

This also sharpens **OC-2**: none of the three shipping products exercises the
sandboxed-host + `system-extension.install` combination, so that shape has no
local precedent to lean on.

**D-5 — the NE value differs by channel, not by role or platform.** Both members
of a pair always carry the same value on the same channel (§4.1).

**D-6 — the Sparkle Mach lookup exception, macOS host only.** This is the
verdict-02 correction. D-4 already argued that the host is sandboxed *because* of
Sparkle, and quoted the spec clause naming the `-spks` / `-spki` exceptions — but
the matrix never authored the entitlement. The exhaustive allowlist of §9.1 would
therefore have **rejected a correctly built host**, which is the same defect class
as r1's F3.

`.spec/platform-distribution.md` is explicit:

> The sandboxed host enables `SUEnableInstallerLauncherService` and Sparkle's
> documented `<host-bundle-id>-spks` / `<host-bundle-id>-spki` Mach lookup
> exceptions. Because the host has outbound network-client access, Downloader,
> Installer Connection, and Installer Status XPC services stay disabled.

A sandboxed process cannot reach Sparkle's bundled `Installer.xpc`
(`CFBundleIdentifier` `org.sparkle-project.InstallerLauncher`) without a
`global-name` Mach lookup exception. Sparkle names its endpoints by suffixing the
host bundle identifier, so the value is authored with the
`$(PRODUCT_BUNDLE_IDENTIFIER)` build variable per the team rule in §1, and the
JSON also records `resolvedValue` — `works.relux.tunnel.mac-spks` /
`works.relux.tunnel.mac-spki` — because a **signed bundle carries the expanded
form**, and A14 has to be checkable against a bundle.

Verified on this Mac with `codesign -d --entitlements :-` — six shipping apps
carry exactly this pattern:

| app | sandboxed | mach-lookup values |
| --- | --- | --- |
| Mimestream `com.mimestream.Mimestream` | **true** | `-spks`, `-spki` — and nothing else |
| WhatsApp `net.whatsapp.WhatsApp` | **true** | `-spks`, `-spki` — and nothing else |
| Slipbox `ai.slipbox.macos.app` | **true** | `-spks`, `-spki` — and nothing else |
| BoltAI `co.podzim.boltai-mobile` | **true** | `-spks`, `-spki` + unrelated product endpoints |
| AdGuard Mini `com.adguard.safari.AdGuard` | **true** | `-spks`, `-spki` + its own helper |
| Tailscale `io.tailscale.ipn.macsys` | **false** | `-spks`, `-spki` |

Two things are worth stating rather than glossing over. First, **Tailscale — the
same Developer ID packet-tunnel host cited in D-4 — carries the exception while
being unsandboxed.** That is consistent, not contradictory: the exception is inert
without the sandbox. It does mean "a shipping product carries this key" is *not*
by itself evidence that the key is required; the requirement here comes from the
spec plus the sandbox. Second, Sparkle 2's framework binary contains **three**
endpoint suffixes — `-spks`, `-spki`, `-spkp`. Only the first two are entitled,
which matches the spec's decision to leave the Downloader, Installer Connection,
and Installer Status services disabled. **The two-value set is deliberate, not a
truncation.**

*Attribution: `project-architecture`, not `sandbox-consequence`.* Unlike
`network.client` — which any sandboxed process making outbound connections needs,
Sparkle or not — this key requires **two** independent project decisions to both
hold: ADR-018's choice of Sparkle with `SUEnableInstallerLauncherService`, **and**
the decision to sandbox the host. An unsandboxed Sparkle host needs no exception;
a sandboxed host without Sparkle needs no exception. It is not derivable from
"this target is sandboxed", so it is not a sandbox consequence. Validator R25
pins the attribution and R21 is unaffected.

`SUEnableInstallerLauncherService` itself is an **`Info.plist` key, not an
entitlement**, so it is out of this contract's scope. `TASK-260715-uyju7n` sets it
on the generated target; `TASK-260717-xempiv` owns the Sparkle integration.

### 4.3 App Group — one registered record, one literal, two purposes

**Rule G1 (revised in r2, restated in r6).** Every App Group record this contract
declares is allocated on the Developer website and claimed by the **identical
iOS-style literal on both platforms**. No team prefix is added on macOS. **How
many records exist is deliberately not stated here** — G1 read "one record per
family" until r6, which was true of r4's two-record world and false from r5
onward. The count lives in `appGroupDisjointnessRule.recordCount` (R11) and in the
two registered summary sentences (R32); see §7.

| | portal record | entitlement literal, iOS | entitlement literal, macOS |
| --- | --- | --- | --- |
| production | `group.works.relux.tunnel` | `group.works.relux.tunnel` | `group.works.relux.tunnel` |

**One record, since r5.** r1–r4 also declared
`group.works.relux.tunnel.probe`. When the iOS probe pair lost the entitlement
(**D-9**) that record had no consumer left, so it was **deleted** rather than
carried as deferred portal surface. Gate **R11** ties `recordCount` to the
declared records, so the table and the JSON cannot drift apart.

**Why this changed.** Apple distinguishes two App Group ID styles: an *iOS-style*
ID begins `group.`, is allocated on the Developer website, and is authorised by a
provisioning profile; a *macOS-style* ID begins with the Team ID and **cannot be
explicitly allocated on the Developer website**. Apple DTS, verbatim:

> "Starting in Feb 2025, iOS-style app group IDs are fully supported on macOS for
> all product types."
>
> "On 21 Feb 2025 we rolled out a change to the Developer website that completes
> the support for iOS-style app group IDs on the Mac. Specifically, it's now
> possible to create a Mac provisioning profile that authorises the use of an
> iOS-style app group ID."
>
> "With Xcode 16.3, it's now the default for macOS as well."
>
> "If you're writing new code that uses app groups, use an iOS-style app group ID."
>
> — <https://developer.apple.com/forums/thread/721701>

r1 registered `group.works.relux.tunnel` but made the macOS entitlement claim
`262RZ595FP.group.works.relux.tunnel` and called it the same record with a team
prefix. Those are two different identifiers in two different styles: the macOS
literal did not identify the portal record the artifact said it consumed. This
project is new and builds with Xcode 26.5, so it takes the current registrable
style on both platforms. `TASK-260715-uyju7n` must not override Xcode's
**Register App Groups** default back to the macOS style.

**Rule G2 — the literal is the same; the grant is not.**

- **iOS, production:** a genuinely shared filesystem container and `UserDefaults`
  suite. The host publishes the non-secret profile snapshot; the appex reads it.
  Same user, same context. **Granted** to `ios.host` and `ios.provider`.
- **iOS, probe:** **no grant** since r5. See D-9.
- **macOS:** no function, therefore **no grant**. See D-7.

**Rule G3 (restated in r5).** **No probe target carries an App Group at all**, on
either platform. This is strictly stronger than r4's property that the production
and probe records were disjoint: with no probe grant there is no probe state that
*could* reach production state, so the probe stays disposable **by construction**
rather than by careful naming. If a probe ever regains a group under G4's
reopening condition, its record must be a distinct `group.` literal disjoint from
every production record, and G3 reverts to a disjointness test. Gate: **R11**.

**D-7 — rule G4: `com.apple.security.application-groups` is prohibited on every
macOS target.** This is what verdict 03 asked for, decided rather than deferred.

r3 granted the capability on both macOS production targets while its only named
purpose was *"the channel `TASK-260728-7ii1xz` **will** use"*, plus not having to
repeat Ceremony C1. Verdict 03 was right that this is a possible future
requirement and an operational convenience, not a current one. That task has
since finished, so the question is answerable instead of deferrable.

**Rule G4.** The entitlement is granted only to a target whose **currently
selected** design uses one of the grants the entitlement actually confers on that
platform. A spec sentence, a shipping third-party bundle, and the cost of a
second portal sitting are none of them a function.

*What the entitlement actually grants on macOS.* Not a matter of opinion: it is
two `sandbox-array-entitlement` blocks in the system App Sandbox profile, and
they are the only two occurrences of the key in it. Both were read in full at
`/System/Library/Sandbox/Profiles/application.sb` on macOS 26.5 (25F71).

| # | grant | lines | namespace | crosses root↔user? | used by the selected design? |
| --- | --- | --- | --- | --- | --- |
| 1 | group container read/write and sandbox extensions | 305–315 | home-relative | **no** | no |
| 2 | `network-bind` / `network-outbound` inside the group container (UNIX sockets) | 307–314 | home-relative | **no** | no |
| 3 | `/Library/Application Support/AppStore/GroupContent/<suite>` | 316–321 | system-wide | yes | no — Mac App Store only; this project ships development and Developer ID |
| 4 | `mach-lookup` / `mach-register` on `global-name-prefix "<suite>."` | 326–328 | system-wide | yes | no — the XPC candidate was **rejected** |
| 5 | `ipc-posix*` on `ipc-posix-name-prefix "<suite>/"` | 329 | system-wide | yes | no — no candidate proposed POSIX shm |
| 6 | `~/Library/Application Scripts/<suite>` | 459–465 | home-relative | **no** | no — and no user scripts ship |

Three of the six are home-relative, and those are the ones that break: the host
resolves them under the logged-in user's home, the root provider under
`/private/var/root`. Three are **system-wide and do work across the boundary** —
worth stating plainly, because "App Groups do nothing on macOS" would be the
convenient version and it is false. Grant 4 is the one that ever made the macOS
group look load-bearing, and `TASK-260728-7ii1xz` evaluated exactly that channel
as candidate C and rejected it. Grant 5 crosses the boundary and nobody proposed
it; it is named here so a future design cannot claim the option went unseen.

*The selected design uses none of them.* Candidate D: the provider owns a
file-based system-domain keychain item, seeded once over
`NETunnelProviderSession.sendProviderMessage`, with the non-secret snapshot in
`providerConfiguration`. Keychain, NE app message, `providerConfiguration` — not
one is an App Group mechanism.

*And a private container is redundant, not merely unused.* Amendment **M6** left
the rows granted because *"a private root-context container may still have uses
this task did not survey"*. Surveyed here, and the answer is no.
`(appsandbox-container-common)` and `(appsandbox-container-macos)` at
`application.sb:107-108` sit at top level — **not** inside any `(when (entitlement
…))` form — so every sandboxed target already has its own private container from
the `application_container_id` parameter, with no App Group entitlement at all.
The only thing a group container adds over the container the provider already has
is **sharing**, and sharing is precisely what the root/user split breaks.
`application.sb:754-756` makes the same point for grant 2: the target may already
bind and connect UNIX sockets in its own container, unentitled.

**What would reopen this row** — and it is deliberately narrow, each case a grant
from the table rather than an appeal to App Groups in general:

1. the macOS host↔provider channel becomes a group-prefixed **Mach service**
   (grant 4 — the XPC candidate revived);
2. it becomes a group-prefixed **POSIX IPC** object (grant 5);
3. the provider is moved **out of root into a user context**, making the group
   container genuinely shared (grants 1, 2, 6).

It does **not** reopen because `.spec/architecture.md:111` mentions App Groups,
because a shipping third-party product carries the key, or to spare a portal
sitting. Reopening is an amendment under §11 naming which case became true.

**The ceremony argument is dead, not merely demoted.** Withholding costs no
additional human sitting. The four iOS App IDs are already in C1's
`explicitlyNotAuthorized` under ADR-024, so iOS provisioning **already** requires
a later portal session that C1 does not cover — and the remaining App Group
record's only consumers are two of those same iOS App IDs. It is allocated there.
Nothing C1 could grant today is needed today.

**iOS production is untouched.** Host and appex run as the same user in the same
context, so the container really is shared and `.spec/architecture.md:111` holds.
`ios.host` and `ios.provider` keep the entitlement as `required`, and the record
stays iOS-style (G1) so the iOS row re-arms unchanged.

**D-9 — rule G4's `probeRule`: the iOS probe pair is withheld too. New in r5.**

r4 granted the group to `ios.probe.host` and `ios.probe.provider` on the grounds
that *"the disposable probe pair exercises the same shared-container path
production depends on"*. Verdict 04 F3 asked where that path is written down. It
is not. `TASK-260715-1jckn0` scopes the iOS probe to `NETunnelProviderManager`
save, load, enable, start, status, app-message and stop, one provider protocol
and a versioned response, and a clean stop; its **AC3** puts the entire
host↔provider exchange on **app messaging**. No shared container, no
`UserDefaults` suite, no snapshot appears anywhere in that task.

So the path the probe actually exercises is `sendProviderMessage`, which needs no
group. G4 tests a mechanism **currently selected on this target** — the rule now
says so explicitly:

> A probe inherits **identifiers and profile classes** from the production shape
> it rehearses. It does **not** inherit entitlements. Each probe row is tested
> against its own probe task's scope and acceptance criteria. If a probe is meant
> to prove that a capability can be *provisioned* at all, that is a
> **verification deliverable** and must be written into the probe task as an
> acceptance criterion first; the entitlement then follows the criterion, not the
> other way round.

That last sentence is the reviewer's own alternative exit, kept open rather than
taken: amending `TASK-260715-1jckn0` to add a real shared-container deliverable
would justify the grant. It was not taken because **no board element asks for
it**, and adding a deliverable to a disposable probe purely to justify an
entitlement it was already given is the circularity F3 named.

**Consequence.** `group.works.relux.tunnel.probe` had exactly two consumers, and
both just lost the grant. A portal record no target reads is surface without a
function, so the record is **deleted** (G3). The same discipline as D-7: the
withheld rows carry a narrow `reopensOnly` naming the probe AC that would have to
exist first, and re-creating the record is part of that amendment.

Gates: **R28** (`probeRule` present, no probe in the granted set, both directions
of the grant/withhold split), **R9** (a granted row must have a record naming it,
*and* a record may not name a row that lost the grant), **R11** (`recordCount`
matches the declared records; no probe target is granted), assertion **A18**.

Gates: **R28** (the grant/withhold split, the survey's completeness and honesty,
a reopening condition on every withheld row, and rejection of conditional wording
in a granted rationale), **R30** (C1 may not authorize a capability or record no
authorized App ID requires), assertion **A16** (absent from every macOS bundle and
profile). See **OC-4** for the one place the style choice could still bite, now
dormant.

### 4.4 Keychain access group

| field | value |
| --- | --- |
| name | `works.relux.tunnel.shared` |
| entitlement literal | `$(AppIdentifierPrefix)works.relux.tunnel.shared` |
| resolved | `262RZ595FP.works.relux.tunnel.shared` |
| granted to | `ios.host`, `ios.provider` — **iOS only, since r5** |
| withheld from | `macos.host` (**D-8**, r5), `macos.provider` (D-2, settled r4), the entire probe family |

Keychain sharing is not a separate portal App ID record. The group must fall
inside the generated profile's `keychain-access-groups` allowlist. Verified on
this Mac: a Mac Development profile's `Entitlements` dict carries
`keychain-access-groups = ["<TEAMID>.*"]`, a team-wide wildcard, so the group is
authorised without a dedicated portal record. The probe family handles no
credentials (`TASK-260715-1r0fxv` scope excludes SSH), so it gets no keychain
group at all. **Ceremony C1 therefore performs no Keychain mutation whatsoever** —
there is no portal record to create, and after r5 no macOS target claims the
group either.

**D-8 — rule K2: `keychain-access-groups` is withheld from the macOS host. New in
r5.**

r4 kept the group on `macos.host` with the purpose narrowed by amendment M4: *the
host's own vault plus a pre-seed staging item held across system-extension
approval*. Verdict 04 F1 pointed out that neither half needs a **shared** access
group, and that r4 had applied the least-privilege test to the provider row (D-2)
and never to the host row. That is correct.

**Rule K2.** The entitlement is granted only to a target that must share a Data
Protection Keychain item with a **named second target in this contract**. A
target that only reads and writes its own items is already served by the default
access group the signing toolchain gives it.

*Sharing is the only thing the entitlement does.* It does not unlock the Data
Protection Keychain, does not change item durability, and does not survive
anything the default group does not. So any argument for granting it that cannot
name a second reading target is an argument for something the entitlement does
not do — and on macOS there is no second target: K1 excludes the root/system-domain
provider on technical grounds, and neither probe touches the Data Protection
Keychain.

*Withholding costs the host nothing, and this is documented rather than inferred.*
Apple, [Sharing access to keychain items among a collection of
apps](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps):

> "Xcode automatically adds the `application-identifier` entitlement (or the
> `com.apple.application-identifier` entitlement in macOS) to every app during
> code signing, formed as the team identifier (team ID) plus the bundle
> identifier (bundle ID)."
>
> "The system recognizes this app ID as the name of your app's default keychain
> access group … Any keychain items stored with this access group are **private
> to App One**."
>
> "If you don't specify any keychain access groups, then **the app ID is the
> default**."

and TN3137: *"macOS builds the list of data protection keychain access groups
available to your program from its code signing entitlements. These entitlements
must be authorized by a provisioning profile."* `macos.host` is provisioned on
both channels (**R14**), so its injected `com.apple.application-identifier` is
profile-authorized and the default group is available. The host's vault and the
pre-seed staging item are both host-only, so both are served by it. Persistence
across an interrupted approval flow is a property of **the keychain**, not of a
shared access group.

**The one real consequence: the default group moves.** K2 records the ordering
law, because it is what makes this safe *and* what makes it a downstream
requirement rather than a first-build surprise. The system forms the access-group
array as `keychain-access-groups` first, then the application identifier, then the
app groups; **the first element is the default** when a caller names none. So:

| | r4 default group on `macos.host` | r5 default group on `macos.host` |
| --- | --- | --- |
| | `262RZ595FP.works.relux.tunnel.shared` | `262RZ595FP.works.relux.tunnel.mac` |

`TASK-260715-379cpk` must therefore **not** pass `kSecAttrAccessGroup` on macOS —
naming the shared group now returns `errSecMissingEntitlement`. On iOS it
continues to name `262RZ595FP.works.relux.tunnel.shared` explicitly, because
there the group is real and shared with the appex. This is a platform branch in
the vault, not a shared constant. No item has been written yet, so there is
nothing to migrate — but the vault must not be authored against the r4 default.

*Settled by decision, not by omission.* r1–r4 left the four **probe** keychain
rows `prohibited` with no reopening condition at all, which is indistinguishable
from nobody having considered them. R31 now rejects that, and all four state one.
This was found by the new gate, not by inspection.

Gates: **R12** (the exact per-target status map), **R31** (K2's fields and Apple
sources; the record's consumers equal the granted rows in both directions; a
group granted to fewer than two targets fails outright; every consumer is iOS;
every withheld row states a reopening condition; the recorded default group obeys
the ordering law), assertion **A17**.

**Rule K1 — what replaces the deleted `amendmentRule`.**

> On macOS the file-based (system-domain) keychain is controlled by per-item
> `SecAccess` ACLs. `keychain-access-groups` applies only to the Data Protection
> Keychain, which is unavailable outside a user context. A root-context provider
> targeting the system-domain keychain therefore never needs this entitlement,
> and the presence of the key in a shipping third-party provider **is not
> evidence that it functions**.

The last clause is load-bearing. PureVPN's packet-tunnel system extensions carry
`keychain-access-groups`; that observation stands, and under K1 it may not be
used to argue the row back open. A key in a signed bundle is not proof that the
mechanism it names is the one the process uses. Without K1 the next revision
re-grants the row by analogy with PureVPN, which is the exact reasoning D-2
deletes. `macos.provider` reopens **only** if the provider is moved into a user
context — not merely because it touches a keychain. Gate: **R29**.

**K1 governs the provider only — and r5 says so.** That silence is exactly what
let r4 keep a shared group on `macos.host` with nobody to share it with: the host
*does* run in a user context and *does* use the Data Protection Keychain, so K1
had nothing to say about it. **K2** (D-8) is the rule for that case. K1 now
carries a `hostScope` clause pointing at it, and **R31** fails if that clause is
removed — the gap does not get to reopen silently.

**Rule K3 — the OS-version scope K1 never stated. New in r10, verdict 08 F1.**

K1 has two halves, and only one of them is version-independent.

| K1 clause | scope | why |
| --- | --- | --- |
| `keychain-access-groups` is **inapplicable** to the provider | every macOS version | The file-based keychain is controlled by per-item `SecAccess` ACLs; access groups belong to the Data Protection Keychain, which has no meaning in a root context. This is an access-control *model*, not a policy file. |
| the provider needs **no keychain entitlement at all**, because the sandbox already grants what it needs | **macOS 26.5 (25F71) only** | It rests on `application.sb:792-793`, a **base OS sandbox policy file** that Apple ships with the OS and may change between releases. |

The second row is the finding. r4 read that file on this Mac and stated the
conclusion unconditionally; the binding floor for generated targets is **macOS
15.0** (`.spec/platform-distribution.md` *Minimum platform policy*, selected
exactly in
`.research/260720_task-260715-3r0993-project-generator-deployment-target-policy.md`).
Nothing in the contract said the supporting evidence stopped ten major releases
short of the floor it has to hold on.

> **Rule K3.** The conclusion that the macOS provider needs no keychain-related
> entitlement rests on a **base OS sandbox grant** — an OS-version-scoped fact
> about the running system, not an invariant of this contract. It holds on the
> versions where it has actually been read. On any supported version below that it
> is **UNVERIFIED**, and this contract models it as unresolved instead of settling
> it by silence.

**Why this is modelled and not measured.** The honest answer to *"does macOS 15.0
grant it?"* is that nobody here knows. This environment has no macOS 15 host,
virtual machine, installer, or SDK-resident sandbox profile — sandbox profiles
ship with the OS, not with an SDK, and only Xcode 26.5 and macOS 26 SDKs are
installed. Apple does not document `application.sb` contents, so no secondary
source closes it. **The gap is stated, not inferred.**

**The installed products do not settle it either**, and r10 re-read them rather
than citing r4:

| shipping provider | `LSMinimumSystemVersion` | keychain-related entitlement |
| --- | --- | --- |
| Surfshark packet tunnel | 10.15 | `…temporary-exception.files.absolute-path.read-write` over `/private/var/db/mds/`, `/Library/Keychains/`, and a further private path |
| PureVPN packet tunnel (two of them) | 10.15 | `keychain-access-groups` |
| Tailscale network extension | 12.4 | none |

A support range opening at **10.15** spans OS versions this project does not
support, and a bundled defensive path set is not a targeted floor fix. So
Surfshark's exception is not proof of necessity at macOS 15.0, and Tailscale's
silence is not proof of redundancy there. **K1's clause runs in both directions
here:** a key present in a shipping bundle is not proof the mechanism functions,
and a key absent from one is not proof it is unnecessary.

**Who closes it, without a new board element.** `TASK-260715-1uxx3i` already owns
the credential-free Apple build matrix, and the deployment-target policy already
names **`macos-15`** as its minimum hosted lane. Reading
`/System/Library/Sandbox/Profiles/application.sb` on that runner is a
credential-free static read of the runner's own system files — squarely inside
that task's AC2 static checks — and it already reaches this contract transitively
through `TASK-260715-uyju7n`. `TASK-260715-1o9wjz` consumes the same answer at
runtime, because an absent grant surfaces there as a provider-context failure
rather than as a build finding.

**Both directions are pre-decided**, so the answer lands as an amendment and not
as an argument:

| floor evidence | consequence |
| --- | --- |
| grant **absent** on the oldest supported macOS | Arm register entry **X1-C1** (§4.5): `…files.absolute-path.read-write` = `/Library/Keychains/`, `macos.provider` only, both macOS channels. **Do not** re-grant `keychain-access-groups` — an absent sandbox grant is an argument for a file exception, never for the row K1 deleted. |
| grant **present** | Record the evidence and retire X1-C1. The row stays `prohibited` under K1, for the reason K1 already gives. |

**Arming costs Ceremony C1 nothing.** A temporary file exception is a
signing-time App Sandbox entitlement: no App ID capability, no portal record, and
nothing that *can* be created in the Developer portal. `ceremonyC1Impact` is
`none`, and R39 fails if that claim is edited.

Gates: **R39** (K3's fields; the two version numbers are distinct and neither
absorbs the other; the row's `osVersionScope` agrees with the rule and names the
same owner; the reopening condition mentions K3; the register entry is unarmed,
value-bounded, channel-valid, disjoint from the active register, and its row sits
in no allowlist), assertion **A19**, and **R29** for K1's `osFloorScope` clause.

### 4.5 Rule X1 — reviewed exceptions and banned relaxations

Granting the first temporary exception without a rule governing exceptions would
leave the contract weaker than the spec it implements. The same clause that
forced D-6 also says:

> Hardened Runtime remains enabled on all executable code. Distribution has no
> `get-task-allow`, disabled library validation, unsigned/JIT executable-memory,
> or **unreviewed exception entitlement**.

**Rule X1.** An App Sandbox temporary exception or a Hardened Runtime relaxation
may appear in a signed bundle **only if** it is an authored row in this matrix
**and** is listed in `exceptionEntitlementRule.reviewedExceptions`. Being listed
there **is** the review the spec demands; nothing else counts as reviewed.

| reviewed exception | target | values | reason |
| --- | --- | --- | --- |
| `…temporary-exception.mach-lookup.global-name` | `macos.host` | `-spks`, `-spki` | Sparkle installer launcher (ADR-018) |

**The conditional register — `conditionalExceptions`. New in r10, verdict 08 F1.**

X1 as written had exactly one shape for an exception: granted and reviewed, or
absent and forbidden. Rule K3 produces a third — *reviewed, and required only if
a supported OS turns out to need it*. Without somewhere to put that, the correct
requirement would arrive as **drift** the day the evidence does.

| conditional exception | target | values if armed | armed | arms on |
| --- | --- | --- | --- | --- |
| **X1-C1** `…temporary-exception.files.absolute-path.read-write` | `macos.provider` | `/Library/Keychains/` | **no** | `TASK-260715-1uxx3i` evidence that the base App Sandbox profile on the oldest supported macOS does **not** grant `/Library/Keychains` to Network Extension processes |

**A conditional entry is reviewed but not granted.** It authors nothing, enters
no allowlist, moves no count, and must be **absent from every signed bundle**
while `armed` is false — which is assertion **A19**. Its row on `macos.provider`
carries the status `conditional-pending-decision`, deliberately in the
`pending-decision` class so that **R13** lets it name a `resolutionOwner`: a row
nobody owns is how OC-1 sat open for three revisions.

**It is disjoint from the active register by construction.** `reviewedExceptions`
must equal the set of temporary exceptions the target rows actually author —
that equality is **R26**, and it is what keeps the active register honest. A
conditional entry sits outside it, and R39 fails if the same `(key, target)`
appears in both: an exception is either granted or pending, never simultaneously.

**Why pre-authorize at all.** The spec clause X1 enforces bans an *unreviewed*
exception entitlement. If the floor turns out to need this one, the review has to
have happened **before** the evidence, or the exception is unreviewed at the
moment it becomes necessary and X1 rejects the right answer. Listing it here *is*
that review — the review is recorded now, the evidence belongs to the owner.
Arming moves the entry into `reviewedExceptions` and the row into
`required-adjacent` in one amendment under §11; it is never a local build
setting, and it is not a fresh review round.

Banned outright on every target and every channel:
`com.apple.security.cs.disable-library-validation`,
`…cs.allow-unsigned-executable-memory`, `…cs.allow-jit`,
`…cs.disable-executable-page-protection`,
`…cs.allow-dyld-environment-variables`, `…cs.debugger`. A future need is an
**amendment** under §11, never a local build setting.

`get-task-allow` is deliberately **not** in that banned list: the toolchain
injects it on the development channel and strips it on distribution export, so it
belongs to the signing-generated classification and assertion A10d (§9.1). Banning
it in both places would make the two mechanisms contradict each other about the
development channel — validator R26 rejects exactly that.

**Scope limit.** X1 and A10a–A10e apply to this project's four production targets
and its probe targets. Sparkle's own nested code — `Sparkle.framework`,
`Installer.xpc`, `Downloader.xpc`, `Autoupdate`, `Updater.app` — carries
entitlements authored by Sparkle, and re-signing it on Developer ID export is
owned by `TASK-260715-3gkwn0` and `TASK-260717-xempiv`, not by this matrix.

#### Every field of a conditional entry is derived — new in r11

Reviewer verdict 09 F1. r10 established `X1-C1` by requiring the register entry
and its copy on the target row to **agree**, and stopped there. That is a
consistency check, not a review: the reviewer changed **both** copies of three
fields and `validate-matrix.py` exited **0** each time, where a negative control
must exit 1.

| field | derived from | why a coordinated edit cannot restate it |
| --- | --- | --- |
| `target` | the **unique** row carrying an `osVersionScope` governed by the entry's rule | R39's settled-row checks fail closed if that scope block is missing from `macos.provider`, so relocating the entry means breaking them first |
| `key` | pinned to the read-write absolute-path form, and cross-checked against K3's `ifGrantAbsentAtFloor` | the base grant it replaces is `file-read*` **and** `file-write*`; drifting the key means drifting a sentence a reader sees |
| `valuesIfArmed` | a **path-subtree bound**: at or inside `/Library/Keychains/`, never an ancestor of it, `/` banned outright, one value | an ancestor test is a property of the *value*. Widening to `/` or `/Library/` fails however many copies agree |
| `channelsIfArmed` | `targets[macos.provider].channels`, **in full** | a base sandbox profile does not vary by signing channel, so a subset leaves one channel broken on the same OS — dropping `developer-id` would break the shipping provider while development looked fine. That list is held by NE1/R7/R19/R22/R23 and the profile rules |
| `armedBy` | the element inside K3's `resolutionOwner`, **and** a declared consumer | rule **D1** requires every declared consumer to exist on the live board and to reach this task. Verdict 09 moved this to `TASK-260715-9yp8to` — a *real* consumer, which is why a shape check on the element id could not see it |
| `governedBy` | pinned to `K3` | an entry governed by nothing is unreviewable |
| `reviewedIn` | rule **X1-P**: the revision in which the entry first appears in the digest-pinned snapshot chain, cross-checked against `revisionLog[].introduces` | the claim that makes the entry pre-authorized rather than merely written down, so it is derived from evidence *older* than the claim. `X1-C1` is absent from the `r8` and `r9` baselines and present in `r10` — a fact about attached files, not about this one |
| `scopeIfArmed` | rendered from the derived target and channel count | the same instrument rule **S1** applies to the cross-platform summary: the prose cannot describe a wider grant than the fields do |

The reviewed path lives **in the gate**, not only in the register: a bound that
lives inside the data it bounds is not a bound. So does the vocabulary of bound
kinds — a derivation may not declare a bound the gate does not implement, and
"agrees with the target row", however spelled, is not among them. Widening either
is a reviewed amendment under §11, visible in a diff.

**That bound is closed — rule X1-P, new in r12.** r11 stated it here instead:
*the gate cannot tell which issued revision reviewed an entry, only that the
revision exists*. Reviewer verdict 10 F1 moved `X1-C1.reviewedIn` from `r10` to
`r2` and the validator exited **0**. Writing a gap down is not closing it, so
`reviewedIn` is now **derived**, for **both** registers.

| evidence class | when it applies | what it rests on |
| --- | --- | --- |
| **snapshot-proven** | the entry is absent from at least one attached baseline | the per-revision baselines, pinned by a content digest and consumed independently by the preservation harnesses. `X1-C1`: absent from `r8` and `r9`, present in `r10` |
| **summary-attested** | the entry predates the oldest attached baseline, so the chain cannot decide it | the oldest `revisionLog` summary naming the exception key verbatim. `X1-A1`: named by `r3`, not by `r2` |

The gate **refuses** attestation wherever the chain can decide, so the weaker
class cannot be selected as a convenience. The chain cannot be narrowed either:
it runs contiguously to the revision this contract supersedes, and every baseline
sitting beside the contract must be declared in it — dropping the snapshot in
which an entry is *absent* would otherwise make it undecidable and demote it. Both
classes are cross-checked against `revisionLog[].introduces`, which is a
cross-check and not the derivation: it lives inside the file it describes, so
alone it would be exactly the self-attestation the verdict rejected.

**The active register was the worse half.** `reviewedExceptions[].reviewedIn` was
required only to be non-empty, so it accepted a revision this contract has never
issued — and its one entry authorises an exception that *is* in a shipped bundle,
unlike the conditional register's. Each register is gated by the rule that owns
it: **R26** for the active one, **R39** for the conditional one.

**Residual bound, stated.** An edit coordinated across a baseline, its pin, the
introduction record and the entry would pass *this validator*. It does not pass
the preservation harnesses, which read the same baselines for a different reason —
injecting the conditional entry into the `r9` baseline makes `preserve.py` exit 1
on a changed `exceptionEntitlementRule` and `preserve-r10.py` exit 1 on
*"conditionalExceptions is not new in r10"*. Both were run against a tampered
baseline, not assumed. That is still weaker than a gate: it holds only while those
harnesses are run and their baselines stay attached. What none of this establishes
is that the review recorded in that revision was a *good* review; it establishes
that the entry names the revision it actually entered in.

**The sweep found two the verdict had not named.** A coordinated **target** move
to `macos.host` — entry and row together — passed r10, which would have
pre-authorized a filesystem exception on a target nobody reviewed. So did a
`reviewedIn` naming a revision that never existed. A third, key drift, failed
under **R35**'s assertion-scope partition rather than under the rule that owns the
register; it is now gated where it belongs.

---

## 5. Environment naming: debug versus release

**Rule E1. One bundle identifier per target, for every build configuration.** No
`.debug`, `.dev`, `.staging`, `.beta`, `.internal`, or `.release` suffix.

1. macOS system-extension user approval is keyed to Team ID + extension bundle
   identifier. A per-configuration suffix multiplies physical approval friction on
   Hold H2 (`TASK-260715-3f4rhy`) and H3 (`TASK-260715-1r48pc`).
2. `TASK-260715-9yp8to` must exercise the identity that actually ships.
3. Fewer App IDs and Network Extension profiles to keep valid.

**Rule E2. Environment is expressed by signing channel, never by identifier:**
signing identity class, profile class, hardened-runtime state, `get-task-allow`,
and — new in r2 — the channel-keyed Network Extension entitlement value (§4.1).

**Rule E3 — the single exception.** The disposable probe family is a distinct
identity, development-signed **only**. Never Developer ID signed, never notarized,
never uploaded, never shipped. It exists so the production identity is not burned
on throwaway system-extension approvals. Its profiles have no distribution row
(validator R15), and by NE1 it can only ever prove the development entitlement
shape.

**Rule E4.** A host and its embedded provider MUST carry identical
`CFBundleShortVersionString` and `CFBundleVersion`. The monotonic build sequence
is ADR-018's, owned by `TASK-260715-1tzaed`.

---

## 6. Profile classes

| target | development | distribution | C1-authorized |
| --- | --- | --- | --- |
| `macos.host` | Mac Development, this Mac registered | Developer ID Application | development only |
| `macos.provider` | Mac Development, this Mac | Developer ID Application | development only |
| `macos.probe.host` | Mac Development, this Mac | **none** | development only |
| `macos.probe.provider` | Mac Development, this Mac | **none** | development only |
| `ios.host` | iOS App Development | App Store Distribution | **no** — ADR-024 |
| `ios.provider` | iOS App Development | App Store Distribution | **no** — ADR-024 |
| `ios.probe.host` | iOS App Development | none | **no** — ADR-024 |
| `ios.probe.provider` | iOS App Development | none | **no** — ADR-024 |

Every profile row also records `authorizesNetworkExtensionValues`, which validator
R23 pins to the entitlement value of that row's channel. Distribution profiles are
owned by `TASK-260715-3gkwn0` (macOS Developer ID / notary) and
`TASK-260715-3661ps` (iOS TestFlight/App Store); they are explicitly **not** part
of Ceremony C1.

### What Ceremony C1 authorizes, exactly

`TASK-260728-q5kjta` step 3 authorizes creation and download of exactly:

- App IDs `works.relux.tunnel.mac`, `works.relux.tunnel.mac.tunnel`,
  `works.relux.tunnel.probe.mac`, `works.relux.tunnel.probe.mac.tunnel`
- the **Network Extensions** capability on those four App IDs, enabled **by
  capability name**
- one Mac Development profile per App ID, with this Apple-silicon Mac registered

**No App Group record, and no App Groups capability on any App ID.** r3
authorized both; r4 and r5 do not. Rule G4 prohibits
`com.apple.security.application-groups` on every macOS target, so no
C1-authorized App ID needs the capability. Since r5 there is only **one** record
left, `group.works.relux.tunnel`, whose consumers are two of the iOS App IDs C1
explicitly does not authorize; it is allocated when iOS re-arms under ADR-024, at
a sitting that ADR-024 already requires. The probe record was deleted in r5
(D-9) and must not be created at all. **This shrinks the ceremony; it adds no
sitting.**

**And no Keychain access group mutation either.** Keychain sharing has no portal
record in the first place — the Mac Development profile's team-wide
`keychain-access-groups = ["<TEAMID>.*"]` wildcard covers it — and since r5 rule
K2 leaves no macOS target declaring the key at all. An operator asked at C1 to
"create the Keychain access group" is being asked for a mutation that does not
exist.

**`TASK-260728-q5kjta`'s own board text was corrected to match this, in r5**
(verdict 04 F2). Its scope previously named *a* host App ID and *a* packet-tunnel
extension App ID — the singular production pair, omitting the probe pair — plus
an App Group and a Keychain access group, and its AC4 excluded only *two* iOS
identifiers. All four points now match `c1AuthorizationScope` exactly: four macOS
App IDs, Network Extensions only, zero App Group records and capabilities, no
Keychain mutation, the Mac Development profile class, and all four iOS App IDs
excluded. A downstream-consequence paragraph in this matrix is not the contract
the operator reads; the board task is.

Because C1 creates Mac Development profiles only, the entitlement values it puts
in circulation are `packet-tunnel-provider` — unsuffixed. The `-systemextension`
values enter later, with the Developer ID profiles owned by `TASK-260715-3gkwn0`.
The operator is never asked to select an entitlement value.

Explicitly **not** authorized: the four iOS identifiers, any distribution profile,
and any change to `works.relux.proxy`.

Validator R16 ties `authorizedAppIds` to exactly the set of `provisioned: true`
targets; R22 ties `authorizedNetworkExtensionValues` to the development-channel
values of those targets and rejects any suffixed value in C1 scope. **R30** ties
the capability and record lists to what the authorized App IDs actually require,
so C1 scope is *derived* — neither growing nor shrinking it by hand can pass.

### Who spends the authorization: rule P1, new in r6

Ceremony C1 is a *human* authorization. The mutations themselves are performed
unattended by `TASK-260715-3jloqy`, which is blocked by this matrix and by C1 and
runs afterwards with whatever contract its own board record states. Reviewer
verdict 05 **F2** found that r5 had corrected the ceremony and left that task on
the pre-r5 contract: create **shared groups**; provision **App Group and Keychain
capabilities**; AC1 requiring the shared groups to exist; AC2 requiring the
packet-tunnel entitlement **only on provider identifiers**.

The last of those is a defect independent of r5, and the worst of the four. Apple
requires `com.apple.developer.networking.networkextension` on the **containing
app** as well as the embedded provider — R7 has required it on all eight target
rows since r2 — so provider-only verification would have *passed* a portal state
in which neither macOS host App ID carries the capability, and the failure would
have surfaced at first build, after the human sitting was over.

`TASK-260715-3jloqy`'s description, scope, acceptance criteria and checklist are
corrected on the board to `c1AuthorizationScope` exactly. **Rule P1**
(`portalMutationTaskContract`) pins the requirement in the JSON — required
mutations, forbidden mutations, the two negative assertions, and the three exact
pre-r5 phrases that may never return — and
`TASK-260715-ypo7yo_check-portal-consumer.py` reads the pin and the live board
record and exits non-zero on drift. R32 checks that the pin still agrees with
`c1AuthorizationScope`; the script checks that the board still agrees with the
pin. **A downstream-consequence paragraph is not the contract an executing agent
reads — the board task is. That is the same lesson as r5's F2, one node further
down the chain.**

### Which revision the ceremony authorizes: rule A1, new in r7

Rule P1 pins the task that *spends* the authorization. **Rule A1
(`authorizationNodeContract`) pins the task that *grants* it** — and it exists
because r6 fixed one of those two edges and left the other.

r5 corrected `TASK-260728-q5kjta`'s mutation set and stamped its scope with
"revision `2026-07-28.r5`". r6 then superseded r5 **without re-pointing that
stamp**. Reviewer verdict 06 **F1** found the ceremony still authorizing
`2026-07-28.r5` — a revision that had received `CHANGES REQUESTED` and was never
the independently accepted matrix AC5 requires. The mutations it enumerated were
r6-correct; the revision it authorized was rejected.

**Why that is not harmless even though the mutation set matched.** C1 is the
authorization node named by AC5 and by `humanAuthorizationNode`. An operator
reading it approves *a named revision*, not a diff — and the next contract-only
revision that changes a mutation while the label stays put produces a sitting where
the human authorized one thing and the board asks for another. The r6 gate could
not catch it, because it was aimed at `TASK-260715-3jloqy` alone.

A1 therefore states four things, and every one of them is **derived** rather than
written down twice:

- **The revision phrase is a template**, `revision {revision}`, rendered from the
  contract's own `revision`. R34 rejects a template that hard-codes a revision, so
  the pin cannot be frozen at the revision that authored it.
- **The banned set is derived from `revisionLog`**, not hand-listed. Every entry
  that is not the current revision is forbidden in the node's live text, so a bump
  extends the ban automatically.
- **`excludedFields` names `notes`.** A past revision label in an append-only
  progress log is a *true historical statement*, not drift — the same reason rule S1
  excludes `revisionLog` from its count scan. Scanning every field would manufacture
  a failure out of correct history.
- **Exclusions are checked by negation, not by absence.** Stating "the four iOS App
  IDs are NOT authorized" is what *puts* those identifiers in the text, so the gate
  requires every occurrence to sit inside a negation window rather than requiring it
  to be absent. The window is symmetric and character-based on purpose: these
  strings cannot be split into sentences on `.` — every identifier here contains
  dots — and **AC4 states its exclusion *after* the identifiers it excludes**, so a
  preceding-context check would have missed the real text.

**One deliberate divergence from the required rework, stated plainly.** Verdict 06
offered "a machine-resolved immutable matrix resource digest plus revision" as an
alternative pin. **Rejected, with reasoning.** A digest changes on every edit to the
JSON, including edits that change nothing the operator is asked to approve, so it
forces a board write per revision without pinning anything the revision label does
not already pin — and a stale digest fails exactly like a stale revision. The label,
a *derived* banned set, and a gate that fails closed is the same guarantee at lower
maintenance cost. **The gate is what closes the defect, not the pin format.**

**And the amendment rule is where the class actually dies.** §11 now requires every
amendment to re-point *both* pinned consumers by task ID, and **R34 fails if
`amendmentRule` stops naming them** — because the root cause of this finding was not
a bad label, it was an amendment procedure that bumped `revision` without saying
which live board records had to follow.

---

## 7. Cross-platform sharing rules

**These six sentences are a rendering, not a source.** Each one is
`crossPlatformRules[i]` in the JSON, and each has a structured rule in
`crossPlatformSharingContract` (**rule S1**) that names the entitlement it
summarises. **R32** derives the grant set from the target rows, cross-checks it
against the record's own `consumedByTargets`, then requires the *grant clause*
(**bold** below) verbatim, requires the target names inside it to equal the
derived set, and requires every *other* target named in the sentence to be a
declared non-grantee mention carrying its own clause. **R33** requires the same
grant clauses to appear in this document. §13 explains why: through r5 these were
six unchecked strings, and one of them still asserted the r4 Keychain contract.

1. **XP-1** — Bundle identifiers are **not** shared across platforms. No
   multiplatform / universal-purchase App ID; four production identifiers, one per
   target. *(No entitlement summarised; identifiers are R1–R5's job.)*
2. **XP-2** — One App Group record exists in this contract,
   `group.works.relux.tunnel`, and its iOS-style literal is identical on both
   platforms (G1) — but the entitlement is **granted to the iOS host and the iOS
   provider only (rule G4)**. On macOS the root provider and the user-context host
   resolve different containers and the selected transport uses no App Group
   mechanism, so all four macOS targets are prohibited. The iOS probe host and the
   iOS probe provider are prohibited too, because `TASK-260715-1jckn0` names no
   shared container of its own (G4 `probeRule`). The record stays defined here so
   the iOS production row re-arms unchanged under ADR-024.
3. **XP-3** — One Keychain access group **name**, `works.relux.tunnel.shared`,
   **granted to the iOS host and the iOS provider only, and to NO macOS target on
   either channel, in either family (rules K1 and K2)**. Never the macOS provider,
   which reads the system-domain keychain, where access groups do not apply (K1).
   Every macOS target uses the default access group its injected application
   identifier provides; see K2 (§4.4, **D-8**) for why that costs it nothing.
   *This is the sentence reviewer verdict 05 F1 caught: through r5 it still read
   "the iOS host and appex, and the macOS host". The correction states the
   exclusion **universally** rather than naming the host, because naming a target
   is what went stale — a universal clause is derived from all eight rows and has
   nothing to forget.*
4. **XP-4** — The Network Extension **value** is a function of the signing
   channel, not the platform (NE1). **Every target on both platforms requires the
   entitlement; only the value differs.** macOS development signing and both iOS
   channels use the unsuffixed value; only direct Developer ID signing uses the
   suffixed one.
5. **XP-5** — The Sparkle Mach lookup exception is **not** shared at all (D-6,
   X1). **It is granted to the macOS host alone**, because Sparkle is linked into
   that target alone; iOS updates through the App Store and no packet-tunnel
   target updates anything.
6. **XP-6** — `ReluxTunnelCore` MUST NOT hardcode any of these. Values are
   injected through `PlatformVPNIdentity`
   (`Sources/ReluxTunnelCore/VPNManagerRepository.swift:8`), whose
   `production(for:)` deliberately throws until `TASK-260715-1tzaed` binds them.
   This matrix is that binding's input; it does not itself unblock it.

**How many App Group records exist is stated in exactly three places** —
`appGroupDisjointnessRule.recordCount` (checked by R11), XP-2, and
`c1AuthorizationScope.appGroupNote` (both checked by R32). Any other sentence in
the JSON that counts them fails R32's count scan, which is how r4's leftover "the
two App Group records" was found in `appGroupLeastPrivilegeRule` after r5 had
already deleted one of them.

---

## 8. Open constraints

**OC-1 — CLOSED in r4 by `TASK-260728-7ii1xz`.** *(was architecture-blocking for
macOS credentials)* The constraint was confirmed as stated and then resolved. The
replacement is candidate D: the provider owns a **file-based system-domain
keychain item**, seeded once from the host over
`NETunnelProviderSession.sendProviderMessage`. Matrix consequence: `macos.provider`
`keychain-access-groups` is settled `prohibited` under rule K1, not pending. The
five downstream tasks each revise the assumption named in
`TASK-260728-7ii1xz_macos-credential-transport-decision.md` §8. The original
statement, kept for the record:

> A macOS NE system extension runs as root outside a user context; the Data
> Protection Keychain is user-context only; access groups share between programs
> running as the same user. The host↔provider shared-access-group design in
> `.spec/security-privacy.md` and `.spec/threat-model.md` DF-02/M-02 therefore
> fails on macOS and holds on iOS. Corroborated on this Mac: two shipping
> providers need `/private/var/root/Library/Group Containers/` path exceptions;
> one reaches `/Library/Keychains/`; one carries `keychain-access-groups`
> directly — i.e. the real-world pattern is a file-based/System keychain or an IPC
> seed, not a shared Data Protection Keychain group. Blocks `379cpk`, `1o9wjz`,
> `29ws8l`, `3f4lxy`. Matrix effect: D-2 only.

**OC-2 — sandboxed host plus `system-extension.install`.** *(verify at first build)*
Reports of failure trace to an **invalid (not expired) provisioning profile**
producing a spurious "would like to access data from other apps" prompt, not to a
sandbox incompatibility. Treat profile invalidity as the first hypothesis. Note
that none of the three shipping products inspected is a sandboxed host, so this
combination has no local precedent. Owner: `TASK-260715-9yp8to`. Matrix effect:
none.

**OC-3 — App ID Prefix assumed equal to Team ID.** *(verify at portal)* See T2.
Owner: `TASK-260715-3jloqy`. Matrix effect: every `$(AppIdentifierPrefix)`
resolved literal.

**OC-4 — iOS-style App Group as a Mach service name prefix.** *(dormant — verify
only if XPC is ever selected)* Downgraded in r4 per amendment M3. The XPC channel
was evaluated as candidate C and **rejected**, and rule G4 now prohibits
`com.apple.security.application-groups` on every macOS target, so no macOS target
holds a group prefix at all. The question is dormant rather than pending.

**New evidence, r4.** r3 said no source consulted addressed whether an iOS-style
`group.` identifier is accepted as a Mach prefix. One does, on the sandbox side.
`application.sb:326-328` builds the authorised prefix as
`(global-name-prefix (string-append suite "."))`, where `suite` is the **literal
entitlement value**, whatever its style — so an iOS-style
`group.works.relux.tunnel` would yield the prefix `group.works.relux.tunnel.` and
the sandbox mechanism is style-agnostic. **This is evidence, not proof:** the
`launchd` bootstrap-registration side and the profile-authorisation side were not
exercised and nothing was signed. Recorded so that a revival of the XPC channel
starts from what is known rather than from r3's flat "no source addresses it".

Owner: `TASK-260715-ypo7yo`. Matrix effect: none. A revival is G4 reopening case
(a) and an amendment under §11; only then does the style question need settling,
and if an iOS-style prefix were rejected the amendment would add a **separate,
unregistrable** macOS-style identifier for that single purpose — macOS-style IDs
cannot be allocated on the Developer website, so it carries no portal record and
no C1 dependency, and the registered iOS-style records stay exactly as they are.

**OC-5 — the base sandbox grant at the macOS floor.** *(verify on the minimum-OS
lane; new in r10)* The macOS provider's freedom from **any** keychain-related
entitlement depends on the base App Sandbox profile granting `/Library/Keychains`
to Network Extension processes. That grant is read and confirmed on **macOS 26.5
(25F71)** and is **unverified on the binding macOS 15.0 floor**. If it is absent
there, the provider needs the temporary file exception pre-authorized as register
entry **X1-C1** (§4.5).

Not resolvable from installed products — the three shipping providers inspected
declare 10.15 and 12.4 minimums, support ranges far wider than this project's, so
none of them isolates macOS 15.0 behaviour (rule K3,
`productEvidenceIsNotProof`). Owner: `TASK-260715-1uxx3i`, on the `macos-15`
minimum lane it already runs; `TASK-260715-1o9wjz` consumes the same answer at
runtime. Matrix effect: one conditional row and one unarmed register entry — no
authored entitlement, no allowlist change, no portal record, and no change to the
Ceremony C1 authorization scope in either direction.

None of the four still open is a stop-the-line: each has an evidence-resolvable
question and a named owner, and none blocks Ceremony C1 — which, after r4, grants
no App Groups capability at all.

---

## 9. Machine-checkable verification

```sh
codesign -d --entitlements :- --xml <bundle> | plutil -convert json -o - -
security cms -D -i <profile>.provisionprofile
codesign --verify --deep --strict --verbose=4 <bundle>
ls <host>.app/Contents/Library/SystemExtensions
```

**Channel binding.** Every assertion that mentions a channel MUST be evaluated
against the channel the artifact was actually signed on, determined from the
embedded profile class — never assumed.

| id | assertion |
| --- | --- |
| A1 | bundle identifier equals the matrix value exactly |
| A2 | provider identifier equals host identifier + `.tunnel` |
| A3 | `com.apple.developer.networking.networkextension equals entitlements[key].valueByChannel[<channel actually signed>] exactly` — **no extra provider values**; the `-systemextension` suffix appears **iff** that channel is `developer-id` (**AS-1**, present-exclusive over all eight rows) |
| A4 | `com.apple.developer.system-extension.install present on macOS hosts only` (**AS-2**, present-exclusive: the word *only* is what discharges the six rows that must not carry it) |
| A5 | `application-groups` is **PRESENT on the two PRODUCTION iOS bundles — the iOS host and the iOS provider —** with exactly the matrix array and no team prefix; the record literals are iOS-style on both platforms. The iOS probe pair is **not** in scope here — that is A18 (**AS-3**) |
| A16 | **least privilege (G4)** — `com.apple.security.application-groups is ABSENT from every macOS bundle on every channel, production and probe alike`, and no macOS profile's `Entitlements` dict carries the key or names an App Group (**AS-4**) |
| A17 | **least privilege (K2)** — `keychain-access-groups is ABSENT from every macOS bundle on every channel, production and probe alike`. The macOS host reads and writes its own items through the default access group the injected `com.apple.application-identifier` supplies (**AS-8**) |
| A18 | **least privilege (G4 `probeRule`)** — `com.apple.security.application-groups is ABSENT from both iOS probe bundles and no probe profile names an App Group`; the probe's host↔provider exchange is `sendProviderMessage` (**AS-5**) |
| A6 | `keychain-access-groups present only where status == required, which after r5 is ios.host and ios.provider alone`; **`ABSENT from every macOS target, production and probe alike, and from the iOS probe pair`** (**AS-6**, **AS-7**) |
| A7 | the profile authorises every required key, and its `authorizesNetworkExtensionValues` is a superset of the channel's value |
| A8 | profile `TeamIdentifier` is `262RZ595FP`, `ApplicationIdentifierPrefix` is `["262RZ595FP"]` |
| A9a | `every macOS development profile — the four Mac Development profiles, which are exactly the profiles Ceremony C1 authorizes — carries ProvisionedDevices containing this Mac`, and that list equals the device set declared for the same target (**PS-1**) |
| A9b | `NO iOS development profile is created or checked at Ceremony C1: all four declare profiles[].development.devices as deferred under ADR-024` — there is no declared device set to compare a profile against yet (**PS-2**) |
| A9c | `every Developer ID profile carries ProvisionsAllDevices == true and no ProvisionedDevices key` — a distribution-channel assertion over the two Developer ID profiles, saying nothing about any development profile (**PS-3**) |
| A10a | **completeness** — every `required` key is present |
| A10b | **containment** — every present key is in the computed allowlist (§9.1) |
| A10c | **exclusion** — no `prohibited` / `prohibited-pending-decision` / `not-applicable` key is present |
| A10d | **channel hygiene** — development-only signing keys are absent on `developer-id` and `app-store` |
| A10e | **completeness (project architecture)** — every `required-adjacent` key is present too, on every channel the target declares |
| A14 | `com.apple.security.temporary-exception.mach-lookup.global-name is present on the macOS host bundle with exactly the two values in entitlements[key].resolvedValue` (`<host-bundle-id>-spks`, `<host-bundle-id>-spki`), and `is ABSENT from the macOS provider, from every iOS bundle, and from every probe bundle` (**AS-9**, **AS-10**) |
| A15 | no `exceptionEntitlementRule.prohibitedKeys` entry is present on any channel, and every `temporary-exception.*` key present is registered in X1 for that exact target |
| A19 | **conditional floor exception (K3)** — `com.apple.security.temporary-exception.files.absolute-path.read-write` is `ABSENT from all eight signed bundles on every channel while register entry X1-C1 is unarmed`; its presence is a drift finding for `TASK-260715-uyju7n` until `TASK-260715-1uxx3i` shows the base sandbox grant is missing at the macOS 15.0 floor, and arming it is still no portal capability and no change to Ceremony C1 (**AS-11**) |
| A11 | no bundle identifier matches `^works\.relux\.proxy(\.\|$)` |
| A12 | production and probe App Groups are disjoint |
| A13 | no `forbiddenNetworkExtensionValues` entry appears in any bundle or profile |

Drift policy is **fail-closed**: a mismatch fails the gate, it does not adapt.

### 9.1 Authored versus signing-generated entitlements

r1's A10 ("no entitlement key outside the matrix union is present") was not
executable: the signing toolchain injects keys the matrix does not author, so A10
would have rejected a legitimate signed development bundle. A10 is now four
assertions over an explicit allowlist.

```
allowlist(target, channel) =
      { keys with status required or required-adjacent }
    ∪ signingGenerated[platform].always
    ∪ ( channel == development ? signingGenerated[platform].developmentChannelOnly : ∅ )
```

| platform | always injected | development channel only |
| --- | --- | --- |
| macOS | `com.apple.application-identifier`, `com.apple.developer.team-identifier` | `com.apple.security.get-task-allow` |
| iOS | `application-identifier`, `com.apple.developer.team-identifier` | `get-task-allow` |

**macOS evidence** (observed on this Mac): every signed macOS bundle inspected —
the Tailscale, PureVPN and Surfshark hosts and their packet-tunnel system
extensions, plus `/System/Applications/Notes.app` — carries
`com.apple.application-identifier` and `com.apple.developer.team-identifier`. A
local Mac Development profile's `Entitlements` dict contains
`com.apple.application-identifier = "<TEAMID>.<bundleid>"` and
`com.apple.developer.team-identifier`. Xcode injects
`com.apple.security.get-task-allow` into debug builds and strips it on
distribution export, so it belongs to the development channel only.

**iOS confidence: medium.** No iOS bundle was built here — iOS is deferred by
ADR-024. The iOS spellings carry no `com.apple.` prefix, unlike their macOS
counterparts. `TASK-260715-3dno4w` verifies them at first iOS profile inspection.

Unknown-key policy is **fail-closed**: an unexpected key is a finding for
`TASK-260715-3jloqy` or `TASK-260715-uyju7n` to resolve against this contract,
never a silent local exception.

For the `macos.host` **development** channel the allowlist resolves to exactly
**eight** keys — **five authored** plus **three** the toolchain injects:

```
com.apple.developer.networking.networkextension        authored (required)
com.apple.developer.system-extension.install           authored (required)
com.apple.security.app-sandbox                         authored (required-adjacent)
com.apple.security.network.client                      authored (required-adjacent)
com.apple.security.temporary-exception.mach-lookup.global-name
                                                       authored (required-adjacent, r3)
com.apple.application-identifier                       signing-generated (always)
com.apple.developer.team-identifier                    signing-generated (always)
com.apple.security.get-task-allow                      signing-generated (development only)
```

On the `developer-id` channel the same list applies minus `get-task-allow`:
**seven**. This is the concrete list a correctly built, sandboxed Sparkle host
produces.

Three corrections are folded into that list. **First**, verdict 03's secondary
correction: r3's prose claimed "exactly seven keys" while the list beneath it
held ten. The JSON was right; the sentence was arithmetic that nobody had
recomputed after r3 added a row. **Second**, r4 dropped
`com.apple.security.application-groups`, because rule G4 withholds it from every
macOS target (D-7). **Third**, r5 drops `keychain-access-groups`, because rule K2
withholds it from every macOS target (D-8) — note that
`com.apple.application-identifier`, two lines below it, is what now supplies the
host's default access group, so nothing was lost. A macOS bundle still carrying
either key fails **A10b** (containment) plus **A16** or **A17** (the explicit
least-privilege checks).

### 9.3 Rule S2 — an assertion's scope is derived, not asserted

New in **r8**, for both findings of verdict 07.

An assertion carries **no independent authority** over *which* targets or
profiles it applies to. Its scope is **derived from the authoritative rows** —
`targets[]` for an entitlement claim, `profiles[]` for a profile claim — and
**R35**/**R36** recompute the derivation before the contract may pass.

Each scope-bearing assertion has one `entitlementScopes` (or `profileScopes`)
entry per polarity, and the scope in it is derived **three independent ways**:

1. **`classPredicates`** over the row classes (`platform`, `role`, `family`),
   evaluated as a union;
2. **`scopeTargets`** — the explicit list, which must equal (1);
3. the **row statuses** themselves, which must agree with the entry's polarity —
   an authored status for `present`, a non-authored status or no row at all for
   `absent`.

A predicate typo, a stale hand-written list, and a moved row each break a
*different* one of the three. A predicate field that matches **no** row is also a
failure, so a typo cannot silently select a smaller set than it reads as.

The `scopeClause` must then appear **verbatim** in the assertion text *and* in
this document, and every target named anywhere in the assertion must be either in
scope or a declared `nonScopeMentions` contrast carrying its own clause.

**The partition rule** is the check the two findings were failing. For every
registered entitlement key:

```
presentScopes            == { rows whose status for the key is authored }
presentScopes ∩ absentScopes == ∅
presentScopes ∪ absentScopes ∪ (all rows, if a present-exclusive entry exists) == all rows
```

A5 and A18 **overlapped** on the two iOS probe rows — one claiming presence, the
other absence — and nothing computed the union. `present-exclusive` is the third
polarity: it asserts presence on its scope **and**, through an `exclusivityMarker`
that must appear in the text, absence everywhere else, so `A4`'s "…on macOS hosts
**only**" discharges its own complement. Declaring it *without* the marker in the
text is a failure, because "present on X" alone says nothing about the rest.

**Coverage** is what makes the class fail closed rather than this one pair: every
entitlement key named literally in *any* assertion must be registered, and every
registered key must still be named by its assertion.

For profiles, `deviceBinding` declares what the rows must say for the scope to be
honest — `enumerated` (a concrete device list), `deferred` (every device entry
carries **both** the marker `deferred` and the basis `ADR-024`), or `all-devices`
(the distribution form). The development-channel scopes must **partition** the
profile rows, and the enumerated set must equal the set Ceremony C1 authorizes —
the tie that keeps **A9a** and the C1 scope from drifting apart.

### 9.2 Self-check evidence

`validate_matrix.py` applies **38** internal consistency rules (R2-R39) to the JSON,
and from r6 also to the grant clauses this document renders — from r8, to the
assertion **scope** clauses too. `check-portal-consumer.py` applies the two board
rules the validator structurally cannot: **P1** and, from r7, **A1**.

r12's gates:

| finding | gates |
| --- | --- |
| **F1 (verdict 10)** — `reviewedIn` accepting any issued revision | **R39** (the conditional register's `reviewedIn` must equal the revision rule **X1-P** derives, from the digest-pinned snapshot chain: the entry is absent from `r8` and `r9` and present in `r10`) and **R26** (the same derivation over the ACTIVE register, whose `reviewedIn` had been bounded only to non-emptiness) |
| **F1 (verdict 10)** — the evidence itself | **R39** (every declared snapshot must be on disk and match its content digest, must carry the revision it is declared as, and the chain must run **contiguously** to the revision this contract supersedes, with no baseline left undeclared beside it — so the chain can be neither tampered with nor narrowed past the absence that proves an introduction) |
| **F1 (verdict 10)** — the class, not the instance | **R39** (the introduction record `revisionLog[].introduces` must be complete, unique per entry, and free of ids that are in no register; monotone presence across the chain; the weaker attested class is **refused** wherever the chain can decide; the rejected `known-revision` bound is removed from the implemented vocabulary, so it cannot return as a declaration) |

r8's gates:

| finding | gates |
| --- | --- |
| **F1 (verdict 07)** — A5 claiming every iOS bundle against prohibited probe rows | **R35** (A5's scope derived three ways from the rows; the **partition** check over `application-groups` across AS-3/AS-4/AS-5, which fails on any present∩absent overlap; the probe pair declared as `nonScopeMentions` with its clause present), **R27** (the phrase `is PRESENT on every iOS bundle` is banned outright, and the corrected scope phrase is pinned) |
| **F2 (verdict 07)** — A9 claiming this Mac for deferred iOS profiles | **R36** (A9a/A9b/A9c scoped over `profiles[]`; `deviceBinding` checked against `development.devices` row by row; the development scopes must partition the eight profile rows; the deferred set must equal the rows that actually defer; the enumerated set must equal the C1-authorized set), **R27** (the phrase `every development profile carries ProvisionedDevices` is banned) |
| **the class**, not the two strings | **R35** coverage in both directions (an assertion naming an entitlement key with no registered scope fails; a registered scope whose assertion stopped naming the key fails) and **R35**/**R36** rendering (every scope clause must appear in this document, which is what caught the stale A6 row below) |

r7's gates:

| finding | gates |
| --- | --- |
| **F1 (verdict 06)** — the ceremony authorizing a superseded revision | **A1** in `check-portal-consumer.py` (the node's live text must contain the revision phrase *rendered from the current revision*, and must contain **no** revision in the derived superseded set; every C1-authorized App ID named with a right boundary; every clause naming an excluded identifier, App Group record or the legacy identity carrying its own negation) |
| **F1 (verdict 06)** — the pin itself rotting | **R34** (A1 is complete and pins `humanAuthorizationNode`, and *not* the P1 task; mirrors `c1AuthorizationScope` in both directions; refuses every declared App Group record, the legacy identity and the App Groups capability; the revision phrase is a **template** containing `{revision}` and no A1 field hard-codes the current revision; the negated set is declared **DERIVED**; `notes` is excluded and no field is both checked and excluded; a positive negation window and non-empty markers exist) |
| **F1 (verdict 06)** — the class, not the instance | **R34**'s revision bookkeeping (`revisionLog[0]` is the current revision, `supersedes` is `revisionLog[1]`, no repeats, every entry matches `<date>.r<n>`, the log is newest-first) plus **R34**'s requirement that `amendmentRule` name `re-point`, `TASK-260728-q5kjta` and `TASK-260715-3jloqy` — so a future amendment cannot bump the revision without being told which board records must follow, which is exactly what r6 did |
| **F1 (verdict 06)** — the gate never proven to fail | **13 board-record negative gates** (§ below), which the r6 gate did not have at all |

r6's gates:

| finding | gates |
| --- | --- |
| **F1 (verdict 05)** — the summary contradicting the rows | **R32** (rule S1 is complete; one structured rule per rendered sentence, `renderedIndex` a bijection; each grant set **derived** from the target rows and cross-checked against the record's own `consumedByTargets`; the grant clause present verbatim; the target names inside it equal to the derived set; a universal claim must cover every target and name none; every *other* target named in the sentence is a declared non-grantee mention whose clause is also present; every `group.` literal in a sentence is a declared record; no display name is a substring of another) |
| **F1 (verdict 05)** — the same class in a *count* | **R32**'s count scan (every "N App Group record(s)" claim anywhere in the JSON must sit at a registered path and equal the declared record count; a registered path that stops stating a count fails too, so the register cannot rot; a historical exclusion that resolves to nothing fails) |
| **F1 (verdict 05)** — drift between the JSON and this file | **R33** (every grant clause is rendered here, whitespace-normalised so hard wrapping is allowed and rewording is not; this file carries the current revision) |
| **F2 (verdict 05)** — the portal task's contract | **R32** (rule P1 is complete, pins the task this matrix authorizes, names every C1-authorized App ID, forbids every declared App Group record, forbids the App Groups capability while no C1 target needs it, and keeps `hosts included` in the board gate's required phrases) plus the board gate `TASK-260715-ypo7yo_check-portal-consumer.py`, which R32 cannot run because a JSON validator cannot read the board |

r4's gates, all retained — the gates that make verdict 03's finding, and the
amendment packet's defect class, fail closed:

| finding | gates |
| --- | --- |
| **F1 (verdict 03)** — an App Group granted on a future transport | **R28** (granted iff iOS; every withheld macOS row is `prohibited`, states a reopening condition, and claims no portal capability; every granted row names its function; a granted rationale containing conditional wording is rejected, and so is rule G2's macOS text; the G4 survey must cover all six grants, must record namespace and cross-context reachability per grant, must include at least one system-wide grant, and **must not** contain a grant the selected design uses) |
| **F1 (verdict 03)** — C1 pre-granting | **R30** (C1's capability list, record list and each record's `c1Authorized` flag are all *derived* from what C1-authorized App IDs require; a record deferred past C1 must name its allocator, its timing and its consuming targets, and those targets must actually be granted the group) |
| **M1 / M5** — a settled row keeping the fields that held it open | **R13** (a non-pending row may carry neither `resolutionOwner` nor a row-level `amendmentRule`), **R29** (rule K1 is present and cites TN3137; the settled row states a reopening condition and names the task that settled it; a closed constraint names a resolver and a resolution, drops its `resolutionOwner`, and reads as closed; an open one still has an owner; OC-1 is closed by `TASK-260728-7ii1xz`) |
| **assertion set** | **R27**, extended — the set must still contain **A16**, so the macOS absence cannot stop being checked |

r3's gates, all retained:

| finding | gates |
| --- | --- |
| **F1 (verdict 02)** — missing Sparkle exception | **R25** (present on `macos.host` with the exact authored and resolved values, `project-architecture` attribution, spec citation, portal-capability false, target actually sandboxed; absent from every other target) |
| **rule X1** — reviewed exceptions | **R26** (authored `temporary-exception.*` rows ↔ the register are equal sets; register values match the entitlement row; the banned set is non-empty and clashes with no target and no signing-generated key) |
| **assertion set integrity** | **R27** (assertion ids are exactly the expected set, none empty, and the set mentions the exception key, `required-adjacent` presence, and the banned set) |

r2's gates, all retained:

| finding | gates |
| --- | --- |
| F1 — NE per signing channel | R7 (value derived from NE1, suffix iff channel), R19 (channels ↔ profile rows), R22 (C1 scope is development-only), R23 (profile authorizes the channel's value) |
| F2 — App Group style | R9 (records iOS-style with no team prefix on either platform; a granted row carries exactly its record's literal; a withheld row carries **no** literal), R10 (literals identical across platforms), R18 (literal == portal record; C1 may not name a record this contract does not declare) |
| F3 — entitlement allowlists | R20 (allowlist computable; authored ∩ signing-generated empty; required ⊆ allowlist; non-authored ∩ allowlist empty; dev-only keys only on development) |
| F4 — sandbox attribution | R21 (`requirementSource` per role/platform; a host claiming an Apple requirement fails; every `sandbox-consequence` row sits on a sandboxed target) |

r5's gates:

| finding | gates |
| --- | --- |
| F1 — macOS host keychain group | **R31** (rule K2's fields and both Apple sources; K1's `hostScope` clause; the record's consumers **equal** the granted rows in both directions; a group granted to fewer than two targets fails outright, since one member means the default group would have done; every consumer is iOS; every withheld row states a reopening condition; the recorded default group obeys K2's ordering law), **R12** (per-target status map), **R27**/**A17** |
| F3 — iOS probe App Group | **R28** (`probeRule` present; no probe in the granted set; grant/withhold split in both directions), **R9** (granted ⇒ a record names it; withheld ⇒ no record names it), **R11** (rule G3's `recordCount` matches the declared records; no probe target is granted), **R30** (C1 scope derived through consumer lists rather than family), **R27**/**A18** |

- positive run: **1024 checks, exit 0** (r6: 975; r5: 846; r4: 801; r3: 598 over R1–R27)
- board gate: **43 checks over two consumers, exit 0** — 23 under A1, 20 under P1
- **130 negative gates, all holding** (r6: 117; r5: 92; r4: 66; r3: 41). The **13
  added in r7 are the first negative gates the BOARD gate has ever had.** r6's gate
  was only ever run in the passing direction, so nothing proved it would fail closed
  rather than pass vacuously — a gate never observed failing is an assumption. Each
  one snapshots both live records, corrupts the snapshot, and feeds it back through
  `check-portal-consumer.py --simulate-board`; **no live board record is mutated to
  test a gate**, and each failure must be reported under the *drifted consumer's own
  rule*, so a mutation to one consumer cannot be credited by a failure in the other.
  **10 against A1** — the r6 defect verbatim (the scope left at `r5`); a revision
  older still; the label *deleted* rather than made stale; the current revision
  present *alongside* a superseded one (the subtler version, which a "contains the
  current revision" check alone would pass — this is the reviewer's own `jq` gate's
  blind spot); one of the four C1 App IDs dropped; an excluded iOS App ID turned
  authorized; the legacy identity named without its negation; the Network Extensions
  capability unnamed; the ADR-024 deferral dropped; the profile class widened past
  Mac Development — and **3 against P1**, which had no negative gates before either:
  `hosts included` lost, a pre-r5 phrase returning, an unauthorized iOS App ID named
  as something to create.
- **57 preservation assertions** hold over r6 → r7: all eight target rows
  byte-for-byte, `c1AuthorizationScope`, `verification`, `openConstraints`, every
  entitlement rule object, both record lists, rule S1 and rule P1's pin content, the
  older revision-log entries, and the fact that exactly **one** top-level key was
  added and none removed. **r7 changes what the contract says about *who has
  authorized it*, not what it grants** — the authorized mutation set is identical to
  r6's.
- **The board gate reproduced verdict 06 F1 mechanically before the fix**: run
  against the live pre-fix record it reported 2 failures over 23 A1 checks while P1
  passed 20/20, exit 1 — the current revision unnamed, and the superseded `r5`
  named. After the board correction: 43 checks, exit 0. The reviewer's own `jq`
  freshness gate, re-run verbatim, moves from `false`/exit 1 to `true`/exit 0.
- **117 negative gates from r6, all still holding.** The **25 added in
  r6** split as **18 against verdict-05 F1** — the r5 sentence restored verbatim; a
  stale grantee appended *after* an intact grant clause (the subtler version, which
  a substring check alone would miss); the structured claim widened; the clause
  narrowed to one of two grantees; the deleted probe record resurrected in a
  sentence; the record list drifting; the Sparkle summary widened to the provider;
  a universal claim relabelled enumerated and an enumerated one relabelled
  universal; a sentence losing its structured rule; two rules claiming one
  sentence; a *grantee* laundered as a contrast mention; a contrast clause reworded
  in the register but not the sentence; a summary claiming an entitlement no row
  grants; an unregistered sentence counting records again; a registered claim
  stating r4's two; a registered path ceasing to state a count; a dead historical
  exclusion — **5 against F2** (the pin dropping a C1 App ID, the board gate losing
  `hosts included`, the banned-phrase register emptied, the pin retargeted at the
  ceremony instead of the mutation task, the pin ceasing to forbid the App Groups
  capability) — and **2 against R33**, which mutate *this document* rather than the
  JSON: the r5 Keychain sentence kept here after the JSON is corrected, and this
  file left at the superseded revision.
- **53 preservation assertions** hold over r5 → r6: all eight target rows
  byte-for-byte, every rule object except the two sentences that had to change,
  `c1AuthorizationScope`, `verification`, `openConstraints`, the record lists, the
  older revision-log entries, and the fact that exactly two top-level keys were
  added and none removed. r6 changes what the contract *says about itself*, not
  what it grants.
- **The board gate reproduces F2 mechanically.** Run against the pre-fix board
  record it reported 14 failures over 20 checks — the three pre-r5 phrases, seven
  missing required phrases, and all four C1 App IDs unnamed. Run after the
  correction: 20 checks, exit 0.
- the r5 gates below are retained unchanged; two r6 mutations reuse their style
- **92 negative gates from r5, all still holding**: each mutation re-introduces
  a defect and is rejected naming its rule. The 26 added in r5 split as **14
  against F1** (the macOS host re-granted; re-granted *with* a matching consumer
  added, so the record cannot be used to launder it; a withheld row keeping the
  literal; an **iOS** row withheld — the over-correction, since the gate must fail
  in both directions; the record dropping its consumers; naming an unGranted
  consumer; silently re-widening to macOS; a withheld row dropping its reopening
  condition; a *probe* row going back to settled-by-silence; the host dropping its
  recorded default group; recording the *shared* group as the default; K2 losing
  the ordering law; K2 dropping its Apple basis; K1 dropping `hostScope`), **10
  against F3** (both iOS probe rows re-granted; the deleted record restored with no
  consumer; restored still naming the rows that lost the grant; a withheld row
  keeping its literal; still claiming the portal capability; dropping its reopening
  condition; G4 losing `probeRule`; G3 miscounting its records; G3 forgetting the
  record ever existed), and **2** deleting assertions A17 and A18.
- **One gate caught this author.** The mutation that re-grants the macOS host
  *while* adding it to the record's consumer list made the validator raise
  `KeyError` instead of failing cleanly, because R31 read `e["value"]` on a
  granted row that had no literal. The rule was made crash-safe rather than the
  mutation dropped — a rule that throws is a rule that reports nothing.
- The 66 r4 gates are retained unchanged, except two that referenced the deleted
  probe record: one now stages the record collapse by appending a duplicate
  record instead of renaming the probe's, the other asserts against the
  production record. Neither weakens what it tests.
- **41 r3 gates retained unchanged.**

  The 25 added in r4 break down as **15 against verdict-03's F1** — the macOS host
  re-granted, the macOS provider re-granted, the *probe* host re-granted (the same
  defect one row over), an iOS row withheld (the over-correction), a withheld row
  keeping its literal, a withheld row dropping its reopening condition, a withheld
  row still claiming the portal capability, a granted row dropping its function,
  rule G2 reverting to r3's future-conditional wording, the survey conceding a
  grant *is* used, the survey trimmed to hide the system-wide grants, C1
  re-enabling the capability, C1 re-authorizing a record, a record claiming C1
  authorization, a deferred record dropping its allocator — **9 against the
  amendment packet** (the settled keychain row keeping `resolutionOwner`, keeping
  the deleted `amendmentRule`, sliding back to pending, being re-granted, dropping
  its reopening condition; K1 losing its TN3137 basis; OC-1 reopened, closed
  without a resolver, closed while still naming a pending owner) — and **1**
  deleting assertion A16. The mutations operate on the parsed JSON, not on text,
  so they cannot silently fail to apply.

Log: `TASK-260715-ypo7yo_validate-matrix-07.log` (r6, r5, r4 and r3 evidence
retained as `…-06.log`, `…-05.log`, `…-04.log` and `…-03.log`).
Harness: `TASK-260715-ypo7yo_validate-matrix.py`,
`TASK-260715-ypo7yo_mutate.py`, `TASK-260715-ypo7yo_preserve.py`, and
`TASK-260715-ypo7yo_check-portal-consumer.py` — the **board** gate rather than a
contract gate: it shells out to `task-board` from the repo root and compares the
live records of **both** consumers this contract pins against rules **A1** and
**P1**. Its `--simulate-board` flag exists only so `mutate.py` can drive board
negative gates without touching a live record.

### 9.4 Rule N1 — a count is derived, never written

r6 closed half of this class. Verdict 05's finding F1 had a second instance — a
stale App Group **record** count — and the scan r6 built for it
(`crossPlatformSharingContract.recordCountClaimRule`) is specific to App Group
record counts. The other live count class is the **size of a target's entitlement
allowlist**, and §9.1 above records it going wrong once already: r3's prose
claimed a number over a list that held a different one, r4 corrected it by hand,
and r5 moved it again when rule **K2** withdrew `keychain-access-groups` from
every macOS target. Three revisions, three numbers, three hand corrections, and no
gate — in **either** artifact.

Rule **N1** (`numericClaimContract` in the JSON) registers each of those claims
with the derivation that produces it:

```
allowlist(target, channel) =
      { keys with status in authoredStatuses }
    ∪ signingGenerated[platform].always
    ∪ ( channel == development ? signingGenerated[platform].developmentChannelOnly : ∅ )
```

Gate **R38** resolves each registered claim, recomputes the number from the rows,
spells it as an English word, and requires the rendered sentence **verbatim** — in
the JSON *and* in this document. For **N1-3** it also parses the fenced key list
in §9.1 and compares the **set** of keys against the derived allowlist in both
directions, so a row added to `macos.host` that nobody rendered, and a key left
rendered after its row was withdrawn, both fail. That is the check that would have
caught the r3 defect at the time: the number and the list beneath it disagreed, and
only a human noticed.

A **coverage scan** then requires every `<number> keys` claim in either artifact to
sit inside a registered claim, or to be excluded for a stated reason. Exactly one
phrase is excluded individually: the §9.1 paragraph that documents the r3
correction. Quoting a wrong number is how a correction is recorded — deriving it
would erase it. Two regions are excluded wholesale, on the same grounds that rule
S1 excludes `revisionLog` and rule A1 excludes `notes` — they are history, and a
past number in history is a true statement:

- the **change-history preamble** at the head of this document, everything before
  §1, which is the prose twin of `revisionLog`;
- **§13**, which records how each verdict was verified and necessarily quotes the
  numbers that were wrong at the time. Those must *not* be updated to the current
  allowlist size.

Excluding §13 wholesale opens one hole, so it is closed by registration rather than
left: the r9 entry in §13 states a **live** derived count of its own, and it is
registered as **N1-4**. A registered claim is recomputed wherever it lives — the
section exclusions govern the *scan*, not the *derivation*.

**The scan's bound is stated rather than implied.** It finds `<number> keys`. Two
of the registered claims render their number without that word adjacent, so the
scan alone would not have found them — *registration* found them. N1 guarantees
that every registered count is derived and that no `<number> keys` claim is
unregistered. It does not guarantee that no count of any other shape exists
anywhere.

---

## 10. Traceability

| element | spec requirement |
| --- | --- |
| four targets and their names | `.spec/platform-distribution.md` "Planned targets" |
| macOS provider is a system extension | `.spec/platform-distribution.md` signing/release channels; TN3134 |
| NE, App Group, Keychain as the state boundary — **on iOS production only** | `.spec/platform-distribution.md` "Apple capabilities". After r5 all three are macOS-free (G4, K2) and the App Group is also withheld from the iOS **probe** pair (D-9); only `ios.host` / `ios.provider` carry the full set. |
| least privilege on the extension | `.spec/security-privacy.md`; `.spec/threat-model.md` M-02 |
| host↔provider state is an App Group snapshot + Keychain refs — **iOS only; false on macOS, see below** | `.spec/architecture.md:111` |
| macOS host↔provider state is `providerConfiguration` + an app-message seed into a system-domain keychain item | `TASK-260728-7ii1xz_macos-credential-transport-decision.md` §5.1, §6 — **divergence from the spec, recorded not resolved here** |
| sandboxed hardened-runtime macOS host | `.spec/platform-distribution.md` Sparkle section; ADR-018 |
| Sparkle `-spks` / `-spki` Mach lookup exception on the host (D-6) | `.spec/platform-distribution.md` "The sandboxed host enables `SUEnableInstallerLauncherService` and Sparkle's documented … Mach lookup exceptions"; ADR-018; `.research/260721_macos-self-update.md` |
| no unreviewed exception entitlement (rule X1) | `.spec/platform-distribution.md` "Distribution has no `get-task-allow`, disabled library validation, unsigned/JIT executable-memory, or unreviewed exception entitlement" |
| iOS defined but not provisioned | ADR-024 |
| deferral is `blocked`, never an unlinked backlog item | ADR-027 |
| C1 authorizes exactly this matrix's macOS entries | ADR-028; `TASK-260728-q5kjta` AC4 |
| legacy identity preserved | `.spec/platform-distribution.md`; `scripts/check-legacy-preservation.sh` |
| probe identifier differs from the real app's | `.spec/goal-macos-v1.md` Hold H2 |

### 10.1 What r4, r5 and r6 hand downstream

Amendment **M6** was explicit that the §10 traceability row above, and any G2 text
implying a shared container on macOS, are **false on macOS**. Correcting them has
consequences beyond this artifact, and r5's two least-privilege corrections add
more. Each is recorded in the JSON under `downstreamConsequences` with a named
owner; none is actioned here, and no product source, spec file, or generated
project was modified by this revision.

| owner | consequence |
| --- | --- |
| `TASK-260728-q5kjta` | Ceremony C1 shrinks, and **its board text was corrected in r5** (verdict 04 F2) to match: exactly four macOS App IDs, Network Extensions only, **no** App Group record, **no** App Groups capability, **no** Keychain mutation, one Mac Development profile each, all four iOS App IDs excluded. Fewer mutations, same sitting. **r7, verdict 06 F1: its scope named the *superseded* revision `2026-07-28.r5`** — the revision verdict 05 rejected — while enumerating r6's mutations correctly. The scope now names the current revision; **the authorized mutation set is unchanged**, and rule **A1** plus the extended board gate make a stale label fail closed instead of surviving as prose nothing reads. |
| `TASK-260715-3jloqy` | **r6, F2: this task's own board contract was corrected**, because it is the task that *spends* the C1 authorization unattended — see §6. Description, scope, AC and checklist now state rule **P1** exactly: four macOS App IDs, Network Extensions on all four **including both hosts**, one Mac Development profile each, no App Group record, no App Groups capability, no Keychain portal mutation, no iOS App ID, no distribution profile. The removed AC2 clause *"the packet-tunnel entitlement appears only on provider identifiers"* was a material defect independent of r5. Portal verification must also assert **two negatives**. App Groups: no macOS App ID has the capability enabled and no Mac Development profile's `Entitlements` dict carries the key (**A16**). Keychain: no macOS bundle declares `keychain-access-groups` (**A17**). A17 is asserted against the **bundle**, not the profile — a Mac Development profile legitimately carries the team-wide `["<TEAMID>.*"]` wildcard, and that is not a finding. |
| `TASK-260715-uyju7n` | Generated macOS targets must declare **neither** `com.apple.security.application-groups` **nor** `keychain-access-groups`, and neither the App Groups nor the Keychain Sharing capability may be added to them in Xcode. G1's **Register App Groups** instruction now applies to iOS targets only. The `macos.host` allowlist is **eight** keys on `development`, **seven** on `developer-id` (§9.1). |
| `TASK-260715-33oofa` | **r9:** recorded because rule **D1** exposed this task as a *declared consumer the contract never explained* — its obligation sat inside the `uyju7n` row above, which is the **macOS** task. It is the iOS half, and it carries the opposite instruction: both generated iOS **production** targets must declare `com.apple.security.application-groups` with the registered iOS-style literal **and** `keychain-access-groups` with the shared group (G1, G4, K2 — iOS is where all three are real), and G1's **Register App Groups** setting applies *here and only here*. Both iOS **probe** targets declare neither (**A18**). Nothing is provisioned at C1: all four iOS App IDs are deferred under ADR-024, so this task authors entitlements against identifiers with no portal record yet, and **A9b** is the check that no iOS development profile is expected. |
| `TASK-260715-1r0fxv` | The macOS probe pair carries no App Group and no keychain group; its entitlement inspection gains **A16** and **A17** as negative checks. The app-message path is unaffected — `sendProviderMessage` needs no App Group. |
| `TASK-260715-1jckn0` | **r5, F3:** the iOS probe pair carries **no** App Group and no keychain group. Its host↔provider exchange is `sendProviderMessage` only, which is exactly what its **AC3** already specifies — **no acceptance criterion changes and no scope is added**. Its AC5 archive inspection gains **A18** as a negative check. A real shared-container deliverable would be the amendment path in the rows' `reopensOnly`: the criterion is written first, the entitlement follows. |
| `TASK-260715-379cpk` | **r5, F1:** the macOS Keychain vault must **not** pass `kSecAttrAccessGroup`. On macOS the host's items live in its default access group `262RZ595FP.works.relux.tunnel.mac`, supplied by the injected `com.apple.application-identifier`; naming the shared group now returns `errSecMissingEntitlement`. On iOS the vault still names `262RZ595FP.works.relux.tunnel.shared` explicitly. This is a **platform branch**, not a shared constant. The macOS default **moved** in r5 (D-8) — no item has been written yet so there is nothing to migrate, but the vault must not be authored against the r4 default. |
| `TASK-260715-1o9wjz` | **r5:** unchanged in substance, now unambiguous. The macOS resolver reads the provider-owned **file-based system-domain** keychain item seeded over the app-message channel; it never reads a Data Protection Keychain access group, and after r5 there is no macOS access group to read. iOS is unchanged. |
| `TASK-260715-3f4lxy` | The macOS snapshot loader cannot read an App Group container and cannot fall back to one; on macOS the snapshot arrives in `providerConfiguration`. iOS is unchanged. Same revision `7ii1xz` §8 already assigns. |
| `TASK-260715-1tzaed` | **`PlatformVPNIdentity` no longer type-checks against this contract on macOS.** `Sources/ReluxTunnelCore/VPNManagerRepository.swift:17` declares `appGroupIdentifier` as a non-optional `String` for both platforms; after G4 there is no macOS value to supply. The shape must change — most plainly to an optional or a platform-keyed identity. `production(for:)` still throws, so nothing is broken today; this matrix is the input that forces the change. |
| spec amendment, `TASK-260715-35nc5m` | `.spec/architecture.md:111` and `.spec/threat-model.md` DF-02/M-02 state an iOS property as if it were cross-platform. On macOS neither half holds: the container is not shared, and the secret lives in the root-unlocked system-domain keychain rather than the user's password-protected Data Protection Keychain. `7ii1xz` already flags `security-claims.md` and M-02; `architecture.md:111` is added here. |

---

## 11. Amendment rule

This matrix is amended only by `TASK-260715-ypo7yo` (or a successor task that
explicitly assumes ownership), on the strength of a named resolving task. An
amendment MUST update the JSON, bump `revision`, append to `revisionLog`,
**re-point every live board consumer this contract pins** — the authorization node
`TASK-260728-q5kjta` under rule **A1**, whose scope names the revision it
authorizes, and the portal mutation task `TASK-260715-3jloqy` under rule **P1** —
keep `validate_matrix.py` **and `check-portal-consumer.py`** passing, and state
which open constraint it closes. Downstream tasks do not locally reinterpret a row;
they raise a blocker against the owner.

**The re-pointing clause is not decoration.** r6 bumped the revision and re-pointed
one of the two consumers; that omission is reviewer verdict 06's finding F1, and
**R34 fails if this rule stops naming both task IDs and the word `re-point`.** An
amendment procedure that does not say which live records must follow is how a
contract acquires a consumer authorizing a rejected revision.

## 12. Consumers

`TASK-260728-q5kjta` (C1 scope) · `TASK-260715-3jloqy` (portal mutation) ·
`TASK-260715-1r0fxv` / `TASK-260715-9yp8to` (macOS probe, Gate P0) ·
`TASK-260715-1jckn0` (iOS probe, D-9) ·
`TASK-260715-uyju7n` / `TASK-260715-33oofa` (generated targets) ·
`TASK-260715-379cpk` / `TASK-260715-1o9wjz` (keychain vault, resolver) ·
`TASK-260715-3f4lxy` (profile snapshot loader) · `TASK-260715-1tzaed` (release
identity) · `TASK-260715-3gkwn0` (Developer ID / notary) · `TASK-260715-3661ps`
(iOS TestFlight/App Store) · `TASK-260715-3dno4w` (iOS profile inspection) ·
`TASK-260728-7ii1xz` (macOS credential transport, OC-1 and OC-4) ·
`TASK-260715-29ws8l` (profile trust and credential contract, OC-1) ·
`TASK-260715-2hhh7x` (profile key and ownership contract, OC-1) ·
`TASK-260715-35nc5m` (legacy migration decision; the `architecture.md:111`
amendment) · `TASK-260717-xempiv` (Sparkle integration; the rule X1 reviewed
exception and nested-code re-signing) · `TASK-260715-1uxx3i` (minimum-macOS CI
lane; the rule K3 floor check that closes OC-5, new in r10).

### 12.1 Rule D1 — a consumer must actually run after this contract

The four entries at the end of that list were **not** there before r9. Three of
them carried obligations assigned from inside prose fields —
`legacy.migrationDecisionOwner` had named `TASK-260715-35nc5m` for eight
revisions, and two sentences in §4.5 and §4.2 had named `TASK-260717-xempiv` for
five — and the fourth was named only in `OC-1.affects`. A list nothing derives
falls behind the contract that feeds it.

That is the smaller half. The larger half is that **the list was never compared
against the board's dependency graph at all**, and three declared consumers had
no path to this task:

| consumer | what it consumes | state before r9 |
| --- | --- | --- |
| `TASK-260715-1o9wjz` | the macOS extension credential resolver reads the system-domain keychain item, never an access group (K1, K2) | no dependency path to this task |
| `TASK-260715-3f4lxy` | the snapshot loader cannot read a macOS App Group container (G4) | no dependency path to this task |
| `TASK-260715-29ws8l` | its **AC2** specifies what travels in "App Group and `providerConfiguration` data" and its **AC4** specifies "Keychain accessibility, access group" — exactly what G4 and K2 decide | no dependency path to this task, **and it blocks the other two** |

With `max_parallel=1` the scheduler was free to run all three while this matrix sat
in `analysis` under its eighth changes-requested verdict. The resolver, the loader
and the profile-trust contract would each have been authored against an unaccepted
matrix — and 29ws8l without this matrix reproduces precisely the iOS-only
assumption that **OC-1** was raised against.

Rules **A1** and **P1** exist because a consumer that names a *revision* can name a
stale one. Every other consumer names no revision, so the dependency edge is the
only thing ordering it after acceptance — and **a missing edge fails silently**,
because nothing reads a prose consumer list. This is the verdict-05 F2 class one
field over: verdict 05 checked what a consumer *says*, A1 and P1 check which
revision it names, and nothing checked *when it runs*.

**The fix is one edge.** `TASK-260715-29ws8l` is now blocked by this task, which
orders all three, because it already blocks the other two. The edge is semantically
real rather than a scheduling trick — see its AC2/AC4 above — and the whole
`blockedBy` graph was checked for cycles before it was added.

**Rule D1** then closes the class. The declared-consumer set is **derived** by
scanning *every* string in the JSON for an element id, not by reading three named
lists, because that is how both prose-field owners were missed. Every id found must
be a declared consumer, a registered exemption, or this contract's own owner.
Reachability is **transitive** — thirteen consumers reach this task through
`TASK-260715-3jloqy`, which is the honest shape, since they consume the matrix
through the portal state it produces. Requiring a direct edge from each would
flatten a DAG the board already orders correctly.

Two deliberate strictnesses. **`done` is not an exemption:** having finished is not
evidence that a consumer ran with this contract in hand, it is evidence that it
ran, which is the failure this rule exists to catch. The only allowed basis is
**upstream**, and the gate *verifies* the upstream claim instead of accepting it —
`TASK-260728-7ii1xz` qualifies because it **blocks** this task, and requiring the
reverse would be a cycle. And the two unrelated blockers that stood in those three
chains are **described, not named**, in the JSON's `staleClaimsFound`: naming them
would make them mentions, and D1's own coverage rule would then demand they be
declared consumers of a contract they do not consume — a rule that manufactures
violations by documenting them.

`validate_matrix.py` cannot read the board, so **R37** checks only that the pin is
well formed and that the mention set and the consumer list agree in both
directions. The live check is a third block in `check-portal-consumer.py`, which
reads `blockedBy` for every task **and bug** — a bug can carry an edge, and a
closure over a subgraph would be wrong in both directions.

---

## 13. How the reviewers' findings were verified

Every finding was re-checked independently before being accepted, against the
spec's own text and against artifacts on this machine — not taken on trust.

### r12 — verdict 10

**The reviewer's control was reproduced before the finding was accepted.**
`X1-C1.reviewedIn` was moved from `2026-07-28.r10` to `2026-07-28.r2` in the
*unmodified* r11 artifact. `validate-matrix.py` printed `PASS — every rule holds`
over 2805 checks and exited **0**, where a negative control must exit **1**.
**CONFIRMED.** The reviewer's reading of why it matters is right: `r2` predates
the conditional register entirely, so the label attributes a review to a revision
that never saw the exception, and everything downstream of arming rests on that
attribution.

**r11 had already written the defect down.** `conditionalExceptionDerivation`
said, in the `reviewedIn` entry's own `whyNotACopy`, that pointing the field at an
older revision to imply a review that did not happen is the verdict-06 stale-label
class inside the register — and then bounded the field to *membership in the
issued revision set*, and recorded the shortfall in §4.5 under **Stated bound**.
Documenting an open bound is better than hiding one and is still not closing it.
That is the reason this survived a revision, and it is why the fix is a derivation
rather than a stricter string.

**The sweep found the same class in the active register, which no verdict had
reported and which was strictly worse.** `R26` required
`reviewedExceptions[].reviewedIn` to be *non-empty* and nothing else, so the
active register accepted `2026-07-28.r99` — a revision that has never existed,
the very case the conditional register had rejected since r11. Verified by
mutation against the unmodified r11 artifact: PASS, exit 0. That register is the
one whose single entry authorises an exception that is **actually present** in the
signed macOS host bundle, so it is gated here too, under `R26`.

**The introducing revision is computed, not read off r11.** `X1-C1` is absent from
the `r8` and `r9` baselines and present in `r10` — checked directly, in the
attached files, before the derivation was written. `X1-A1` is present in every
attached baseline, so the chain genuinely cannot decide it; the `r3` revision-log
entry is the oldest whose summary names
`com.apple.security.temporary-exception.mach-lookup.global-name` verbatim, and
`r2`'s does not name it at all. That asymmetry is why the rule declares two
evidence classes and refuses the weaker one wherever the chain can decide, rather
than pretending both entries rest on the same evidence.

**The residual bound is stated, not implied.** A baseline is pinned by digest, so
editing one to manufacture an introduction fails; editing a baseline *and*
recomputing its pin defeats the digest and is then caught by the derivation
disagreeing with `revisionLog[].introduces` — a fourth place, exercised as a
negative gate rather than asserted. Beyond that, an edit coordinated across the
baseline, its pin, the introduction record and the entry would pass this
validator. It was run against the preservation harnesses instead of assumed: with
the conditional entry injected into the `r9` baseline, `preserve.py` exits 1 on a
changed `exceptionEntitlementRule` and `preserve-r10.py` exits 1 on
*"conditionalExceptions is not new in r10"*. A cross-harness catch is weaker than
a gate and is recorded as such. The derivation is machine-checkable, with **64**
negative mutations behind `R39`, four of which corrupt a baseline rather than a
claim about one.

### r11 — verdict 09

**The finding was reproduced before it was accepted.** All three of the
reviewer's coordinated-drift mutations were replayed against the *unmodified* r10
artifact: `valuesIfArmed` and the row widened together to `/`; `channelsIfArmed`
and the row reduced together to `development`; `armedBy` moved to
`TASK-260715-9yp8to`. `validate-matrix.py` printed `PASS — every rule holds` and
exited **0** for each, where a negative control must exit **1**. **CONFIRMED**,
and the reviewer's reading of *why* it matters is right: a broadened path grants
more filesystem than was reviewed, a missing `developer-id` channel breaks the
shipping provider on the same OS policy, and a different arming owner severs the
evidence chain.

**The sweep required by item 3 found two more of the same class, and one that
passed by accident.** Moving the entry *and its row* to `macos.host` passed r10 —
a coordinated **target** drift, which would pre-authorize a filesystem exception
on a target nobody reviewed. So did a `reviewedIn` naming `2026-07-28.r99`, a
revision this contract never issued. Key drift *did* exit 1, but under **R35**'s
assertion-scope partition — the rule that noticed AS-11 scoped an entitlement no
row declared — not under the rule that owns the register. A gate that catches a
defect for an unrelated reason is not the gate that owns it, so all three are now
in **R39**.

**The counts were read in place, not taken from the verdict.** The preamble said
nine, §13 said seventeen, and the harness held seventeen. The verdict's item 4 is
correct, but correcting the string would have left the class: the shape rule N1
scanned for was `<n> keys`, so neither sentence was ever visible to it, and both
sat in scan-excluded regions besides. The count is now derived by the harness and
rendered into both artifacts, the preamble is scanned, and the derivation was
machine-checkable at r11 with 39 negative mutations behind `R39`.

**A third stale number surfaced one paragraph from the second.** With the preamble
scanned and the harness-count shape live, §9.2's opening sentence — *"applies 36
internal consistency rules (R1–R36)"* — was the same defect: a hand-written number
about the harness, in the section describing the harness, and wrong in both its
count and its range, since the file gates **R2–R39** and has never had an R1. It
is derived from the validator's own gate calls now. This is the fourth hand
correction of a harness number in this document and the last one that will be
needed.

### r10 — verdict 08

**F1 is accepted in full, and it is correct.** The reviewer's claim was narrow and
checkable: every observation behind "the provider needs no keychain entitlement
at all" was taken on **macOS 26.5 (25F71)**, the generated-target floor is **macOS
15.0**, and the contract had no version scope, no floor-specific exception, and no
reopening condition for sandbox-policy drift. All four are true as stated. r4 was
right about the OS it measured and silent about the nine below it.

**The cited evidence was re-read rather than carried forward.**
`/System/Library/Sandbox/Profiles/application.sb` on this Mac still carries
`(when (entitlement "com.apple.developer.networking.networkextension") (allow
file-read* file-write* (subpath "/Library/Keychains")))` at lines 792–793, and
`com.apple.securityd.xpc` / `com.apple.SecurityServer` at lines 655–656. The r4
reading is accurate. Its *scope* was the defect, not its content.

**The floor could not be measured here, and that is reported rather than worked
around.** `sw_vers` reports macOS 26.5 (25F71); the only installed toolchain is
Xcode 26.5 (17F42) with macOS 26 SDKs; there is no macOS 15 host, virtual machine,
installer, or second volume, and no VM tooling (`tart`, `UTM`, `prlctl`,
`VBoxManage` all absent). Sandbox profiles ship with the OS and are **not** SDK
content — `find` over `Xcode_26_5.app` returns no `application.sb` — so no
installed SDK could stand in for the floor. Apple does not document the file's
contents. **No secondary source closes it, so the gap is modelled instead of
asserted**, which is the alternative the verdict explicitly allowed.

**The installed-product argument was re-run and still does not settle it — in
either direction.** All three shipping providers on this Mac were re-inspected for
`LSMinimumSystemVersion` against their keychain entitlements (§4.4). Surfshark
ships the `/Library/Keychains/` exception at a **10.15** minimum, bundled with two
unrelated paths; PureVPN's two providers carry `keychain-access-groups` at
**10.15**; Tailscale's carries neither at **12.4**. Support ranges that wide say
nothing about macOS 15.0 specifically. The reviewer's point that Surfshark's
exception is not proof of *necessity* stands — and the symmetric point is now
recorded in rule K3: Tailscale's silence is not proof of *redundancy* either.

**Required rework, item by item.** (1) The floor is modelled explicitly as rule
**K3**, since it could not be verified here. (2) **K1** gains `osFloorScope`, the
provider row gains `osVersionScope`, and its reopening condition names K3 — so an
OS-floor difference has a stated path instead of being rejected as drift; rule
**X1** gains a `conditionalExceptions` register, disjoint from its active one by
**R26**'s equality, holding pre-authorized entry **X1-C1**. (3) Assertion **A19**
and gate **R39** make the unarmed state machine-checkable, with **seventeen**
negative mutations; the owner is `TASK-260715-1uxx3i`, an **existing** task whose
`macos-15` minimum lane and credential-free static checks already cover the read,
and which already reaches this contract — **no board element was created**. (4)
Ceremony C1 is untouched: a temporary file exception has no portal record, and
`ceremonyC1Impact` is `none` under R39. (5) The r8 baseline is attached as a
task-scoped outcome, so the r8→r9 preservation gate is independently rerunnable,
and `preserve-r10.py` proves the r9→r10 boundary the same way.

**One gate was found lying by omission.** The r10 run exposed a *negative* gate
that had silently stopped working: the R33 document mutation hard-coded
`revision **2026-07-28.r9**`, so it stopped applying the moment the contract
moved and was counted as holding while mutating nothing. It now derives the
revision pair from the contract. This is rule N1's defect class one file over —
in the harness that is supposed to catch it.

### r9 — no verdict; self-audit

**There is no verdict 08.** r8 was handed off to review and this revision is a
self-audit of the artifact in the interval, so there was nothing to re-verify —
everything below was **derived** before it was written.

**Reachability was computed, not spot-checked.** Every task and bug record on the
board was read for `blockedBy`, a transitive closure was taken from each declared
consumer, and the result was 16 of 19 reaching this task. The three that did not
were then read for whether an edge is *semantically* real rather than merely
convenient, because adding a dependency to make a gate pass is the same defect as
correcting a string to make a gate pass. `TASK-260715-29ws8l` AC2 and AC4 require
it to specify the App Group snapshot and the Keychain access group, which are
exactly what rules **G4** and **K2** decide, so the edge is real; and since it
already blocks the other two, **one** edge is both correct and sufficient. The
whole graph was checked for cycles with the edge added — none, since this task
depends only on `TASK-260728-7ii1xz`, which depends on nothing.

**The mention set closes exactly.** After the four additions, the ids found by
scanning every string in the JSON number the same as the declared consumers plus
this contract's own owner, with no residue in either direction. That symmetry is
what R37 checks; it is the reason the rule can be stated as an equality rather than
a containment.

**The N1 numbers were recomputed, not trusted.** `macos.host` authors five keys —
the Network Extension entitlement, `system-extension.install`, `app-sandbox`,
`network.client`, and the r3 Sparkle Mach-lookup exception — and the toolchain
injects three on `development`, two on `developer-id`. Both surviving prose numbers
are therefore correct at r9. They were checked precisely because §9.1 records the
same sentence being wrong at r3 and different again at r4: the reason to gate a
number is not that it is currently wrong, it is that it has moved every time a row
moved.

**One thing found and deliberately not actioned.** This task still lists
`TASK-260728-7ii1xz` in its own `Blocked By` even though that task is `done`. That
is a resolved edge, not a stale claim — it is the record of where rules K1, K2 and
G4 came from, and rule D1's exemption register depends on the edge existing. It is
named here so a reviewer does not have to wonder whether it was missed.

### r8 — verdict 07

Both findings were **re-derived from the rows** before being accepted, not taken
on trust. Both **CONFIRMED**.

**F1 — A5 contradicts the target rows and A18.** The `application-groups` status
of `ios.probe.host` and `ios.probe.provider` is `prohibited` (rule G4's
`probeRule`, r5). A5 said the key is present on *every* iOS bundle; A18 says it is
absent from *both* iOS probe bundles. Both cannot hold. Because the matrix is the
input to automated entitlement checks, the contradiction is not cosmetic: a check
following A5 would have **over-entitled both disposable probes**, and one
following A18 would have failed A5. Confirmed by deriving the granted set
straight from the rows — two targets, not four.

**F2 — A9 is not platform-scoped.** All four iOS profile rows declare
`development.devices` as `["deferred — ADR-024"]`; the four macOS rows declare
`["this Apple-silicon Mac"]`. A9's universal claim is therefore false for exactly
half the rows. Confirmed by reading all eight `profiles[].development.devices`
values. The failure mode is real in both directions: a profile check following A9
would reject every iOS development profile the moment one existed, or would
"pass" by treating the deferral sentinel as a device name.

**A third instance, found here and not reported by any verdict.** Registering
**A6**'s scope required its clauses to be rendered in this document — and this
document's own assertion table still read *"`keychain-access-groups` present only
where status is `required` — `ios.host`, `ios.provider`, **`macos.host`**;
absent from `macos.provider` and the whole probe family"*. That is the **r4**
contract. r5 removed the group from `macos.host` under rule **K2**, so the grant
set has been `ios.host` and `ios.provider` alone since then, with **every** macOS
row prohibited. This is the verdict-05 **F1** defect — a prose artifact still
granting the macOS host a Keychain group the JSON prohibits — one revision later
and one file over. **R33** did not catch it because R33 renders `grantClause`s,
not assertions; **R35**'s rationale-document check is what closes that half. The
table also had **no rows at all** for A17 and A18; both are now present and gated.

It is recorded in `assertionScopeContract.staleClaimsFound` alongside the two
reported findings, because the pattern — a projection of the rows that nothing
recomputes — is the same one three times, and the third instance is the argument
for closing the class rather than correcting the strings.

### r7 — verdict 06

**F1 — the ceremony authorizing a superseded revision. CONFIRMED.** The reviewer's
own `jq` freshness gate was re-run verbatim against r6 and returned `false`, exit
**1**, exactly as reported.

**The mutation set was then checked independently of the reviewer's claim that it
matched**, because the required rework says to correct the revision *without*
changing the already-correct mutation set — and that instruction is only safe if the
set really is correct. Field by field against `c1AuthorizationScope`: all four
authorized App IDs are named with a right boundary (so
`works.relux.tunnel.mac` is not satisfied by `works.relux.tunnel.mac.tunnel`), the
Network Extensions and Mac Development wording is present, `ADR-024` is cited, and
all four iOS App IDs plus `works.relux.proxy` appear **only inside a negation**.
The revision label was the only defect. **Preserving the set is therefore correct,
and it is preserved.**

**Then the class was swept rather than assumed bounded.** All **402** live board
elements were scanned for a matrix revision label. Exactly **two** carry one:

1. `TASK-260728-q5kjta`'s `scope` — the reviewer's finding. **A real defect.**
2. `TASK-260715-ypo7yo`'s own `notes` — **which the reviewer did not report.**

**The second is not a defect, and the distinction is load-bearing.** `notes` is an
append-only progress log, where "r5 (`2026-07-28.r5`) closes all three verdict-04
findings" is a *true historical statement* — the same reason rule S1 excludes
`revisionLog` from its count scan. A gate that flagged it would be manufacturing a
failure out of correct history, and the obvious "scan every field" implementation
would do exactly that. **That is why A1's `boardGate` declares `excludedFields`**,
and why R34 fails if a field is ever both checked and excluded. The sweep is also
what lets this revision assert something stronger than the reviewer asked for: **no
third live board consumer carries a revision label at all**, so extending the gate
to these two consumers covers the class rather than the instance.

**Why the fix is a rule and a procedure, not a label.** The reviewer's rework asked
for four things and all four are done — the scope re-pointed, the gate extended to
both consumers, a negative gate for a restored superseded revision, and the stale
`.sh` reference corrected. But the *cause* is none of those: r6 bumped `revision`
and re-pointed one of two consumers, and nothing in the amendment procedure said
otherwise. So `amendmentRule` now names both consumers and the obligation to
re-point them, and **R34 fails if it stops doing so**. The instance is fixed by the
board edit; the class is fixed by the procedure plus the gate.

**And the board gate had never been proven to fail.** r6 introduced it and only ever
ran it in the passing direction. Thirteen board negative gates now drive it from a
simulated record — including the case the reviewer's own `jq` gate would pass: a
node that names the current revision **and** a superseded one. `contains($revision)`
returns `true` there; A1 fails it, because the derived banned set is checked
independently of the required phrase.

**Those gates immediately found two defects in the gates themselves.** Neither came
from review; both came from a mutation that should have failed and did not:

1. **The right-boundary check could not see a sentence-final identifier.** r6's
   `(?![\w.-])` rejected *every* following dot, so the mutation appending "Also
   create `works.relux.tunnel.ios`." to the portal task's scope read as **no
   mention at all** and passed. The r6 absence checks were defeatable by a full
   stop. The boundary is now `(?![\w-])(?!\.\w)` — a dot violates the boundary only
   when it *continues* the identifier, which is the property the check actually
   wanted. This strengthens rule P1's checks as well as A1's.
2. **A 220-character symmetric negation window let a neighbouring clause's negation
   launder an authorization.** The mutation turning "`works.relux.proxy` is not
   touched" into "`works.relux.proxy` is **migrated**" passed, because AC4's earlier
   "explicitly **NOT** authorized" was still inside the window. A window wide enough
   to reach backwards over a list of four App IDs is necessarily wide enough to do
   this. Negation is now attributed **per clause**, and `negationWindow` was
   **removed** from the contract rather than left as a field the gate reads and
   ignores — a dead field a gate still consults is the same rot R32's dead-exclusion
   check exists to catch.

A gate whose first negative run finds something its author had not is worth more
than one that confirms what he already believed. That was true of R32's count scan
in r6, and it is true of these two in r7.

### r6 — verdict 05

**F1 — the summary contradicting the rows. CONFIRMED.** The reviewer's own `jq`
gate was re-run against the r5 artifact and returned `false`, exit **1**, exactly
as reported. The finding was then widened rather than taken at face value: every
string in the r5 JSON was swept for a stale r4 grant or count claim, and **two**
survivors turned up — `crossPlatformRules[2]`, which the reviewer found, and
`appGroupStyleRule.statement`'s "one record per family", which had been true of
r4's two-record world and false since r5 deleted the probe record. That is why the
fix is a rule over all six sentences plus a count scan rather than two string
edits: two independent instances in one artifact is a class, not a typo.

**And the rule immediately found a third.** R32's count scan, run for the first
time, failed on `appGroupLeastPrivilegeRule.ceremonyCostIsZero` — "**the two App
Group records** are allocated at that sitting" — which neither the reviewer nor r5
had spotted. It is now corrected and the sentence carries a note saying how it was
found. A gate whose first run finds something its author had not is worth more
than one that confirms what he already believed.

**One deliberate divergence from the required rework, stated plainly.** The
reviewer's rework item 1 asks the sentence to say the group is granted to the iOS
host and provider only and that "every macOS target uses no custom Keychain access
group". The corrected sentence states the exclusion **universally** — "and to NO
macOS target on either channel, in either family" — rather than naming the macOS
host as an excluded target. Naming a target is precisely what went stale: r4 named
the host as a grantee, r5 moved the row, and the name stayed. A universal clause
is derived from all eight rows by R32 and has nothing to forget. The reviewer's
gate, which asserts textually that this sentence no longer contains "macOS host",
passes. The host-specific reasoning lives in **K2** and **D-8**, which is where it
belongs.

**F2 — the portal task's contract. CONFIRMED.** `TASK-260715-3jloqy`'s board
record was read in full and all four quoted statements are present verbatim. Its
dependency edges confirm the sequencing the finding assumes: it is blocked by this
matrix, by `TASK-260715-apc34w`, and by `TASK-260728-q5kjta`, so it runs
**after** the human sitting, unattended, with whatever its board record says. The
AC2 half was checked independently of anything r5 changed: this contract's own
target rows have required
`com.apple.developer.networking.networkextension` on **all eight** targets since
r1, and R7 has enforced it since r2, so "only on provider identifiers"
contradicted r1 as much as it contradicts r6 — it is not an App Groups
regression, it is a pre-existing defect that would have left both macOS host App
IDs without the capability and failed at first build, after the ceremony was over.
The correction is pinned as rule **P1** and gated by
`TASK-260715-ypo7yo_check-portal-consumer.py`, which reproduces the reviewer's
hand check: run against the pre-fix record it failed 14 of 20 checks; after the
correction, 20 checks, exit 0.

### r5 — verdict 04

**F1 — the macOS host Keychain group. CONFIRMED.** The finding turns on a claim
that had to be checked rather than assumed: that withholding the entitlement
still leaves the host able to read and write its own items. It does, and Apple
says so directly. *Sharing access to keychain items among a collection of apps*
states that the application-identifier entitlement is added to **every** app at
signing, that the system recognises it as the app's **default keychain access
group**, that items stored in it are **private to that app**, and that "if you
don't specify any keychain access groups, then the app ID is the default". TN3137
adds the macOS-specific half: the access-group list is built from code-signing
entitlements **authorized by a provisioning profile** — and `macos.host` is
provisioned on both channels (**R14**), so its injected identifier qualifies.
Both documents were fetched from `developer.apple.com` on 2026-07-28 (the
rendered pages are JavaScript-driven, so the documentation JSON endpoints were
read instead).

The same reading produced something the verdict did **not** name: withdrawing the
entitlement **moves the default access group**, because the first
`keychain-access-groups` entry outranks the app identifier. Under r4 an
unqualified macOS write would have landed in `…tunnel.shared`; under r5 it lands
in `…tunnel.mac`. Nothing has been written yet so there is no migration, but the
vault must be authored against the new default — recorded as a downstream
requirement on `TASK-260715-379cpk` (§10.1) rather than left to surface at first
build. The reviewer's second exit — naming a second macOS consumer — was checked
and is empty: K1 excludes the root/system-domain provider, and both macOS probe
rows already withhold the key.

**F3 — the iOS probe App Group. CONFIRMED.** `TASK-260715-1jckn0`'s scope and
acceptance criteria were read in full. They name `NETunnelProviderManager`
save/load/enable/start/status/app-message/stop, one versioned provider response,
and a clean stop. There is **no** shared container, `UserDefaults` suite, or
snapshot anywhere in that task, and its AC3 puts the host↔provider exchange on
app messaging. r4's claim that the probe "exercises the same shared-container
path production depends on" is therefore unsupported by the probe's own contract.
The reviewer's alternative exit — amend the probe task to add a real
shared-container deliverable — was considered and **declined**, because no board
element asks for one and adding a deliverable purely to justify an entitlement
already granted is the circularity the finding names.

**F2 — Ceremony C1's board text. CONFIRMED, and fixed on the board.** The scope
of `TASK-260728-q5kjta` was read and did conflict with `c1AuthorizationScope` in
all four ways the verdict listed. `set_details` corrected the scope and AC4; the
`blockedBy` link to this task is unchanged. This was autonomous metadata rework.

### r4 — verdict 03, and the `TASK-260728-7ii1xz` amendment packet

**F1 — CONFIRMED, and the fix goes further than the finding.** Verdict 03 said
the macOS App Group was granted on a possible future transport plus an
operational convenience. Both halves check out against the r3 artifact:
`appGroupPurposeRule.macOS` said *"the channel … **will** use"*, and the rationale
ended *"so C1 need not be repeated"*. The reviewer offered two exits — prove the
selected transport needs it, or withhold pending `TASK-260728-7ii1xz`. Neither was
taken as written, because by the time this rework began that task was **`done`**
and amendment **M6** had explicitly handed the least-privilege call here: *"a
private root-context container may still have uses this task did not survey;
whether it survives least privilege is a separate review under `ypo7yo`'s
ownership."* So the survey was done rather than the row deferred again.

| what was checked | how | result |
| --- | --- | --- |
| what the entitlement grants on macOS | read `/System/Library/Sandbox/Profiles/application.sb` (26.5 / 25F71) in full at the only two places the key appears — lines 302–330 and 459–465 | six grants, tabulated in D-7. Three home-relative, **three system-wide**. The r3 shorthand "sandbox-visible namespace" was neither wrong nor precise enough to decide anything |
| whether any of the six is used | against the selected candidate D and the rejected candidates | none. Grant 4 (Mach prefix) was candidate C, rejected; grant 5 (POSIX IPC) was never proposed by anyone |
| M6's "may still have uses" | `application.sb:107-108` — `(appsandbox-container-common)` / `(appsandbox-container-macos)` are at top level, inside no `(when (entitlement …))` | a private group container is **redundant**, not merely unused: every sandboxed target already has its own container. This is a stronger answer than M6 expected |
| the amendment packet's own keychain claim | re-read `application.sb:792-793` and `655-656` locally rather than trusting the citation | exact. NE-entitled processes get `/Library/Keychains` read+write; every sandboxed process gets the `securityd` / `SecurityServer` lookups |
| the ceremony objection | C1's `explicitlyNotAuthorized` already lists all four iOS App IDs under ADR-024 | withholding costs **no** extra sitting, so the convenience argument does not need to be weighed against anything — it simply evaporates |

**Three things recorded rather than smoothed over.**

1. **Three of the six grants really do cross the root/user boundary.** "App Groups
   are useless on macOS" would have been the tidier story and it is false. The
   verdict rests on *these grants are unused*, not on *the entitlement is inert* —
   which is why the reopening conditions in D-7 name individual grants.
2. **Grant 5 (`ipc-posix*`) was found by reading, not by looking for it.** No
   candidate transport mentioned POSIX shared memory. It is written down so a
   later design cannot claim the option was never on the table.
3. **OC-4 gained real evidence while being downgraded.** `application.sb:326-328`
   shows the Mach prefix is built from the literal entitlement value, so the
   sandbox side is style-agnostic — which contradicts r3's flat "no source
   addresses it". It is still not proof: nothing was signed, and the `launchd` and
   profile sides were not exercised.

**One judgement call for the reviewer.** The macOS **probe** rows were withheld
too, though verdict 03's gate only covered `macos.host` and `macos.provider`.
Leaving the probe granted would have parked the identical defect one row over,
and `TASK-260715-1r0fxv`'s scope and AC name no App Group function. The gates
treat it as the same class of defect (mutation *"the same defect one row over"*).

**The secondary correction is fixed and the number changed underneath it.** r3's
prose said the `macos.host` development allowlist was "exactly seven keys" over a
list of ten. r4 states **nine** — because six are authored now that the App Group
is withheld, plus three injected — and eight on `developer-id`. §9.1.

### r3 — verdict 02

| finding | verification |
| --- | --- |
| F1 — missing Sparkle Mach lookup exception | Three independent confirmations. (a) `.spec/platform-distribution.md` mandates `SUEnableInstallerLauncherService` and the `<host-bundle-id>-spks` / `-spki` exceptions for the sandboxed host. (b) This repo's own `.research/260721_macos-self-update.md` records the identical two-value set, written before this task existed. (c) `codesign -d --entitlements :-` over `/Applications` found six shipping apps carrying exactly the `<bundle-id>-spks` / `-spki` pattern under this key, three of them sandboxed with those two values and nothing else. **Confirmed.** |

Two things the evidence added that the finding did not state, recorded rather
than smoothed over:

1. **Tailscale carries the exception while unsandboxed.** The same product cited
   as D-4 evidence ships `io.tailscale.ipn.macsys-spks` / `-spki` with
   `app-sandbox = false`, where the exception is inert. So "shipping products
   carry it" is not on its own a reason to grant it — the reason is the spec plus
   this project's sandbox. D-6 says so explicitly instead of leaning on the
   product count.
2. **Sparkle's binary names three endpoints, not two** (`-spks`, `-spki`,
   `-spkp`). The spec entitles two because the Installer Status/Connection and
   Downloader services stay disabled. That makes the two-value set a deliberate
   least-privilege choice, and it is now recorded as such rather than looking like
   an omission the next reviewer has to re-derive.

The finding also exposed a gap it did not name: the spec bans "unreviewed
exception entitlement", and the matrix had no rule about exceptions at all. Rule
X1 (§4.5) closes that, so this class of defect cannot recur one key at a time.

### r2 — verdict 01

| finding | verification |
| --- | --- |
| F1 | Apple DTS statement quoted verbatim in §4.1, plus three shipping Developer ID products on this Mac carrying the suffixed value on both host and provider. **Confirmed.** |
| F2 | Apple DTS statement quoted verbatim in §4.3, including the 21 Feb 2025 Developer-website change and the Xcode 16.3 default. **Confirmed.** |
| F3 | `codesign -d --entitlements :-` over four signed macOS bundles and `security cms -D` over a local Mac Development profile, establishing the injected key set. **Confirmed.** |
| F4 | `com.apple.security.app-sandbox` read off three shipping host/provider pairs: hosts `false`, providers `true`. **Confirmed, and stronger than the finding stated** — the shipping evidence shows hosts are routinely *not* sandboxed. |

One place where the evidence pushed **against** the reviewer's recommendation is
recorded rather than suppressed: F2 suggested using the iOS style "unless a
documented project constraint requires the older, separate macOS-style identity",
and every Mach-service-prefix example found does use the macOS style. That did not
change the decision — this project has no XPC Mach service today — but it is
recorded as **OC-4** with a named owner and a concrete amendment path, instead of
being asserted away.

Commands, exit codes and full output are in
`TASK-260715-ypo7yo_validate-matrix-02.log` and in the handoff evidence. No
product source, spec file, or generated project was modified. No secret value,
key path, key ID, issuer ID, or account credential appears in any of these
artifacts; third-party bundle identifiers and Team IDs quoted as evidence are
public metadata embedded in shipped binaries.
