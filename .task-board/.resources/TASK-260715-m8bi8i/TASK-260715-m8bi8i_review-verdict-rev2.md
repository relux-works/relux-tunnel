# TASK-260715-m8bi8i review verdict — revision 2

## Verdict

Accepted. CR `CR-TASK-260715-m8bi8i-2` revision 2 was reviewed at candidate tree `3f84a08ab1590b3a5649ed40b003eef051385bbf` against base `cd7187adc02ad2ebd54fad9b3583381e9256dcf5`. The exact binary patch SHA-256 is `dee8de3c4fb01a0d13b4f32cbf1cf8c9d91daa45e02fb4b35962fedd1b102d4b`.

No review finding requires rework. The revision-1 findings are closed at the production entry point `HarnessApplication.run -> M1RuntimeHarnessCommand.run`: mandatory SSH/DNS loss must now drive `TunnelRuntimeCoordinator` to `.failed` before cleanup stop, and the released simulated host owner owns the real `HarnessCoreComposition` plus `DeterministicHarnessSessionFactory` bootstrap boundary before runtime-owned TCP/DNS forwarding.

## Independent negative evidence

All mutants were applied only to a disposable exact-candidate copy and restored before the final gates. The restored `M1RuntimeCommand.swift` SHA-256 is `f247f10825bcb255ad08adbc9735d29067751ec6c5d7b482128c40c53097c5c5`, byte-identical to the candidate object.

- SSH health delivery was narrowed to impossible `generation == 0`. `swift test --filter productionEntryRequiresSSHHealthDelivery` exited `1`; the production entry returned lifecycle failure rather than mandatory-failure exit 74.
- DNS health delivery was narrowed to impossible `generation == 0`. `swift test --filter productionEntryRequiresDNSHealthDelivery` exited `1` with the same refusal shape.
- Host-owner release was narrowed to impossible `expectedGeneration == 0`. `swift test --filter productionEntryDoesNotRetainOrConsultHostOwner` exited `1` before successful TCP/DNS forwarding.
- Descriptor close accounting was narrowed to impossible `descriptor == -1`. `swift test --filter successfulComposedGenerations` exited `1` with `m1-runtime resource growth detected`.
- Restored focused SSH/DNS tests and restored repeated-success test each exited `0`.

Production call sites under test are `HarnessApplication.run`, `M1RuntimeHarnessCommand.run`, `M1HarnessSSHSession.injectLoss`, `M1HarnessDNSConsumer.injectLoss`, and `M1HarnessTrackingSocketIO.closeDescriptor`.

## Commands rerun by this reviewer

- `make m1-runtime-harness-test`: exit `0`; six M1 tests passed, harness product built, fixture manifest passed 7/7.
- Two additional unchanged-binary fixture-manifest runs: both exit `0`; each row reported `passed=true` and `privacySafe=true`; observed exits were exactly `0/70/71/72/73/74/74`.
- `swift test --filter ReluxTunnelHarness`: exit `0`; 38 tests in three suites passed.
- `swift test`: exit `0`; 514 tests in 44 suites passed with the existing 25 known unavailable-ReluxNIOSSH issues.
- `make check-core-boundaries`: exit `0`.
- `swift format lint --strict` on every changed Swift source/test: exit `0`.
- `git diff --check` for the exact base/candidate pair: exit `0`.

Producer evidence was inspected but not substituted for these reruns. The task-scoped fixture manifest, dependency revisions, CI commands, expected outputs, privacy-safe reporting, resource assertions, and LOGBOOK/README documentation match the acceptance criteria.

## Reviewer artifacts

- `.temp/TASK-260715-m8bi8i/m1-runtime-harness-review-rev2-01.log`
- `.temp/TASK-260715-m8bi8i/m1-runtime-fixture-report-review-rev2-02.json`
- `.temp/TASK-260715-m8bi8i/m1-runtime-fixture-report-review-rev2-03.json`
- `.temp/TASK-260715-m8bi8i/swift-harness-review-rev2-01.log`
- `.temp/TASK-260715-m8bi8i/swift-full-review-rev2-01.log`
- `.temp/TASK-260715-m8bi8i/core-boundaries-review-rev2-01.log`
- `.temp/TASK-260715-m8bi8i/swift-format-review-rev2-01.log`
- `.temp/TASK-260715-m8bi8i/negative-review-rev2-ssh-delivery-01.log`
- `.temp/TASK-260715-m8bi8i/negative-review-rev2-dns-delivery-01.log`
- `.temp/TASK-260715-m8bi8i/negative-review-rev2-host-owner-01.log`
- `.temp/TASK-260715-m8bi8i/negative-review-rev2-descriptor-accounting-01.log`
