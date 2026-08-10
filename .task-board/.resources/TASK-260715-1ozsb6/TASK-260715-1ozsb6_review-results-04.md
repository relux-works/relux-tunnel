# TASK-260715-1ozsb6 reviewer result — round 4

Verdict: CHANGES REQUESTED. Route to to-dev.

The pinned package, full test/build suite, source gates, lint, and Apple matrix reproduce green. AC 2, AC 3, and AC 5 remain unsatisfied because the passing tests encode or omit several retained cancellation, deadline, and cleanup semantics.

## Blocking findings

1. Long-lived reads have an implicit idle timeout. performChannelRead creates its deadline from configuration.timeouts.writeCreditWait (LibSSH2Transport.swift:1215) and progress converts ordinary read idleness into timedOut. The retained reviewed contract section 11 explicitly says long-lived reads have no implicit idle timeout; writeCreditWait applies to write-credit waits. The new loopback test currently asserts this incorrect read timeout. Remove the implicit read deadline, keep cancellation operation-scoped, and add a regression proving an idle read remains pending until data, EOF, or caller cancellation.

2. Authentication timeout can wait for the external signer instead of bounding it. The sign callback starts an independent signatureTask (LibSSH2Bridge.swift:335-343); waitForSignature awaits that task without a cancellation path (367-369). progress wraps that await in withTimeout (LibSSH2Transport.swift:872-875), but withTimeout cancels and then joins its child (1870-1871). Cancelling the waiting child does not cancel the independent signatureTask, and teardown cannot cancel it until authenticate returns. A slow signer can therefore extend authentication beyond its deadline and prevent task/allocation baseline restoration. Make signature waiting deadline-aware with explicit cancel-and-join ownership and add a successful-handshake fixture with a suspended signer and short authentication timeout.

3. Session scheduling still misses required rekey/keepalive behavior. runRekeyFlight waits on sessionOperationGate before performRequestRekey starts the deadline (LibSSH2Transport.swift:541-575), so a queued rekey can exceed the explicit deadline; SSHRekeyPolicy.timeout is unused. sendKeepalive enters beginSessionOperation, which accepts only ready (609-625, 989-997), so a due keepalive during rekey is rejected instead of deferred until KEX succeeds. The automatic loop then exits while state is rekeying (910-941), permanently disabling keepalives. Apply a caller-visible bounded deadline before gate admission, use the reviewed rekey timeout policy consistently, queue one keepalive behind KEX, and test both paths deterministically.

4. EOF/exec/open error scope and cleanup remain inconsistent. finishWriting is not serialized through the per-channel write gate, so it can race an accepted write that is suspended across EAGAIN (1334-1364), contrary to EOF-after-accepted-bytes. EOF and exec-exit progress omit channel scope (1360, 1388), producing lane-scoped requiresTeardown errors, yet their catch paths neither reset the channel nor tear down the connection. The reviewed contract requires uncertain EOF to reset that channel and exec wait/upload timeout to reset the exec channel while preserving the connection. Engine channel-open rejection also uses engineError without operation/channel scope, reporting requiresTeardown even though only the open attempt is failed. Serialize EOF after queued writes, perform the required channel cleanup, and add error-shape/sibling-survival tests for EOF, exec-exit, upload, and rejected opens.

## Reviewer validation

- make validate-core: exit 0; 357 tests in 31 suites passed and swift build passed.
- make validate-libssh2: exit 0; pinned static artifact and client/server rekey/global-request fixture passed. The printed command failed count=-43 is the intentional injected failure.
- make test-libssh2-source-gates: exit 0.
- make native-apple-matrix: exit 0; dual-architecture macOS provider and harness release builds/linkage passed.
- swift format lint --recursive --strict Package.swift Sources Tests: exit 0.
- git diff --check: exit 0.
- task-board validate: exit 0 with the existing PARENT_STATUS_MISMATCH for STORY-260715-lkshfz while this task is reviewing; no dependency or status was bypassed.
