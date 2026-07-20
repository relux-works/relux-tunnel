# TASK-260715-2ny6z4 — SSH transport conformance contract

Status: producer handoff for review  
Decision boundary: candidate-neutral; ADR-014 remains open  
Consumers: ReluxNIOSSH fork and adapter, libssh2 adapter, and the shared SSH conformance suite

## 1. Purpose and authority

This contract refines `.spec/ssh-transport.md`, `.spec/security-privacy.md`,
ADR-005, ADR-006, ADR-014, and the reviewed candidate audit from
TASK-260715-28ok1k. It defines the behavior that both SSH engine adapters expose
to `ReluxTunnelCore`. It does not select an engine, set production lane policy,
freeze numeric window values, or permit candidate-specific types to cross the
boundary.

Normative words `MUST`, `MUST NOT`, `SHOULD`, and `MAY` are used in their usual
requirements sense. A candidate that cannot satisfy a mandatory row records a
red result; the suite does not skip or weaken the row.

The current `Sources/ReluxTunnelCore/SSHContracts.swift` is a boundary skeleton,
not this conformance surface. A separate implementation task owns translating
this reviewed contract into public Swift types and protocol requirements.

## 2. Architectural invariants

1. One transport instance owns exactly one SSH connection and one immutable,
   caller-injected lane identity. A lane pool owns multiple instances; pooling,
   lane scheduling, and live-flow migration are outside this contract.
2. The transport, its connection state, engine session, socket, timers, key
   exchange, and channel registry have one serialized owner. The adapter MAY use
   an actor, event loop, or serial executor internally, but concurrent public
   calls MUST observe the same ordering and bounds.
3. The transport strongly owns every nonterminal channel. A channel holds only
   an opaque lease back to its transport. Terminal channels unregister exactly
   once. Closing the transport terminates and unregisters all channels before
   releasing the engine session and socket.
4. The engine is created by an injected, type-erased `SSHTransportFactory`.
   `ReluxTunnelCore` imports no ReluxNIOSSH, SwiftNIO, libssh2, OpenSSL, or
   candidate adapter type. Candidate identity belongs to harness registration
   metadata, not the runtime transport API.
5. Configuration contains opaque credential/profile references, never private
   key bytes or passphrases. Network I/O, host policy, credential lookup, clock,
   cancellation, metrics/events, logging, and randomness are injected.
6. SFTP, ProxyJump, password prompts, agent/X11 forwarding, interactive shells,
   relay framing, production lane scheduling, and final numeric constants are
   absent from the interface.

## 3. Candidate-neutral Swift shape

The spelling may change during implementation, but the behavior and information
content below are mandatory.

```swift
protocol SSHTransportFactory: Sendable {
  func makeTransport(
    lane: SSHLaneIdentity,
    dependencies: SSHTransportDependencies
  ) async throws -> any SSHTransport
}

protocol SSHTransport: AnyObject, Sendable {
  func connect(configuration: SSHConnectionConfiguration) async throws -> SSHSession
  func openDirectTCPIP(
    destination: TunnelEndpoint,
    originator: TunnelEndpoint,
    policy: SSHChannelPolicy
  ) async throws -> any SSHByteChannel
  func openExecChannel(
    request: SSHExecRequest,
    policy: SSHChannelPolicy
  ) async throws -> any SSHExecChannel
  func upload(_ request: SSHExecUploadRequest) async throws -> SSHExecExit
  func requestRekey(reason: SSHClientRekeyReason) async throws
  func sendKeepalive() async throws -> Duration
  func snapshot() async -> SSHTransportSnapshot
  func close() async
}

protocol SSHByteChannel: AnyObject, Sendable {
  var identity: SSHChannelIdentity { get }
  func read(maximumBytes: Int) async throws -> Data?
  func writeSome(_ bytes: Data) async throws -> Int
  func finishWriting() async throws
  func receiveWindow() async -> SSHReceiveWindowSnapshot
  func cancel() async
  func reset() async
  func close() async
}

protocol SSHExecChannel: SSHByteChannel {
  func readStandardError(maximumBytes: Int) async throws -> Data?
  func waitForExit() async throws -> SSHExecExit
}
```

`SSHTransportDependencies` MUST contain candidate-neutral seams for:

- TCP connection/readiness, so EAGAIN/event-loop readiness and cancellation are
  testable without sleeps;
