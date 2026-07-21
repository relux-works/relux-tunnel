# TASK-260715-1juybj — private SOCKS-to-`direct-tcpip` contract

Status: production contract proposed for review  
Owner: `ReluxTunnelCore` TCP consumer / `SSHProxyAdapter` inside one packet-tunnel runtime generation  
Applies to: shared iOS 18+ and macOS 15+ provider builds  
Wire protocols: SOCKS5 plus RFC 1929 admission; RFC 4254 `direct-tcpip`  
Schema: `socks_tcp_adapter.v1`

## 1. Decision and authority

This contract freezes the M1 boundary between the accepted HEV SOCKS client and
the candidate-neutral SSH byte-channel seam. It does not implement the adapter,
choose an SSH engine, tune physical memory/window values, schedule lanes, or
define UDP relay framing.

The accepted-input resource refers to `TASK-260715-100wu6`. That ID does not
exist. The source and board evidence identify the intended accepted task as
`TASK-260720-100wu6` — **Implement the candidate-neutral SSH transport
contract**. This document corrects only that traceability typo; it does not
change or reopen the accepted SSH contract.

Normative priority, highest first:

1. `TASK-260715-1juybj` description, scope, AC, checklist, and accepted inputs.
2. Accepted `TASK-260715-30zng6_runtime-contract.md` for generation ownership,
   sequencing, cancellation, route truthfulness, and future seams.
3. Current shared production evidence:
   `Sources/ReluxTunnelNativeAdapter/HEVSOCKSBoundary.swift`,
   `Sources/ReluxTunnelNativeAdapter/HEVIntegration.swift`,
   `Sources/ReluxTunnelCore/SSHContracts.swift`, and their accepted tests.
4. Accepted packet-plane outcomes `TASK-260715-uopycx`,
   `TASK-260715-1vv52g`, `TASK-260715-35wctc`, including their reviewer
   verdicts and `BUG-260720-2p4fln` closure evidence.
5. `.spec/security-privacy.md`, `.spec/packet-plane.md`,
   `.spec/architecture.md`, `.spec/routing-dns-lifecycle.md`, and
   `.spec/ssh-transport.md`.
6. Clauses marked **M1 decision** below.

## 2. Private endpoint and admission proof

### 2.1 Approved mechanism

The pinned HEV build accepts an IP/name plus TCP port for its upstream SOCKS
server. It does not expose a supported Unix-domain upstream endpoint or a
connection-owner callback. The approved endpoint is therefore:

- one `AF_INET/SOCK_STREAM` listener bound to exactly `127.0.0.1` and kernel
  assigned port `0` for each runtime generation;
- no wildcard, physical-interface, IPv6-any, user-configurable, advertised, or
  persisted listener address;
- one fresh RFC 1929 username/password capability generated for the generation,
  passed only to that generation's HEV YAML, and erased with the boundary;
- a caller-injected positive pending-authentication ceiling and, as an **M1
  decision**, one monotonic absolute accept-to-authentication deadline;
- listener cancellation, pending-socket shutdown, authentication-task join, and
  descriptor close before generation cleanup returns.

Loopback restricts the network reachability surface, but it does **not** prove
process identity. The capability is the unpredictable generation credential
plus listener lifetime/ownership. No code or documentation may describe a TCP
peer address, PID lookup, audit token, or loopback alone as ownership proof.

**Current evidence versus required M1 enforcement.** The checked-in boundary
already supplies the loopback bind, ephemeral port, fresh capability, bounded
pending set, pre-handoff rejection, and owned teardown. It does **not** yet
supply the absolute deadline above. `setAuthenticationTimeout` installs only
`SO_RCVTIMEO`; for the blocking `recv` sequence this is a per-receive inactivity
bound that can restart when more bytes arrive. `authenticate` carries no
monotonic accept timestamp or shared remaining budget across greeting, RFC 1929
reads, comparisons, and replies, and `sendAll` has no send deadline. The current
pending set is therefore memory/count bounded, but a slow-trickle or
reply-stalling non-owned client can retain one slot longer than the configured
receive interval. `TASK-260715-b6uruh` must close this implementation gap; it
does not change the selected admission capability.

