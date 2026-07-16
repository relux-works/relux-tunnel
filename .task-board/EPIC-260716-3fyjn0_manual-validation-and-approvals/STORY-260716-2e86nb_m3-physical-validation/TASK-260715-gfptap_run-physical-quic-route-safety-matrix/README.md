# Run the physical QUIC and route-safety matrix

## Description
Execute controlled iPhone and Mac acceptance rows for representative QUIC clients and UDP/443 probes under Allow, Block, and Auto with compatible and fail-closed modes across full, degraded, reasserting, failure, endpoint change, and stop.

## Scope
In scope: named physical iPhone and Mac; supported OS; controlled HTTP/3 or UDP/443 and TCP fallback fixtures; unrelated UDP and UDP or TCP DNS; relay full and loss; lane latency and loss shaping; all QUIC policies; compatible and fail-closed where supported; endpoint changes; authorized access and exit captures; failure latency; routes; snapshots; memory; energy; counters; cleanup. Out of scope: public-site correctness guarantees, absolute kill-switch claims, unsupported API rows presented as passes, captive and NAT64 matrix owned separately, or parameter tuning during acceptance.

## Acceptance Criteria
1. A TASK-ID-scoped matrix records device, OS, revisions, route and QUIC policy, capability, impairment, fixture, timings, routes, snapshots, counters, memory, energy, captures, and raw artifact references for every row. 2. Allow carries eligible UDP/443 only through the relay, Block and rejecting Auto fail within the contract bound and permit controlled TCP fallback where the client supports it, and unrelated UDP and tunnel DNS match policy. 3. Full, degraded, reasserting, failed, stopping, relay-loss, and endpoint-change rows show no ordinary UDP or DNS physical fallback and no recursive SSH route. 4. Compatible and supported fail-closed captures match the documented system-exception matrix, while unsupported or changed OS behavior is recorded red and routed to the platform support task. 5. Repeated rows preserve byte correctness, bounded queues and memory, truthful snapshots, and return associations, channels, settings, routes, tasks, timers, sockets, and descriptors to baseline.
