# Enforce ordered pressure actions and reconnect-overlap reservations

## Description
Implement the centralized pressure-policy executor and reservation service that applies the declared soft, pressure, and critical actions once per current generation and prevents old and replacement transports from exceeding the explicit reconnect memory ceiling.

## Scope
In scope: lane opening suppression; idle channel close requests; smaller new-channel window cap; cache shrink; WINDOW_ADJUST withholding; HEV session and cache limit reduction; nonessential-flow fast refusal; replacement transport reservation; critical old-transport release; explicit provider failure when recovery is impossible; idempotent acknowledgements; rollback on recovery where safe; cancellation; action metrics. Out of scope: measuring memory, implementing each consumer internals, killing arbitrary user flows outside policy, relying on jetsam, changing routes, tuning thresholds, or silently leaking refused traffic.

## Acceptance Criteria
1. Each soft, pressure, and critical transition produces the exact ordered idempotent action set from the contract and records consumer acknowledgement, timeout, failure, and released bytes. 2. Optional lane admission, new windows, HEV sessions, caches, and nonessential flows cannot exceed current policy ceilings even when callbacks race or a consumer is unavailable. 3. A replacement transport can start only after a ledger reservation fits the overlap ceiling, and critical state releases the old transport before replacement or returns an explicit terminal failure. 4. Recovery restores only reversible limits in documented order and never recreates closed flows, channels, associations, or stale generations. 5. Integration and fault tests inject every state during lane open, rekey, relay load, DNS load, reconnect reservation, stop, and stale callback and reconcile requested, acknowledged, released, refused, and remaining resources.
