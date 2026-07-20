# TASK-260715-p89bdj — PacketFlowBridge concurrency and observability contract

Status: design outcome for review  
Consumers: `TASK-260720-9xy8yx`, `TASK-260715-3o0co4`, `TASK-260715-3dn813`, `TASK-260715-1vv52g`  
Normative terms: MUST, MUST NOT, SHOULD, and MAY are requirements keywords.

## 1. Decision summary

`PacketFlowBridge` is one lifecycle-supervised, restartable bridge run around one
public `AF_UNIX/SOCK_DGRAM` socket pair. The Swift side owns endpoint A. Endpoint
B is lent exclusively to the HEV runner for the duration of its blocking main
call; HEV never owns or closes it. The bridge closes endpoint B only after that
main call has returned.

There are no application queues between `NEPacketTunnelFlow` and the socket
pair. The only permitted storage is one current Network Extension callback batch,
one current reverse `writePackets` batch, fixed framing scratch space, and the
bounded kernel datagram queues. Kernel-queue pressure drops the current packet;
it is never retried or copied into a side buffer.

All lifecycle mutation is serialized by a bridge lifecycle actor. Packet pumps
are supervised child tasks, not detached tasks. HEV's blocking main call runs on
one dedicated native thread behind an injected descriptor-borrow seam. A
one-shot run termination handle is the provider's observation boundary for
failures that occur after `start` returns.

## 2. Public and injected contracts

The implementation MAY choose concrete Swift names, but it MUST preserve these
semantic interfaces:

- `PacketFlowBridge.start(packetFlow:configuration:) async throws -> RunHandle`
  returns only after descriptor configuration, endpoint-B borrow acceptance,
  readiness installation, and child-task supervision are active.
- `RunHandle.waitForTermination() async throws` completes exactly once. Normal
  explicit stop returns normally; a fatal run error throws the one primary
  privacy-safe bridge error.
- `PacketFlowBridge.stop() async` is idempotent and joins cleanup. Returning from
  `stop` proves that all bridge child tasks ended, the HEV main call returned,
  and both socket descriptors were closed exactly once.
- `DescriptorBorrowConsumer.beginBorrowing(_:)` receives a raw descriptor only
  as an exclusive, scoped borrow and returns a handle with `requestStop()` and
  `waitForReturn()`. It MUST NOT close, duplicate, reopen, or transfer the
  descriptor. The real implementation is supplied by the HEV integration task;
  bridge tests use a fake.
- `PacketFlow` is the platform-neutral typed packet boundary. The iOS and macOS
  adapters are responsible for the `NEPacketTunnelFlow` callback/synchronous
  API transition described in section 7.

`PacketBridgeConfiguration` remains caller-owned and contains no production
defaults. It MUST provide positive socket send/receive buffer requests, a
positive maximum work count, a positive monotonic elapsed-time budget, and a
positive MTU. `maximumDatagramBytes` is checked arithmetic `4 + mtu`; overflow
or a nonpositive input is a startup configuration failure. Final values remain
measurement outcomes and are outside this design.

## 3. Descriptor ownership and socket configuration

| Resource | Creator | Lifetime owner | Permitted borrower/observer | Close authority |
| --- | --- | --- | --- | --- |
| Endpoint A (`bridgeFD`) | Injected socket-pair factory during `starting` | `PacketFlowBridge` run | Forward sender, reverse receiver/readiness source | Bridge cleanup only |
| Endpoint B (`hevFD`) | Same atomic socket-pair creation | `PacketFlowBridge` run | HEV runner, exclusively from borrow acceptance until blocking main returns | Bridge cleanup only, after HEV return |
| Readiness source for A | Bridge during `starting` | Bridge supervisor | Reverse child task | Supervisor cancels and joins it; source never closes A |

Socket setup is all-or-nothing and occurs before either raw descriptor escapes
the lifecycle actor:

1. Call `socketpair(AF_UNIX, SOCK_DGRAM, 0, pair)` through the injected factory.
2. Wrap both integers immediately in move-only or equivalent exactly-once owned
   descriptor tokens.
