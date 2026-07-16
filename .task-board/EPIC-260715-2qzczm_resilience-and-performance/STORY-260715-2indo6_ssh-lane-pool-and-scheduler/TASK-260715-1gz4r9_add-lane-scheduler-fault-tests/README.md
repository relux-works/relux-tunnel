# Add lane-pool scheduler and failure-injection tests

## Description
Build the candidate-neutral deterministic suite for lane lifecycle, identity, health snapshots, assignment, immutable pinning, congestion, rekey gating, memory admission, failures, recovery, cancellation, fairness, and resource bounds.

## Scope
In scope: fake SSH sessions and channels; injected clock, RTT, windows, queues, server limits, memory, host identity, capability sink, and failures; one to four lanes; hundreds of channel requests; control, DNS, ordinary, and bulk classes; property and race tests; resource counters; privacy snapshots. Out of scope: real public traffic, physical network shaping, selected-engine conformance already covered by M0, path reconnect, final performance thresholds, or implementation fixes inside the test task.

## Acceptance Criteria
1. A transition and scenario table covers every lane state, identity outcome, health eligibility state, flow class, tie, saturation, rekey, pressure, failure, recovery, stop, and stale generation. 2. Hundreds of concurrent opens under controlled schedules produce exactly one assignment or typed rejection each, preserve control priority and flow pinning, and reconcile channels and registry entries. 3. Deliberate queue, window, lane, and server saturation remains inside fixed memory and pending-request ceilings and never busy-spins or grows a side buffer. 4. Race tests cover stop or failure during open, simultaneous lane events, late metrics, duplicate close, replacement generation, and lane-A plus safe-DNS loss with one ordered outcome. 5. Repeated randomized seeds return sessions, channels, requests, tasks, timers, metrics, and registries to baseline and golden logs contain no prohibited data.
