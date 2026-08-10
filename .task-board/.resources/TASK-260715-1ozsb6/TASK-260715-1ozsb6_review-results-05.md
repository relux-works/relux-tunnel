# TASK-260715-1ozsb6 reviewer result — round 5

Verdict: CHANGES REQUESTED. Route to to-dev.

The round-4 targeted regressions pass, and packaging, source gates, lint, and the Apple matrix are green. AC 2, AC 3, and AC 5 remain unsatisfied, and the required full validation gate is red in this reviewer run.

## Blocking findings

1. Connection-fatal failures do not consistently own teardown. engineError deliberately converts socket failures to lane scope and requiresTeardown at Sources/ReluxTunnelLibSSH2Adapter/LibSSH2Transport.swift:1918-1992. The direct/open wrappers only release the operation permit and rethrow at lines 294-306 and 372-383; channel read/write only map and rethrow at lines 1290-1295 and 1371-1375; manual keepalive only releases its permit and rethrows at lines 671-676. A socket send/receive/disconnect can therefore return a lane-fatal error while state and session remain ready, and raw connection errors from channel-open progress can escape without the privacy-safe mapper. Centralize post-operation failure disposition: channel/operation failures preserve the connection, while every requiresTeardown failure transitions and deterministically tears down. Add injected socket-failure tests for open, read, write, and manual keepalive.

2. Automatic keepalive can still be permanently disabled by an active KEX. sendKeepalive gives gate admission only the keepalive reply deadline while allowing rekeying at lines 649-660. If KEX lasts longer than that deadline but remains within the rekey deadline, beginSessionOperation times out while state is rekeying. handleAutomaticKeepaliveFailure returns false for every non-ready state at lines 1011-1025, so the automatic loop exits and is never restarted after successful KEX. Add a deterministic KEX-longer-than-keepalive-deadline regression and preserve one deferred keepalive plus subsequent scheduling.

3. Pending operation and teardown queues are not comprehensively bounded, and automatic task baseline evidence is optimistic. channelExit admits unlimited concurrent waiters through beginChannelOperation at lines 1529-1537 and the count increments without a ceiling at lines 1236-1247. connectDrainWaiters, channelDrainWaiters, and teardownWaiters append with no positive cap. performTearDown cancels automatic tasks and immediately nils their handles at lines 1748-1756 without joining them, while ownedResourceSnapshot counts nil handles as zero at lines 741-751. This does not prove tasks returned to baseline when close returns. Bound or reject every waiter class, join owned tasks, and test concurrent exit/close/cancel pressure against real task and allocation baselines.

4. Opened-channel cleanup can discard a live nonblocking libssh2 pointer. Exec request failure calls libssh2_channel_free exactly once and ignores the result at lines 428-460. The pinned libssh2 ssh2_channel_free path returns LIBSSH2_ERROR_EAGAIN before freeing when close needs socket progress (pinned src/channel.c:2601-2607). The pointer was never inserted into channels, so adapter cleanup cannot retry it. General channelDispose also removes the record before its bounded free loop and drops it when cleanupProgress times out at lines 1653-1671. Retain ownership until free succeeds; on a cleanup deadline, fail/tear down the connection rather than reporting closure while dropping the only pointer. Add forced-EAGAIN exec-request and channel-close baseline tests.

## Reviewer validation

- swift test --filter LibSSH2: exit 0; 27 tests in 3 suites.
- make validate-core: exit 2; 361 tests in 31 suites ran, with 4 failures in Private HEV UDP datagram adapter. The exact suite rerun via swift test --filter HEVUDPDatagramAdapterTests exited 0 with 12 tests, indicating order/interference sensitivity; the full gate remains failed and must not be reported green.
- make validate-libssh2: exit 0.
- make test-libssh2-source-gates: exit 0.
- make native-apple-matrix: exit 0.
- swift format lint --recursive --strict Package.swift Sources Tests: exit 0.
- git diff --check: exit 0.
- task-board validate: exit 0 but reports the existing PARENT_STATUS_MISMATCH for STORY-260715-lkshfz.

The four M3-deferred semantics remain explicit unsupported/notReported states and are not the reason for rejection.