- `SSHHostKeyPolicy`, invoked with raw evidence before credentials are requested;
- `SSHCredentialProvider`, invoked only after host acceptance;
- monotonic `TunnelClock`, cancellation checking, logger, typed observer/metrics,
  and secure identity generation;
- an optional experiment recorder whose candidate label is harness metadata and
  never visible to ordinary `ReluxTunnelCore` consumers.

All public values are `Sendable`. Engine handles, event loops, channels, error
objects, key objects, and allocator pointers remain adapter-private.

## 4. Configuration, identities, and capability report

`SSHConnectionConfiguration` supplies the canonical SSH endpoint, username,
opaque credential reference, allowed KEX/host-key/cipher/MAC algorithms,
`SSHTimeoutPolicy`, `SSHRekeyPolicy`, and `SSHKeepalivePolicy`. All numeric policy
values are caller supplied and validated before any network work. No production
default is selected here.

`SSHLaneIdentity` is an immutable opaque identifier generated by the runtime or
harness. It MUST NOT encode hostname, username, profile name, destination,
fingerprint, or credential reference. It is the only lane dimension permitted
in product metrics. `SSHChannelIdentity` is random, connection-local, and used
only to correlate lifecycle events; it has no routing meaning.

Each factory exposes a harness-only `SSHAdapterCapabilities` value using common
enums. It reports algorithm and feature support without leaking candidate
types. Unsupported required behavior produces the stable
`unsupportedCapability`/`algorithmUnavailable` error and a red matrix row; it is
not a candidate-specific skip. In particular, RSA-SHA2 support by libssh2 and
its absence in the audited NIOSSH baseline are represented as data while
Ed25519 plus an approved product fallback remains the selection gate.

## 5. Connection lifecycle and state ownership

The observable connection states are:

```text
idle -> resolving -> tcpConnecting -> keyExchange
     -> awaitingHostDecision -> authenticating -> ready
ready <-> rekeying
any nonterminal state -> closing -> closed
any nonterminal state -> failed -> closing -> closed
```

Rules:

- `connect` is valid only in `idle`. Concurrent or repeated calls fail with
  `invalidState`; they never start a second socket.
- Host policy is the sole exit from `awaitingHostDecision`. Authentication
  cannot begin before an accept decision.
- `connect` returns only in `ready`, after authentication succeeds. The returned
  session contains opaque session/lane identity, accepted host-key evidence,
  negotiated algorithms, and the current key-exchange generation.
- New channel opens are accepted only in `ready`. Calls made while `rekeying`
  wait in a bounded, cancellable open queue and consume their existing
  channel-open deadline. They are never silently opened on another lane.
- Existing channels remain logically valid during `rekeying`. Reads/writes MAY
  suspend behind engine KEX processing, but all adapter-owned read/write buffers
  remain within their configured bounds and payload bytes are neither lost,
  duplicated, nor reordered.
- A connection-fatal error stops new work, fails all pending operations with the
  same connection scope/cause, and enters teardown exactly once.
- `close` is idempotent from every state. It rejects new work, cancels timers and
  pending opens, asks channels to close, enforces the injected close grace
  deadline, force-releases remaining engine resources, closes the socket, and
  returns only after ownership counts are zero. Caller cancellation does not
  interrupt this cleanup.

The linked lifecycle diagram is
`TASK-260715-2ny6z4_connection-lifecycle.puml`.

## 6. Host verification and authentication

### 6.1 Evidence

After transport key exchange exposes the server key and before any user-auth
request or credential lookup, the adapter MUST call `SSHHostKeyPolicy.evaluate`
with:

- canonical profile hostname and connected SSH endpoint;
- exact negotiated host-key algorithm name;
- exact SSH wire-format host-key bytes, copied into immutable `Data`;
- canonical OpenSSH-style `SHA256:<base64-without-padding>` fingerprint computed
  from those bytes;
- lane identity and the profile's opaque trust-record reference.

Evidence supports Ed25519, ECDSA, and RSA-SHA2 algorithm names without changing
the public shape. Unknown algorithms remain representable and are rejectable.
Raw bytes and the fingerprint are available to policy even when the decision is
reject.

### 6.2 Policy decisions

The common decisions are:

- `acceptFirstUse(explicitTrustRecord)`: valid only when a prior explicit user
  trust action created the supplied record; the packet-tunnel transport never
  prompts or silently trusts;
