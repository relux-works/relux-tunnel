# TASK-260728-3a2dnr — results (rework round 4)

The round-3 independent review returned **CHANGES REQUESTED** on exactly one
axis. Its substantive findings on planning, ceremony shape, dependency edges,
notary custody, Sparkle ordering, and autonomy counts were **accepted**; the
single failing gate was `swift test`, red on a reproducible
`ProviderAdapterContractTests.providerFailureHandoff` ordering race
(observed `1009`, required `1007`).

Round 4 closes that gate and re-proves every other gate on the current tree.
No planning decision was changed, because the review did not ask for one and the
regenerated plan is identical (verified below, not asserted).

---

## Required item 1 — race diagnosed and fixed in a separately scoped defect ✅

The review required the fix to live outside this planning task. It does.

**`BUG-260728-3jfjkh`** *stabilize-provider-failure-first-callback-ordering*
(parent `STORY-260715-1y04r0`) owns the defect, the fix, the regression
coverage, and its own independent review. It is now `done` with an accepted
reviewer verdict.

Root cause, as recorded on the bug: `TunnelProviderAdapter.providerDidFail` was
`nonisolated` and deferred *all* admission into a freshly spawned unstructured
`Task`. Swift orders nothing between unstructured tasks contending for the same
actor, so two sequential provider-failure callbacks could enter
`handleProviderFailure` in reverse order. The `cancelTunnelIssuedGeneration`
ledger enforced exactly-once but had no notion of *which* call arrived first, so
the second error (`internalInvariant` 1009) beat the first
(`runtimeStartupFailed` 1007) in **10 of 40** focused runs (~25%). That is why
round 3 saw red where round 3's producer had seen green — the gate was flaky in
the failing direction, not misreported by the reviewer.

Fix (in the bug's commit `6bfa966`, not in this task's diff): a file-private
`NSLock`-guarded `ProviderFailureAdmission` claim taken **synchronously** on the
caller's thread before the task hop, released when `startGeneration` bumps
`latestGeneration`. Both platform seams inherit it through the shared adapter.
NSError codes were not changed and the assertion was not relaxed, exactly as the
bug's own scope required.

**This planning task still contains no tunnel product code.** Verified below by
an empty product-path `git status`.

## Required item 2 — focused test and full suite re-run to real exit 0 ✅

Independently re-run on the current tree in this run, not quoted from the bug:

| Command | Result |
| --- | --- |
| `swift test --filter ProviderAdapterContractTests.providerFailureHandoff` | **exit 0** |
| same focused filter, **15 consecutive** invocations | **15/15 pass, 0 failures** |
| `swift test` | **335 tests / 29 suites passed, exit 0** |
| `make validate-core` (boundaries, native deps, core test, core build) | **exit 0** |

Logs: `.temp/TASK-260728-3a2dnr/focused-providerFailureHandoff-01.log`,
`.temp/TASK-260728-3a2dnr/swift-test-full-01.log`,
`.temp/TASK-260728-3a2dnr/validate-core-01.log`.

The count moved 332 → 335 because the bug added three regression tests
(`providerFailureFirstCallOrdering` on both seams and
`providerFailureConcurrentAdmission`). The repeatability run is included
deliberately: a single green run of a previously ~25%-flaky test would not be
honest evidence.

## Required item 3 — results updated with exact exit codes ✅

This document. The round-3 record is retained verbatim below so the accepted
substance and its judgement calls stay auditable.

---

## Round-4 gate table (all re-run on the current tree)