Current credential generation produces an ASCII username of 42 bytes and an
ASCII password of 79 bytes, both within RFC 1929's one-octet length limit. A
production generator may change their format only if both remain independently
unpredictable, nonempty, YAML-safe, at most 255 UTF-8 bytes, generation-unique,
never logged, and never persisted.

### 2.2 Rejection proof on iOS and macOS

The proof is one shared implementation, not two platform-specific claims:

1. `HEVLoopbackSOCKSBoundary.start()` creates `AF_INET/SOCK_STREAM`, binds
   `127.0.0.1:0`, requires method `0x02`, compares both credential fields, and
   transfers a descriptor to the adapter only after `[01 00]` was sent. A
   no-auth client receives `[05 ff]`, is closed, and the adapter sees neither
   bytes nor descriptor. This proves capability-gated handoff; it does not
   prove an end-to-end authentication deadline.
2. `HEVIntegrationTests.externalIngressRejected` executes the negative and
   positive paths and asserts adapter acceptance remains zero for the unowned
   client. `HEVBridgeIntegrationTests.realHEVUDPInTCPAndInternalIngress`
   repeats the negative path while the real pinned HEV/lwIP stack is active.
3. The boundary file has no platform-conditional branch. The Swift package
   declares both iOS and macOS, and `ReluxTunnelNativeAdapter` is the same target
   consumed through both platform packaging anchors.
4. The accepted `TASK-260715-1vv52g` reviewer reran `make validate-native`: the
   shared target and iOS device/simulator plus macOS provider/harness schemes
   built and linked the same boundary and pinned HEV artifact; the macOS-hosted
   rejection tests passed. Thus the rejecting code path is byte-identical at
   source and compile-linked on both platforms, with executable rejection proof
   on the available macOS host. The already-created implementation task
   `TASK-260715-b6uruh` retains iOS and macOS provider-sandbox smoke as a release
   validation row; it may not substitute a different admission mechanism.
5. Existing tests do not cover a client that trickles bytes within each receive
   inactivity interval or stops reading a method/authentication reply. Those
   are explicit downstream validation rows, not evidence attributed to the
   current source.

An authenticated connection is not a public proxy client. It is generation
owned infrastructure. In M1, authentication failure, absolute-deadline expiry,
pending-limit rejection, generation stop, or stale-generation handoff closes
the socket before `SSHProxyAdapter` obtains it. Current source already proves
the no-auth, pending-limit, stop, and stale-handoff shape; the absolute deadline
and its adversarial rows remain assigned to `TASK-260715-b6uruh`.

## 3. Owners and lifetime

| Resource/state | Sole owner | Acquisition | Release invariant |
| --- | --- | --- | --- |
| Listener, credential, pending-auth set | `M1PacketPlaneSession` through `HEVSOCKSBoundary` | Packet-plane activation for one generation | Admission closes first; stop cancels listener, shuts pending sockets, joins authentication, then erases credentials |
| Authenticated local socket | One `TCPFlow` after synchronous registry reservation | Boundary hands over `HEVSOCKSChannel` positioned at the first request byte | Exactly one terminal cleanup closes it; no other component retains/borrows after cleanup begins |
| Parsed destination | Same `TCPFlow` | Complete valid request | Retained in memory only for open/lifetime needs; never emitted to default diagnostics |
| Open reservation | Generation TCP admission registry | Before parsing/open work that can allocate or suspend | Converted to active-flow reservation or released once on every failure/race |
| `SSHByteChannel` | Same `TCPFlow` | `openDirectTCPIP` returns before SOCKS success | Closed/reset/cancelled once by the flow; a late channel after cancellation is immediately closed and never published |
| Directional buffer | Its one pump task | One bounded read | Retained until its bytes are accepted/written; no second read in that direction while nonempty |
| Pump/timer tasks | Flow structured task group | After channel ownership and success-reply eligibility | Cancelled and joined by shielded once-only cleanup; no detached tasks |
| Metrics reservation/gauges | Generation TCP registry | Atomic state transition | Reconciled with resource release in the same serialized transition |

The flow owner serializes state transitions and terminal claiming. Socket
readiness and SSH operations may run on their native executors, but they return
bounded values/events to the owner. No blocking socket operation runs on the
coordinator, packet bridge, lifecycle actor, or SSH engine event loop.

## 4. SOCKS5 byte and state contract

