# Add NAT64, sleep, captive, app-termination, and lifecycle fault tests

## Description
Build the deterministic M3 lifecycle suite that simulates address-family and synthesized-endpoint changes, sleep and wake races, captive transitions, containing-app termination, provider stop reasons, cancellation during start, repeated loops, API capability changes, leaks, and cleanup.

## Scope
In scope: fake path, resolver, endpoint, SSH, settings, route mode, packet, DNS, relay, lane, memory, lifecycle, provider, containing-app, clock, and stop inputs; every-boundary faults; traffic sentinels; property and race tests; repeated generations; API availability fixtures; redaction. Out of scope: physical platform claims, real public captive traffic, final performance measurement, implementation fixes in the test task, or private API use.

## Acceptance Criteria
1. Scenario coverage maps every row from the recorded matrix that can be deterministic to exact states, settings, traffic, capability, retry, memory, and cleanup assertions. 2. NAT64 cases cover synthesized and native endpoints, family transitions, cache invalidation, exact route replacement, DNS generation, relay invalidation, and no stale delivery or route loop. 3. Lifecycle races cover sleep or wake plus path change, rapid cycles, UI process exit, cancellation during each startup boundary, every provider stop reason, duplicate or late callbacks, and critical pressure. 4. Captive and route-mode cases prove no ordinary application or DNS fallback while accurately modeling the platform captive exception and unsupported API changes. 5. Repeated seeded runs return observers, generations, routes, sessions, lanes, channels, associations, DNS work, tasks, timers, sockets, and descriptors to baseline and pass prohibited-data scans.
