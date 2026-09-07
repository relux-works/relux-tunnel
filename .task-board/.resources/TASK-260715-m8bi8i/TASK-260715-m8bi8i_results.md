# TASK-260715-m8bi8i results — review rework

## Outcome

The composed `m1-runtime` harness now satisfies the two revision-1 review findings at the production entry point `HarnessApplication.run -> M1RuntimeHarnessCommand.run`.

- `M1RuntimeHarnessCommand.run` injects SSH or DNS mandatory loss, waits for the production `TunnelRuntimeCoordinator` to publish `.failed`, and only then calls `stop(.providerFailure)` as idempotent cleanup. It no longer manufactures the expected terminal state with an explicit stop.
- `M1HarnessHostOwner` now owns the real `HarnessCoreComposition` and `DeterministicHarnessSessionFactory` bootstrap boundary used to create each runtime. The command releases that owner after readiness, proves it deallocated, and only then exchanges runtime-owned TCP and safe-DNS traffic.
- Dedicated production-entry tests separately bind SSH health delivery, DNS health delivery, and host-owner independence.

The original M1 scope remains intact: versioned configuration, production shared coordinator and bridge-backed packet composition, deterministic packet/SSH/TCP/DNS/route substitutes, ordered readiness, representative traffic, aggregate diagnostics, clean stop, repeated generations, stable failure exits, zero resource growth, and privacy-safe CI output. No containing app, Network Extension, VPN preference, real credential, public network, route, DNS, interface, or packet-filter operation ran.

## Negative evidence

Production call site: `M1RuntimeHarnessCommand.run` in `Sources/ReluxTunnelHarnessSupport/M1RuntimeCommand.swift`, reached through `HarnessApplication.run`.

1. SSH delivery was narrowed so `M1HarnessSSHSession.injectLoss` delivered to `healthSink.receive` only for impossible `generation == 0`. `swift test --filter productionEntryRequiresSSHHealthDelivery` exited `1`; the response became generic lifecycle failure instead of expected exit `74`.
2. DNS delivery was narrowed so `M1HarnessDNSConsumer.injectLoss` delivered only for impossible `generation == 0`. `swift test --filter productionEntryRequiresDNSHealthDelivery` exited `1` with the same refusal shape.
3. Host-owner release was narrowed to impossible `expectedGeneration == 0`. `swift test --filter productionEntryDoesNotRetainOrConsultHostOwner` exited `1` before traffic could be reported successful.

Every mutant was restored from `.temp/TASK-260715-m8bi8i/M1RuntimeCommand.swift.pre-mutants`; `cmp` succeeded after each restore. The restored production source SHA-256 is `f247f10825bcb255ad08adbc9735d29067751ec6c5d7b482128c40c53097c5c5`. Logs:

- `.temp/TASK-260715-m8bi8i/negative-narrow-ssh-delivery-01.log`
- `.temp/TASK-260715-m8bi8i/negative-narrow-dns-delivery-01.log`
- `.temp/TASK-260715-m8bi8i/negative-narrow-host-owner-release-01.log`

## Fixture manifest commands and results

Manifest: `Fixtures/M1Runtime/TASK-260715-m8bi8i_fixture-manifest-v1.json`.

```bash
make m1-runtime-harness-test
python3 scripts/validate-m1-runtime-harness.py \
  --executable .build/debug/ReluxTunnelHarness \
  --output .temp/TASK-260715-m8bi8i/m1-runtime-fixture-report-rework-02.json
python3 scripts/validate-m1-runtime-harness.py \
  --executable .build/debug/ReluxTunnelHarness \
  --output .temp/TASK-260715-m8bi8i/m1-runtime-fixture-report-rework-03.json
```

All three unchanged-code executions exited `0`. Each reported `passed=true`, seven of seven rows passed, and every row reported `privacySafe=true`. Observed exit codes were exactly `0`, `70`, `71`, `72`, `73`, `74`, and `74`. The success fixture itself runs three generations and asserts zero descriptor, task, channel, socket, native-runtime, and host-owner growth.

## Validation

- `make m1-runtime-harness-test`: exit `0`; six focused tests passed, product build passed, manifest passed 7/7.
- `swift test --filter ReluxTunnelHarness`: exit `0`; 38 tests in three suites passed.
- `swift test`: exit `0`; 514 tests in 44 suites passed with the existing 25 known unavailable-ReluxNIOSSH issues.
- `make check-core-boundaries`: exit `0`.
- `swift format lint --strict` on the changed Swift source and tests: exit `0`.
- `git diff --check`: exit `0`.

One attempted `swift test --filter M1RuntimeHarnessTests -count=1` invocation exited `64` because `-count` is a Go test flag and unsupported by SwiftPM. No tests ran in that invocation. The corrected Swift command immediately passed and is the reported gate.

## Task-scoped artifacts

- `.temp/TASK-260715-m8bi8i/m1-runtime-harness-test-rework-01.log`
- `.temp/TASK-260715-m8bi8i/swift-harness-suite-rework-01.log`
- `.temp/TASK-260715-m8bi8i/swift-full-rework-01.log`
- `.temp/TASK-260715-m8bi8i/check-core-boundaries-rework-01.log`
- `.temp/TASK-260715-m8bi8i/swift-format-rework-02.log`
- `.temp/TASK-260715-m8bi8i/m1-runtime-fixture-report.json`
- `.temp/TASK-260715-m8bi8i/m1-runtime-fixture-report-rework-02.json`
- `.temp/TASK-260715-m8bi8i/m1-runtime-fixture-report-rework-03.json`
