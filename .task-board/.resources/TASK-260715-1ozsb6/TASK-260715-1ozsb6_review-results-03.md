# TASK-260715-1ozsb6 reviewer result — round 3

Verdict: CHANGES REQUESTED. Route to to-dev.

Packaging, focused tests, the full core suite, libssh2 source/fork validation, and the Apple matrix reproduce green. AC 2 and AC 3 remain unsatisfied; the current positive fixture does not exercise the failing branches.

## Blocking findings

1. Channel operation cancellation and timeout have connection scope. channelRead and channelWrite call progress (LibSSH2Transport.swift:1129,1198). progress wraps bridge service with a cancellation handler that permanently marks the bridge terminal and closes the shared TCP connection (LibSSH2Transport.swift:817-826). The timeout race cancels that service task (1682-1697). The reviewed contract requires read/write-credit timeout or cancellation to cancel only that operation and preserve the channel and siblings; this path instead destroys the session.

2. Rekey/open scheduling does not preserve the reviewed semantics. beginChannelOpen rejects every state other than ready and starts no deadline while waiting for the session gate (873-887), so opens during rekey fail instead of waiting and queued opens can exceed their channel-open deadline. requestRekey similarly requires ready (904-919); concurrent triggers do not coalesce. Once rekey starts, caller cancellation is caught by requestRekey and tears the whole transport down (486-500), whereas the contract requires the caller to leave while the connection-global KEX continues.

3. Concurrent writes on one channel can resume libssh2 with different payload arguments. beginChannelWrite bounds aggregate bytes but does not serialize per-channel writes (985-1017,1133-1205). The pinned source stores one channel write_state (libssh2_priv.h:519-520), and channel.c:2173-2274 requires the same nonblocking write to resume across EAGAIN. transport.c:970-990 explicitly requires the same argument set. A second Swift write can therefore complete the first packet while reporting acceptance for the second, followed by a duplicate/reordered retry of the first. The socket-service serialization test does not cover this channel state machine.

4. Caller-approved user-key policy is not enforced. Credential lookup receives configuration.algorithms.hostKey as allowedPublicKeyAlgorithms (218-224), and the returned credential algorithm is checked only against factory-wide capabilities (231-235), not the caller-provided allowlist. A provider can return a supported but disallowed user key and the adapter proceeds to authentication, violating approved public-key and algorithm policy.

## Required rework

Make read/write cancellation operation-scoped with an independently cancellable readiness waiter; add bounded deadline-aware open/rekey scheduling with open-during-rekey and trigger-coalescing behavior; serialize or otherwise preserve exact per-channel write arguments across EAGAIN; enforce the credential request allowlist; and add deterministic tests for sibling survival, queued-open deadlines, rekey cancellation/coalescing, concurrent same-channel writes, and disallowed credential algorithms. Mandatory rows not implemented must be recorded red rather than claimed green.

## Reviewer validation

- swift test --filter LibSSH2: exit 0; 19 tests passed.
- swift-format lint --recursive --strict Package.swift Sources Tests: exit 0.
- git diff --check: exit 0.
- make validate-core: exit 0; 353 tests in 31 suites plus swift build passed.
- make validate-libssh2: exit 0.
- make test-libssh2-source-gates: exit 0.
- make native-apple-matrix: exit 0; macOS provider/harness and release linkage passed.
