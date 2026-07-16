# Record the PacketFlowBridge concurrency and observability contract

## Description
Turn the packet-plane specification into an implementation-level bridge contract that fixes descriptor ownership, execution context, framing, socket configuration, bounded work, error semantics, counters, cancellation, and test seams before code is written.

## Scope
In scope: AF_UNIX SOCK_DGRAM socket-pair lifecycle; endpoint ownership; nonblocking flags; SO_SNDBUF and SO_RCVBUF request and readback; Darwin family headers; batch and time budgets; bounded loss; EMSGSIZE and persistent-error startup failure; NEPacketTunnelFlow async boundaries; metric schema; privacy-safe errors; injectable socket and clock seams. Out of scope: choosing final measured buffer, MTU, or batch constants; HEV internals; SSH; routes; DNS; and private utun access.

## Acceptance Criteria
1. A TASK-ID-scoped design states which component creates, owns, transfers, closes, and observes each descriptor and asynchronous task for start, cancellation, failure, and stop. 2. Forward and reverse framing algorithms define byte order, IPv4 and IPv6 classification, malformed-frame behavior, packet-boundary preservation, and batch construction. 3. EAGAIN, EWOULDBLOCK, ENOBUFS, EMSGSIZE, EOF, cancellation, and persistent errors each have one explicit state transition, counter, and logging rule. 4. Batch count and elapsed-time budgets, queue nonexistence, metric units, counter monotonicity, and maximum-datagram tracking are testable. 5. The contract explicitly prohibits utun control access, file-descriptor scanning, reopening system descriptors, unbounded retries, and unbounded side buffers.
