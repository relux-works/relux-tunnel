# Implement the Auto QUIC lane-health evaluator

## Description
Implement the pure versioned Auto policy evaluator that consumes allowed lane-loss, RTT, health-age, relay-capability, and pressure evidence, applies validated thresholds and hysteresis, and returns allow or fast-reject with one aggregate reason.

## Scope
In scope: current control and general lane health snapshots; relay capability generation; recent loss or failure rate; RTT and health age; writable capacity; memory pressure; validated threshold configuration; hysteresis and dwell using injected clock; missing and stale inputs; deterministic reason enum; bounded state; tests. Out of scope: collecting metrics, classifying UDP/443, forwarding or rejecting packets, machine learning, per-destination history, payload data, final tuned values, path selection, or route settings.

## Acceptance Criteria
1. The evaluator returns allow or reject and a finite reason only from current contract fields and never uses destination identity, payload, query name, application, or unbounded history. 2. Missing, stale, failed, relay-unavailable, rekeying, pressure, and healthy inputs have explicit deterministic outcomes and generation replacement resets state safely. 3. Thresholds validate units and ranges, hysteresis and minimum dwell prevent oscillation, and injected time makes every boundary reproducible. 4. Evaluation is constant-space and bounded-time and exposes aggregate decision, input-age, and transition counters without high cardinality. 5. Table, boundary, property, and fake-clock tests cover threshold edges, oscillation, lane disagreement, relay changes, pressure, stale data, configuration replacement, and deterministic serialization.
