# Record the private SOCKS-to-direct-tcpip adapter contract

## Description
Produce the task-scoped production contract between HEV and SSHProxyAdapter before implementation. Specify the process-private endpoint mechanism, SOCKS5 negotiation, destination and originator representation, direct-tcpip open, bounded streaming, close semantics, admission, metrics, errors, and ownership.

## Scope
In scope: approved endpoint type supported by the pinned HEV build, per-generation admission proof or ephemeral credentials when loopback is required, CONNECT for IPv4, IPv6, and domain names, remote-resolution semantics, channel policy, buffer and queue bounds, backpressure, EOF and half-close, cancellation, timeouts, error replies, aggregate metrics, and future lane-selection seam. Out of scope: public proxy service, user SOCKS settings, UDP ASSOCIATE, relay framing, engine selection, lane scheduling, QUIC policy, and implementation.

## Acceptance Criteria
1. A TASK-ID-scoped contract proves how non-owned local clients are rejected on iOS and macOS and records the HEV capability that supports the mechanism. 2. Byte-level SOCKS negotiation and CONNECT request or reply states, bounds, timeouts, and error mappings are defined for all supported address types. 3. One accepted request maps to one direct-tcpip channel with explicit destination, sanitized originator, channel window policy input, and no flow migration. 4. Bidirectional backpressure, buffer ownership, EOF, half-close, reset, cancellation, deadline, and cleanup behavior are specified without unbounded side queues. 5. Limits and metrics fit the measured M0 memory baseline and expose a stable seam for M3 lane assignment without implementing it.