3. On both endpoints, preserve existing flags while adding `FD_CLOEXEC` with
   `F_GETFD/F_SETFD` and `O_NONBLOCK` with `F_GETFL/F_SETFL`.
4. On both endpoints, request both `SO_SNDBUF` and `SO_RCVBUF` using the supplied
   positive byte values.
5. Read back all four effective values with `getsockopt`: A send, A receive, B
   send, and B receive. Darwin clamping is observable, not itself a failure.
6. Record requested and effective byte gauges before endpoint B is borrowed.

Any creation, flag, set, or readback failure fails startup and closes every
descriptor already created. Cleanup calls `close` once per owned token. A failed
`close`, including `EINTR`, is recorded but is never retried because the numeric
descriptor may already have been reused.

There is no descriptor ownership transfer to HEV. The phrase "pass endpoint B"
means an exclusive scoped borrow. The bridge MUST NOT close B to wake HEV; it
requests HEV stop, waits for the blocking main call to return, then closes B.

## 4. Task ownership and execution contexts

| Work | Execution context | Owner and observation |
| --- | --- | --- |
| Lifecycle/state mutation | One bridge actor or equivalent serial executor | Provider calls `start/stop`; run handle observes terminal result |
| Forward packet pump | One supervised Swift child task | Supervisor cancels and awaits it |
| Reverse socket pump | One supervised Swift child task plus a cancellation-safe readiness source | Supervisor cancels source/task and awaits both |
| HEV blocking main | Exactly one dedicated native thread | Borrow handle is stored and joined by supervisor |
| Packet-flow read callback registration | At most one registration in each platform adapter | Single-resume gate completes on callback, cancellation, or shutdown |
| Metrics snapshot/update | Injected concurrency-safe sink | Run-scoped snapshot, no payload access |

No task is fire-and-forget. The supervisor stores or structurally owns every
child and awaits every child before terminal cleanup completes. The first fatal
error wins as the run's primary error. Later sibling/cleanup errors increment
their own counters but do not replace it or create additional provider failures.

## 5. Lifecycle state machine

States are `idle`, `starting(runID)`, `running(runID)`, `stopping(runID)`,
`failing(runID,error)`, `stopped(lastRunID)`, and `failed(runID,error)`.

- `start` is accepted only from `idle`, `stopped`, or `failed`, and a new run ID
  and run-scoped metric set are created. Starting while active is a typed error
  with no side effects.
- Startup succeeds only after section 3 setup, readiness installation, HEV
  borrow acceptance, and supervisor installation. Then `starting -> running`.
- Explicit `stop` causes `starting|running -> stopping -> stopped`.
- Cancellation of the owning provider task uses the same stopping path and is
  not reported as a failure.
- A fatal error causes `starting|running -> failing -> failed` after cleanup.
- A fatal error that occurs before `start` reaches `running` is thrown by
  `start`. A fatal error after that point completes the run handle with failure.
- `stop` during `failing` joins the in-progress failure cleanup and does not
  change the primary error or terminal state.

The attached `TASK-260715-p89bdj_lifecycle-state.puml` is the normative state
view. `TASK-260715-p89bdj_ownership-sequence.puml` is the normative ordering view.

## 6. Start, stop, cancellation, and failure ordering

### Start

1. Enter `starting`; validate configuration without side effects.
2. Create and fully configure both descriptors; publish buffer metrics.
3. Create A's cancellation-safe readiness source, initially gated.
4. Begin B's scoped HEV borrow and obtain its observed run handle.
5. Install the supervisor and its forward, reverse, and HEV-termination children.
6. Enter `running`, open the task gate, and return the run handle.

### Normal stop or cancellation

1. Atomically enter `stopping`; duplicate calls join the same cleanup.
2. Prevent new packet-flow reads and cancel the current adapter registration.
3. Cancel the reverse readiness wait and both bridge child tasks.
4. Await both bridge child tasks and readiness cancellation.
5. Request HEV stop once, if its borrow began.
6. Await the blocking HEV main call's return.
7. End the borrow, close B exactly once, then close A exactly once.
8. Complete the run handle and enter `stopped`.

### Fatal cleanup

