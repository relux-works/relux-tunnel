# Implement rekey lane isolation and bounded recovery

## Description
Integrate rekey outcomes with the lane pool so a failed key exchange disables only the affected lane first, deterministically fails its channels, updates capabilities when lane A is affected, and requests an admitted replacement without flow migration.

## Scope
In scope: rekey start and finish lane state; scheduler eligibility; success resume; timeout, protocol, socket, server-close, and cancellation failure; channel failure semantics; lane-A relay and DNS implications; optional-lane replacement request; memory and server admission; retry class; duplicate and stale event handling; aggregate reasons. Out of scope: performing key exchange, path selection, route mutation, preserving channels after transport loss, infinite retry, host-key auto-accept, or tuning thresholds.

## Acceptance Criteria
1. Rekey start makes only the current lane unavailable to new assignment before the exchange begins and success restores eligibility without changing existing flow assignment. 2. Rekey failure marks only that lane failed first, closes or fails its channels exactly once, and never replays or migrates bytes. 3. Lane-A failure invalidates current relay or control capability before any degraded snapshot and remains degraded only when the safe-DNS and mandatory base predicates are true. 4. Replacement requests obey lane, server, and memory admission and terminal authentication or host-identity causes never loop. 5. Fault tests cover each failure stage, simultaneous lane rekeys, lane-A plus relay or DNS events, stop, replacement denial, late success, repeated recovery, snapshot order, and resource baselines.
