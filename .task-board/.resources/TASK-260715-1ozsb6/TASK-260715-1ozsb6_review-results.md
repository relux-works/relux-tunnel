# TASK-260715-1ozsb6 reviewer result

Verdict: CHANGES REQUESTED. Route to to-dev. Packaging and existing gates are green, but AC 2, AC 3, and AC 5 are not satisfied.

## Blocking findings

1. Concurrent EAGAIN progress is not serialized. LibSSH2NetworkBridge.service snapshots outbound bytes, awaits writeSome, then removes bytes. Actor reentrancy plus upload async stdout/stderr and writes allow multiple service calls at once, so the same bytes can be written twice or removed inconsistently. Suspended channel operations also retain raw channel pointers while cancel/reset/close can free them, creating a use-after-free path. No per-stream pending-read enforcement or operation generation protects this lifetime. Evidence: LibSSH2Bridge.swift lines 72-104; LibSSH2Transport.swift lines 340-364, 639-666, 687-785, 847-889.

2. Bounded timeout and task ownership are incomplete. SSHTimeoutPolicy.upload is never referenced; upload source reads have no overall deadline and returned chunks are not checked against chunkBytes. The external signer starts an untracked Task, polls every 1 ms on EAGAIN, and is neither cancelled nor counted during teardown. The task-group timeout helper waits for cancelled child completion, so a non-cooperative injected dependency can defeat the deadline. Evidence: LibSSH2Bridge.swift lines 156-178; LibSSH2Transport.swift lines 340-364, 639-650, 1157-1171. Scoped rg for timeouts.upload returned exit 1.

3. Keepalive failure policy is ignored. allowedConsecutiveMisses is never referenced and the automatic keepalive task catches any send failure and simply exits, leaving the transport ready without fatal teardown or retry-budget application. This does not apply the cheaply available failure signal required by M0. Evidence: LibSSH2Transport.swift lines 421-448 and 668-684. Scoped rg returned exit 1.

4. Error phases and mandatory metrics are not truthful. connect tears down before mapping non-SSH errors, so state is closed and failures are labeled transportClose rather than resolution, connect, host decision, credential lookup, or authentication. operationsTimedOut and pendingChannelOpens/pendingReads/pendingWrites are never updated; snapshot defaults therefore report zero during pending work. Evidence: LibSSH2Transport.swift lines 222-229, 450-470, 1126-1149. Scoped rg returned exit 1.

5. Adapter conformance evidence is insufficient. The seven adapter tests cover sequential bridge behavior, capability declarations, allocator hooks, and failed-handshake cleanup only. There is no successful adapter-level host-before-auth/auth/direct-tcpip/exec/upload/rekey/keepalive test, no concurrent channel/cancel test, and no repeated successful connect/cancel baseline. The C rekey harness validates the pinned library but bypasses this Swift adapter.

## Required rework

Add one serialized socket-progress owner; protect channel/session pointer lifetime with tracked pending operations and generation-safe cancellation; enforce one pending read per stream and queued-write bounds; apply upload and signer deadlines with joined task cleanup; apply keepalive miss/failure policy; preserve the failing phase before teardown; maintain mandatory operation counters/gauges; and add positive adapter plus concurrent cancel/lifecycle tests.

## Reviewer validation

- swift-format lint --recursive --strict Package.swift Sources Tests: exit 0.
- git diff --check: exit 0.
- swift test --filter LibSSH2BridgeTests: exit 0, 7 tests.
- make validate-core: exit 0, 345 tests in 30 suites plus build.
- make validate-libssh2: exit 0.
- make test-libssh2-source-gates: exit 0.
- make native-apple-matrix: exit 0.
- Scoped rg for unused upload timeout, keepalive miss policy, timeout counter, and pending gauges: exit 1, no adapter references.
