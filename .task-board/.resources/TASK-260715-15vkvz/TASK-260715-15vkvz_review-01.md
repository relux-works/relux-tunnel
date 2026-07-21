# TASK-260715-15vkvz review 01 — changes requested

## Findings

1. P1 — Unsupported future manager-contract versions can be downgraded. `inspectOwned` classifies a version greater than 1 as future only when `UInt16(exactly:)` succeeds. Values such as 65536 or `Int.max` therefore become `.corrupt`; `ensure` explicitly accepts `.corrupt`, applies the canonical v1 protocol, and saves it. This violates AC 2/4 and the accepted contract requirement that every version greater than 1 is preserved with zero setter/save/remove calls. Preserve every positive future Int version, use an error representation that cannot overflow, and add ensure/remove/duplicate-repair zero-mutation tests for values above UInt16.max.

2. P1 — Explicit enable does not reject active session transitions. `setEnabled(true)` skips `stopIfNeeded` and has no guard for `.connecting`, `.reasserting`, or `.disconnecting`, so it reaches `setEnabled` and save during a transition. The accepted lifecycle contract requires enable to have no active transition. It also returns immediately for an already-enabled manager instead of performing the contract-described explicit save/reload operation. Add a stable transition outcome and zero-write tests for all transitional states; align already-enabled behavior with the normative save/reload contract.

3. P2 — Required stale-object and reload-persistence evidence is incomplete. The stale tests cover owned-to-owned replacement only, while the task checklist explicitly requires an unrelated-manager stale-object conflict test. The fake load also returns the same manager object after save, so the suite does not prove that verification consumes a distinct freshly loaded object or rejects a save that reloads noncanonical persisted fields. Add stale reload cases that become unrelated, unmarked, or future-owned and assert zero mutation of the new objects; add distinct post-save manager instances plus persisted-field mismatch verification.

## Independent validation

- `swift test --filter OwnedVPNManagerRepositoryTests`: PASS, 18 tests.
- `make validate-core`: PASS, 236 tests in 24 suites plus build.
- `swift format lint --recursive Sources Tests Package.swift`: PASS.
- `git diff --check`: PASS.
- Existing iOS Simulator and macOS build logs end in BUILD SUCCEEDED.

Verdict: changes requested; route to `to-dev` for implementation and test rework, then a fresh reviewer cycle.