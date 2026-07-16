# M3 — Resilience and performance

## Description
Make the tunnel robust across loss, path changes, memory pressure, NAT64, sleep, lane congestion, QUIC, and fail-closed routing modes.

## Scope
Multi-lane SSH scheduling, channel windows/rekey, memory controls, reconnect/path state machine, QUIC policy, NAT64, sleep/wake, route modes, and evidence-led tuning.

## Acceptance Criteria
The resilience matrix passes on physical devices; no routing loops, unbounded queues, avoidable jetsam, or ordinary DNS leaks occur; lane and memory policies meet recorded performance baselines.