- `acceptMatch(trustRecord)`: algorithm and fingerprint match an approved record;
- `rejectUnknown`: no approved record and no explicit first-use trust;
- `rejectChanged`: the canonical host has approved history but evidence differs;
- `rejectAlgorithm`: policy forbids or does not understand the host-key algorithm;
- `rejectPolicy`: any other explicit policy denial.

`rejectChanged` is a high-severity, non-retryable-without-configuration-change
connection failure. It closes the socket before credential access, never opens
a channel, never reconnects into acceptance, and cannot be converted to first
use by an adapter. All lanes for one higher-level session are checked against
the same approved identity by the injected policy.

### 6.3 Authentication

Only after acceptance may the adapter request credentials and enter
`authenticating`. Baseline authentication is noninteractive public-key auth.
The common outcome enum distinguishes:

- `success`;
- `rejectedByServer`;
- `methodUnavailable`;
- `keyAlgorithmUnavailable`;
- `credentialUnavailable`;
- `credentialInteractionRequired` (locked/passphrase/UI action required);
- `signatureFailed`;
- `cancelled` and `timedOut`.

Ed25519 and approved fallback fixtures (ECDSA and/or RSA-SHA2 according to the
product matrix) are expressed through common algorithm identifiers. Password
prompts and agent forwarding are not fallback behavior. No auth rejection may
be misreported as a host-key rejection or generic network failure.

The linked ordering diagram is
`TASK-260715-2ny6z4_host-verification-sequence.puml`.

## 7. Channel open and byte-stream semantics

### 7.1 Direct TCP

`openDirectTCPIP` transmits the caller's destination and originator in the RFC
4254 `direct-tcpip` request. Destination host and nonzero port are required.
Originator host and port are explicit immutable input and are sent verbatim; the
adapter neither substitutes the SSH peer nor derives routing policy from them.
Neither endpoint is emitted to default logs, errors, metrics, or event labels.

Open success returns a channel in `open`; server rejection preserves the SSH
reason category in a candidate-neutral `channelOpenRejected` code. Timeout or
cancellation after a remote channel ID exists performs best-effort close and
unregisters the partial channel before returning.

### 7.2 Exec

`openExecChannel` opens an SSH session channel, sends exactly one exec request,
and returns only after acceptance. It exposes stdin through `writeSome` and
`finishWriting`, stdout through `read`, stderr through `readStandardError`, and
exit metadata through `waitForExit`.

Stdout and stderr have independent single-reader gates and bounded buffers.
They may be drained concurrently with stdin writes. `SSHExecExit` distinguishes
numeric status, signal, and `notReported`; a nonzero remote exit is a result, not
a transport error. `waitForExit` returns only after exit metadata or remote
close establishes that it is absent. Exit metadata may arrive before stream EOF,
so callers may continue draining until each read returns `nil`.

### 7.3 Exec-stdin upload

`upload` is a convenience operation implemented only with an exec channel; it
MUST NOT initialize or call SFTP. It:

1. opens the caller-supplied, already safely constructed exec request;
2. reads no more than the configured upload chunk from `SSHUploadSource`;
3. loops on `writeSome` until each chunk is accepted, with total adapter-owned
   queued bytes bounded by channel policy;
4. drains stdout and stderr concurrently so remote output cannot deadlock stdin;
5. sends EOF with `finishWriting`, waits for exit, and closes the channel;
6. on source, write, timeout, exit-wait, or cancellation failure, resets only the
   upload channel and preserves the connection unless the underlying error is
   connection-fatal.

Remote path quoting, checksum policy, atomic rename, and relay installation are
higher-layer concerns. The SSH transport never logs the command, path, stdin,
stdout, or stderr.

## 8. Bounded read, write, EOF, reset, cancel, and close

Each channel has independent read-side and write-side states:

```text
read:  open -> eofObserved -> closed
write: open -> eofSent -> closed
whole: opening -> open -> closing -> closed
                  \-> reset -> closed
```

- `read(maximumBytes:)` requires `maximumBytes > 0`, returns `1...maximumBytes`
  bytes, and returns `nil` only after remote EOF/close and buffered bytes are
  drained. Subsequent reads return `nil`. One read per stream may be pending;
  overlap fails with `operationInProgress`.
