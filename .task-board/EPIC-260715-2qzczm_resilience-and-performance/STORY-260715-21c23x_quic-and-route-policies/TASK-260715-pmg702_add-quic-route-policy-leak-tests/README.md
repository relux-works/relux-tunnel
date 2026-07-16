# Add QUIC, route-policy, rollback, and leak fault tests

## Description
Build the deterministic and composed suite covering UDP/443 classification, Allow, Block, Auto, fast failure, lane-health changes, capability transitions, compatible and fail-closed settings, endpoint replacement, apply faults, sentinels, cleanup, and privacy.

## Scope
In scope: fake classifier, evaluator, relay admission, associations, lane snapshots, clock, settings builder and provider, endpoint, DNS, routes, capabilities, profile changes, platform API availability, traffic sentinels, property and race tests, repeated generations, redaction. Out of scope: physical Apple exception claims, real public traffic, final performance thresholds, NAT64 or captive execution, or implementation work inside the test task.

## Acceptance Criteria
1. A scenario table covers every policy, route mode, capability state, family, endpoint, platform branch, and settings transition with exact traffic and snapshot outcomes. 2. Fast-reject tests prove the bounded latency and zero relay association, SSH channel, physical socket, retry timer, or unrelated-UDP impact for Block and rejecting Auto branches. 3. Route and DNS sentinels prove no recursive SSH route, broad bypass, ordinary DNS fallback, or stale-generation traffic during apply, rollback, reconnect, degraded, reasserting, failed, stopping, and mode changes. 4. Race and fault tests cover lane-health oscillation, relay loss, policy replacement, endpoint replacement, includeAll unsupported, apply timeout, stop, late callbacks, and simultaneous failures. 5. Repeated seeded runs return policies, associations, settings, routes, DNS state, tasks, timers, sockets, and metrics to baseline and golden output contains no prohibited data.
