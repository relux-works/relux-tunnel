# Run the integrated M1 TCP concurrency and rekey matrix

## Description
Measure and validate the complete M1 TCP path in ReluxTunnelHarness and controlled Mac harness contexts under staged concurrent flows, representative traffic, large uploads and downloads, slow peers, selected-engine client and server rekey, cancellation, and repeated cleanup. Consume M0 decisions rather than comparing alternatives.

## Scope
In scope: staged 1, 25, 100, 250, and measured safe-ceiling flows, short and idle mixes, at least 5 GiB bulk transfer, simultaneous bidirectional traffic, slow reader or writer, selected byte or time rekey, server rekey, connection loss, CPU, memory, queues, channels, drops, integrity, resource recovery, and a handoff matrix for physical provider acceptance. Out of scope: comparing SSH engines, Apple system routing or lifecycle evidence, multi-lane HoL mitigation, final window tuning, path migration, UDP, QUIC, and claims beyond the measured ceiling.

## Acceptance Criteria
1. A TASK-ID-scoped matrix records harness, OS, source and dependency revisions, server, algorithms, MTU, buffers, windows, traffic seed, concurrency, duration, rekey triggers, loss, and metrics. 2. Nominal runs preserve hashes and have no unexplained packet, stream, or channel loss below saturation. 3. At least one 5 GiB mixed transfer survives client and server rekey with active flows and exact integrity. 4. Above-limit and slow-peer cases stay within admission and queue bounds and fail new work quickly. 5. Repeated cycles return resources to the M0-derived budget and publish exact physical-provider rows consumed by the final lifecycle acceptance tasks.
