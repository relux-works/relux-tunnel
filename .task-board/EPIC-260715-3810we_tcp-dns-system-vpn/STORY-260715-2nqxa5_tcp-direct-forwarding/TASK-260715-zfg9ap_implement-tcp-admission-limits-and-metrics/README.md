# Implement TCP admission limits and privacy-safe flow metrics

## Description
Implement the bounded registry and admission policy for M1 TCP flows using the measured M0 extension budget. Enforce global and per-state ceilings, reject new work quickly when capacity is unavailable, account for queued bytes and channels, and expose aggregate metrics without destinations.

## Scope
In scope: configurable maximum flows within M0 safe ceiling, handshake and open sub-limits, queued-byte budget, session health gate, atomic reservation and release, fast SOCKS failure, active and peak counts, open latency buckets, byte totals, terminal reasons, pressure rejects, and diagnostic snapshot integration. Out of scope: per-destination policy, traffic prioritization, multi-lane scheduling, BDP windows, memory-watermark adaptation, analytics, and destination labels.

## Acceptance Criteria
1. Admission reserves capacity before expensive work and concurrent requests cannot exceed configured flow, opening, or queued-byte ceilings. 2. Rejection is fast and maps to a documented SOCKS failure without opening an SSH channel or retaining a side queue. 3. Every terminal path releases exactly its reservations and repeated churn does not reduce or inflate available capacity. 4. Metrics expose only aggregate counts, bytes, timing buckets, pressure, and terminal reasons with no hostname, address, port, or payload label. 5. Stress tests at below, at, and above each limit prove bounded memory, fairness for admitted flows, deterministic rejects, and return to baseline.
