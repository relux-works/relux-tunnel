# Implement the HEV UDP payload codec

## Description
Implement the inner MSGLEN, HDRLEN, ATYP, address, port, and DATA codec shared by relay datagrams, with exact HEV compatibility and independent validation of inner and outer lengths.

## Scope
In scope: unsigned network-byte-order MSGLEN; one-byte HDRLEN and ATYP; IPv4, IPv6, and length-prefixed domain forms; destination or response-source port; zero-length and maximum permitted DATA; IDNA or raw-domain byte policy inherited from HEV; inner-versus-outer length checks; encoder size computation; typed association-local errors where safe. Out of scope: DNS resolution, socket creation, outer stream framing, association allocation, domain-name logging, datagram fragmentation, and application-layer protocol parsing.

## Acceptance Criteria
1. Valid IPv4, IPv6, and domain datagrams round-trip byte exactly against recorded HEV layout examples at zero, typical, and maximum permitted payload sizes. 2. MSGLEN and HDRLEN are recomputed and independently validated against available bytes, address form, port, DATA, and outer payload length before any slice or allocation. 3. Unknown ATYP, invalid domain length or bytes per the chosen policy, truncated address or port, inconsistent lengths, overflow, and oversized DATA return bounded typed errors with the documented association-versus-session consequence. 4. Response encoding preserves the source endpoint reported by the relay and does not substitute the original destination or resolve domain text on the client. 5. Table, property, and fuzz tests use privacy-safe synthetic addresses and prove equivalent Swift and relay behavior with bounded allocations.
