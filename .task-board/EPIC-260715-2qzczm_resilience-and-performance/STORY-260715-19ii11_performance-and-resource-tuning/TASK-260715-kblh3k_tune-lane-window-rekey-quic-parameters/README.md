# Tune lane, window, rekey, and Auto QUIC parameters

## Description
Use physical baseline and fault evidence to select lane count policy, congestion weights, optional bulk admission, window profiles and BDP caps, rekey byte and time thresholds, and Auto QUIC thresholds or hysteresis within memory, latency, safety, and compatibility ceilings.

## Scope
In scope: one, two, and four lane comparisons; scheduler inputs and weights; control and DNS priority; optional lane D admission; 32 KiB, 64 KiB, and capped BDP windows; relay burst credit; adjustment thresholds; rekey byte and elapsed time; Auto loss, latency, freshness, hysteresis, and failure bound; mixed flows; loss and latency; memory, CPU, energy, throughput, TTFB, DNS latency, queues, rekeys, failures, cleanup; before and after evidence. Out of scope: live flow migration, per-destination learning, cryptographic algorithm changes, route-mode semantics, unbounded windows, weakening fast failure, or accepting values without both direct-tcpip and relay evidence.

## Acceptance Criteria
1. Every candidate configuration is compared under the recorded one, two, and four lane mixed-load and impairment rows with fixed integrity, memory, DNS, route, failure, and cleanup gates. 2. Accepted lane and scheduler values materially improve or preserve control and short-flow latency under bulk congestion without starvation, excess connections, or greater resource risk. 3. Accepted windows and BDP caps improve throughput where measured while global credit, queues, physical footprint, pressure behavior, and hundreds-of-channel scale remain bounded. 4. Accepted rekey and Auto QUIC thresholds survive active mixed traffic, lane and relay failures, client TCP fallback cases, and device variance without long silent UDP/443 timeouts. 5. A TASK-ID-scoped decision records all tested and rejected values, effects, interactions, final defaults and bounds, device or server caveats, regression thresholds, and raw references.