| Gate | Command | Result |
| --- | --- | --- |
| board validation | `task-board validate` | **Board is valid. No issues found.** exit 0 |
| container links | `task-board repair-links` | **No suspicious container links found.** exit 0 |
| focused regression | `swift test --filter ProviderAdapterContractTests.providerFailureHandoff` | exit 0 |
| focused repeatability | same filter ×15 | 0 failures |
| full suite | `swift test` | 335 tests / 29 suites, exit 0 |
| core validation | `make validate-core` | exit 0 |
| whitespace | `git diff --check` | clean, exit 0 |
| no product code in this task | `git status --porcelain -- Sources Tests Protocol relay scripts config Package.swift Makefile` | **empty** |
| independent DAG traversal | tasks **and** bugs, 356 elements | **0 missing blocker targets, 0 cycles** |
| deferral sealing | `list(type=task, status=blocked)` | **15**, all iOS / Gate A0 / NIOSSH — matches ADR-027 |
| secret-leak scan | `AuthKey_*`, private-key blocks, `.p8` paths, issuer/key IDs over `.spec`, `.task-board`, `.planning` | only ADR-025's own **policy prose**; no path, key ID, issuer ID, or key bytes |
| invariant presence | host-key-before-auth, Keychain-only, fail-closed DNS, bounded memory, PacketFlow bridge, rootless relay, notarized release | all present in `.spec/` |

## Plan re-derivation — the fix changed nothing in the plan

`waves.py` was re-run against the live DAG after the bug landed and its output
diffed against the round-3 `plan.json`:

| | round 3 | round 4 |
| --- | --- | --- |
| autonomous agent tasks | 226 | **226** (same) |
| human-input nodes | 17 | **17** (same list, same order) |
| sealed deferred | 15 | **15** (same) |
| unreached behind deferred/holds | 34 | **34** (same) |
| full serial timeline | — | **byte-identical** |

`BUG-260728-3jfjkh` is `done`, so it is correctly absent from the forward plan
rather than inflating the autonomous count.

## Contract ordering re-verified live

| Edge | State |
| --- | --- |
| `TASK-260715-1ozsb6` ← `TASK-260728-yx2fca` | present — libssh2 integration cannot start before the M0 contract re-scope is accepted |
| `TASK-260715-1u2vpc` ← `TASK-260715-2ayxqn` | present — the functional/rekey matrix stays behind Gate P0 |
| `TASK-260728-3cveay` ← `1gjxer`, `3kimon`, `yx2fca` | present — the four deferred Tier-2 M3 semantics cannot be fabricated or forgotten |
| `TASK-260728-q5kjta` ← `TASK-260715-ypo7yo` | present — the single ceremony is bounded by the approved identifier matrix |
| `TASK-260728-3bj9bk` ← `ziprhs`, `xempiv`, `1mt4e7` | present — Sparkle pinning/verification stays after the target and appcast exist |

## Deviation from the literal task AC, carried forward unchanged

AC1 asks the canonical artifacts to encode "Relux Works signing/notary
availability". They encode signing-identity availability and explicitly **deny**
notary readiness, because the credential exists only as a mode-0600 file and the
Keychain-only invariant forbids calling that ready (ADR-025). Encoding AC1
literally would re-introduce the defect an earlier review round required fixing.

---

# Round 3 record (retained verbatim — substance accepted by the round-3 review)

Rework after the independent review of 2026-07-28 returned **CHANGES REQUESTED**
with 6 required items. Each item below states the exact change and its evidence.
No tunnel product code was written; `Sources`, `Tests`, `Protocol`, `relay`,
`scripts`, `config`, `Package.swift`, and `Makefile` are untouched.

The reviewer was right on every item. Two of them were the same class of defect:
the plan asserted things in prose that the live graph and the task texts did not
support.

---

## Item 1 — C1 is now one real up-front sitting in the live graph ✅

**Root cause.** No board element owned the human sitting. C1 was prose; the graph
ordered `apc34w` → {`3jloqy`, `dveo1o`}, so a `max_parallel = 1` scheduler
correctly produced `HUMAN C1/D1` → autonomous segment → `HUMAN C1` again.

