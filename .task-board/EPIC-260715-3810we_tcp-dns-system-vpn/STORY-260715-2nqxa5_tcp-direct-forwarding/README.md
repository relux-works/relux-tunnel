# TCP SOCKS-to-SSH direct forwarding

## Description
Implement the process-local SSHProxyAdapter that accepts HEV SOCKS CONNECT flows and maps each accepted flow to one bounded SSH direct-tcpip channel. Preserve independent flow semantics, backpressure, EOF and half-close, cancellation, error mapping, resource limits, and aggregate observability.

## Scope
In scope: private SOCKS endpoint admission, SOCKS5 CONNECT for IPv4, IPv6, and domain destinations, originator metadata, direct-tcpip channel opens, bounded full-duplex pumping, half-close and reset, cancellation, admission limits, per-flow aggregate metrics, parser fuzzing, conformance tests, end-to-end HEV integration, concurrency, and large-transfer validation. Out of scope: general public proxy exposure, SOCKS authentication UI, UDP ASSOCIATE forwarding, relay framing, lane pools, flow migration, QUIC policy, SSH-engine selection, and application-specific routing.

## Acceptance Criteria
1. Only the owned HEV and adapter path can reach the internal SOCKS service, and unsupported commands or malformed requests fail within bounded memory. 2. Every accepted CONNECT opens one direct-tcpip channel with the requested destination and remains pinned to the baseline SSH session until close. 3. Bidirectional data, bounded write pressure, EOF, half-close, reset, cancellation, and channel rejection produce deterministic SOCKS or TCP-visible outcomes without leaked tasks or channels. 4. Unit, fuzz, fake-transport, and end-to-end tests cover IPv4, IPv6, domain targets, concurrency, early close, pressure, and repeated cleanup. 5. Representative and multi-gigabyte TCP transfers through the integrated M1 path preserve byte integrity across selected-engine rekey behavior and record throughput, memory, queue, and error evidence.
