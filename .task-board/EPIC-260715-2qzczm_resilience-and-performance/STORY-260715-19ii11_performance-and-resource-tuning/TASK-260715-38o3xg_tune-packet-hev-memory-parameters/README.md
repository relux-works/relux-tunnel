# Tune packet bridge, HEV, MTU, buffer, batch, and memory parameters

## Description
Use the recorded baseline and fixed safety gates to select packet and HEV settings through controlled one-factor or declared multivariate comparisons, including MTU, effective socket buffers, batch budgets, HEV sessions and caches, and packet-plane memory limits.

## Scope
In scope: MTU 1500, 4096, and 8500 evidence; fragmentation and datagram limit; IPv4 and IPv6 behavior; requested and effective SO_SNDBUF and SO_RCVBUF; batch count and time budgets; HEV task stack, TCP buffer, session count, cache and queue limits; packet drops; syscall and copy profile; memory, CPU, energy, throughput, latency; device variance; configuration validation; before and after regression runs. Out of scope: HEV source fork unless separately approved, private utun access, changing UDP-over-TCP baseline before adapter work, weakening backpressure semantics, tuning lanes or rekey, or optimizing only one device without support bounds.

## Acceptance Criteria
1. Each candidate parameter set has protocol-compliant before-and-after evidence with all other variables controlled or the interaction model declared, and includes practical effect and noise analysis. 2. The accepted MTU passes v4, v6, NAT64, fragmentation, maximum datagram, representative app, latency, memory, packet rate, syscall, and error gates on named devices. 3. Accepted socket, batch, HEV session, stack, buffer, cache, and queue values stay within the extension ceiling, preserve bounded EAGAIN or ENOBUFS behavior, and produce no ordinary nominal drops. 4. No accepted change worsens byte correctness, route and DNS safety, cleanup, crash or hang, memory pressure behavior, or supported-device regression thresholds. 5. A TASK-ID-scoped decision records tested values, rejected values, measured tradeoffs, device or OS overrides if justified, final configuration, validation commands, and raw evidence references.