- `writeSome` requires a nonempty input no larger than
  `maximumWriteCallBytes`. One write may be pending. It waits without polling for
  at least one byte of queue credit, accepts only a prefix that keeps aggregate
  adapter-owned queued bytes at or below `maximumQueuedWriteBytes`, and returns
  that positive accepted count. Zero is never a successful result.
- Acceptance means the prefix is owned by the transport, not that the peer has
  consumed it. The caller retries the suffix. FIFO order is preserved. On
  cancellation before acceptance the call throws with zero accepted. Once any
  prefix is accepted the call returns its count before cancellation is observed
  by a later call, eliminating ambiguous retry/duplication.
- `finishWriting` sends SSH EOF after all accepted bytes and is idempotent. It
  preserves the read half. Writes after it fail with `writeAfterEOF`.
- Remote EOF closes only the read half. Local EOF and remote EOF do not imply
  channel close; both halves and exit metadata remain independently observable.
- `cancel` aborts pending operations with `cancelled`, discards unsent queued
  bytes, performs best-effort EOF/close, and reaches `closed`. It does not cancel
  sibling channels or the transport.
- `reset` is the local abrupt-abort semantic: discard buffers immediately,
  best-effort SSH close, and fail operations with `channelReset`. SSH provides no
  guarantee that this becomes a destination TCP RST, so the API makes no such
  claim. A peer close without orderly EOF is reported as `peerReset`.
- `close` is idempotent graceful teardown: finish the write half if still open,
  request channel close, drain already-buffered inbound data only within the
  configured close policy, then force-release on deadline. It never expands a
  buffer to complete gracefully.

## 9. Receive windows and WINDOW_ADJUST

`SSHChannelPolicy` contains caller-supplied positive values for:

- `initialReceiveWindowBytes`;
- `maximumAdvertisedReceiveWindowBytes` (the immutable cap);
- `windowAdjustThresholdBytes` or equivalent deterministic trigger;
- `maximumBufferedReadBytes`;
- `maximumQueuedWriteBytes` and `maximumWriteCallBytes`.

The initial window MUST be sent on the wire for each channel and MUST NOT exceed
the cap. The adapter tracks protocol receive credit independently per channel.
Credit is consumed when SSH payload is received; it is eligible for return only
after `read` delivers those bytes to the consumer. A stalled consumer therefore
causes remaining credit to fall and WINDOW_ADJUST to be withheld. Engine intake
alone never earns credit.

Every adjustment satisfies:

```text
0 < adjustment
remainingCreditBefore + adjustment <= maximumAdvertisedReceiveWindowBytes
```

An advertised window is never revoked. Memory pressure may withhold adjustment
and influence policy for future channels, but cannot raise this channel's cap.
The adapter MUST use the configured policy for direct and exec channels; the
libssh2 direct helper's 2 MiB default and NIOSSH's audited 16 MiB target do not
override it.

`receiveWindow()` returns a consistent snapshot containing initial value, cap,
remaining protocol credit, buffered unread bytes, delivered-but-not-yet-returned
credit, adjustment count, and cumulative adjustment bytes. A typed
`windowAdjusted(channel, before, amount, after, cap)` event makes each adjust
independently observable without payload or endpoint data.

## 10. Rekey and keepalive

### 10.1 Rekey

`SSHRekeyPolicy` supplies a positive protected-byte threshold per direction, a
positive elapsed-time threshold, and a rekey timeout. Protected bytes are
counted after SSH packet encoding and before socket write, or after socket read
and before SSH packet decoding; TCP/IP overhead is excluded. Either direction
reaching the byte threshold triggers client rekey. Time uses the injected
monotonic clock from the last successful key exchange, independent of traffic.

Client triggers are `byteThreshold`, `timeThreshold`, and explicit `test` or
`manual`. Server `SSH_MSG_KEXINIT` is `serverInitiated`. At most one KEX runs per
connection. Concurrent triggers coalesce into that KEX while retaining a set of
observed reasons. A successful KEX increments `keyExchangeGeneration`, resets
protected-byte counters and the monotonic origin, and emits started/succeeded
events. The explicit test trigger uses the same production path; no test-only
engine symbol crosses the adapter boundary.

Cancellation of a caller waiting on `requestRekey` does not attempt to roll back
an already-started connection-global KEX; the call returns `cancelled` while the
transport continues and reports the eventual result. Rekey timeout, protocol
failure, or key validation failure is connection-fatal because crypto state is
uncertain. Existing channels then fail with that lane-local connection error;
cross-lane recovery belongs to the lane pool.

