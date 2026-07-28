# Run the physical rekey, memory-pressure, and soak matrix

## Description
Execute named physical Apple-silicon Mac trials, with the physical-iPhone rows deferred with iOS under ADR-024 and never inferred from Mac results, with active multi-lane direct-tcpip and relay traffic, automatic and server rekeys, staged channel counts, pressure conditions, and reconnect overlap to prove resource behavior and establish tuning inputs.

## Scope
In scope: at least 5 GiB mixed TCP and UDP relay traffic; byte, time, and server rekey; one, two, and four lanes; 32 KiB, 64 KiB, and capped BDP windows; staged 100, 250, 500, and configuration-limit flows when budget permits; memory warnings and controlled allocation pressure; HEV sessions and buffers; DNS cache; reconnect reservation; physical footprint; peak; available-memory samples; CPU; energy; queues; drops; descriptors; cleanup. Out of scope: intentional device destabilization, public-user traffic, claiming a universal jetsam limit, changing parameters mid-row, or waiving red rows.

## Acceptance Criteria
1. A TASK-ID-scoped matrix records device, OS, revisions, algorithms, traffic hashes, lane and window config, rekey triggers, pressure method, duration, counters, footprint, peak, advisory samples, CPU, energy, and artifacts for every row. 2. Client and server rekeys complete during verified at-least-5-GiB mixed traffic with byte integrity and no unintended channel migration, DNS fallback, or UDP escape. 3. Window, queue, session, cache, buffer, and reconnect overlap values remain within declared ceilings and pressure actions occur in order with bounded refusal. 4. Critical-pressure rows release old transport before admitted replacement or stop explicitly and no test relies on an actual jetsam termination for success. 5. Repeated rows show no monotonic tasks, channels, sessions, associations, buffers, sockets, descriptors, timers, or footprint growth and provide comparable evidence for tuning.
