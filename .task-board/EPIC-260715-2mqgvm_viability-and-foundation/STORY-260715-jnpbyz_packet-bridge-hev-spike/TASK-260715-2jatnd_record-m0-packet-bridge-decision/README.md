# Record the M0 packet-bridge and HEV decision

## Description
Consolidate implementation, deterministic tests, fuzzing, physical MTU, pressure, lifecycle, and memory evidence into the M0 Bridge gate decision, including initial configuration and the measured fork-versus-upstream disposition.

## Scope
In scope: public-API compliance; correctness; selected MTU, socket buffers, batch budgets, and session baseline; error and drop behavior; physical-device memory headroom; known gaps; upstream pin; notice status; fork decision; revalidation triggers; downstream M1 readiness. Out of scope: SSH or relay gate claims, production route and DNS approval, future performance guarantees, and authorizing a fork without Instruments evidence.

## Acceptance Criteria
1. A TASK-ID-scoped ADR links every required M0 Bridge row to reproducible evidence and marks pass, fail, or blocked without averaging away a red platform or address-family result. 2. The record selects initial MTU, requested socket buffers, batch count and time budgets, HEV settings, and measured session ceiling with rationale. 3. Pass requires public API only, correct IPv4 and IPv6 framing, bounded backpressure, clean lifecycle, no nominal unexplained loss, and physical-device memory headroom. 4. A fork is rejected by default and allowed only when Instruments identifies bridge copies or syscalls as a material bottleneck and a measured callback prototype improves it with regression coverage and rebase plan. 5. Residual risks, device and OS revalidation triggers, notices, and tasks unblocked for M1 are explicit.
