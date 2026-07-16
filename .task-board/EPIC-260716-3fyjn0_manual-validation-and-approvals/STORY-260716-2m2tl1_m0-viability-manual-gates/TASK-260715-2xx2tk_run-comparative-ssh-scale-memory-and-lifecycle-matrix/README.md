# Run the comparative SSH scale, memory, and lifecycle matrix

## Description
Measure both viable candidates under identical concurrent-channel, connection-count, loss, cancellation, and memory conditions so engine selection accounts for extension budgets and cross-flow behavior rather than functional support alone.

## Scope
In scope: staged 100, 250, 500, and measured safe channel counts; control-like, ordinary, bulk, early-close, half-close, and idle mixes; one, two, and four independent SSH connections; 32 KiB, 64 KiB, and capped BDP windows; Wi-Fi-like latency and loss; connection and control-lane failure simulation; repeated connect and close; physical iPhone and Mac footprint; CPU; queued bytes; descriptors; tasks; custom allocator metrics where available. Out of scope: production lane scheduler, flow migration, QUIC policy, forcing a functionally red candidate through unsafe scale tests, and claiming advertised windows are eagerly allocated.

## Acceptance Criteria
1. A TASK-ID-scoped comparative matrix records identical fixture, device, OS, source, dependency, algorithm, traffic, window, connection-count, loss, duration, and measurement inputs for both candidates. 2. Staged channel counts stop at each candidate safe ceiling with explicit reason; hundreds of independent channels must pass for a selectable candidate. 3. One, two, and four connection trials report throughput, latency, CPU, physical footprint and peak, available-memory samples, queued bytes, window credit, channels, tasks, sockets, descriptors, and failures. 4. At least one hundred connect, active-traffic, cancel, and close cycles show no monotonic resource growth for a selectable candidate. 5. The report estimates remaining extension budget after HEV and bridge baselines, distinguishes reserved window credit from measured allocation, and preserves all red lifecycle or memory rows.