All integers below are unsigned octets except ports, which are two-octet
network-byte-order values. Reads are incremental and exact: an input length may
select among fixed states but may not directly determine an unbounded
allocation. `EINTR` retries within the same absolute deadline/fairness slice;
would-block waits for readiness without polling.

### 4.1 Method negotiation — boundary owned

The byte behavior below is normative M1 behavior. Every greeting and RFC 1929
read, comparison, and reply consumes the single accept-time monotonic deadline
defined in section 6; no successful byte or partial reply restarts it. The
current `SO_RCVTIMEO`-only source does not yet satisfy that deadline clause.

Client greeting:

```text
+-----+----------+------------------+
| VER | NMETHODS | METHODS          |
| 05  | 01..ff   | NMETHODS octets  |
+-----+----------+------------------+
```

- Maximum encoded greeting: 257 bytes.
- `VER` must be `05`; otherwise close without a version-5 reply.
- `NMETHODS=00`, truncation, deadline expiry, or absence of `02` returns
  `[05 ff]` only when the same absolute deadline still has writable budget,
  then closes.
- Presence of `02` returns exactly `[05 02]`; method `00` is never selected even
  when offered alongside `02`.

RFC 1929 request and response:

```text
+------+-------+-----------+-------+-----------+
| VER  | ULEN  | UNAME     | PLEN  | PASSWD    |
| 01   | 1 byte| ULEN bytes| 1 byte| PLEN bytes|
+------+-------+-----------+-------+-----------+

success: [01 00]     failure: [01 01]
```

- Maximum encoded authentication request: 513 bytes.
- `VER` must be `01`; `ULEN` and `PLEN` must be nonzero and each at most 255.
- Both supplied fields are evaluated even if the first fails; each comparison
  is constant-time over the longer of supplied and expected bytes so content
  mismatches do not short-circuit. Credential lengths are not treated as secret.
- Any mismatch, malformed/truncated field, deadline expiry, or generation stop
  sends `[01 01]` only when the same absolute deadline still has writable
  budget, then closes. A socket rejected before it acquires a
  pending-authentication slot closes immediately without joining negotiation.
- On `[01 00]`, the boundary transfers exclusive socket ownership with the next
  unread octet being the first SOCKS request octet. Credentials never cross that
  seam.

### 4.2 CONNECT request — adapter owned

```text
+-----+-----+-----+------+----------------+----------+
| VER | CMD | RSV | ATYP | DST.ADDR       | DST.PORT |
| 05  | 01  | 00  | ...  | variable       | 2 bytes  |
+-----+-----+-----+------+----------------+----------+
```

Address forms:

| `ATYP` | Wire address | Exact request length | `TunnelEndpoint.host` |
| --- | --- | ---: | --- |
| `01` IPv4 | 4 network-order bytes | 10 bytes | Canonical `inet_ntop` numeric address; never DNS-resolved |
| `04` IPv6 | 16 network-order bytes | 22 bytes | Canonical `inet_ntop` numeric address without brackets or zone ID; never DNS-resolved |
| `03` domain | `LEN` then `LEN` bytes | `7 + LEN`, maximum 262 | Exact accepted ASCII hostname bytes decoded without case-folding, normalization, search suffix, or local resolution |

**M1 decision — domain validation.** `LEN` is `1...255`. The bytes must be ASCII
DNS host form: optional final dot; otherwise labels are `1...63` bytes, start
and end alphanumeric, and contain only alphanumeric or `-`. IDNs arrive as
ASCII A-labels. NUL, whitespace, control/non-ASCII bytes, empty interior labels,
zone IDs, bracketed literals, and overlong labels are rejected before channel
open. The accepted string is passed verbatim to the exit-side SSH server so
resolution remains remote. This adapter never calls a resolver for a domain
destination.

`DST.PORT` must be nonzero and is preserved exactly. `VER=05`, `CMD=01`, and
`RSV=00` are mandatory. `BIND (02)`, `UDP ASSOCIATE (03)`, HEV's private
UDP-in-TCP command `(05)`, and every other command are outside this TCP adapter
and receive command-not-supported. A higher packet-plane demultiplexer may own
the separately specified UDP/DNS path; it may not reinterpret such a request as
`direct-tcpip`.