**Fix.** New task **`TASK-260728-q5kjta`** *conduct-c1-apple-permission-ceremony*
(parent `STORY-260716-2m2tl1`, `review=required`, estimated). It is the only
up-front human-input node and holds every grant: Keychain unlock and
always-allow, portal authentication including two-factor, authorization of the
macOS identifiers/capabilities/profiles, `notarytool store-credentials` into a
named Keychain profile plus the source-file disposition decision, and Sparkle
ed25519 generation into custody. Its only blocker is `TASK-260715-ypo7yo`, the
approved matrix that defines exactly what may be authorized.

`apc34w`, `3jloqy`, `dveo1o`, and `ziprhs` are now blocked by it and were
re-scoped to unattended agent evidence work. **None of their evidence obligations
were dropped** — `dveo1o` still has to authenticate through the named profile
alone and verify the disposition actually holds, and `ziprhs` still has to state
that downstream integration remains open.

Recorded as **ADR-028**. Generated result: one batch `C1` containing exactly two
nodes — the ceremony and owner decision D1 (`intsjz`, no Mac access needed) —
then five autonomous tasks, then `A1`.

**A1 stays separate**, and `S1` (below) is separate for the same reason: an
approval cannot be pre-granted for an artifact that does not exist yet.

## Item 2 — Provider evidence is no longer scheduled before P0 ✅

`TASK-260715-1u2vpc ← TASK-260715-2ayxqn` **restored**. The libssh2 functional and
rekey matrix keeps its full scope, including the Gate-P0 provider smoke on the
physical Apple-silicon Mac; it simply runs after the P0 disposition. Restoring
was chosen over splitting because splitting would have moved a real Apple-target
row into a weaker early harness task.

Consequence, stated rather than hidden: M0 engine selection (`1gjxer`) now lands
after P0 too. That is correct — the engine cannot be selected without evidence it
works on the Apple target. The M0 harness core (`1ozsb6` behind `yx2fca`, and
`2d3g5e`) still runs in segment 1, so libssh2 viability signal is not delayed to
the end.

## Item 3 — The zero-input claim is now evidence-based ✅

The primary orchestrator ran a read-only `BatchMode` probe against the
owner-authorized SSH alias: authentication succeeded without a prompt and the
remote reports Darwin. No hostname, address, username, key path, credential, or
remote content was recorded. Evidence:
`TASK-260728-3a2dnr_relux-ssh-readiness.md`.

Conditional hold X1 is withdrawn and the reasoning is recorded on
`TASK-260715-39xz9g` itself, including the limit: the probe is **not** conformance
evidence, and the task still owes raw pre-auth host-key evidence and its own
fixture validation.

## Item 4 — Canonical contradictions reconciled ✅

Every statement that otherwise **gated this goal** now carries an unambiguous
deferral qualifier. The future iOS/App Store requirement is preserved verbatim in
each case, with an explicit "re-arms unchanged" clause.

| document | what changed |
| --- | --- |
| `.spec/architecture.md` | Gate A0 no longer says "before product implementation proceeds beyond a disposable spike"; a new scope paragraph states A0 is an App Store/App Review gate, deferred for the Developer ID direct-distribution macOS release, mandatory before iOS submission, sealed by ADR-027 |
| `.spec/delivery.md` | M4 iOS archive/TestFlight and the App Review package marked deferred and removed from this goal's M4 exit; a separate deferred exit condition preserves them |
| `.spec/platform-distribution.md` | the physical-iPhone baseline row is a named deferred gap for this goal; the Apple-silicon Mac is named as the only physical baseline that gates it |
| `.spec/product.md` | "A physical iPhone is required for milestone gates" scoped to iOS milestone gates and explicitly excluded from this goal |
| `.spec/validation.md` | iOS/TestFlight install and the App Review notes check marked deferred |
| `.spec/threat-model.md` | A0/P0 release-boundary bullet given explicit scope |
| `.spec/security-privacy.md` | the pre-VPN disclosure requirement now binds **every** client including macOS, not only iOS — a strengthening, and it removes the ambiguity |
| `.spec/decisions.md` | ADR-026 updated for the ceremony node; **ADR-028** added |
| `.spec/goal-macos-v1.md` | stop-the-line section rewritten around the single ceremony node and the full later-gate list |

