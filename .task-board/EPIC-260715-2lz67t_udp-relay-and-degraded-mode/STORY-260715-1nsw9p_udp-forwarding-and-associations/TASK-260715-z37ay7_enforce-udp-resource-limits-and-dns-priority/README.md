# Enforce negotiated UDP resource limits, fairness, and DNS priority

## Description
Apply the approved protocol-limit decision across client and relay admission, buffers, sockets, timers, datagram work, domain resolution, and diagnostics so nominal traffic remains fair and hostile pressure stays within the extension and exit-host budgets.

## Scope
In scope: consume TASK-260715-18owh7; local hard caps and peer-advertised values where approved; effective max frame, UDP datagram, associations, sockets, total and per-association queued bytes, pending resolution, timers, and idle timeout; per-turn frame, datagram, byte, and time budgets; DNS latency class; control precedence; drop and refusal policy; memory accounting; capability diagnostics. Out of scope: selecting wire format, general SSH channel windows, M3 memory-pressure state machine, automatic device-specific tuning, splitting datagrams, reliable UDP retransmission, and destination-level metrics.

## Acceptance Criteria
1. One immutable session limit snapshot derives every effective value from approved fixed or exchanged inputs and never exceeds either peer or process hard ceiling. 2. Admission and enqueue paths reserve or reject atomically before association, socket, timer, frame, resolution, or byte budgets are exceeded and release reservations once on every terminal path. 3. Scheduling gives health and close control precedence and bounded DNS latency priority while guaranteeing finite progress for admitted general UDP under unsaturated conditions. 4. Saturation, oversize, exhaustion, receiver stall, and memory-pressure inputs produce documented drops or fast errors with reason-specific aggregate counters and no unbounded retry or hidden side buffer. 5. Deterministic pressure tests reconcile configured limits with maximum observed associations, descriptors, timers, queued bytes, frames, resolutions, work per turn, drops, and post-cleanup baseline on client and relay.
