# BUG-260811-3qdo3e reviewer verdict — round 3

## Verdict

Changes requested; route to development. The cancellation and automatic-keepalive lifecycle fixes are accepted, but acceptance criterion 3 is still failing under independent review: the fresh unfiltered streak stopped at run 3 with a nonzero exit.

## Accepted implementation and semantics

- The exact caller-cancellation case passed 30/30 focused lifecycle runs. It advances `ManualFixtureClock` while the idle read remains pending, verifies `.cancelled` with exact channel scope, `.sameChannelOperation`, and `requiresTeardown == false`, then reuses the same channel and a sibling before asserting zero owned resources.
- Public keepalive callers continue to await fatal teardown. The transport-owned automatic keepalive starts teardown without awaiting its own drain, matching the existing automatic-rekey ownership pattern and removing the observed self-join.
- The positive keepalive/rekey and fatal automatic-keepalive regressions passed in all 30 focused lifecycle runs. The four-test focused set, including channel-pressure coverage, completed 30/30 with exit 0.
- No skip, sleep-only workaround, shorter timeout, wall-clock masking, or SSH security-policy change is present.
- TASK-260715-1u2vpc's approved-algorithm compatibility matrix and both negotiated algorithm rows remain present.

## Independent unfiltered gate

- Fresh run 1: exit 0, 427 tests in 35 suites.
- Fresh run 2: exit 0, 427 tests in 35 suites.
- Fresh run 3: exit 1, 427 tests in 35 suites, one issue. `rekeyCoalescingAndOpenScheduling` threw `SSHTransportError(code: .timedOut, phase: .channelOpen, scope: .operation)` and failed after 0.908 seconds.
- The target caller-cancellation, positive keepalive/rekey, fatal keepalive, and channel-pressure cases all passed in failed aggregate run 3. The suite completed; no hang occurred.
- The failed run is retained at `.temp/BUG-260811-3qdo3e/reviewer-round3/unfiltered-03.log`.
- Focused follow-up of `rekeyCoalescingAndOpenScheduling`: 20/20 runs passed with exit 0, confirming an aggregate-scheduling-sensitive fixture boundary rather than a deterministic production failure.

## Root cause and required rework

`rekeyCoalescingAndOpenScheduling` configures a real 300 ms channel-open deadline while the observer intentionally suspends rekey. The first queued open is expected to expire. The second queued open starts a fresh real deadline, waits for actor-side pending-open state, then relies on aggregate scheduler latency to resume rekey and complete admission before that same 300 ms expires. Under unfiltered load, run 3 consumed the deadline and the supposedly successful open returned `.timedOut`.

Make the test's deadline boundary deterministic with the existing manual-clock seam: explicitly advance the clock to expire the first open, then keep it fixed while admitting and releasing the second open. Preserve the intended pre-admission deadline assertion; do not extend the wall-clock timeout, add sleeps, skip the case, or weaken the expected error. Then rerun a fresh reset-on-any-failure streak of at least twenty unfiltered suites with 427 or more tests each.

## Other gates and resource evidence

- `swift build`: exit 0.
- `swift format lint --recursive Sources Tests Package.swift`: exit 0 with no diagnostics.
- `git diff --check`: exit 0.
- `make validate-libssh2`: exit 0.
- `task-board validate`: process exit 0 while reporting the known `STORY-260715-lkshfz` parent-status mismatch.
- Post-review sshd listener set is unchanged at the two pre-existing PIDs 1330 and 34815; no reviewer-created listener leaked.
- No source, test, algorithm-matrix, or foreign dirty work was edited, reverted, stashed, staged, or committed by this reviewer.