**23 board elements** were re-scoped by exact-substring substitution
(`.temp/TASK-260728-3a2dnr/rescope3.py`, dry-run verified 30/30 before applying)
so no other requirement in any field changed: `jnpbyz` (and its garbled round-2
AC6), `3ao1u9`, `eto58m`, `2cjf4i`, `d37sts`, `2byjks`, `EPIC-260716-3fyjn0`,
`EPIC-260715-w5gzf4`, `1k3wsk`, `37eem9`, `3hvz8n`, `gfptap`, `ixevcp`, `k5uxim`,
`132kb2`, `zwtrhy`, `2kchi0`, `14u9bo`, `3r0993`, `pmww4f`, `1tzaed`, `29r0k8`,
plus `EPIC-260715-2mqgvm` AC1 ("Gate A0 has documented evidence").

`TASK-260715-pmww4f` was a live contradiction worth naming: its AC said the
generated workspace "is gated behind Gate A0/P0". It now says Gate P0 only.

A rescan of every reachable element for unqualified physical-iPhone/Gate-A0
gating language returns only the deferred branch itself (`2itwz7`, `243sh0`,
`2dtdql`), which is correct — that branch must keep its requirements.

## Item 5 — Complete dependency-edge ledger ✅

New artifact `TASK-260728-3a2dnr_dependency-edge-ledger.md`, generated by
`.temp/TASK-260728-3a2dnr/edge_audit.py` + `ledger.py`, which parse the
`## Blocked By` section of **every** `progress.md` at `git HEAD` and in the
working tree. Nothing is sampled.

- **75 removed** — 37 task-to-task, 38 container-involving
- **21 added** — all task-to-task
- **0 elements deleted**; no task, resource, note, or evidence was destroyed

Every task-to-task removal is classified and justified, and each row shows the
blocker's live reachability and the blocked task's **current** blocker list, so a
reviewer can check the retained gate rather than take the claim on faith:

| class | count |
| --- | --- |
| iOS deferral (ADR-024 + ADR-027) | 26 |
| NIOSSH deferral (ADR-014 + ADR-027) | 3 |
| Gate A0 deferral (ADR-013 + ADR-027) | 3 |
| dependency-cycle repair | 2 |
| ceremony ordering (ADR-028) | 1 |
| superseded by a stricter edge | 1 |
| redundant, gate still transitively enforced | 1 |

The removal the reviewer named as proof the audit was needed —
`whtdsf ← 2ayxqn` — turns out to be the "redundant" row: `whtdsf` keeps `32umrc`,
which is itself blocked by `2ayxqn`, so Gate P0 still precedes it.

The 38 container removals were `task-board repair-links` clearing unsupported
container-to-container links, which also carried the four container-level cycles
present at `HEAD`. For each one the ledger checks **live** whether the same
ordering is still enforced at task level: 34 yes, 4 no. All four are intentional
(three are the Gate A0 deferral; one decouples the SSH engine spike from the
packet-bridge spike per ADR-011, which also stops a physical-iPhone gate leaking
into engine selection).

The ledger closes with an invariant re-check: host-key-before-auth, Keychain-only
secrets, fail-closed DNS, bounded memory, the public PacketFlow bridge, the
rootless exec/stdio relay, macOS provisioning/P0, and signed+notarized release
each name the live blocker chain that still enforces them.

## Item 6 — Corrected autonomy labels and counts ✅

`waves.py` now models three things instead of one:

- **HUMAN node** — completion requires a human action or decision. It is a
  barrier and is never counted as autonomous, even when agent work runs inside
  the same node afterwards.
