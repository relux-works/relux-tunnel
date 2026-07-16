# Implement lane health, congestion, and admission signals

## Description
Implement a bounded versioned lane-health projection that samples writable window, queued bytes, RTT and keepalive age, open-channel count, transport and rekey state, recent failures, and admission capacity for scheduler and policy consumers.

## Scope
In scope: stable metric types and units; monotonic timestamps; sample freshness and unavailable state; writable and queued byte bounds; RTT smoothing input without final tuning; channel counts; keepalive and transport health; rekey state; memory and server admission; current generation; aggregate counters; snapshot rate limiting; test clock. Out of scope: choosing a lane, inspecting payloads or application identity, destination logging, calculating channel windows, path monitoring, analytics, or final threshold selection.

## Acceptance Criteria
1. Each snapshot is generation-scoped and contains all contract-required health and congestion fields with documented units, valid ranges, timestamp, freshness, and unavailable encoding. 2. Queued bytes, window credit, channel counts, and event histories use fixed ceilings or bounded aggregation and cannot create per-destination series. 3. Stale, failed, opening, closing, rekeying, memory-blocked, and server-blocked lanes are unambiguously ineligible or qualified according to the contract. 4. Sampling cannot block SSH event loops, has an explicit cadence or on-change budget, and drops or coalesces excess observations with counters. 5. Fake-clock and fake-transport tests cover updates, stale data, counter rollover policy, rekey, failure, pressure, late generations, concurrency, and redacted serialization.
