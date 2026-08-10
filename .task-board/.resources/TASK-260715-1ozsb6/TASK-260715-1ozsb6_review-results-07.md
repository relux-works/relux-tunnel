# TASK-260715-1ozsb6 reviewer result — round 7

Verdict: CHANGES REQUESTED. Route to to-dev.

The revised owned timeout race fixes the round-6 caller-detachment issue for a non-cooperative resolver, upload source, and signer. The named adapter boundary, explicit M3 deferred states, pinned packaging, macOS provider, and harness integration remain structurally correct. No architecture diagram change is required.

## Blocking findings

1. Cooperative cancellation does not deterministically reconcile the owned-operation registry before teardown completes. performTearDown calls asyncOperations.cancelAll at LibSSH2Transport.swift:2074 but never waits for cooperative race children to retire; ownedResourceSnapshot then counts asyncOperations.outstandingCount. Under the full suite, repeated connect cancellation observed a nonzero task at iteration 10 and again at iteration 9 on retry; repeated failed handshakes also observed automaticTasks=1 at iteration 15. This leaves AC 5 and the Tests green gate red. Rework must boundedly join cooperative registry children within transportClose while retaining genuinely non-cooperative work as explicit owned state after the deadline.

2. The transport close deadline is established only at LibSSH2Transport.swift:2093, after three unbounded waits: injected connection.close at line 2077, owned automatic task joins at line 2078, and network bridge drainServices at line 2085. drainServices itself awaits every service task at LibSSH2Bridge.swift:185. The existing bridge test releases the suspended write from close and therefore does not cover a socket close or readiness/write call that ignores cancellation. Add deterministic non-cooperative socket teardown coverage and ensure public close returns within transportClose without unsafe late bridge mutation.

3. A connector result that arrives after its timeout is discarded by the generic timeout race without closing the returned SSHTCPConnection. The TCP connect operation at LibSSH2Transport.swift:236 can lose to the timer; LibSSH2TimeoutRace.childCompleted at lines 2545-2566 drops the losing success value. Add an abandoned-result cleanup path and a cancellation-ignoring connector test proving the late socket is closed and returns to baseline.

4. The automatic keepalive test is not scheduling-stable in the full suite. make validate-core missed the expected second keepalive at LibSSH2AdapterIntegrationTests.swift:307. The retry passed this assertion, indicating a fixture synchronization race; wait for the next manual-clock sleeper or another explicit readiness condition before advancing.

## Reviewer validation

- swift test --filter LibSSH2: exit 0; 37 tests / 3 suites.
- make validate-core: exit 2; 371 tests / 31 suites, with two lifecycle baseline failures and one keepalive failure in the libssh2 suites.
- swift test full retry: exit 1; repeated connect cancellation failed again at iteration 9; one unrelated HEV test also failed.
- make validate-libssh2: exit 0.
- make test-libssh2-source-gates: exit 0.
- make native-apple-matrix: exit 0; arm64/x86_64 macOS provider and harness release targets linked the pinned graph.
- swift format lint --recursive --strict Package.swift Sources Tests: exit 0.
- git diff --check: exit 0.
- task-board validate before verdict routing: exit 0 while reporting the existing parent status mismatch caused by this task being reviewing.

Logs are under .temp/TASK-260715-1ozsb6-review-07/.

The four M3-deferred semantics remain explicit unsupported or notReported states traceable to TASK-260728-3cveay and are not a rejection reason.