- **agent follow-up** — work that merely consumes access or a decision granted by
  an earlier human node. Autonomous, and named as that node's follow-up.
- **autonomous** — everything else.

Human nodes were found by reading every reachable element's own
description/scope/AC for human-decision language, not from a hand-kept list.
That surfaced six the previous rounds missed:

| node | why it is human |
| --- | --- |
| `2ayxqn` (S1) | AC5: the accountable engineering or release owner acknowledges the P0 verdict |
| `1dsqnj` (R1) | "Manual governance checkpoint… Human product/engineering owners ratify"; AC2 "silence is not approval" |
| `l639qp` (R2) | "manual accountable ratification checkpoint" |
| `2d308k` (R3) | "MANUAL batch ratification checkpoint… Release, security, and platform owners ratify" |
| `1r48pc` (H3) | clean-system install of the Developer ID-signed candidate with system-extension approval; scope forbids bypassing system approval, and the release identity differs from the development build so H2 does not carry over |
| `2aessv` (H4) | AC2 requires real system-approval rows; scope excludes "human approval without recorded evidence" |
| `yynqbr` (S3) | scope: "bad-candidate declaration, freeze and owner approval" |

Honest totals from the live DAG: **226 autonomous agent tasks; 17 human-input
nodes in 9 batches.** Round 2's 245/8 is superseded.

False positives were excluded deliberately and are listed in the plan: "no manual
Xcode edits", out-of-scope mentions of TestFlight, system-approval *guidance* in
UI copy, and physical macOS runs that reuse an earlier approval
(`12x6oq`, `2wqffe`, `zwtrhy`, `qdpbd1`).

---

## The generated plan

| | what | size |
| --- | --- | --- |
| Segment 1 | harness core, relay assets, contract re-scope, identifier matrix | 23 agent tasks, 5 waves |
| **Batch C1** | the permission sitting + owner decision D1 | 2 human nodes |
| Segment 2 | account readiness, portal mutations, notary check, Sparkle evidence, probe | 5 agent tasks, 3 waves |
| **Batch A1** | approve the probe's system VPN / system extension | 1 human node |
| **Batch S1** | owner acknowledges the Gate P0 verdict | 1 human node |
| **Segment 3** | **the longest autonomous run: M0 matrix → M1 → M2 → M3** | **167 agent tasks, 26 waves** |
| Batch H2+D2+D3+D4+R1+R2+L2 | real-app VPN approval, 3 owner decisions, 2 ratifications, legal review | 7 human nodes |
| Segment 4 | M1/M4 physical evidence, localization, accessibility | 20 agent tasks, 6 waves |
| Batch S2 | release identity/entitlement/migration approval | 1 human node |
| Segment 5 | release-contract follow-ups | 2 agent tasks, 2 waves |
| Batch C2+R3 | release environment ceremony + M5 ratification | 2 human nodes |
| Segment 6 | notarized DMG, appcast, signed publication | 9 agent tasks, 5 waves |
| Batch H3 / S3 / H4 | clean-system approval, rollback freeze, final acceptance | 3 human nodes |

15 elements stay `blocked` with evidence packets (iOS, Gate A0, NIOSSH); 34 more
are unreached behind them. No `blocked` element and nothing behind one appears in
any autonomous segment — re-verified after every edit.

## Gates