The parser cap is 262 bytes. It requests no more than the exact state requires,
so trailing bytes normally remain in the kernel socket buffer. If a stream
abstraction already buffered request plus early payload, its read maximum must
be `remainingRequestBytes + localReadChunkBytes`; the unused suffix transfers
as the first local-to-SSH buffer and no further read occurs until it drains. It
is neither rejected nor copied into a side queue. Payload is not forwarded
before a successful channel open and success reply.

### 4.3 Reply encoder

Every post-request reply is the fixed ten-byte IPv4 form:

```text
[05, REP, 00, 01, 00, 00, 00, 00, 00, 00]
```

`BND.ADDR=0.0.0.0` and `BND.PORT=0` are intentional privacy-safe placeholders;
the adapter does not expose the SSH server's destination-side socket. The
pinned HEV client accepts IPv4/IPv6 reply addresses but not a domain reply, so
the fixed IPv4 form is the interoperable canonical encoding.

| Condition | `REP` | Required action |
| --- | ---: | --- |
| Channel owned and ready | `00` succeeded | Send fully before starting either pump; reply-write failure resets/closes the channel |
| Admission/resource/queue limit; generic internal or transport loss | `01` general failure | No channel attempt when rejected before open; close after reply |
| SSH administrative prohibition | `02` ruleset denied | Close after reply |
| `networkUnavailable` during open | `03` network unreachable | Close after reply |
| Domain resolution failure, `resolutionFailed`, or explicit host-unreachable result | `04` host unreachable | Close after reply |
| SSH `connectFailed` / connection-refused result | `05` connection refused | Close after reply |
| Channel-open absolute deadline expires | `04` host unreachable | Cancel open; close any late channel; close after best-effort reply |
| `CMD != 01` | `07` command not supported | Never call SSH |
| Unknown `ATYP` | `08` address type not supported | Never call SSH |

Malformed `RSV`, zero port, invalid domain bytes, impossible length, or an SSH
error lacking a more specific stable classification maps to `01`. A wrong SOCKS
version closes without claiming a version-5 reply. Truncation, cancellation, or
deadline before a complete valid request closes; after a complete request it
sends the mapped reply only if the reply-write deadline and generation remain
valid. No failure reply is retried and no failure path forwards trailing bytes.

For `SSHTransportError(code: .channelOpenRejected)`, `channelOpenReason` refines
the mapping: `.administrativelyProhibited -> 02`, `.connectFailed -> 05`,
`.unknownChannelType -> 07`, `.resourceShortage -> 01`, `.other/nil -> 01`.
`.channelLimitReached` and `.resourceLimitExceeded` map to `01`; `.timedOut`
during channel open maps to `04`; v1 emits `06` only if a future accepted SSH
error can distinguish actual TTL expiry. Cancellation/provider stop is `01` only when a
safe best-effort reply remains possible and otherwise closes silently.

## 5. One request to one `direct-tcpip` channel

After a complete valid request and required admission reservations:

1. Call the injected assignment seam exactly once. In M1 it always returns the
   already authenticated baseline `SSHTransport` and caller-supplied
   `SSHChannelPolicy`. It performs no scheduling.
2. Construct destination `TunnelEndpoint(host: parsedHost, port: parsedPort)`.
3. Construct the constant sanitized originator
   `TunnelEndpoint(host: "127.0.0.1", port: 0)`. It is the same for every flow
   and must not contain the HEV socket peer, device address, application source
   port, physical interface, username, or other local identity.
4. Call `openDirectTCPIP(destination:originator:policy:)` once under the
   injected channel-open absolute deadline.
5. Do not retry on the same or another transport. Cancellation after a remote
   channel exists closes that late channel. A failed open never reaches pumps.
6. Atomically transfer the returned channel to the flow, send `REP=00`, then
   start the two pumps. Success may not be optimistic.

The future seam is conceptually:

```swift
protocol TCPDirectAssignmentSelecting: Sendable {
  func assignment(for request: TCPDirectAssignmentRequest) async throws
    -> TCPDirectAssignment // transport + SSHChannelPolicy + opaque lane identity
}
```

The request may carry destination and low-cardinality in-memory hints needed by
future M3 selection, but the selector output is chosen once before open. The
selected transport/lane remains pinned until channel close. The seam emits no
destination-bearing metrics and offers no live-flow migration API. M1 injects a
constant selector; M3 may replace it without changing parser, pump, or cleanup
contracts.

