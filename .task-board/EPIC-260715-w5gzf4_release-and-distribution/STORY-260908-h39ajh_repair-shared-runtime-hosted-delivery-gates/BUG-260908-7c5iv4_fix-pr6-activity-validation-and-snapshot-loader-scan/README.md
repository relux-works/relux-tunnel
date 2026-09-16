# BUG-260908-7c5iv4: fix-pr6-activity-validation-and-snapshot-loader-scan

## Description
PR 6 at signed head 87451b53960ceabe88a01c44c287fee7f9ebf386 fails hosted board/spec validation and pinned offline relay toolchain. The board checker treats .task-board/.activity ID directories as ordinary elements requiring README/progress. The supply-chain scanner rejects Foundation Data URL loads in SnapshotDiff test support unchanged from base. Both failures were independently reproduced from a clean exact-head archive by RUN-260907-765f2f. Fix the actual boundaries and add negative regression coverage; never waive the failures as external CI.

## Scope
.github/workflows/ci.yml board validation path and narrowly extracted checker if justified; scripts/relay_supply_chain.py with exact file-URL/test-support boundary and focused tests; narrowly necessary existing main validation-contract correction only if required to compose the accepted Shared Runtime dependency. No protocol, SSH engine, VPN lifecycle or unrelated supply-chain-policy change. Keep clean baseline and PR-head evidence separate.

## Acceptance Criteria
1. Actual CI board checker accepts activity streams but fails a genuine incomplete element, including a negative that detects overbroad hidden-directory skipping. 2. Actual relay supply-chain audit accepts legitimate local snapshot loading only under a justified boundary and rejects a malicious network/runtime-download variant. 3. Reproduce both failures before the fix and prove targeted positive and negative behavior after; verify on exact PR 6 composition, not only a base missing Shared Runtime. 4. Preserve signed existing objects and unrelated work; publish a minimal immutable CR for independent review before updating hosted delivery. 5. Stop and preserve work before 04:59 Asia/Tbilisi 2026-09-08; no real VPN, no successors, no tool source patches or installs.