Fatal cleanup is the same ordered sequence except that the state is `failing`,
the first error is retained, the run handle throws it, and the terminal state is
`failed`. No fatal path closes B before HEV return.

## 7. `NEPacketTunnelFlow` async boundary

The platform adapters use only `NEPacketTunnelFlow.readPackets` and
`writePackets(_:withProtocols:)` plus public Darwin family constants.

- There is at most one outstanding `readPackets` callback registration per
  adapter. The forward pump does not issue another read until the current batch
  has been completely inspected.
- Each registration owns a thread-safe single-resume gate. Callback arrival,
  Swift task cancellation, and adapter shutdown race through that gate. Exactly
  one wins and resumes the awaiting task. A late callback releases its values,
  performs no bridge work, and schedules no next read.
- Callback packet/protocol arrays MUST have equal counts. Mismatch is surfaced
  as a typed batch anomaly; it is never silently truncated with `zip`.
- `AF_INET` and `AF_INET6` are the only supported protocol values. The adapter
  also checks that a nonempty payload's first nibble is respectively 4 or 6.
  Unsupported families, empty packets, and family/version mismatches are
  reported in the typed result so the bridge can count each dropped packet.
- Reverse batches have equal packet/protocol counts and preserve order.
  `writePackets == false` or a thrown adapter error is a fatal packet-flow error;
  the batch is not retried.
- Callback queue identity is never assumed. Callback results re-enter the
  adapter gate and then the supervised forward task; lifecycle state is touched
  only through its serial executor.

This gap is isolated as `TASK-260720-9xy8yx` — Harden PacketFlow adapter read
lifecycle, which blocks the bridge implementation.

## 8. Forward framing: PacketFlow to HEV

For each typed packet, in callback order:

1. Count one inspected packet against the work-slice count budget, including a
   packet that will be dropped.
2. Reject an empty payload, unsupported family, or address-family/IP-version
   mismatch and increment `packet_bridge_forward_drop_malformed_total`.
3. Select `AF_INET` only for IPv4 and `AF_INET6` only for IPv6.
4. Encode `UInt32(family).bigEndian` as exactly four bytes. On Darwin, the IPv4
   memory produced by `htonl(AF_INET)` is the wire byte sequence `00 00 00 02`;
   tests MUST derive constants from the target SDK rather than hard-code an
   `AF_INET6` number.
5. The attempted datagram is exactly `[4-byte family word][unchanged IP packet]`.
   Use one datagram send operation; scatter/gather is allowed, coalescing
   multiple IP packets is forbidden.
6. Before the send, max-assign the attempted byte count. If it exceeds checked
   `4 + mtu`, synthesize the same fatal classification as `EMSGSIZE`.
7. A full-length send counts one sent datagram. A positive short send violates
   `SOCK_DGRAM` atomicity and is a fatal persistent socket error. A zero result
   for a nonempty datagram is also fatal.

At a count or time boundary, the pump yields before inspecting more packets.
It MAY retain only the current immutable callback batch and an index while it
yields; it MUST NOT copy the remainder into another queue. It completes that
batch before issuing another `readPackets` call.

## 9. Reverse framing: HEV to PacketFlow

One `recvmsg` consumes at most one datagram. The receiver uses a fixed buffer of
`4 + mtu` bytes and obtains truncation/full-length information; it never allocates
from an untrusted claimed length.

For every received datagram, in kernel order:

1. Count one inspected datagram against the work-slice count budget and
   max-assign the full observed datagram size.
2. A zero-length datagram is a real datagram, not EOF. It and lengths 1...3 are
   undersized malformed frames and are dropped.
3. If the kernel reports truncation or a full size greater than `4 + mtu`,
   synthesize fatal `EMSGSIZE` with the observed/attempted size.
4. Decode the first four bytes as an unsigned network-byte-order family word.
   Only `AF_INET` and `AF_INET6` are supported.
5. The payload after the family word MUST be nonempty and its first nibble MUST
   match 4 for `AF_INET` or 6 for `AF_INET6`. Unknown family or mismatch is a
   malformed-frame drop. Deep IP header/length validation remains the IP stack's
   responsibility and is not invented here.
