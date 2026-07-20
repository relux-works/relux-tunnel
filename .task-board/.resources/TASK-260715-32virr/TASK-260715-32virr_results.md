# TASK-260715-32virr — deterministic coordinator fault-suite evidence

Date: 2026-07-21
Role: tester
Rework: 01

## Test deliverable

- Extended `Tests/ReluxTunnelCoreTests/TunnelRuntimeCoordinatorTests.swift`; production sources remain unchanged.
- Every one of the eleven startup failure-table rows now asserts its exact `TunnelRuntimeCoordinatorError.startupFailed` redacted domain/code, exact rollback order, exactly one cleanup of every acquired resource, one disconnecting publication, one failed publication, terminal error preservation, and internal/external baselines.
- Added the committed settings-apply error disposition. Not-committed performs zero clears; committed and uncertain perform exactly one clear; all three preserve `networkSettings/network_settings_apply_failed` and restore the fixture baseline.
- Directly exercised `ProviderStopReason.startupFailure` and `.providerFailure`. Both assert the exact runtime-invariant error, capability revocation before cleanup, full reverse cleanup, repeated-stop single completion, and resource baselines.
- Expanded the legal/illegal control table from seven to ten rows with start-while-stopping, start-after-stopped, and start-after-failed rejection. Existing dedicated tests reconcile stop-during-start, stop-while-usable/stopping/failed, current/stale/healthy/late callbacks, and stop-before-start.
- Retained the fourteen before/after ownership-boundary cases, eight continuation-driven stop phases, 32 concurrent starts, 32 repeated stop/health race generations, all mandatory health mappings, and 100 factory lifecycle iterations with typed task/timer/socket/channel/dependency counters.
- Correctness scheduling uses checked continuations and a fixed fake clock. The test file invokes neither `Task.sleep` nor `Task.yield`.

## Verification

| Command | Result |
|---|---|
| `swift test --filter TunnelRuntimeCoordinatorTests` | PASS — 21 tests; 11 exact startup mappings, 14 ownership boundaries, 8 stop phases, 10 controls, 4 health components, 2 direct failure-stop reasons |
| focused command repeated 25 times | PASS — 25/25 suite passes |
| `swift test --sanitize=thread --filter TunnelRuntimeCoordinatorTests` | PASS — 21 tests, no Thread Sanitizer report |
| `swift test --enable-code-coverage --filter TunnelRuntimeCoordinatorTests` plus `xcrun llvm-cov report ... TunnelRuntimeCoordinator.swift` | PASS — 95.48% lines, 92.25% regions, 96.36% functions |
| `make validate-core` | PASS — boundary/native gates, 213 tests in 23 suites, post-test `swift build` |
| `swift-format lint --strict --recursive Sources Tests Package.swift` | PASS |
| `git diff --check` | PASS |
| no-`Task.sleep`/no-`Task.yield` audit | PASS |
| `task-board validate` | PASS |

## Resource baseline

The fixture separately accounts for packet-read tasks; DNS timers; SSH, DNS, and packet sockets; TCP and packet channels; and SSH, TCP, DNS, packet, and settings dependencies. Successful lifecycles, exact startup failures, direct failure-stop reasons, concurrent controls, and mandatory health loss restore those counters to zero. One hundred factory generations also restore the coordinator's retained configuration, startup task, cleanup task, settings, and component footprint after every generation.

## Remaining gaps

No known in-scope gap remains. Real Network Extension APIs, real SSH servers, HEV performance, physical-device execution, UDP, reconnect policy, and UI behavior remain excluded by task scope. TSan evidence covers the shared host SwiftPM coordinator and deterministic fakes, not a physical-device sanitizer run.

## Evidence archive

`TASK-260715-32virr_test-evidence.zip` contains focused 25x repeated, TSan, coverage, coordinator coverage report, full validation, strict format, diff, no-sleep, and board-validation logs for rework 01.
