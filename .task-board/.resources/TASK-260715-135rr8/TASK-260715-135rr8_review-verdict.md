# TASK-260715-135rr8 — CR rev1 independent review verdict

Verdict: **changes requested**. Route: `to-dev`.

Reviewed change request: `CR-TASK-260715-135rr8-1`, revision 1.

- Declared base OID: `a3a3352697686154fa69cc7c12d5eff9bec9d15c`.
- Candidate tree OID: `9151ec165c428d0c7749d8d95ff183bd58db2585`.
- Current integration base: `d177ac7dae6c10b7527c15f0a1ad31387890828e` (`main` tree `1ff0faff38d3b16d0ff75d94744ab59a94b1001a`).
- Patch SHA-256 independently reproduced: `17fc8d95d7554004a9ac673b3c04431e4548b2bc34d2cc327244fa94d1011014`.

## Blocking findings

1. **Rev1 is stale-base and contains duplicate already-integrated MTU scope.** The six-path rev1 delta is based on `a3a3352`, not current `main` `d177ac7`. `MTUMatrixCommand.swift`, `SmokeCommand.swift`, and `HarnessTests.swift` have identical blob IDs in current main and candidate (`8925bb8...`, `15921edb...`, and `3a192eb...` respectively), yet rev1 re-adds/modifies them. Against current main, the only repository paths that differ from the candidate after excluding board data are `LOGBOOK.md`, `README.md`, and `HEVBridgeIntegrationTests.swift`. A clean-index application check against current main failed with exit 1: `MTUMatrixCommand.swift: already exists in index`, plus patch failures in `LOGBOOK.md`, `README.md`, `SmokeCommand.swift`, and `HarnessTests.swift`. This violates review-focus requirement 1 and blocks integration.

2. **Raw matrix evidence is not bound to the exact reviewed tree.** The attached raw JSON records `sourceRevision` as stale base `a3a3352`, while the reviewed candidate tree is `9151ec1`. The implementation hard-codes that stale commit at `HEVBridgeIntegrationTests.swift:377`; dependency revision is only `current worktree`. Candidate working-file blob hashes do match the declared candidate blobs, but the attached measurement cannot establish that it ran from those bytes. This violates exact-tree validation and AC1 source-revision authenticity.

3. **Lifecycle evidence contains a constant attestation rather than a measurement from the matrix run.** `physicalMemoryAndConcurrencyMatrix` writes lifecycle `result` as a string referring to another test and unconditionally writes `monotonicGrowthObserved: false` at lines 359 and 368. The matrix run does not collect lifecycle footprint samples or derive that boolean. This is fabricated/proxy metric evidence under the negative-evidence contract, even if the separate lifecycle test passed.

4. **Required independent repeatability is absent for rev1.** Producer evidence reports physical matrix `1/1`; review-focus requires at least three independent reproductions or equivalent repeatability proof. No reviewer rerun is counted because findings 1–3 already make rev1 unacceptably stale and unauthentic. Running expensive physical/full-suite gates cannot cure those defects.

## Checks and exit codes

- Initial reviewer status mutation: exit 0.
- Compact board/resource query: exit 0.
- Tool/platform readiness (`task-board`, `git`, Swift 6.3.2 arm64 macOS, `rg`): exit 0; scratch record at `.temp/TASK-260715-135rr8/reviewer-tool-readiness.md`.
- Candidate patch/resource SHA-256: exit 0, matches CR declaration.
- Candidate working-file blobs vs candidate tree for all six paths: exit 0, all match.
- Exact rev1 `git diff --check`: exit 0.
- Rev1 patch apply check against a temporary index populated from current main: exit 1, as expected for the stale/duplicate delta.
- Safety scan of the exact rev1 delta found final sampling through public `task_info(TASK_VM_INFO)` and no `proc_pid_rusage`; no prohibited host-mutating command was executed by this review.
- Focused tests, full Swift suite, coverage, strict format, and physical matrix repetitions: not rerun because the mandatory stale-base and evidence-authenticity gates already failed. Producer-pass claims are not promoted to reviewer evidence for the exact tree.

## Required rework for CR rev2

1. Rebase/regenerate the candidate from current main (or its exact successor) and publish a clean CR containing only TASK-260715-135rr8 scope; exclude already-merged TASK-260715-gyg51r MTU changes.
2. Bind raw evidence to the exact new candidate tree/revision and pinned dependency revisions. Do not hard-code the old base or use `current worktree` as provenance.
3. Measure lifecycle samples in the run that emits the report, or attach and cryptographically bind a separate lifecycle artifact; derive `monotonicGrowthObserved` from captured samples instead of writing `false`.
4. Reproduce the final opt-in physical matrix at least three times on the exact rev2 tree, attach each raw/log artifact, then rerun focused/full/coverage/format/diff/privacy-safety gates against that same tree.

No code was modified by the reviewer. No NetworkExtension/VPN, routes, DNS, interfaces, packet filters, SSH sessions, Keychain, global pressure, `sudo`, `powermetrics`, `memory_pressure`, or `launchctl` operation was used.
