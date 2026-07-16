# Implement advisory memory sampling and watermark state control

## Description
Implement the low-overhead memory observation and deterministic watermark state machine that combines uncached os_proc_available_memory samples with physical footprint and ledger evidence and emits soft, pressure, critical, and recovery transitions.

## Scope
In scope: platform service abstraction; uncached advisory available-memory sample; physical-footprint input; ledger current, reserved, and peak bytes; configured device baseline; monotonic timestamps; cadence and event-driven samples; validation; hysteresis; missing or stale samples; memory warning input; one serialized state generation; bounded history and metrics; test clock. Out of scope: applying resource actions, querying private APIs, treating advisory bytes as a guarantee, final thresholds without tuning evidence, polling at unbounded frequency, or storing sensitive traffic data.

## Acceptance Criteria
1. Every observation contains documented units, provenance, timestamp, configuration generation, physical footprint, ledger bytes, and either one current advisory sample or an explicit unavailable state. 2. os_proc_available_memory is invoked at observation time and its value is not cached as future availability or used alone to promise an allocation. 3. Soft, pressure, critical, and recovery transitions follow validated thresholds and hysteresis and simultaneous warning or sample events produce one deterministic current state. 4. Sampling has bounded cadence, execution time, retained history, and cardinality and cannot starve packet, SSH, or lifecycle executors. 5. Fake-clock and service tests cover thresholds, oscillation, unavailable or stale data, warning bursts, pressure recovery, configuration replacement, concurrent observations, overflow, and redacted metrics.
