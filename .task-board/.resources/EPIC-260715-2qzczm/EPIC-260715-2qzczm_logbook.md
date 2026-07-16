# M3 decomposition logbook

Date: 2026-07-15
Role: solution architect
Scope: board-only planning

## Findings

1. Existing M0, M1, and M2 work already owns SSH engine selection, packet-plane acceptance, authenticated bootstrap, compatible route and safe-DNS startup, relay resource limits, and full or degraded capability state. The M3 tasks consume those concrete gates rather than reopening them.
2. The critical M3 dependency order is lane pool, then channel windows and memory, then reconnect, then QUIC and route modes, then NAT64 and lifecycle validation, then untuned baseline and evidence-led tuning.
3. Memory is a cross-layer ledger. Packet buffers, HEV sessions, SSH windows and queues, DNS and relay state, lanes, and reconnect overlap must be measured and reserved together.
4. Reconnect owns a generic generation-scoped endpoint and settings transaction. Route-mode work owns compatible or fail-closed builder composition and lifecycle policy. This ownership removed an otherwise reciprocal story dependency.
5. Auto QUIC thresholds, MTU, socket buffers, batches, session ceilings, lane counts, windows, rekey thresholds, watermarks, backoff, and sampling cadence are intentionally unresolved until named-device evidence exists.
6. HEV remains unmodified by default. TASK-260715-3mnqn8 decides the Instruments gate. TASK-260715-yjpk5a is a conditional blocked implementation path and is closed without code when the gate is negative.
7. Physical platform claims remain scoped to named iPhone and Mac hardware and OS versions. Red and unavailable rows are preserved and create regression or follow-up work rather than being waived.

## Dependency anomaly and resolution

The first dependency draft made the reconnect story consume the fail-closed builder while route-mode lifecycle consumed reconnect. Task ordering was acyclic, but parent escalation produced reciprocal story blocking. The redundant reconnect-to-builder edge was removed. Reconnect now exposes and consumes a generic settings transaction, and route-mode integration composes the selected builder after that transaction seam exists.

## Review-handoff status anomaly and resolution

The first epic to-review mutation was rejected because exact child task prerequisites had auto-escalated unfinished M0, M1, and M2 epics onto the M3 epic. Those dependencies correctly block implementation, but they also prevented review of the board-only decomposition artifact.

Resolution:

- Every concrete upstream task-to-task dependency remains linked.
- Story-level execution blockers remain visible.
- Only the three derived epic-to-epic summary edges were removed.
- Representative lane, memory, and reconnect tasks still report isBlocked until their exact prerequisites are done or closed.
- task-board validate reports no issue after the normalization.
- The epic can now express the solution-architect review handoff independently of future implementation readiness.

## Safety invariants retained

- No live flow migration.
- No broad SSH endpoint exclusions.
- No ordinary physical DNS fallback.
- No silent long-timeout UDP/443 blocking.
- No unbounded packet, channel, DNS, relay, or reconnect side queues.
- No jetsam-dependent pressure policy.
- No HEV fork without material before-and-after evidence.
- No absolute kill-switch claim beyond Apple platform guarantees.
