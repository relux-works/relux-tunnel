# Relay protocol v1 and cross-language conformance

## Description
Deliver one versioned language-neutral relay wire contract implemented identically by the Apple client and rootless relay. Define negotiation, framing, HEV datagram payloads, association identity, close and error behavior, resource limits, compatibility rules, and shared conformance evidence before deployment or UDP integration consumes the protocol.

## Scope
In scope: relay implementation and binding strategy; protocol v1 constants; client and server hello; feature and maximum-frame negotiation; incremental envelope parsing; IPv4, IPv6, and domain HEV UDP payloads; client-allocated association IDs; PING, PONG, close, and bounded error messages; reserved flags and unknown types; allocation ceilings; generated vectors; fragmentation, coalescing, hostile-input, fuzz, and compatibility tests. Out of scope: opening UDP sockets, building release assets, remote upload or installation, tunnel capability state, physical-device traffic validation, and protocol v2 behavior.

## Acceptance Criteria
1. A recorded implementation and binding strategy fixes the relay language, generated-artifact ownership, dependency ceiling, and portability constraints without leaving downstream language choices implicit. 2. Swift client and relay implementations encode and decode every protocol v1 message and IPv4, IPv6, and domain payload according to one generated constants source. 3. The same canonical vectors pass in both implementations across incremental reads, coalesced frames, limits, closes, errors, and version mismatch. 4. Malformed magic, lengths, flags, types, inner payloads, association IDs, and stream input fail at the specified session or association boundary with bounded allocation and no payload logging. 5. Compatibility documentation states when a feature bit is sufficient, when a new protocol version is required, and how vector changes gate consumers.
