# Record the capability state, reason, and ownership contract

## Description
Define the binding M2 capability model and transition truth table for full, degraded, failed, and reasserting-compatible states, including readiness predicates, reason codes, generation ownership, consumer snapshots, and the boundary to M3 reconnect.

## Scope
In scope: provider as live-state authority; TCP, safe-DNS, and UDP capability bits; connecting, full, degraded, failed, stopping, and relay-reprobe substates; reasserting-compatible projection; bootstrap and relay failure reasons; safe-DNS readiness; association invalidation; snapshot version and monotonic generation; app-message projection; retry eligibility; stop behavior; privacy-safe diagnostics; M1 and M3 seams. Out of scope: implementing transitions, final UI presentation, path-change reconnect, lane scheduler, includeAllNetworks fail-closed mode, analytics, and claiming absolute kill-switch behavior.

## Acceptance Criteria
1. A TASK-ID-scoped state table defines entry, exit, required resources, allowed traffic, published capability bits, reason, cleanup, and retry behavior for every state and transition. 2. Full requires authenticated SSH, mandatory packet and TCP path, safe DNS, and a validated live relay session; degraded requires the same mandatory base without UDP; failed advertises no usable traffic. 3. Every unsupported platform, asset, bootstrap, checksum, launch, version, feature, limit, framing, health, process, lane, safe-DNS, stop, and stale-generation event maps to one stable finite reason and disposition. 4. Provider snapshots are versioned, generation-scoped, truthful under late callbacks, and expose aggregate build or limit evidence without destinations, queries, payloads, credentials, or remote-controlled strings. 5. The contract clearly assigns relay-only reprobe to M2 and path, host, route, lane-pool, sleep, NAT64, or captive reconnect to M3 with no contradictory ownership.
