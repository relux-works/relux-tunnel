# TASK-260715-32virr reviewer verdict — changes requested

Date: 2026-07-21
Role: reviewer
Verdict: CHANGES REQUESTED
Route: to-dev

## Acceptance blocker

The deterministic lifecycle, rollback, race, capability-ordering, resource-baseline, fake-clock, repeated-execution, TSan, coverage, lint, and full-validation evidence is green. However, the task explicitly places error mapping in scope, and the suite does not verify exact startup mappings.

TunnelRuntimeCoordinatorTests.partialStartRollback asserts only that TunnelRuntimeCoordinatorError is thrown. StartupFailurePoint defines expected cleanup but no expected error. Consequently, every configuration, SSH, TCP, DNS, packet preparation, settings-plan/apply, packet-activation, and final-health case would still pass if the coordinator returned the wrong redacted domain or code.

Independent line coverage corroborates missing mapping branches: stop reasons startupFailure and providerFailure are unexecuted, and NetworkSettingsCommitDisposition.committed from an apply error is unexecuted. The existing providerFailure calls occur only after a health failure has already set termination, so they do not test that mapping.

## Required rework

1. Add exact expected TunnelRuntimeCoordinatorError.startupFailed values to the startup failure table and assert equality for every injected failure.
2. Add the committed apply-error disposition case and prove it is cleared exactly once while preserving the exact network-settings failure.
3. Exercise stop reason startupFailure and providerFailure mappings directly, asserting exact terminal error, capability revocation, cleanup order, single completion, and resource baseline.
4. Complete or explicitly reconcile the legal/illegal control table for start after failed and any control states currently covered only indirectly. Keep all scheduling continuation-driven with no sleep or yield polling.
5. Rerun focused repeated execution, TSan, coverage, strict format, make validate-core, diff/no-sleep checks, and update task-scoped evidence.

## Independent verification

- swift test --filter TunnelRuntimeCoordinatorTests: PASS, 20 tests with all parameterized cases.
- Focused suite repeated 25 times: PASS 25/25.
- swift test --sanitize=thread --filter TunnelRuntimeCoordinatorTests: PASS, no TSan report.
- Coordinator coverage: 95.17 percent lines, 91.47 percent regions, 96.36 percent functions.
- make validate-core: PASS, 212 tests in 23 suites plus swift build.
- swift-format strict, git diff --check, board validation, and no invoked sleep or Task.yield audit: PASS.

This is ordinary implementation/test rework, not a stop-the-line blocker.