6. Append the unchanged payload and matching typed protocol to parallel batch
   arrays. One input datagram becomes exactly one output packet; no splitting or
   coalescing is allowed.
7. Stop a drain slice when the number of datagrams inspected (valid plus invalid)
   reaches the count limit, or monotonic elapsed time reaches the time limit.
   Flush a nonempty valid batch once through `writePackets`, then yield. Empty
   batches are not written.
8. `EAGAIN/EWOULDBLOCK` ends the current drain. Flush a nonempty batch and wait
   for fresh readiness. Unread datagrams stay only in the kernel queue.

The elapsed timer starts immediately before a slice's first receive attempt.
After every syscall/frame, the injected monotonic clock is checked. A slice may
inspect at least one datagram after readiness, but it MUST NOT begin a second
receive when either budget is already exhausted.

## 10. Error, state, counter, and logging rules

Darwin defines `EWOULDBLOCK` as `EAGAIN`; the runtime cannot distinguish them.
They are one canonical `wouldBlock` reason and one counter per operation context.
Tests MAY inject the two symbolic spellings but MUST expect the same normalized
result.

| Condition and operation | State/action | Required counter | Logging |
| --- | --- | --- | --- |
| `EAGAIN/EWOULDBLOCK` from forward send | Stay `running`; drop current packet; no retry | `packet_bridge_forward_drop_would_block_total` +1 packet | No per-packet log; included in bounded aggregate drop summary |
| `EAGAIN/EWOULDBLOCK` from reverse receive | Stay `running`; end drain and yield; no packet is claimed dropped | `packet_bridge_reverse_drain_would_block_total` +1 event | No log |
| `ENOBUFS` from forward send | Stay `running`; drop current packet; no retry | `packet_bridge_forward_drop_no_buffer_total` +1 packet | No per-packet log; aggregate summary |
| `ENOBUFS` from reverse receive | Stay `running`; end drain; no retry or side storage | `packet_bridge_reverse_receive_no_buffer_total` +1 event | Aggregate summary only |
| Real or synthetic `EMSGSIZE`/`MSG_TRUNC` | `starting|running -> failing -> failed`; cancel siblings and run ordered cleanup; never retry | `packet_bridge_fatal_message_too_large_total` +1 event; startup/terminal failure counter as applicable | Exactly one error log with direction, operation, attempted/observed datagram bytes, configured max, and all requested/effective buffer bytes |
| EOF/peer-closed signal while active | `starting|running -> failing -> failed` | `packet_bridge_fatal_peer_eof_total` +1 event | Exactly one error log; no payload/address fields |
| `recvmsg == 0` | Stay `running`; malformed zero-length datagram, not EOF | `packet_bridge_reverse_drop_malformed_total` +1 packet | Aggregate malformed summary only |
| Owner task cancellation | `starting|running -> stopping -> stopped`; no failure | `packet_bridge_cancellation_total` +1 event | Exactly one info log per run |
| Any other socket errno, short datagram send, readiness failure, or repeated/unknown syscall result | Immediate `starting|running -> failing -> failed`; no retry | `packet_bridge_fatal_socket_error_total` +1 event | Exactly one privacy-safe error log with operation and symbolic/numeric errno |
| PacketFlow write rejection/throw | Immediate fatal cleanup; batch not retried | `packet_bridge_fatal_packet_flow_error_total` +1 event and `packet_bridge_reverse_drop_write_rejected_packets_total` + batch count | Exactly one privacy-safe error log |
| Unexpected HEV main return while active | Treat as peer EOF and fail | `packet_bridge_fatal_peer_eof_total` +1 event | Exactly one privacy-safe error log |
| Close failure during cleanup | Preserve primary terminal result; never retry close | `packet_bridge_cleanup_close_error_total` +1 event | One warning per failed owned token, descriptor number omitted |

`packet_bridge_startup_failure_total` increments once when the run never reached
`running`. `packet_bridge_terminal_failure_total` increments once for every run
that ends `failed`. A single event MAY increment its reason counter and one of
these lifecycle counters; this is intentional and testable.

## 11. Bounded work and memory invariants

