# BUG-260811-3qdo3e developer outcome

## Reproduction and root cause

The original real-sshd cancellation fixture opened two sequential `sleep 2` exec channels while using `ManualFixtureClock`. Caller cancellation detached the pending read correctly, but channel disposal still had to progress libssh2 cleanup behind the bridge-owned POSIX service and remote process exit. Because the injected clock also owned the channel-close deadline and was no longer advanced, suite completion depended on two wall-clock subprocess lifetimes and could strand channel, socket, and sshd retirement under aggregate scheduling. The clean baseline took about 4.1 seconds, matching the two sequential sleeps.

Independent aggregate review then exposed a transport-owned automatic keepalive self-join. A fatal keepalive failure awaited teardown, while teardown attempted to drain that same automatic keepalive task. With the manual teardown timer no longer advanced, both the keepalive and `transport.close()` remained suspended.

Subsequent aggregate runs found two additional fixture synchronization boundaries: fixed `Task.yield()` counts did not prove that `.keepaliveSent` had been emitted, and `rekeyCoalescingAndOpenScheduling` used a real 300 ms deadline for both an intentionally expired open and a second open expected to succeed. Reviewer round 3 passed the accepted cancellation, keepalive, and channel-pressure regressions, then unfiltered run 3 consumed the second open's real deadline under aggregate scheduler load.

## Implementation and preserved semantics

- The cancellation test now uses one EOF-driven `cat` channel. Advancing the manual clock proves the idle read remains pending with no implicit timeout. Cancelling the caller returns `.cancelled` for the exact channel, `.sameChannelOperation`, and `requiresTeardown == false`. The same channel then echoes a payload, a sibling exec succeeds, the connection remains ready, and transport close reports zero owned resources.
- Public `sendKeepalive()` callers still await fatal teardown. The transport-owned automatic keepalive starts teardown without awaiting its own drain, returns from its failure handler, and can then be joined safely by teardown. A socket-failure regression requires `.closed` plus `ownedResourceSnapshot() == .zero`.
- The positive long-rekey test waits on emitted `.keepaliveSent` events through continuation-backed observer thresholds instead of a fixed scheduler-yield count.
- The rekey/open scheduling test now injects `ManualFixtureClock`, waits for the first open's 300 ms timer, and advances exactly 300 ms to preserve the expected pre-admission timeout. It leaves the clock fixed while the second open queues and rekey resumes, so aggregate scheduler latency cannot consume the successful open's deadline.
- No skip, sleep-only workaround, shorter or extended wall-clock timeout, security-policy change, or weakened expectation was added.
- TASK-260715-1u2vpc's approved algorithm matrix remains present: both curve25519/Ed25519/aes256-ctr/hmac-sha2-256 and group14-sha256/P-256/aes128-ctr/hmac-sha2-512 rows still negotiate and assert exact algorithms.

## Before/after and deterministic coverage

- Before: the exact cancellation fixture took about 4.1 seconds and three aggregate attempts hung near it; reviewer evidence later localized the automatic-keepalive teardown cycle and the aggregate-only fixture races.
- After the final manual-clock rework, the exact rekey/open case passes in 0.099 seconds.
- The five cancellation, rekey/open, positive automatic-keepalive, fatal automatic-keepalive, and channel-pressure regressions pass together in 30/30 consecutive focused runs, five tests per run, every exit 0.
- A fresh reset-on-any-failure streak passes 20/20 consecutive unfiltered `swift test --skip-build` runs. Every run passes 427 tests in 35 suites with exit 0 and 16-18 second wall durations, including prior failure positions 3, 13, 16, and 17.
- Focused logs: `.temp/BUG-260811-3qdo3e/round3-rework/focused-01.log` through `focused-30.log`.
- Unfiltered logs: `.temp/BUG-260811-3qdo3e/round3-rework/unfiltered-01.log` through `unfiltered-20.log`.

## Resource cleanup and validation

The sshd listener set before and after focused stress, the 20-run unfiltered streak, and all validation remained exactly the two pre-existing PIDs 1330 and 34815. No task-created listener leaked.

- `make validate-core`: exit 0; 427 tests passed and `swift build` passed.
- `make validate-libssh2`: exit 0.
- `swift format lint --strict --recursive Sources Tests Package.swift`: exit 0 with no diagnostics.
- `git diff --check`: exit 0.
- `task-board validate`: process exit 0; it reports the known `STORY-260715-lkshfz` parent-status mismatch while this child remains in `development` before handoff.

Existing dirty work was not reverted, stashed, staged, or committed. The task-scoped finding and final evidence are recorded in `LOGBOOK.md`.
