# Run the physical multi-lane head-of-line and loss matrix

## Description
Execute a reproducible physical iPhone and Mac matrix comparing one, two, and four SSH lanes under controlled latency, loss, congestion, mixed flows, relay traffic, and lane failures, and preserve evidence for policy tuning.

## Scope
In scope: named baseline iPhone and Mac; supported OS and Xcode; controlled SSH and destination fixtures; one, two, and four lanes; short web-like flows, large upload and download, DNS, UDP relay bursts, many idle connections, and mixed bidirectional load; Wi-Fi loss and latency shaping; general and lane-A failure; channel counts; RTT; queues; throughput; TTFB; DNS latency; memory; CPU; energy; drops; cleanup; redacted captures. Out of scope: public-user traffic, changing parameters during measurement, path switching, NAT64, final acceptance tuning, or waiving failed rows.

## Acceptance Criteria
1. A TASK-ID-scoped matrix records device, OS, revisions, algorithms, lane and window configuration, workload, impairment, duration, samples, counters, physical footprint, CPU, energy, and raw artifact references for every row. 2. Nominal unsaturated runs preserve bytes and show no ordinary packet or channel drops, while induced saturation produces only bounded documented rejection or backpressure. 3. Two or four lanes show a measured control or small-flow latency improvement under bulk congestion versus one lane, or the row is explicitly red with follow-up evidence. 4. Lane-local and lane-A failures match capability and DNS safety contracts, create no physical fallback, and restore only admitted new capacity without flow migration. 5. Repeated runs return lanes, channels, queues, associations, tasks, timers, sockets, and descriptors to baseline and provide statistically comparable inputs for the tuning story.
