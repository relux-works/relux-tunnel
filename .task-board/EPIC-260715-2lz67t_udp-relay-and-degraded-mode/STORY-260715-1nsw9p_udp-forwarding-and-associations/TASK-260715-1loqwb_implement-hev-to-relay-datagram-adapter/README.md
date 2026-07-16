# Implement the HEV-to-relay UDP datagram adapter

## Description
Bridge the private HEV UDP-in-TCP stream contract to client association IDs and protocol UDP_DATAGRAM messages, preserving frame boundaries, addresses, ports, payloads, replies, and backpressure outcomes without exposing a public proxy.

## Scope
In scope: consume the accepted HEV socks5.udp tcp configuration; private adapter admission; one HEV logical association to one registry handle; incremental MSGLEN input; coalesced datagrams; inner codec validation; request mapping; response source-endpoint mapping; UDP_ERROR and close translation; bounded pending input and output; cancellation; metrics. Out of scope: outer SSH frame pumping, relay socket behavior, DNS cache, public SOCKS UDP ASSOCIATE service, TCP CONNECT handling, destination logging, and association-limit policy owned by the registry and resource task.

## Acceptance Criteria
1. Only the owned process-local HEV path can create an adapter association and every valid IPv4, IPv6, or domain HEV datagram maps to the same bytes and address semantics in one protocol datagram. 2. Split and coalesced HEV stream input is parsed using the inner declared length with fixed ceilings and cannot cross-deliver bytes between associations. 3. Relay responses return to the originating HEV association with the relay-observed source endpoint; errors, close, expiry, and session loss produce the documented HEV-visible outcome. 4. Invalid lengths, address types, ports, oversize payloads, stalled consumers, timeout, and cancellation are bounded and cannot open an association or retain an unbounded side queue. 5. Fake-HEV and fake-relay tests cover both families, domains, bidirectional datagrams, multiple associations, partial I/O, close and error cases, external admission rejection, and resource cleanup.