## 6. Bounded admission, deadlines, and accounting

All numeric limits and durations are positive caller-injected configuration,
validated before listener activation. No value in this document promotes an M0
measurement candidate into final product policy.

Required limits:

- `maximumPendingAuthentications` — boundary-owned unauthenticated sockets;
- `maximumReservedFlows` — all authenticated parsing/opening/active/draining
  flows;
- `maximumConcurrentChannelOpens` — subset of reserved flows in `opening`;
- `parserBufferBytes >= 262` with hard cap 262 for the CONNECT message itself;
- `localReadChunkBytes` and `remoteReadChunkBytes`;
- `maximumAggregateAdapterBufferedBytes` across both pump-owned buffers;
- the per-flow `SSHChannelPolicy` fields, including maximum buffered reads,
  queued writes, write call, initial/capped window, and adjustment threshold;
- fixed fairness byte/operation or monotonic-time slice budgets;
- bounded Core diagnostic snapshot/event capacity.

Required monotonic absolute deadlines:

- accept-to-complete authentication reply, including greeting header/methods,
  method selection reply, RFC 1929 header/username/password, both credential
  comparisons, and authentication reply;
- authenticated-handoff-to-complete request;
- channel-open attempt;
- SOCKS reply write;
- SSH write-credit wait and local writability wait;
- half-close drain and graceful channel close;
- generation stop/cleanup join.

The authentication deadline is computed once from a monotonic timestamp taken
when the descriptor is accepted. Every read, comparison, and write uses only
the remaining budget. Progress, `EINTR`, readiness wakeups, partial reads, and
partial replies do not extend it. Expiry closes the socket, releases the
pending-authentication slot once, and prevents adapter handoff. The existing
`SO_RCVTIMEO` setting is retained only as current implementation evidence; it
is not accepted as this production guarantee.

Long-lived open TCP reads have no implicit idle timeout. An optional injected
idle policy may cancel a flow, but it is disabled unless a later accepted policy
defines it; provider stop, transport loss, and explicit deadlines remain
effective. Deadlines are computed once per phase and are not extended by
one-byte progress.

Admission is non-waiting: atomic `tryReserve` succeeds or rejects. There is no
FIFO of unadmitted flows. A reservation precedes parser/open allocations and is
released by the once-only terminal path. The channel-open sub-reservation is
released immediately after success/failure; it does not wait for flow close.

### 6.1 Memory relationship to the accepted M0 baseline

Accepted M0 evidence currently exercises an injectable HEV baseline of MTU
1,500, effective task stack 24,576 bytes, TCP buffer 4,096 bytes,
`udp-copy-buffer-nums=2`, and maximum HEV sessions 1,200. These are measurement
inputs, not final adapter settings. The full extension target remains the
provisional 25–30 MiB physical-iPhone envelope in `.spec/packet-plane.md`.

The configuration owner must prove, using measured object/task overhead:

```text
F_reserved <= HEV.maximumSessionCount

AdapterPeak <= FixedAdapter
             + PendingAuth * MeasuredAuthSocketTask
             + F_reserved * (FlowObjectAndTasks
                              + 262 parser bytes
                              + localReadChunkBytes
                              + remoteReadChunkBytes
                              + SSH.maximumQueuedWriteBytes
                              + SSH.maximumBufferedReadBytes)
             + BoundedDiagnostics

FullExtensionPeak = MeasuredM0HEVAndBridge
                  + AdapterPeak
                  + SelectedSSHTransportPeak
                  + DNS/Core/Provider bounded allocations
                  + explicit reconnect overlap (zero in M1)
```

`maximumAggregateAdapterBufferedBytes` is also enforced dynamically as the sum
of the two adapter-owned directional buffers; SSH queue/read gauges are
reconciled separately and included in the budget. Advertised SSH credit is not
assumed allocated, but all buffering permitted by it is counted in the
worst-case proof. Exceeding any reservation or aggregate bound rejects new work
quickly; it never shrinks an already-advertised window or creates spill storage.

## 7. Bidirectional streaming and backpressure

After the success reply, exactly two structured pumps run independently.

### 7.1 HEV/local socket to SSH

