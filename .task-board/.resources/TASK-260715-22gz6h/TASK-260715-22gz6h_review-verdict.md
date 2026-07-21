# TASK-260715-22gz6h reviewer verdict

Date: 2026-07-21
Verdict: changes requested; route to to-dev

## High-severity finding: a stale idle callback can orphan the current timer

`refreshActivity` cancels the stored task and installs a replacement, but `scheduleTimer` passes only the association key to `idleTimerFired`. If the old sleep has already completed while its actor callback is queued, activity can commit a later deadline and replacement timer first. The old callback then observes `now < record.deadline`, clears `record.timer`, and schedules another task without canceling the replacement it just displaced. That displaced task is no longer reachable by `beginCleanupIfNeeded`, `removeRecord`, generation teardown, cancellation, or provider stop. Repeated deadline/activity interleavings can accumulate untracked sleepers until they independently fire.

Evidence: `ClientUDPAssociationRegistry.swift` lines 627-644 arm by association key only; lines 647-662 let any callback replace the current timer; lines 701-744 can cancel only the task still stored in `record.timer`. The tests assert `snapshot.scheduledTimers`, which counts stored handles, but never assert the fake clocks actual pending sleeps; see registry tests lines 282-315 and 650-660. Thus the current suite masks orphan tasks and does not prove timer baseline.

Impact: violates AC3 bounded memory/timer ownership and AC5 deterministic return of timers to baseline. It also contradicts the implementation claim of at most one timer per association.

Required rework:
1. Give each timer arm a monotonic timer epoch/token and pass it into the callback. A callback whose epoch is not the records current epoch must return without mutating or replacing the current timer.
2. Add deterministic clock/barrier coverage that completes an old sleep, commits activity before its actor callback, then proves the stale callback cannot displace the replacement.
3. Assert actual outstanding clock sleeps/tasks, not only stored record handles: exactly one while active and zero after local/remote terminal paths, session loss/replacement, cancellation, provider stop, and repeated churn.
4. Rerun focused repeats, full `swift test`, format lint, and `make relay-protocol-check`.

## Passing evidence

Actor isolation, nonzero bounded allocation, collision/wraparound fast failure, generation plus allocation-token ABA protection, close/expiry ID reservation, callback idempotence, privacy-safe aggregate state, and shared-core placement otherwise match the contract. Reviewer verification passed format lint, `git diff --check`, five focused registry runs, all 316 Swift tests, the 89-vector protocol check, generated drift checks, and final Swift build.