During KEX, no payload is lost, duplicated, or reordered; read/write suspension
is bounded as in section 8, and new opens wait as in section 5. The linked
channel diagram is `TASK-260715-2ny6z4_channel-window-rekey-sequence.puml`.

### 10.2 Keepalive

`SSHKeepalivePolicy` supplies interval, reply timeout, and allowed consecutive
misses. Automatic keepalive uses an SSH global request that requires a reply.
Its schedule is based on monotonic time and is not reset merely by application
payload; SSH liveness remains distinct from application traffic. A manual
`sendKeepalive` exercises the same path and returns measured monotonic RTT.

Only one keepalive is outstanding. A due keepalive during KEX is deferred until
KEX succeeds without creating an unbounded queue. Success, timeout, and RTT are
observable. Exhausting the miss allowance is connection-fatal. Keepalive never
claims to detect physical path changes; that belongs to higher lifecycle code.

## 11. Timeouts and cancellation points

`SSHTimeoutPolicy` supplies separate values for DNS/endpoint resolution, TCP
connect, initial KEX, host decision, credential lookup, authentication, channel
open, write-credit wait, explicit rekey, keepalive reply, exec exit, upload, and
graceful channel/transport close. Long-lived reads have no implicit idle timeout;
a caller may supply a deadline/cancel its task. Final durations are out of scope.

Every async operation checks cancellation before starting and immediately after
each suspension/readiness wake. Required cancellable waits are: resolution, TCP
connect/readiness, KEX, host policy, credential lookup, authentication, channel
open, read, write credit, EOF flush, exec exit, upload-source read, rekey wait,
keepalive reply, and graceful close wait.

| Cancellation/timeout site | Required scope and cleanup |
|---|---|
| Resolve/TCP/KEX/host/auth during `connect` | Connection-fatal; close partial socket/session; no credential access after host rejection |
| Channel open before remote ID | Fail only the open attempt |
| Channel open after remote ID | Best-effort close partial channel, unregister, then fail attempt |
| Read or write-credit wait | Cancel only that operation; channel remains usable when no bytes were accepted |
| `finishWriting` | If EOF status is uncertain, reset that channel; never retry EOF blindly |
| Exec wait/upload | Reset that exec channel; connection survives unless cause is connection-fatal |
| Explicit rekey wait | Before start: no effect; after start: caller may leave, KEX continues |
| Rekey timeout/failure | Connection-fatal |
| Keepalive reply timeout | Count miss; connection-fatal only at configured miss limit |
| Channel close timeout | Force-release that channel |
| Transport close timeout | Force-release all remaining channels/session/socket; cleanup itself is not caller-cancellable |

Cancellation and timeout are separate stable errors and counters. Adapters MUST
NOT implement deterministic tests with sleeps or busy polling.

## 12. Error taxonomy

`SSHTransportError` contains only common data: stable `code`, `phase`, scope
(`operation`, channel identity, or lane), retry disposition, and whether teardown
is required. It contains no engine object and no unredacted free-form message.

Stable codes:

```text
cancelled, timedOut, invalidArgument, invalidState, operationInProgress,
unsupportedCapability, resolutionFailed, networkUnavailable, connectionLost,
connectionClosed, hostKeyUnknown, hostKeyChanged, hostKeyRejected,
hostKeyAlgorithmRejected, algorithmNegotiationFailed, authenticationRejected,
authenticationMethodUnavailable, authenticationKeyAlgorithmUnavailable,
credentialUnavailable, credentialInteractionRequired, signatureFailed,
channelOpenRejected, channelLimitReached, channelClosed, peerReset, channelReset,
writeAfterEOF, backpressureTimedOut, execRejected, rekeyFailed, keepaliveFailed,
protocolViolation, resourceLimitExceeded, adapterFailure
```

Server channel-open reason and exec signal/status use common enums/values. A
candidate numeric code MAY be sent to a sensitive, local-only diagnostic sink,
but is not part of equality, metrics dimensions, public errors, or control flow.
Unknown engine failures map to `adapterFailure` with phase and scope preserved.

Retry disposition is explicit: `never`, `afterConfigurationChange`,
`newConnection`, or `sameChannelOperation`. Host-key change is
`afterConfigurationChange`; auth rejection is not automatically retried;
protocol/rekey/connection failures require a new connection; resource pressure
waits for higher-layer policy.