1. Read at most `localReadChunkBytes` only when no prior local chunk remains.
2. Hold that one buffer plus an offset.
3. Call `writeSome` with a nonempty suffix no larger than
   `SSHChannelPolicy.maximumWriteCallBytes`.
4. A positive accepted prefix transfers ownership of those bytes to the SSH
   transport. Advance the offset exactly once. Wait for credit when suspended.
5. Do not perform the next socket read until the full chunk is accepted.

### 7.2 SSH to HEV/local socket

1. Call `read(maximumBytes: remoteReadChunkBytes)` only when no previous SSH
   chunk remains pending locally.
2. Hold that one `Data` plus an offset.
3. Write nonempty suffixes to the nonblocking socket; on partial write advance
   exactly once, and on would-block await writability.
4. Do not call the next SSH read until the full chunk has been written.

No pump owns an array of chunks, retry queue, stream accumulator, `AsyncStream`
with unbounded buffering, or detached callback mailbox. Fairness budgets yield
between bounded work slices. Reads/writes preserve byte order and never retry an
already accepted prefix.

Zero progress is never success. `SSHByteChannel.writeSome` returning zero for
nonempty data is a contract violation and resets the flow. A local nonempty
write returning zero is treated as peer closure. Local `read == 0` is EOF;
`SSHByteChannel.read == nil` is remote EOF after buffered data drains. Repeated
readiness wakeups without a successful operation consume the same absolute
deadline and fairness budget; there is no busy spin.

## 8. EOF, half-close, reset, cancellation, and cleanup

The read and write halves are independent:

- Local socket EOF: stop local reads, drain already-read bytes, call
  `finishWriting()` exactly once, and keep SSH-to-local delivery alive.
- SSH remote EOF (`read == nil`): stop SSH reads, call local
  `shutdown(SHUT_WR)` exactly once so HEV observes FIN, and keep accepting local
  bytes until local EOF or the half-close drain deadline.
- Both orderly EOFs: perform bounded graceful channel close, close the local
  socket, and terminate `graceful`.
- Local reset/broken pipe or SSH `.peerReset`/`.channelReset`: cancel the sibling
  pump, discard its unaccepted buffer, use `reset()`/abrupt local close as
  appropriate, and terminate with the stable reset reason. SSH reset is not
  claimed to produce a destination TCP RST because the accepted byte-channel
  contract explicitly makes no such promise.
- Channel/session loss: abort the local socket and channel; never reopen or
  migrate the flow.
- Provider/generation cancellation: immediately close admission, cancel both
  pump waits and timers, call channel `cancel()`, shut down the local socket, and
  enter shielded cleanup.
- Deadline expiry: cancel the affected operation; handshake/open failures use
  the reply rules above, while streaming/close expiry aborts only that flow.

One atomic terminal claim selects the first observed stable reason. Later EOF,
reset, timeout, cancellation, readiness, or late-open callbacks may only
increment bounded discarded-late-event counters; they cannot change the reason,
send another reply/EOF, revive a pump, or release a resource twice.

Cleanup is idempotent and non-cancellable after it starts:

1. cancel timers and both pump tasks;
2. wake/cancel local readiness and SSH waits;
3. cancel/reset/close the channel according to the claimed reason, bounded by
   close deadline and force-release semantics of the SSH contract;
4. `shutdown` then close the local descriptor exactly once;
5. join owned tasks and discard buffers;
6. unregister flow, release open/flow/byte reservations, and reconcile gauges;
7. publish the aggregate terminal metric.

Partial-start rollback applies the same sequence to the subset acquired. In
particular, a channel returned after cancellation is closed before its callback
returns, and a success-reply write failure rolls back the already-open channel.

## 9. State machine

| State | Owned resources | Legal exits |
| --- | --- | --- |
| `authenticated` | Local channel only | `reserved`, `terminal` |
| `reserved` | Local channel + flow/parser reservation | `parsing`, `terminal` |
| `parsing` | Above + at most 262 request bytes / one capped early payload | `opening`, failure reply, `terminal` |
| `opening` | Above + open sub-reservation + one in-flight open | `replying`, failure reply, `terminal`; late success is closed |
| `replying` | Local channel + owned SSH channel | `streaming`, `terminal` |
| `streaming` | Both channels + two pumps + at most one buffer each | `halfClosedLocal`, `halfClosedRemote`, `terminal` |
| `halfClosedLocal` | SSH write EOF sent; receive pump may run | `terminal` or `halfClosedBoth` |
| `halfClosedRemote` | Local write half shut; send pump may run | `terminal` or `halfClosedBoth` |
| `halfClosedBoth` | No new payload; bounded graceful close | `terminal` |
| `terminal` | Once-only cleanup task until release | no exit |

