# TASK-260715-1ozsb6 reviewer result — round 8

Verdict: CHANGES REQUESTED. Route to to-dev.

The round-7 lifecycle fixes are present and all submitted validation gates are green. The named adapter remains architecture-local to ReluxTunnelLibSSH2Adapter, the macOS provider and harness graphs link the pinned extension-safe libssh2/OpenSSL artifacts, and all four M3-deferred semantics remain explicit unsupported/notReported states owned by TASK-260728-3cveay. No architecture diagram change is required.

## Blocking finding

Teardown can skip socket close when the owned async-operation registry is saturated. LibSSH2Transport.maximumPendingOperations is 64 and asyncOperations uses that same cap (LibSSH2Transport.swift:123-134). performTearDown cancels the registry and immediately attempts connection.close through another withTimeout registered in that registry (lines 2078-2088). register throws resourceLimitExceeded while 64 cancelled children have not yet retired; try? suppresses the error, so connection.close never starts. Teardown later clears connection (line 2171), allowing a zero snapshot even though the injected socket did not receive its required close. Retirement is concurrent, so whether a slot opens first is scheduler-dependent.

Existing hard-cap coverage does not close while saturated: channelOperationPressureIsBounded cancels the channel and awaits all 64 operations before transport.close (LibSSH2AdapterIntegrationTests.swift:733-770). The new nonCooperativeSocketTeardownIsBounded test covers a close operation that starts and then suspends, not registration failure before close begins.

Required rework: reserve teardown capacity or run the owner-only socket-close deadline outside the saturable ordinary-operation registry; do not discard registration failure. Add a deterministic test that fills the ordinary registry to its hard cap, initiates transport close before releasing those operations, and proves public close stays bounded, SSHTCPConnection.close is invoked exactly once, late work cannot mutate the bridge, and eventual owned resources return to zero.

This keeps AC 2 and AC 5 red: deterministic cancellation/close and exact socket lifecycle ownership are not guaranteed at the supported pending-operation bound.

## Independent validation

- Attachment SHA-256: contract 207b5834794202a5a3c051b248b80ddeaab0888399a9e39dd4b65274c57bddf7; inputs fec044ef6b854a21318027399eaaa59e6862a653be8106d2c644141cbbed488c.
- swift test --filter LibSSH2: exit 0 — 39 tests / 3 suites.
- make validate-core: exit 0 — 373 tests / 31 suites, boundary checks, pinned verification, and swift build passed.
- make validate-libssh2: exit 0.
- make test-libssh2-source-gates: exit 0.
- make native-apple-matrix: exit 0 — arm64/x86_64 macOS provider and harness release targets linked.
- swift format lint --recursive --strict Package.swift Sources Tests: exit 0.
- git diff --check: exit 0.
- task-board validate: exit 0; it reports the known STORY-260715-lkshfz parent aggregate mismatch while this task is reviewing.

Reviewer logs: .temp/TASK-260715-1ozsb6/reviewer-*-08.log.