## 13. Metrics, events, and privacy

The typed schema version is `1`. `SSHTransportSnapshot` contains immutable lane
identity, connection state, negotiated algorithm names, key-exchange generation,
and these exact aggregate fields:

### Counters (`UInt64`)

```text
connectAttempts, connectSucceeded, connectFailed, operationsCancelled,
operationsTimedOut, hostFirstUseAccepted, hostMatchAccepted, hostUnknownRejected,
hostChangedRejected, hostAlgorithmRejected, authenticationAttempts,
authenticationSucceeded, authenticationRejected, directChannelsOpened,
execChannelsOpened, channelOpenFailed, channelsClosedGracefully, channelsReset,
channelsCancelled, payloadBytesSent, payloadBytesReceived, protectedBytesSent,
protectedBytesReceived, writeBackpressureWaits, windowAdjustments,
windowAdjustmentBytes, clientByteRekeys, clientTimeRekeys, explicitRekeys,
serverRekeys, rekeysSucceeded, rekeysFailed, keepalivesSent, keepalivesAcknowledged,
keepalivesTimedOut
```

### Gauges (`Int64`, nonnegative unless state enum encoding is documented)

```text
openDirectChannels, openExecChannels, pendingChannelOpens, pendingReads,
pendingWrites, queuedWriteBytes, bufferedReadBytes, remainingReceiveWindowBytes,
activeKeyExchange, consecutiveKeepaliveMisses, lastKeepaliveRTTNanoseconds
```

The four byte counters have exact meanings: payload counters count bytes
accepted/delivered by channel APIs; protected counters use section 10's SSH
packet boundary and reset only in the per-KEX rekey snapshot, while lifetime
aggregate metrics never reset. Aggregate queue/buffer/window gauges are sums
across registered channels and MUST remain within the sum of their policies.

Typed events are: connection transition; host decision outcome; auth outcome;
channel open/EOF/close/reset/cancel; write backpressure began/ended;
WINDOW_ADJUST; rekey triggered/started/succeeded/failed with reason set and
generation; keepalive sent/ack/timeout; and common error code with phase/scope.
Event timestamps use the injected monotonic clock. Event order is serialized per
transport.

Default logs, events, snapshots, and metrics MAY contain lane/channel opaque IDs,
state, counts, durations, common errors, and negotiated algorithm names. They
MUST NOT contain host-key bytes/fingerprints, private/public user key material,
passphrases, canonical SSH hostname, username, profile/credential references,
destination or originator endpoints, DNS names, local addresses, exec command,
remote path, stdin/stdout/stderr, packet payload, or traffic samples. Host-key
evidence exists only in policy input and the successful session value; policy
owns any approved persistence. The baseline emits no analytics or telemetry.

## 14. Conformance suite contract

TASK-260715-2d3g5e implements one Swift Testing/harness suite. Each adapter is
registered as data through the same type-erased factory and runs the same test
names, fixtures, fake clock, cancellation gates, readiness driver, observer, and
resource accounting. Candidate-specific branches, sleeps, skips, and lowered
limits are prohibited. An explicitly unsupported capability is a recorded red
assertion, not a skip.

Every row records candidate pin, adapter revision, target/device/OS, server
fixture and revision, negotiated algorithms, policy values, traffic/duration,
loss/latency when applicable, result, common error, metrics snapshot, and raw
artifact location.

