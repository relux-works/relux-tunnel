# TASK-260715-3tlgwm — rework 02 lifecycle and cleanup evidence

Date: 2026-07-21
Role: developer

## Behavioral change

- One `generationConsumed` invariant now covers both start and stop ownership.
- A stop that wins before start records terminal ownership before suspension, enters the existing stopping/cleanup path, releases the retained configuration reference, and prevents revival.
- Repeated stop remains idempotent; the accepted startup-completion health/cancellation handoff remains unchanged.

## Deterministic regression evidence

- `stopBeforeStart` calls stop twice before start, then proves start throws `generationAlreadyConsumed`.
- `stopWinsConcurrentStart` pauses stopping-snapshot publication after stop records ownership, runs start while stop remains in flight, and proves the same rejection before releasing cleanup.
- Both schedules publish exactly one `disconnecting -> disconnected` lifecycle cycle.
- Neither schedule loads configuration, applies settings, or publishes usable TCP/safe-DNS capability.
- Neither schedule acquires component resources; the external resource ledger is zero and `resourceFootprint` equals the all-false baseline, including `retainsConfigurationReference == false`.

## Verification

- `swift test --filter TunnelRuntimeCoordinatorTests`: 15 tests passed.
- `swift test --sanitize=thread --filter TunnelRuntimeCoordinatorTests`: 15 tests passed with no Thread Sanitizer report.
- `make validate-core`: boundary/native verification passed; 207 tests in 23 suites passed; post-test `swift build` passed.
- `swift-format lint --strict --recursive Sources Tests Package.swift`: passed with no diagnostics.
- `git diff --check` and explicit untracked-file whitespace checks: passed.
- `task-board validate`: passed.

## Changed files

- `Sources/ReluxTunnelCore/TunnelRuntimeCoordinator.swift`
- `Tests/ReluxTunnelCoreTests/TunnelRuntimeCoordinatorTests.swift`
- `LOGBOOK.md`
