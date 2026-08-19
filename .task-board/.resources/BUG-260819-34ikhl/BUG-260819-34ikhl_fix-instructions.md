# Harness cancellation determinism rework

Fix `BUG-260819-34ikhl` as the concrete rework required by the independent `TASK-260715-nphtib` review.

Authoritative finding: revision `7dc73ac6e7325f86a4a178a0558619f0fc9d1490` produced one real `swift test` failure in `ReluxTunnelHarness` test `signal cancellation uses signal exit code and cleans all resources`, throwing `TimedOut()` at `Tests/ReluxTunnelHarnessTests/HarnessTests.swift:140`. The test still relies on a scheduler-count loop of 10,000 `Task.yield()` calls. A later clean matrix, coverage run, and 50 targeted repeats passed, but do not invalidate the observed race.

Identify the exact synchronization/ownership cause. Replace scheduler-count polling with explicit event or process-state synchronization. Do not increase arbitrary sleeps/timeouts, add blind retries, weaken signal-exit semantics, or relax zero-resource cleanup assertions.

Preserve exactly-once cleanup for temporary directories, sockets, tasks, descriptors, and signal handlers on success, timeout, and cancellation. Add regression coverage that exercises the old race window deterministically where practical.

Acceptance evidence: at least 50 focused repetitions under load, three clean full `swift test` runs, one coverage run, strict formatting, and relevant boundary checks. Record exact commands and results in a task-scoped outcome.

This development Mac is build-only. Never sign, install, launch, save, start, or stop a VPN; never mutate NetworkExtension preferences, routes, or DNS.
