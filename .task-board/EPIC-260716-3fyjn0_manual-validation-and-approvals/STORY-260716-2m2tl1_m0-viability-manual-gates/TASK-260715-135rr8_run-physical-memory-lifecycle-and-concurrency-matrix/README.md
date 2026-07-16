# Run the physical memory, lifecycle, and concurrency matrix

## Description
Measure the full bridge and HEV baseline under staged flow counts, repeated provider lifecycle, cancellation, and pressure on the physical iPhone and Mac. Establish whether the provisional 25–30 MiB extension target and bounded resource contract are credible.

## Scope
In scope: staged 100, 250, 500, and measured configuration-limit flows; many idle connections; mixed bidirectional traffic; start and stop loops; cancellation during start; host termination; sleep and wake where supported by the spike; induced memory pressure; physical footprint and peak; os_proc_available_memory samples; HEV sessions; socket buffers; queued bytes; descriptors; tasks; counters; reconnect-overlap estimate. Out of scope: claiming an Apple memory guarantee, SSH channel allocations not yet implemented, production reconnect, jetsam experimentation that risks device stability, and raising limits to hit an arbitrary count.

## Acceptance Criteria
1. A TASK-ID-scoped matrix records device and OS, source and dependency revisions, config, traffic, duration, flow counts, physical footprint, peak, available-memory samples, sessions, buffers, queued bytes, descriptors, tasks, drops, and failures. 2. Staged counts stop at the measured safe ceiling with an explicit reason; the task does not force 1200 sessions when the device budget rejects it. 3. At least one hundred start and stop cycles plus cancellation at multiple startup points show no monotonic descriptor, task, session, or physical-footprint growth. 4. Soft, pressure, and critical simulations verify the spike can reduce or stop work in the specified order or explicitly identify behavior deferred until SSH integration. 5. The report states whether the 25–30 MiB steady-state target is met, the remaining budget for SSH, DNS, relay, caches, and reconnect overlap, and every unresolved risk.