- Both directions use the supplied positive count and elapsed-time budgets.
  Count includes malformed and dropped work, so hostile input cannot evade it.
- The reverse batch contains no more valid packets than inspected datagrams and
  therefore no more than the count budget.
- The forward side holds at most the current Network Extension callback batch;
  the reverse side holds at most one configured work-slice batch.
- Framing uses fixed/reused storage bounded by `4 + mtu`. No allocation size is
  taken from packet content or a declared length.
- No retry queue exists. No retry occurs for queue pressure, `EMSGSIZE`,
  PacketFlow rejection, persistent errors, or close errors.
- No unbounded recursion is used to schedule reads. The single supervised loop
  issues the next read only after the current batch finishes.
- Budget exhaustion yields/reschedules; it never spins synchronously.

## 12. Metric schema and arithmetic

Metrics are run-scoped, schema-versioned, and use exact snake-case names below.
Counters start at zero for a new run, only increase, never reset within that run,
and saturate at `UInt64.max` rather than wrap. A saturation is logged once. Byte
counters measure payload bytes unless the name says `datagram_bytes`.

### Traffic and batching counters

| Name | Unit |
| --- | --- |
| `packet_bridge_forward_packets_received_total` | packets |
| `packet_bridge_forward_payload_bytes_received_total` | bytes |
| `packet_bridge_forward_datagrams_sent_total` | datagrams |
| `packet_bridge_forward_datagram_bytes_sent_total` | bytes including 4-byte header |
| `packet_bridge_reverse_datagrams_received_total` | datagrams |
| `packet_bridge_reverse_datagram_bytes_received_total` | bytes including 4-byte header |
| `packet_bridge_reverse_packets_written_total` | packets |
| `packet_bridge_reverse_payload_bytes_written_total` | bytes |
| `packet_bridge_reverse_batches_written_total` | batches |
| `packet_bridge_forward_budget_count_yield_total` | yield events |
| `packet_bridge_forward_budget_time_yield_total` | yield events |
| `packet_bridge_reverse_budget_count_yield_total` | yield events |
| `packet_bridge_reverse_budget_time_yield_total` | yield events |

### Drop, error, and lifecycle counters

The exact required names are those in section 10 plus:

- `packet_bridge_forward_drop_malformed_total` (packets)
- `packet_bridge_reverse_drop_malformed_total` (datagrams)
- `packet_bridge_start_total` (runs)
- `packet_bridge_stop_total` (normal explicit stops)

### Gauges/maxima

| Name | Unit and rule |
| --- | --- |
| `packet_bridge_forward_datagram_max_bytes` | bytes; max-assign attempted size |
| `packet_bridge_reverse_datagram_max_bytes` | bytes; max-assign full observed size |
| `packet_bridge_socket_a_send_buffer_requested_bytes` | bytes; immutable after startup |
| `packet_bridge_socket_a_send_buffer_effective_bytes` | bytes; raw `getsockopt` readback |
| `packet_bridge_socket_a_receive_buffer_requested_bytes` | bytes |
| `packet_bridge_socket_a_receive_buffer_effective_bytes` | bytes |
| `packet_bridge_socket_b_send_buffer_requested_bytes` | bytes |
| `packet_bridge_socket_b_send_buffer_effective_bytes` | bytes |
| `packet_bridge_socket_b_receive_buffer_requested_bytes` | bytes |
| `packet_bridge_socket_b_receive_buffer_effective_bytes` | bytes |
| `packet_bridge_configured_mtu_bytes` | bytes; immutable after startup |
| `packet_bridge_configured_max_datagram_bytes` | bytes; checked `4 + mtu` |

Maximum gauges start at zero and only max-assign during a run. Requested/effective
buffer gauges are endpoint-specific because A send feeds B receive and B send
feeds A receive; collapsing them would hide asymmetric clamping.

## 13. Privacy-safe logging

Allowed public fields are event name, run ID, lifecycle state, direction,
operation, symbolic/numeric errno, packet/datagram counts, byte counts, budget
reason, requested/effective buffer bytes, configured MTU/max datagram, and error
category. Logs MUST NOT include packet bytes, IP addresses, hostnames, ports,
protocol payloads, credentials, raw configuration, or numeric file descriptors.

