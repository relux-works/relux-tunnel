# TASK-260715-22gz6h logbook

## Decisions

1. Registry isolation uses a Swift actor so admission and lifecycle changes linearize without adapter-visible locks.
2. Identity is generation plus associationID plus allocation. Only associationID crosses the wire; allocation is local ABA protection.
3. Local close and remote error retain IDs in closing; idle expiry retains IDs through expired and closing. Relay close/ack or whole-generation teardown is required before reuse.
4. Cleanup state commits before synchronous nonblocking callbacks. HEV and relay cleanup effects run at most once per association, including crossed close and teardown.
5. Allocation scans at most the injected search ceiling, skips zero on UInt32 wraparound, and returns a typed no-wire failure.
6. Every timer arm advances a per-record UInt64 epoch captured by its task. idleTimerFired validates generation, allocation key, timer ownership, and epoch before any timer mutation. A stale arm increments only staleTimerCallbacks and cannot displace the current timer.
7. The fake clock tracks both pending continuations and outstanding sleep calls. Its one-shot post-wake action deterministically commits activity after an old deadline wakes but before the old callback reaches the actor.

## Findings and anomalies

- The reviewer-confirmed orphan-timer race was reproducible by the deterministic post-wake ordering and is closed by timer-arm epoch validation. The test proves one current real sleeper remains after the stale callback.
- Real sleeper/task baselines are now asserted through local close, remote close, remote error, expiry, session replacement/loss, cancellation, provider stop, 100 consecutive rearms, concurrent admission cleanup, and seeded property cleanup.
- The first full Swift run reported one issue in the unrelated providerFailureHandoff provider-adapter race test. The entire provider-adapter suite passed immediately in isolation and the full 318-test suite passed on rerun without unrelated changes; this is recorded as a non-task flaky observation.
- The existing linker alignment reduction warning remains non-fatal and unchanged.
- No destination, domain, address, payload, remote text, or credential data is stored or emitted by the registry or its metrics.