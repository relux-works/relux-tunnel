# BUG-260811-3qdo3e reviewer verdict

## Verdict
Changes requested. Route to development. The exact caller-cancellation test is materially improved, but acceptance criterion 3 is not met under independent review because the unfiltered suite still hangs.

## Accepted portions
- The focused test caller cancellation is scoped and idle reads have no implicit timeout passed 1/1 with exit 0.
- Inspection confirms read cancellation remains channel-scoped with code cancelled, sameChannelOperation retry, and requiresTeardown false.
- Advancing ManualFixtureClock while the read remains pending preserves the no implicit idle-timeout assertion.
- Reusing the same cat channel, exercising a sibling, closing the transport, and asserting ownedResourceSnapshot zero improve deterministic cleanup coverage.
- No skip, sleep-only workaround, wall-clock timeout masking, or security-policy change was added.
- TASK-260715-1u2vpc algorithm-matrix changes remain present.

## Independent gates
- git diff --check: exit 0.
- swift format lint --recursive Sources Tests Package.swift: exit 0.
- swift build: exit 0.
- make check-libssh2: exit 0.
- make validate-libssh2: exit 0.
- One preliminary unfiltered run passed 426 tests in 35 suites with exit 0.
- A fresh streak then passed 15 consecutive unfiltered runs, each 426 tests in 35 suites with exit 0.
- Fresh run 16 did not complete and therefore has no exit code. It remained live beyond 90 seconds, versus the normal 17-second run time, and created sshd listener PID 27811 in relux-libssh2-adapter-E607E669-B5F4-45FF-887E-03B4654B1E2D.

## Root-cause evidence for failed review
swift-inspect dump-concurrency identified the live test as LibSSH2AdapterIntegrationTests.automaticKeepaliveSurvivesLongRekey. The test task was suspended in LibSSH2Transport.close -> tearDown -> Task.value. Concurrent task 17106 was cancelled but waiting in sendKeepalive -> handleOperationFailure -> tearDown. Teardown task 17150 was inside LibSSH2TimeoutRace.wait, and task 17155 was suspended in ManualFixtureClock.sleep for the teardown timeout. This is a lifecycle deadlock: transport close and the automatic keepalive failure path join the same teardown while its only deadline uses a manual clock that is no longer advanced.

The reviewer-created processes 27753, 27763, and 27811 were terminated after sampling. The two older listeners, PIDs 1330 and 34815, were unchanged; no reviewer-created listener remains.

## Required rework
Make automaticKeepaliveSurvivesLongRekey cleanup deterministically retire the automatic keepalive and teardown paths without a sleep-only or wall-clock masking workaround. Preserve the repaired cancellation test and all TASK-260715-1u2vpc matrix changes. Then rerun at least twenty consecutive unfiltered suites with 426 or more tests and attach before/after lifecycle evidence.