The accompanying task-scoped state and ownership-sequence diagrams are
normative views of this table; this text controls if a renderer changes layout.

## 10. Aggregate metrics, errors, and privacy

The adapter emits `socks_tcp_adapter.v1` aggregate observations through bounded
Core diagnostics. Counter/gauge names and finite error values are schema-stable;
new fields require a schema revision or additive reader-compatible rule.

Minimum counters:

```text
accepted_authenticated_total
admission_rejected_total
request_valid_total
request_rejected_total
channel_open_attempted_total
channel_open_succeeded_total
channel_open_failed_total
success_reply_total
failure_reply_total
bytes_local_to_ssh_total
bytes_ssh_to_local_total
local_eof_total
remote_eof_total
flows_graceful_total
flows_reset_total
flows_cancelled_total
flows_timed_out_total
late_event_discarded_total
zero_progress_violation_total
```

Minimum gauges:

```text
reserved_flows
parsing_flows
opening_flows
streaming_flows
half_closed_flows
adapter_buffered_bytes
local_to_ssh_buffered_bytes
ssh_to_local_buffered_bytes
peak_reserved_flows
```

Open latency, backpressure wait, and lifetime use fixed predeclared buckets, not
destination labels. The adapter also consumes/reconciles the accepted SSH
snapshot gauges `openDirectChannels`, `pendingChannelOpens`, `pendingReads`,
`pendingWrites`, `queuedWriteBytes`, `bufferedReadBytes`, and
`remainingReceiveWindowBytes`; it does not duplicate engine-internal truth.

Stable adapter phases are `admission`, `request`, `channel_open`, `reply`,
`local_to_ssh`, `ssh_to_local`, `half_close`, and `cleanup`. Stable reason codes
are finite equivalents of the reply/terminal table: `capacity`, `malformed`,
`unsupported_command`, `unsupported_address`, `policy_denied`,
`network_unreachable`, `host_unreachable`, `connection_refused`, `timeout`,
`cancelled`, `local_reset`, `remote_reset`, `session_lost`,
`contract_violation`, and `internal`.

Never record credentials, raw SOCKS bytes, hostname/domain, destination or
originator address/port, payload, local socket peer, application identity,
per-flow UUID/channel ID, free-form engine text, or an error description that
can contain them. Errors exposed beyond the component contain only schema,
stable phase, stable code/reason, and aggregate count. Any debug-only raw value
requires an explicit sensitive sink and is absent from production snapshots.

## 11. Residual decision table

| Topic | M1 implementable input now | Deferred owner |
| --- | --- | --- |
| Endpoint security | IPv4 loopback, ephemeral port, fresh per-generation RFC 1929 credential, lifecycle close/join; never process-identity claim | `TASK-260715-b6uruh` replaces the current per-receive inactivity timeout with the specified monotonic accept-to-auth deadline and proves slow-trickle/reply-stall release on both platforms; no residual mechanism decision |
| SOCKS bytes | Exact states, caps, supported address types, strict domain rule, fixed replies, trailing-payload handoff | Implementation/fuzz evidence in `TASK-260715-b6uruh` and `TASK-260715-1mr9j2` |
| SSH mapping | One verbatim destination, constant sanitized originator, one open, injected `SSHChannelPolicy`, no retry/migration | Concrete engine observability/selection remains the separate accepted SSH program; this task does not reopen it |
| Buffers/backpressure | One buffer per direction, aggregate cap, partial-I/O and zero-progress rules, injected fairness/deadlines | Exact chunk/window/queue values and per-flow slope from M0/M1 measurements; physical tuning in M3 |
| Admission | Atomic non-waiting flow/open/byte reservations; `F_reserved <= HEV.maximumSessionCount` | Exact safe ceilings from physical memory/concurrency evidence |
| Lane seam | One injected selector returning transport+policy; M1 constant baseline assignment | M3 lane count and scheduling policy; no flow migration |
| Idle policy | No implicit idle timeout; bounded phase/write/half-close/close deadlines | Any future product idle timeout requires a separately accepted policy |
| Metrics | `socks_tcp_adapter.v1` finite aggregate schema and privacy prohibition | Bucket boundaries/capacity derived from bounded Core diagnostics and measured overhead |

