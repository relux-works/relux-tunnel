# Add SOCKS parser, admission-policy, and allocation fuzz tests

## Description
Build deterministic, property, and fuzz tests for the private SOCKS endpoint, negotiation, CONNECT parser, reply encoder, generation admission, deadlines, and allocation bounds. Persist a seed corpus for valid IPv4, IPv6, domain, fragmented, coalesced, malformed, and oversized inputs.

## Scope
In scope: arbitrary byte streams, incremental chunking, all address types, methods and commands, lengths and ports, admission success and rejection, timeout transitions, cancellation, reply encodings, maximum allocations, descriptor cleanup, reproducible seeds, and sanitizer or Swift runtime checks available to the project. Out of scope: direct-tcpip server behavior, full byte pumping, physical-device throughput, UDP ASSOCIATE, public network fuzzing, and retaining sensitive traffic samples.

## Acceptance Criteria
1. Valid messages round-trip across every split and coalescing boundary with identical parsed endpoint and reply bytes. 2. Fuzzing reaches every parser state and unsupported branch without crash, trap, hang, unbounded allocation, out-of-bounds access, or leaked descriptor. 3. Claimed length, domain, method count, extra data, timeout, and admission material inputs are bounded before allocation or comparison. 4. Failures persist as minimal non-sensitive regression seeds and run deterministically in normal test and CI fuzz-smoke modes. 5. The outcome records corpus revision, run duration, iteration count, peak allocation, crashes or timeouts, commands, and remaining coverage gaps.
