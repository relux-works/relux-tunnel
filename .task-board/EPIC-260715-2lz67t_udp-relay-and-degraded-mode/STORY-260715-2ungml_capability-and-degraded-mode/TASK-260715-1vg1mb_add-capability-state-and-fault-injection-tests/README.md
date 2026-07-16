# Add capability state-machine and fault-injection tests

## Description
Build deterministic tests for every full, degraded, failed, stop, and relay-reprobe state and event, including readiness combinations, finite reasons, generation ordering, association invalidation, safe-DNS loss, cancellation, memory overlap, and snapshot compatibility.

## Scope
In scope: table-driven state transitions; fake base TCP, safe DNS, bootstrap, relay, association, health, clock, jitter, memory, and snapshot dependencies; every reason code; startup full and degraded; runtime loss; simultaneous failures; safe-DNS mandatory failure; restore; stop; duplicate and late events; provider-message versions; counters and cleanup. Out of scope: real sockets, remote hosts, physical routing captures, M3 path reconnect, final UI snapshot tests, protocol byte fuzzing, and performance tuning.

## Acceptance Criteria
1. The transition table executes every legal state and event pair and rejects impossible or stale pairs without false-full, double cleanup, or hidden fallthrough. 2. All finite bootstrap, protocol, process, lane, association, safe-DNS, memory, stop, and retry reasons produce the contractually correct mode, capability bits, association action, and retry eligibility. 3. Simultaneous relay and DNS loss, stop during bootstrap or reprobe, duplicate terminal events, old-generation callbacks, and snapshot requests at each boundary are deterministic. 4. Fake-clock and memory fixtures prove one timer and attempt, capped backoff, overlap ceiling, stable reset, cancellation, and no task, buffer, channel, association, timer, or snapshot growth over repeated cycles. 5. Golden snapshots verify schema versions, system-session separation, redaction, unknown-future handling, aggregate diagnostics, and no destinations, queries, payloads, credentials, or remote text.
