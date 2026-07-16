# Add reconnect state, retry, route, DNS-leak, and cleanup tests

## Description
Build the deterministic cross-component suite for every reconnect state and event, endpoint attempt, retry class, memory reservation, settings transaction, capability sequence, cancellation, stale callback, traffic sentinel, and resource baseline.

## Scope
In scope: fake path, endpoint, SSH, lane, packet, TCP, DNS, relay, settings, memory, clock, jitter, provider, capability, and stop dependencies; exhaustive reducer table; fault at every boundary; authorized local sentinels; property and race tests; repeated generations; redaction. Out of scope: physical Wi-Fi or cellular switching, public traffic, final NAT64 or captive rows, performance tuning, or masking implementation failures in test fixtures.

## Acceptance Criteria
1. The suite executes every legal transition and rejects every illegal or stale transition with the exact state, reasserting, capability, retry, traffic, and cleanup outcome. 2. Fault injection covers cached and fresh endpoint stages, required interface, trust and auth, path loss, lane A, safe DNS, relay, memory reservation, settings apply, packet start, optional lanes, stop, and retry exhaustion. 3. Physical-route, DNS, UDP, and TCP sentinels observe zero ordinary fallback or recursive SSH route during connecting, reasserting, degraded, failed, stopping, rollback, and timeout branches. 4. Race tests cover path churn, simultaneous failures, critical pressure, stop during every await, late success, duplicate callbacks, old timers, and profile replacement with one current result. 5. Repeated seeded runs return generations, observers, attempts, timers, reservations, sessions, lanes, channels, associations, routes, DNS transactions, tasks, sockets, and descriptors to baseline and pass prohibited-data scans.
