# Record the M0 SSH engine selection

## Description
Select the production SSH engine only from audited build, conformance, functional, compatibility, rekey, scale, lifecycle, and memory evidence. Document the rejected candidate and maintenance obligations without weakening a failed gate.

## Scope
In scope: every M0 SSH gate; candidate versions; Apple integration; host verification; auth and algorithm support; direct-tcpip; exec; windows; rekey; backpressure; cancellation; compatibility; scale; memory; lifecycle; security and license posture; fork and upstream strategy; residual risks; revalidation triggers; downstream readiness. Out of scope: implementing lane scheduling, relay protocol, profile UX, SFTP, ProxyJump, release approval, and selecting a candidate with a waived mandatory gate.

## Acceptance Criteria
1. A TASK-ID-scoped ADR maps every required gate to row-level evidence for both candidates and marks pass, fail, or not run with reason. 2. The selected engine passes every mandatory gate, including Apple targets, pre-auth host evidence, approved auth, hundreds of direct channels, long-lived exec, configurable windows, client and server rekey, real relux compatibility, extension memory, and leak-free lifecycle. 3. A red preferred candidate routes selection to the alternate or returns the story to analysis; no threshold is weakened after results are known. 4. The ADR records exact dependency pins, adapter boundary, approved algorithms, initial window and rekey policy ranges, license notices, security monitoring, and fork or upstream-rebase owner. 5. Rejected evidence, residual risks, device and server revalidation triggers, and downstream tasks unblocked for M1 and M2 are explicit.
