# Record the production lane-pool and scheduler contract

## Description
Produce the binding candidate-neutral contract for lane roles, lifecycle, identity, admission, flow classification, scheduling, pinning, failure, recovery, memory-pressure behavior, and diagnostics before production lane code is written.

## Scope
In scope: lane A control ownership, lanes B and C general service, optional lane D bulk admission, two-to-four connection bounds, profile and host-identity generation, lifecycle states and events, channel-open interface, congestion signal schema and freshness, deterministic score and tie-break rules, control and DNS priority, bulk hints, immutable pinning, rekey and memory gates, lane-local and control failure outcomes, counters, privacy, diagrams, and M1 or M2 seams. Out of scope: selecting or patching the SSH engine, implementing code, live flow migration, payload inspection, destination logging, final numeric tuning, relay protocol changes, ProxyJump, or UI.

## Acceptance Criteria
1. A TASK-ID-scoped contract defines lane states, roles, required resources, allowed channel classes, ownership, start and stop order, and exact two-to-four connection limits. 2. It specifies normalized scheduler inputs, units, freshness, unavailable-data behavior, score or ordering, deterministic tie-breaks, capacity rejection, and immutable flow-to-lane pinning. 3. It proves every lane uses one approved canonical host identity and credential generation and defines mismatch, rekey, memory, server-limit, and stale-generation behavior before channel admission. 4. Failure tables distinguish general, bulk, and lane-A loss and map each to channel treatment, new-flow admission, relay or DNS capability, degraded handoff, retry ownership, and cleanup. 5. Metrics and diagrams expose aggregate lane health, queues, windows, RTT, channels, assignments, failures, and recovery without destinations, queries, payloads, credentials, or unbounded cardinality.
