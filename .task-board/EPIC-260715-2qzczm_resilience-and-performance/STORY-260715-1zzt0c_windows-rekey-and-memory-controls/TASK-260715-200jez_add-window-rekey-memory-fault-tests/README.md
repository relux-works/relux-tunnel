# Add window, rekey, memory, and allocation-bound fault tests

## Description
Build the deterministic cross-layer suite that proves window reservations, rekey serialization, advisory memory states, ordered pressure actions, overlap denial, fast refusal, critical release, cancellation, and fixed allocation bounds under hostile event schedules.

## Scope
In scope: fake SSH adapter, lanes, packet and HEV limits, DNS and relay consumers, memory service, reconnect reservation, clock, warnings, acknowledgements, failures, and jetsam sentinel; table, property, race, and allocation tests; at least hundreds of channels; repeated cycles; privacy scans. Out of scope: physical-device footprint claims, real public endpoints, performance tuning, changing implementation in the test task, or accepting flaky timing-based outcomes.

## Acceptance Criteria
1. The suite covers all window classes and adjustment states, byte and time and server rekey triggers, every watermark transition, each action failure, reservation fit or denial, and every cleanup path. 2. Randomized channel counts, BDP inputs, credits, queues, sessions, buffers, caches, and reconnect overlap never exceed configured ledger ceilings or overflow arithmetic. 3. Race schedules cover rekey plus pressure, reconnect plus critical state, lane failure plus adjustment, warning bursts, stale generations, duplicate acknowledgements, stop, and late callbacks with one deterministic result. 4. Pressure causes bounded refusal or documented drops and no busy wait, unbounded side buffer, false recovery, leaked DNS, or fallback transport. 5. Repeated seeded runs return windows, reservations, sessions, channels, queues, buffers, tasks, timers, sockets, and metrics to baseline and attach allocation ceiling evidence.
