# TASK-260715-3tlgwm — lifecycle and resource-cleanup evidence

Date: 2026-07-21
Role: developer
Revision: rework 02

## Implementation

- Added `TunnelRuntimeCoordinator`, a single-generation actor implementing `TunnelRuntime` with explicit disconnected, startup-phase, usable TCP/DNS, stopping, and failed states.
- Added a monotonic `TunnelRuntimeCoordinatorFactory`, generation-tagged mandatory health events, candidate-neutral configuration/SSH/TCP/DNS/packet/settings protocols, and `LatestRuntimeSnapshotStore` stale-position filtering.
- Startup is strictly configuration validation -> authenticated SSH -> TCP -> safe DNS -> packet preflight -> mandatory health -> settings apply -> packet reads -> final health -> usable publication.
- Stop and failure cancel and join the tracked startup task, coalesce one shielded cleanup task, revoke capability, stop packet/native work, clear committed or uncertain settings, stop DNS/TCP/SSH, and release configuration and task references.
- Definite settings non-commit skips clear. Unknown apply outcome is conservative/uncertain and requires clear. Failed clear retains truthful `routesInstalled=true` plus `routeState=clearFailed` while TCP and safe DNS remain false.

## Rework 01: startup-completion handoff

- After `operation.value` returns, `start()` now revalidates caller cancellation, environment cancellation, actor lifecycle ownership, and termination before clearing `startupTask` and returning success.
- The revalidation and handle clear have no suspension between them, so they form one actor-isolated ownership handoff. A current callback that wins before the check routes `start()` through failure and cleanup; a callback that enters afterward sees `startupTask == nil` and begins callback-owned cleanup.
- A package-internal async handoff hook provides deterministic test scheduling without changing the public coordinator API or production dependency shape. The public initializer installs no hook.

## Rework 02: stop-before-start generation consumption

- Replaced the start-only `hasStarted` flag with a one-shot `generationConsumed` invariant shared by `start()` and `stop()`.
- A stop that serializes in the initial disconnected state now consumes the generation and records termination before its first suspension, publishes stopping, and joins the existing single cleanup owner. Cleanup releases the retained configuration reference and publishes disconnected before stop returns.
- A competing or later start deterministically throws `generationAlreadyConsumed`; repeated stops remain idempotent and do not publish or clean up again.
- The concurrent regression pauses dependency-level stopping-snapshot publication after the terminal ownership decision, allowing start to enter the actor while stop remains in flight without adding another production test hook.

## Acceptance evidence

- AC1: actor isolation serializes transitions; repeat start is rejected; 32 concurrent stops join one cleanup; generation-mismatched health and older snapshot positions are ignored. Rework 01 covers current-generation health loss during startup completion. Rework 02 proves a pre-start stop consumes the generation before suspension, so a concurrent or later start cannot revive it.
- AC2: event-order assertions prove settings apply follows configuration, SSH, TCP, DNS, packet preparation, and initial mandatory health.
- AC3: every pre-usable snapshot has TCP and safe DNS false; usable appears only after settings, read activation, and final health. After handoff health loss publishes stopping, every later snapshot keeps TCP and safe DNS false.
- AC4: 10 injected failure points and 7 cancellation boundaries assert the exact acquired-resource rollback suffix. The two handoff tests cover mandatory-health failure and caller cancellation after child completion without issuing a later `stop()`; each asserts the full reverse cleanup sequence and exactly one stop/clear/close per resource. The two pre-start-stop tests assert exactly one stopping-to-disconnected cleanup publication cycle and no component cleanup for resources never acquired.
- AC5: 100 generations restore the fake descriptor/task/native/socket/channel resource ledger to zero. Handoff and pre-start-stop paths independently assert zero external resources and the baseline internal footprint, including no retained configuration, startup task, or cleanup task.

## Verification

- `swift test --filter TunnelRuntimeCoordinatorTests`: 15 tests passed, including 10 failure arguments and 7 cancellation arguments.
- `swift test --sanitize=thread --filter TunnelRuntimeCoordinatorTests`: 15 tests passed with no Thread Sanitizer report.
- `swift-format lint --strict --recursive Sources Tests Package.swift`: passed with no diagnostics.
- `make validate-core`: core boundary and native dependency checks passed; 207 tests in 23 suites passed; post-test `swift build` passed.
- `git diff --check` plus checks for the untracked coordinator source and test files: passed.
- `task-board validate`: passed.

## Task-scoped logs

- `.temp/TASK-260715-3tlgwm/swift-test-tsan-rework-01.log`
- `.temp/TASK-260715-3tlgwm/validate-core-rework-01.log`
- `.temp/TASK-260715-3tlgwm/swift-format-rework-01.log`

Rework 02 command results are summarized in the separate task outcome `TASK-260715-3tlgwm_rework-02-evidence.md`.

## Changed files

- `Sources/ReluxTunnelCore/TunnelRuntimeCoordinator.swift`
- `Tests/ReluxTunnelCoreTests/TunnelRuntimeCoordinatorTests.swift`
- `LOGBOOK.md`
