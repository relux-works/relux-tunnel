# Implement exit-side DNS-over-TCP through SSH direct-tcpip

## Description
Implement the M1 DNS upstream transport that opens bounded SSH direct-tcpip channels to the resolver selected by the approved policy, writes and reads RFC-compatible TCP length-prefixed DNS messages, validates correlation and size, and returns explicit failure without any physical resolver fallback.

## Scope
In scope: selected resolver endpoint and port, control-priority channel policy on the baseline session, one-shot or bounded pooled connection policy from the decision, TCP length framing, partial I/O, response ID and question correlation as approved, maximum message size, timeout, cancellation, EOF, retry limited by explicit idempotent policy, metrics, and cleanup. Out of scope: UDP relay, general DoH unless selected by the decision, physical DNS, recursive server behavior, resolver UI, caching, query-name logging, lanes, and reconnect.

## Acceptance Criteria
1. Every upstream connection is opened through the authenticated SSH session to the approved exit-side resolver endpoint and never through a local physical socket. 2. Query and response TCP framing handles partial reads and writes, coalesced frames, maximum sizes, EOF, timeout, cancellation, and hostile resolver data within fixed buffers. 3. Responses are validated against the outstanding transaction according to the DNS contract before client delivery. 4. Transport, channel, resolver, timeout, malformed response, and session-loss failures return typed results that cannot trigger physical DNS fallback. 5. Fake-channel and controlled-resolver tests verify byte-exact framing, pressure, concurrent transactions, cancellation, cleanup, and privacy-safe aggregate latency or error metrics.