| Gate | Result |
| --- | --- |
| `task-board validate` | **valid, 0 issues** (exit 0) |
| `task-board repair-links` | **No suspicious container links found** |
| `swift test` | *superseded — see the round-4 gate table above* |
| `git diff --check` | clean (exit 0) |
| product-path `git status --porcelain -- Sources Tests Protocol relay scripts config Package.swift Makefile` | **empty** |
| non-board diff | `.spec/architecture.md`, `.spec/decisions.md`, `.spec/delivery.md`, `.spec/goal-macos-v1.md`, `.spec/platform-distribution.md`, `.spec/product.md`, `.spec/security-privacy.md`, `.spec/ssh-transport.md`, `.spec/threat-model.md`, `.spec/validation.md`, `LOGBOOK.md` |
| invariant presence scan | host-key-before-auth, Keychain-only, fail-closed DNS, bounded memory, packetFlow bridge, rootless exec/stdio relay, signed/notarized release — all present |
| secret-leak scan (specs + task resources + temp artifacts) | no private-key block, key ID, issuer ID, `AuthKey_*` name, `.p8` path, or passphrase value |
| unqualified iPhone/A0 gating rescan over every reachable element | only the deferred branch itself (`2itwz7`, `243sh0`, `2dtdql`), which correctly keeps its requirements |

Contract ordering re-verified after all edits: `TASK-260715-1ozsb6` is still
blocked by `TASK-260728-yx2fca` and cannot start before it is accepted;
`TASK-260728-3cveay` is still blocked by `1gjxer`, `3kimon`, and `yx2fca`, so the
four deferred Tier-2 M3 semantics cannot be fabricated or forgotten.

## Board delta this round

- **1 task created**: `TASK-260728-q5kjta` (estimated, `review=required`, full
  scope and AC, gap justification in notes, linked in both directions).
- **4 tasks re-scoped** from human-attended to unattended agent evidence:
  `apc34w`, `3jloqy`, `dveo1o`, `ziprhs`. No evidence obligation removed.
- **23 elements** re-scoped by exact substitution for the ADR-013/ADR-024
  deferral qualifiers.
- **6 dependency edges added** (`q5kjta ← ypo7yo`; `apc34w`, `3jloqy`, `dveo1o`,
  `ziprhs ← q5kjta`); **1 restored** (`1u2vpc ← 2ayxqn`); **0 removed**.
- Traceability notes written on `q5kjta`, `39xz9g`, `1u2vpc`, `apc34w`, `3jloqy`,
  `dveo1o`, `ziprhs`.

## Known judgement calls

1. **`2ayxqn` declared sign-off S1.** Nobody asked for it, but AC5 plainly
   requires an owner acknowledgement, and counting it as autonomous would repeat
   the exact defect of review item 6. It is a short asynchronous acknowledgement,
   not a sitting; it cannot be merged into A1 because the verdict does not exist
   until `9yp8to` has been reviewed.
2. **`1r48pc` and `2aessv` declared human.** A Developer ID-signed candidate
   installed on a clean system re-triggers the system-extension approval; the H2
   approval covers the development-signed real app, not the release candidate.
   Both are at the very end of the release path and do not touch the working-
   client milestone.
3. **`ziprhs` keeps its `generate-and-install-…` name** even though generation
   moved to C1. Renaming would break cross-references in ADR-026,
   `TASK-260728-3bj9bk`, `.spec/platform-distribution.md`, and
   `.spec/security-claims.md`; its description, scope, and AC state the new
   boundary precisely.
4. **`security-privacy.md` widened rather than qualified.** The pre-VPN
   disclosure requirement said "the iOS app MUST". Marking it deferred would have
   left the macOS client with no disclosure requirement, so it now binds every
   client. This is the only edit in this round that adds a requirement; it adds
   it to the macOS path, which is the path being executed.
5. **Container-link removals reported as one class.** They were produced by
   `task-board repair-links`, not by hand, so the ledger justifies them as a class
   and then proves per edge whether task-level ordering survived — 34 yes, 4
   intentional no.

## Deviation from the literal task AC, stated explicitly

AC1 asks the canonical artifacts to encode "Relux Works signing/notary
availability". They encode signing-identity availability and explicitly **deny**
notary readiness, because the credential exists only as a mode-0600 file and the
Keychain-only invariant forbids calling that ready (ADR-025). Encoding AC1
literally would re-introduce the defect the previous review round required
fixing. Carried forward from round 2 unchanged.