## 12. Development-ready consumer map and completeness check

No new board task is required: the story already contains atomic consumers with
descriptions, AC, checklists, and dependency edges. This contract supplies their
previously missing decisions.

| Existing task | Contract clauses consumed | Dependency readiness |
| --- | --- | --- |
| `TASK-260715-b6uruh` — private endpoint/parser | 2, 4, 6, 10 | Already blocked by this contract and runtime composition; must prove slow trickle, wrong credential, reply stall, cancellation, stale generation, and slot/descriptor release in iOS/macOS rows |
| `TASK-260715-2yz8du` — channel open | 4.3, 5, 6, 10 | Already blocked by this contract and its SSH transport prerequisite |
| `TASK-260715-sdnk2k` — bounded pump | 6–8 | Already blocked by this contract only |
| `TASK-260715-zfg9ap` — admission/metrics | 6, 10 | Already blocked by this contract and accepted diagnostics work |
| `TASK-260715-1n9v9o` — close/cancel/error | 4.3, 8–10 | Correctly joins the four implementation predecessors |
| `TASK-260715-1mr9j2` — parser/fuzz tests | 2, 4, 6 | Correctly follows endpoint/parser implementation |
| `TASK-260715-1dbmph` — channel/pump conformance | 5–10 | Correctly follows lifecycle integration |
| `TASK-260715-1s9gku` — HEV-to-SSH integration | all runtime clauses | Correctly follows parser and channel/pump conformance plus existing integration prerequisites |
| `TASK-260715-1gvdtz` — concurrency/rekey matrix | 6, 7, 10, 11 | Correctly follows integrated path and selected transport evidence |

Completeness audit: endpoint capability/admission; exact current inactivity-gap
disclosure; monotonic M1 authentication deadline and adversarial iOS/macOS rows; byte states;
IPv4/IPv6/domain and remote DNS; unsupported commands; reply mapping; trailing
bytes; one-open ownership; originator sanitization; future selector; channel
policy; reservations/memory formula; bounded pumps; fairness/zero progress; EOF,
half-close/reset/cancellation/deadlines/rollback/cleanup; aggregate metrics and
privacy; M3 tuning and SSH-engine residuals are all assigned. UDP relay framing,
general proxy service, user SOCKS settings, engine selection, lane scheduling,
QUIC, reconnect, and implementation remain explicitly outside this contract.

## 13. Source trace

| Contract clause | Evidence or decision |
| --- | --- |
| Loopback, credential generation, pre-handoff rejection, exclusive channel, stop/join | `HEVSOCKSBoundary.swift`; `HEVIntegrationTests.externalIngressRejected`; accepted `TASK-260715-1vv52g` results/rework review. Current `SO_RCVTIMEO` is only per-receive inactivity evidence, not the M1 absolute deadline. |
| Pinned HEV endpoint/address/command capability | `TASK-260715-uopycx_pinned-baseline-audit.md`; pinned `hev-socks5-proto.h` and `hev-socks5-client.c` |
| Real HEV negative ingress and bounded lifecycle | `HEVBridgeIntegrationTests`; accepted `TASK-260715-35wctc` and `BUG-260720-2p4fln` evidence |
| Generation/component ownership and reverse cleanup | accepted `TASK-260715-30zng6_runtime-contract.md` |
| `TunnelEndpoint`, `SSHChannelPolicy`, open/read/write/EOF/reset/cancel/close | `RuntimeContracts.swift`, `SSHContracts.swift`, accepted `TASK-260720-100wu6` |
| Remote DNS, no destination logging, memory target, no migration | normative `.spec` files listed in section 1 |
| Strict domain syntax, fixed originator/reply, monotonic accept-to-auth and adapter phase deadlines, metric rules | **M1 decisions in this contract**, implemented/validated downstream rather than attributed to current timeout source |
