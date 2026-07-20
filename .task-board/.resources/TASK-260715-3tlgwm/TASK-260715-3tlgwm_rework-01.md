# TASK-260715-3tlgwm reviewer verdict — changes requested 01

Date: 2026-07-21
Role: reviewer
Verdict: CHANGES REQUESTED
Route: to-dev

## Acceptance blocker

A current-generation mandatory-health callback can win the handoff between completion of the tracked startup child and resumption of the outer start method.

Code evidence:

- TunnelRuntimeCoordinator.start awaits operation.value and then clears startupTask and returns success without rechecking actor state, termination, or caller cancellation (TunnelRuntimeCoordinator.swift lines 354-361).
- receive marks the generation failed and stopping, but deliberately does not start cleanup while startupTask is non-nil (lines 435-448).
- The last ownership check is inside runStartup before that child returns (lines 592-595), so it cannot protect the later child-to-caller handoff.

Failing schedule:

1. runStartup completes its final health check and usable publication, then returns successfully.
2. Before the suspended outer start continuation runs, a current-generation unhealthy callback enters the actor.
3. receive records failure, cancels the already-completed operation, publishes stopping, and defers cleanup because startupTask is still non-nil.
4. The outer start continuation observes successful operation.value, sets startupTask to nil, and returns success. It performs no termination recheck and starts no cleanup.

The coordinator can therefore report start success after a mandatory failure, remain parked in stopping, and retain settings/components until a later explicit stop. This violates AC1 serialized callback ownership, AC3 truthful usable publication after mandatory failure, AC4 failure rollback completion, and AC5 deterministic resource baseline.

The existing stale-health test does not close this race because it emits health only after start has returned and then explicitly calls stop at TunnelRuntimeCoordinatorTests.swift lines 189-221.

## Required rework

- Make the startup completion handoff atomic with actor ownership: after awaiting the startup child, revalidate termination/state and caller cancellation before returning success, or otherwise ensure a callback that observes a non-nil but completed startup task joins/starts cleanup.
- Add a deterministic regression test that forces current-generation health loss into this completion handoff. Do not issue a later explicit stop to mask callback-owned cleanup. Assert start cannot succeed, TCP/DNS never revive, cleanup runs exactly once, and resourceFootprint plus the external resource ledger return to baseline.
- Cover caller cancellation at the same completion handoff so structured cancellation cannot be lost after the child has completed.

## Independent validation

All existing checks are green but do not exercise this schedule:

- swift test --filter TunnelRuntimeCoordinatorTests: 11 tests passed.
- swift test --sanitize=thread --filter TunnelRuntimeCoordinatorTests: 11 tests passed with no Thread Sanitizer report.
- make validate-core: boundary/native checks passed; 203 tests in 23 suites passed; post-test swift build passed.
- swift-format lint --strict --recursive Sources Tests Package.swift: passed.
- git diff --check: passed.
- task-board validate: passed.

This is ordinary implementation rework, not a stop-the-line boundary.