# TASK-260715-32virr reviewer verdict — rework 01

Date: 2026-07-21
Role: reviewer
Verdict: ACCEPTED

## Rework verification

The prior exact-mapping blocker is closed. All eleven startup-failure rows assert exact TunnelRuntimeCoordinatorError.startupFailed values, exact reverse rollback, one disconnecting publication, one terminal failed publication, single cleanup, capability suppression, and typed internal/external resource baselines. The committed settings-apply error preserves network_settings/network_settings_apply_failed and clears exactly once; not-committed clears zero times and uncertain clears once. Direct startupFailure and providerFailure stops assert their exact runtime-invariant errors, capability revocation before cleanup, repeated-stop idempotence, and final baselines. Start while stopping and start after stopped/failed complete the requested control-table reconciliation. Production sources are unchanged.

## Acceptance evidence

- AC1: Fourteen before/after ownership boundaries and eleven startup fault rows assert exact reverse cleanup and single completion.
- AC2: Thirty-two concurrent starts produce exactly one usable runtime; deterministic stop/start, repeated stop/health races, stale generations, and late callbacks cannot revive a stopped or failed generation.
- AC3: Usability follows settings apply, packet-read activation, and final mandatory health; all mandatory component failures revoke TCP and safe DNS before cleanup.
- AC4: One hundred factory generations restore task, timer, socket, channel, dependency, retained configuration, startup-task, cleanup-task, settings, and component baselines.
- AC5: Scheduling is continuation-driven with a fixed fake clock; the suite invokes neither Task.sleep nor Task.yield. The fake clock sleep method throws if called.

## Independent validation

- swift test --filter TunnelRuntimeCoordinatorTests: PASS, 21 tests and all parameterized cases.
- Focused suite repeated 25 times: PASS 25/25.
- swift test --sanitize=thread --filter TunnelRuntimeCoordinatorTests: PASS, no TSan report.
- Fresh coordinator coverage: 95.95% lines, 93.02% regions, 96.36% functions.
- make validate-core: PASS, boundary/native gates, 213 tests in 23 suites, and post-test swift build.
- swift-format lint --strict --recursive Sources Tests Package.swift: PASS.
- git diff --check, task-board validate, and no-invoked-sleep/yield audit: PASS.

## Remaining gaps

Coverage does not execute defensive factory exhaustion, impossible missing-resource guards, invalid internal error-catalog preconditions, or the narrow duplicate-stop wait while final disconnected snapshot publication is still in flight. These are not acceptance blockers: externally meaningful duplicate-stop cleanup coalescing and stopping/failed/disconnected behavior are deterministic and green, and affected coordinator coverage remains above target. Physical-device, real Network Extension/SSH/HEV, UDP, reconnect, and UI validation remain out of scope.

No acceptance-blocking finding or stop-the-line boundary remains.