Required events are:

- `packet_bridge.started` once at info with configuration and buffer readbacks;
- `packet_bridge.socket_buffer_clamped` once at notice if any effective value is
  lower than requested;
- `packet_bridge.drop_summary` at most once per caller-supplied diagnostics
  window and once at termination when unsummarized drops remain;
- `packet_bridge.cancelled` once at info for cancellation;
- `packet_bridge.fatal` once at error for the primary fatal error;
- `packet_bridge.stopped` once at info after descriptors are closed.

The diagnostics window is injected policy, not a constant selected here. Fake
clock and logger tests prove suppression and final flushing.

## 14. Required test seams

- `SocketPairFactory`/`SocketIO`: create owned fake descriptors; inspect flags and
  buffer operations; inject full/short sends, datagrams, truncation, each errno,
  readiness, peer close, and close failures; count exact closes.
- `DescriptorBorrowConsumer`: control borrow acceptance, unexpected return,
  stop request, and delayed main return; assert B is open until return.
- `PacketFlow` plus callback-driver seam: inject batches, cardinality mismatch,
  unsupported families, write rejection, cancellation races, and late callbacks.
- `TunnelClock` and a yield/scheduler probe: advance time deterministically and
  prove count/time boundaries without sleeps.
- `TunnelMetrics`, `TunnelLogger`, and run-ID source: assert exact schema,
  monotonic/saturating arithmetic, max assignment, rate limiting, and privacy.
- Lifecycle barrier hooks available only to tests: pause after every startup and
  cleanup stage so cancellation/failure can be injected at each boundary.

Tests MUST cover all transition rows in section 10, both directions' framing
byte-for-byte, at least one hundred repeated start/stop cycles, cancellation at
every startup stage, first-error-wins races, descriptor/task/registration
baseline restoration, and absence of queue/retry calls.

## 15. Explicit prohibitions

The bridge and its test seams MUST NOT:

- open `com.apple.net.utun_control` or otherwise access utun control APIs;
- scan file descriptors, infer a system descriptor, or reopen/duplicate one;
- use a private Network Extension API;
- close endpoint B before the HEV blocking main call returns;
- retry bounded-queue drops, `EMSGSIZE`, persistent errors, PacketFlow rejection,
  or close errors;
- create an unbounded queue, retry list, overflow cache, or side buffer;
- merge packets into one datagram or split one datagram into several packets;
- use wall-clock time or arbitrary sleeps for work budgets/tests;
- log packet payloads, destinations, credentials, or raw descriptors.

## 16. Development-ready board split

1. `TASK-260720-9xy8yx` — Harden PacketFlow adapter read lifecycle: owns the
   cancellation-safe Network Extension boundary and malformed callback batches.
2. `TASK-260715-3o0co4` — Implement the public socket-pair PacketFlowBridge:
   owns socket setup, framing, pumps, supervision, metrics, and descriptor borrow
   seam according to this contract.
3. `TASK-260715-3dn813` — Add PacketFlowBridge unit and fault-injection tests:
   independently verifies every deterministic contract row.
4. `TASK-260715-52h8i3` — Add packet-frame fuzz/allocation-bound tests: verifies
   untrusted reverse framing within fixed allocation/runtime ceilings.
5. `TASK-260715-1vv52g` — Integrate unmodified HEV/lwIP: supplies the real scoped
   borrow handle, dedicated native thread, quit, join, and no-close behavior.

No additional unresolved research or human decision is required for bridge code.
Final MTU, socket-buffer, work-count, elapsed-time, and diagnostics-window values
remain injected measurement inputs as required by scope.

## 17. Sources

- `.spec/packet-plane.md`
- `.spec/decisions.md`, ADR-003
- `TASK-260715-uopycx_pinned-baseline-audit.md`
- Pinned HEV fact: external `tun_fd` is made nonblocking, retained during the
  blocking main function, and not closed by HEV.
- Darwin SDK fact verified for the active Xcode 26.5 SDK: `EWOULDBLOCK` expands
  to `EAGAIN` (`35`), so a distinct runtime counter is impossible.

