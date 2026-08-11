# BUG-260811-3qdo3e reviewer verdict — round 2

## Verdict

Changes requested; route to development. The keepalive self-join fix and scoped-cancellation test are accepted, but the mandatory unfiltered 20-run gate is not green under independent review.

## Accepted implementation and architecture

- `sendKeepalive()` keeps public callers waiting for fatal teardown, while the transport-owned automatic keepalive starts teardown without joining it. This matches the existing automatic-rekey ownership rule and removes the observed keepalive/teardown self-join.
- The fatal automatic-keepalive regression deterministically advances `ManualFixtureClock`, injects socket failure, requires `.closed`, and asserts a zero owned-resource snapshot.
- The exact caller-cancellation test advances the manual clock while its read remains pending, verifies `.cancelled`, exact channel scope, `.sameChannelOperation`, and `requiresTeardown == false`, then reuses the same channel, exercises a sibling, and closes with zero owned resources.
- No skip, sleep-only workaround, shorter timeout, wall-clock masking, or SSH-policy change is present. TASK-260715-1u2vpc's approved-algorithm matrix remains intact.

## Independent evidence

- Focused cancellation + positive keepalive/rekey + fatal keepalive regression: exit 0, 3 tests.
- Fresh unfiltered streak runs 1–16: exit 0, 427 tests in 35 suites each. Historical hang positions 13 and 16 completed normally.
- Fresh unfiltered run 17: exit 1, 427 tests; `channelOperationPressureIsBounded` received `.cancelled` instead of `.resourceLimitExceeded`. All task-relevant cancellation and keepalive tests passed in this run and the suite did not hang.
- Focused `channelOperationPressureIsBounded`: runs 1–9 exit 0; run 10 exit 1 with the same mismatch.
- `swift format lint --recursive Sources Tests Package.swift`: exit 0.
- `git diff --check`: exit 0.
- `swift build`: exit 0.
- sshd listener set after validation remains the developer-reported baseline PIDs 1330 and 34815; no reviewer listener leaked.
- `task-board validate`: process exit 0 while reporting the known `STORY-260715-lkshfz` parent-status mismatch.

## Root cause of the failed gate and required rework

The pressure test is unchanged by this bug, but it is reproducibly nondeterministic. It waits for the actor-side per-channel count to reach 64 while those 64 exit operations concurrently enter network progress and failure cleanup. A waiter can start channel disposal before the above-cap probe reaches `beginChannelOperation`; because disposal is checked before the cap, the probe then receives `.cancelled`. Make the cap fixture/admission boundary deterministic without accepting the weaker error, adding sleeps/timeouts, or skipping the test. Preserve the accepted cancellation/keepalive fix and algorithm-matrix work, then produce a fresh 20-consecutive-run unfiltered gate with every run successful.
