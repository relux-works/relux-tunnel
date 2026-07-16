# Add DNS protocol, cache, fault, and allocation-bound tests

## Description
Build the deterministic and fuzz-oriented test suites for the tunnel DNS listener, TCP framing, upstream correlation, cache semantics, truncation, malformed messages, timeouts, pressure, cancellation, privacy, and cleanup. Use injected clocks and controlled channels instead of public resolvers.

## Scope
In scope: UDP and TCP client framing, incremental reads, DNS header and section bounds needed by policy, EDNS size, response correlation, TTL and negative cache rules, eviction, coalescing, TC, upstream partial I/O, hostile lengths, query floods, cancellation, allocation ceilings, fuzz corpus, log scans, and repeated resource baselines. Out of scope: system route settings, physical packet capture, public DNS correctness survey, general UDP, DNSSEC validation implementation, and real user query samples.

## Acceptance Criteria
1. Table and property tests cover valid UDP and TCP queries or responses, every split and coalescing boundary, repeated IDs across clients, cache rules, TC, and all typed failures. 2. Fuzzing malformed headers, counts, compression pointers where parsed, lengths, EDNS sizes, TCP prefixes, and response correlation causes no crash, hang, recursion blowup, unbounded allocation, or cross-client delivery. 3. Fake-clock tests prove positive and negative TTL expiry, eviction, resolver-generation invalidation, and miss coalescing without sleep. 4. Pressure and cancellation tests stay within transaction, connection, cache, frame, and queued-byte limits and return tasks, sockets, channels, entries, and timers to baseline. 5. Golden logs and snapshots contain no query names, response records, full addresses, payloads, or high-cardinality identifiers.
