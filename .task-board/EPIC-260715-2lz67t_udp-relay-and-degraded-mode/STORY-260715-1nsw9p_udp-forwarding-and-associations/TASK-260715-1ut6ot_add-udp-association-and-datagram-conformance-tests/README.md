# Add UDP association and datagram conformance tests

## Description
Build deterministic component and composed harness tests for client associations, HEV translation, framed pumping, relay sockets, IPv4, IPv6, domains, replies, errors, close, expiry, DNS, limits, and repeatable cleanup.

## Scope
In scope: fake HEV streams; fake and loopback SSH channels; controlled UDP echo and DNS fixtures; client and relay registries; all address types; multiple destinations per association where supported; request and response byte integrity; source endpoints; ID lifecycle; PING or PONG coexistence; errors and closes; fake clock expiry; configured boundary limits; cancellation; repeated start and stop. Out of scope: arbitrary malformed-byte fuzzing owned separately, public Internet endpoints, physical Apple devices, long soak, bootstrap installation, path transitions, and performance claims.

## Acceptance Criteria
1. Table tests cover every legal association state and protocol message combination for IPv4, IPv6, domain, empty or maximum payload, source response, error, local close, remote close, expiry, and session loss. 2. Composed tests send concurrent bidirectional datagrams through HEV adapter, client pump, protocol peers, relay sockets, and controlled destinations with byte hashes and association identities intact. 3. DNS fixtures prove priority UDP relay behavior and approved TCP fallback on truncation or relay failure without a physical resolver sentinel hit. 4. Boundary runs admit up to each configured limit, reject the next unit deterministically, preserve control progress, and reconcile frames, associations, sockets, timers, queue bytes, drops, and errors. 5. Repeated fake-clock scenarios return all tasks, channels, associations, descriptors, buffers, timers, resolver work, and counters to documented baseline without sleeps or timing flakes.
