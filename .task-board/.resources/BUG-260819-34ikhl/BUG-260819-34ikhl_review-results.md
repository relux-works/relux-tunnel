# BUG-260819-34ikhl independent review — rework 01

## Verdict

Accepted. Terminal movement remains with the commit-owning orchestrator; this reviewer did not supply `commit_ack`.

## Concurrency and ownership review

The original failure was a scheduler race in the test harness: 10,000 `Task.yield()` calls were treated as a deadline while the command task still needed executor time to acquire `ResourceRecorder` and publish resource ownership. The delta removes that polling and its `TimedOut` result.

`ResourceRecorder` now owns an actor-isolated `pending`, `ready`, and `terminal` state machine. Waiter state inspection and registration occur in one actor turn. Readiness, command completion before readiness, and waiter cancellation are serialized through the same actor, so each continuation is removed before it is resumed and competing paths cannot double-resume it. A cancellation check before insertion covers cancellation-before-registration; UUID ownership and the cancellation handler cover stored waiters. Late waiters receive the existing terminal result immediately. No waiter remains after the deterministic startup-failure or cancellation cases.

Readiness is published only after the directory, Unix socket, and managed task have all been registered. The signal path still proves exit 143, empty output, removed directory/socket, and exactly one managed-task cancellation. The injected pre-readiness failure proves exit 1 with the exact diagnostic, removal of the partially owned directory, no socket or task ownership, and zero pending readiness waiters. Production resource cleanup remains unchanged: the task group selects the first event, cancels and joins both children, then the actor-guarded resource scope performs reverse-order cleanup once.

No arbitrary sleep or timeout extension, blind retry, relaxed assertion, production VPN behavior change, or production source change was introduced.

## Independent evidence

- Four CPU-load workers plus `swift test --filter ReluxTunnelHarness`: exit 0; 13 tests passed, including 50 signal cases, 50 injected startup-failure cases, 50 pre-registration cancellation cases, and registered cancellation.
- `swift package clean && swift test`: exit 0; 446 tests in 37 suites passed with 25 declared ReluxNIOSSH-unavailable known issues.
- `swift package clean && swift test --enable-code-coverage`: exit 0; 446 tests in 37 suites passed with the same 25 declared known issues.
- `swift format lint --recursive --strict Sources Tests App Probes Package.swift Project.swift Workspace.swift Tuist.swift`: exit 0.
- `make check-core-boundaries`: exit 0.
- `git diff --check`: exit 0.
- `task-board validate`: exit 0; board valid with no issues.
- Scoped diff audit: only `Tests/ReluxTunnelHarnessTests/HarnessTests.swift` changed under Sources/Tests/Package.swift/Makefile; scheduler polling and `TimedOut` were removed; the existing 3,600-second sleeps are command fixtures, unchanged.

Producer evidence additionally records three clean full-suite runs and one clean coverage run, satisfying the complete acceptance matrix when combined with this independent rerun.

## Safety

All review activity was privacy-safe and build/test-only. No signing, installation, application/provider launch, VPN preference save or mutation, VPN activation, route change, or DNS change ran.
