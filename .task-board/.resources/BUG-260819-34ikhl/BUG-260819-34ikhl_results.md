# BUG-260819-34ikhl developer outcome — rework 01

## Root cause

The original signal test used 10,000 `Task.yield()` calls as a scheduler-count deadline. Under loaded Swift Testing, that loop could finish before the command acquired `ResourceRecorder` and published ownership, so `TimedOut()` represented executor scheduling rather than failed cleanup.

The first explicit-event fix had a second ownership hole found by review: `waitUntilStarted()` stored a non-throwing continuation that only `record(directory:socket:)` could resume. A command failure before full publication, or cancellation of the waiting test task, retained the continuation indefinitely even though `HarnessApplication.run` had already reached a terminal response.

## Fix

`ResourceRecorder` now owns an actor-isolated readiness state machine with atomic `pending -> ready` and `pending -> completed-before-readiness` transitions. The application task publishes its terminal response after production cleanup. Both stored waiters and waiters arriving after completion receive the same typed diagnostic. Each waiter has a UUID; a cancellation handler removes and resumes only that waiter, and registration checks cancellation while actor-isolated, covering cancellation before registration without a missed wakeup or double resume.

Resource publication is staged so the injected pre-readiness failure records its temporary directory without claiming readiness. Readiness is published only after the directory, Unix socket, and managed task are owned. The signal test still asserts exit 143, empty output, removed directory and socket, and exactly one managed-task cancellation. Startup failure asserts exit 1, the exact diagnostic, partial-directory removal, no socket/task ownership, and zero retained waiters. No arbitrary sleep, timeout increase, retry, weakened assertion, or production VPN behavior change was introduced. Production cleanup ordering remains: choose first event, cancel and join both task-group children, then run the actor-guarded reverse-order resource cleanup once.

## Evidence

- `swift test --filter ReluxTunnelHarness`: exit 0; 13 tests including 50 signal cases, 50 injected startup-failure cases, 50 pre-registration cancellation cases, and explicit post-registration cancellation.
- Four CPU-load workers plus `swift test --filter ReluxTunnelHarness`: exit 0; the same focused matrix passed.
- Clean full run 1, `swift package clean && swift test`: exit 0; 446 tests in 37 suites, 25 known ReluxNIOSSH-unavailable issues; 68.18s.
- Clean full run 2, same command: exit 0; 446 tests in 37 suites, same 25 known issues; 69.10s.
- Clean full run 3, same command: exit 0; 446 tests in 37 suites, same 25 known issues; 65.52s.
- Clean coverage, `swift package clean && swift test --enable-code-coverage`: exit 0; 446 tests in 37 suites, same 25 known issues; 66.06s.
- `swift format lint --recursive --strict Sources Tests App Probes Package.swift Project.swift Workspace.swift Tuist.swift`: exit 0.
- `make check-core-boundaries`: exit 0.
- `git diff --check`: exit 0.
- `task-board validate`: exit 0; board valid with no issues.

## Safety

All evidence is privacy-safe and build/test-only. No signing, installation, app/provider launch, VPN preference save or mutation, VPN activation, route change, or DNS change ran.

## Files

- `Tests/ReluxTunnelHarnessTests/HarnessTests.swift`
- `LOGBOOK.md`