| ID | Required rows and assertions |
|---|---|
| E-ALGO | Current OpenSSH Linux/macOS, documented older profiles, and real relux host; Ed25519, ECDSA, and RSA-SHA2 host/user fixtures as applicable; exact negotiated KEX/host-key/cipher/MAC; forbidden SHA-1/CBC never negotiated; unsupported combinations fail explicitly. |
| E-HOSTAUTH | First-use-with-explicit-record, approved match, unknown reject, policy reject, changed-key stop, forbidden algorithm, credential unavailable, interaction required, signature reject, auth reject; spies prove raw bytes/algorithm/fingerprint reach policy before any credential/auth callback and rejection opens no channel. |
| E-CHANNELS | Direct destination/originator wire correctness; exec request acceptance/rejection; simultaneous stdin/stdout/stderr; upload checksum through exec stdin with no SFTP call; early close, ordered EOF, both half-close directions, peer reset, local reset, cancel, idempotent close, exit status/signal/absent ordering, sibling independence. |
| E-BACKPRESSURE | Write-call and aggregate queue caps; stalled socket makes `writeSome` suspend without polling or growth; partial-prefix retry is byte exact; cancellation before acceptance is zero; read stall never exceeds buffer cap. |
| E-WINDOW | Separate direct and exec channels at 32 KiB, 64 KiB, and caller-supplied capped BDP profiles; initial wire window equals policy; remaining snapshot falls under withheld reads; adjustment follows delivered bytes; every adjustment stays under cap; channels do not share credit; aggregate gauges reconcile. |
| E-REKEY | Deterministic byte threshold in each direction, fake-clock time threshold, explicit production-path trigger, server trigger, simultaneous/coalesced triggers, keepalive due during KEX, new open during KEX, active direct+exec channels, and at least 5 GiB mixed transfer; generation/keys change and content has no loss/duplication/reordering. |
| E-KEEPALIVE | Fake-clock schedule independent of application traffic; one outstanding request; reply RTT; timeout/miss threshold; KEX deferral; connection failure only after configured allowance. |
| E-CANCEL | Cancellation in resolution, TCP, KEX, host decision, credential lookup, auth, direct/exec open before and after remote ID, read, write credit, EOF, exec exit, upload source, rekey before/after start, keepalive, and close; 100 connect/cancel and channel/cancel cycles return tasks/channels/sessions/sockets/descriptors to baseline within injected deadlines. |
| E-SCALE | Staged 100/250/500/1,000 independent channels plus concurrent direct+exec mix; report open/close latency, CPU, base/peak physical footprint, per-channel slope, allocator counts where available, queued/buffer/window totals, and descriptors; all configured bounds and lifecycle invariants hold. |
| E-ERRORS | Every stable error maps to correct phase/scope/retry disposition; no candidate type/code leaks; channel-scoped faults preserve siblings; connection-scoped faults fail all channels once. |
| E-METRICS-PRIVACY | Every counter/gauge/event reconciles with scripted activity and serialized order. Sentinel hostnames, endpoints, fingerprints, commands, paths, key material, and payloads are absent from logs, public errors, events, and snapshots. |
| E-INJECTION | Same suite constructs both candidates through `SSHTransportFactory`; fake clock/readiness/policy/credential/observer are replaceable; ordinary core consumers cannot import or downcast to candidate types. |

E-ALGO, E-HOSTAUTH, E-CHANNELS, E-SCALE, E-WINDOW, and E-REKEY are the named
audit gates. The additional rows close the lifecycle, bounded backpressure,
keepalive, error, metric, privacy, and dependency-injection requirements already
present in this task and the M0 story.

## 15. Development decomposition and dependency contract

The reviewed contract is consumed in this order:

```text
TASK-260715-2ny6z4 contract
  -> candidate-neutral ReluxTunnelCore contract implementation
     -> ReluxNIOSSH adapter
     -> libssh2 adapter
     -> shared conformance suite (after both adapters)

TASK-260715-2ny6z4 contract
  -> minimal ReluxNIOSSH fork window/rekey hooks
     -> ReluxNIOSSH adapter
```

The existing adapter, fork, and suite tasks already own their atomic outputs.
The only missing atomic owner is implementation of this common core surface;
that task is created and linked on the board. No new research/clarification
blocker is required: final numeric policy values and production lane scheduling
remain explicitly deferred, while every M0 behavior has an injectable and
testable semantic here.

## 16. Traceability

| Contract area | Authority / downstream owner |
|---|---|
| Engine-neutral boundary and injection | TASK-260715-2nfz7w; common core contract implementation task |
| Candidate source gaps | reviewed TASK-260715-28ok1k audit |
| Direct TCP and exec | ADR-005; both adapter tasks |
| Exec-stdin upload, no SFTP | ADR-006; both adapter tasks and E-CHANNELS |
| Selection remains open | ADR-014; TASK-260715-1gjxer only |
| NIOSSH windows/rekey | TASK-260715-nzdzv3 |
| ReluxNIOSSH adapter | TASK-260715-1af33i |
| libssh2 adapter | TASK-260715-1ozsb6 |
| One suite against both | TASK-260715-2d3g5e |
| Security/privacy | `.spec/security-privacy.md`; E-HOSTAUTH and E-METRICS-PRIVACY |

