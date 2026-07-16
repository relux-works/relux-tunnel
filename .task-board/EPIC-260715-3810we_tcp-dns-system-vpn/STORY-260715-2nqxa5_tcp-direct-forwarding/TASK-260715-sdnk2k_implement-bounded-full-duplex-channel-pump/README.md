# Implement the bounded full-duplex SOCKS and SSH channel pump

## Description
Implement independent asynchronous pumps for client-to-SSH and SSH-to-client bytes after CONNECT succeeds. Respect both local socket writability and SSH channel backpressure, use fixed bounded buffers, preserve byte order, and never block packet, lifecycle, or SSH event executors.

## Scope
In scope: read and write loops, explicit maximum chunk and queued-byte limits, partial writes, suspension and resumption, SSH writability, local socket readiness, fairness budgets, byte accounting, cooperative cancellation, terminal event handoff, and test injection. Out of scope: handshake parsing, channel open, EOF policy decisions owned by the close task, compression, traffic inspection, destination logging, lane assignment, and adaptive M3 tuning.

## Acceptance Criteria
1. Each direction has a documented fixed memory ceiling independent of peer-advertised lengths and maximum concurrent-flow count. 2. Partial reads and writes, EAGAIN or equivalent, SSH window exhaustion, and slow peers suspend work without busy spin, loss, duplication, reordering, or unbounded buffering. 3. Read loops enforce byte or time fairness budgets so one flow cannot starve lifecycle, DNS, or other flows. 4. Cancellation wakes both pumps and releases buffers once without waiting for a permanently unwritable peer. 5. Deterministic tests transfer randomized bidirectional byte sequences under fragmented reads, partial writes, alternating pressure, and cancellation with exact hashes and resource baselines.
