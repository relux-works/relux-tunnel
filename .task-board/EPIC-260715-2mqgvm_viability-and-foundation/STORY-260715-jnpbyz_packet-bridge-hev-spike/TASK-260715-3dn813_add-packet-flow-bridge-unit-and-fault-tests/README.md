# Add PacketFlowBridge unit and fault-injection tests

## Description
Create deterministic Swift Testing coverage for packet framing, batching, socket limits, backpressure, errors, cancellation, and resource cleanup using injected packet-flow, socket, clock, and fault controls.

## Scope
In scope: IPv4 and IPv6 family headers; endianness; empty, undersized, unknown-family, and oversized frames; packet boundaries; batch count and time budgets; effective-buffer readback; induced EAGAIN, EWOULDBLOCK, ENOBUFS, EMSGSIZE, persistent errors, cancellation races, partial startup, repeated lifecycle, and descriptor accounting. Out of scope: HEV behavior, physical-device throughput, SSH, route or DNS integration, and tests that depend on arbitrary sleeps.

## Acceptance Criteria
1. Swift Testing cases cover forward and reverse IPv4 and IPv6 framing byte-for-byte and prove malformed or unknown frames are dropped with the correct counter. 2. Deterministic fault injection proves each bounded-drop errno, fatal EMSGSIZE metadata, persistent-error transition, and no retry or side-buffer behavior. 3. Batch-count and fake-clock time budgets stop work predictably and yield to other tasks. 4. Cancellation at every startup stage and at least one hundred start and stop cycles leave descriptor, task, and continuation counts at baseline. 5. Tests assert metric names, units, monotonic counters, effective buffer values, and maximum observed datagram size.
