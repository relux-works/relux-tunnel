# Implement the private SOCKS endpoint and bounded CONNECT parser

## Description
Implement the approved process-private SOCKS service used only by the owned HEV instance. Accept bounded sessions, enforce per-generation admission, negotiate only the required SOCKS5 method, parse CONNECT for IPv4, IPv6, and domain targets incrementally, and reject malformed or unsupported input safely.

## Scope
In scope: bind and teardown, private endpoint configuration injected into HEV, ephemeral admission material when required, connection and handshake deadlines, incremental reads, fixed maximum domain and frame sizes, CONNECT parsing, reply encoding, unsupported method or command handling, cancellation, and parser metrics. Out of scope: direct-tcpip open, byte pumping after successful CONNECT, public listener configuration, UDP ASSOCIATE, BIND, user credentials, DNS interception, and destination logging.

## Acceptance Criteria
1. Only a client holding the current generation admission context can complete negotiation, and material is regenerated and released per runtime generation. 2. The parser accepts valid IPv4, IPv6, and domain CONNECT requests split or coalesced across arbitrary reads and preserves the destination exactly within normalized bounds. 3. Unsupported versions, methods, commands, reserved fields, address types, zero or invalid ports where disallowed, oversized domains, truncation, timeout, and extra pre-request data return bounded failures. 4. No parser path allocates from an attacker-controlled length without an enforced maximum, blocks an executor, or retains payload after close. 5. Unit and provider-sandbox smoke tests prove bind, HEV configuration, admission rejection, cancellation, and descriptor cleanup on iOS and macOS targets.
