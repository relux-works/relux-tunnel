# Record the M1 runtime ownership and sequencing contract

## Description
Produce the task-scoped production contract for the extension-owned M1 runtime before implementation. Specify components, injected interfaces, actor or executor ownership, startup and teardown ordering, cancellation, state transitions, failure propagation, configuration versions, and which M0 outputs are authoritative.

## Scope
In scope: ReluxTunnelCore coordinator boundary, packet bridge and HEV ownership, selected SSH adapter ownership, TCP and DNS consumers, route application handshake, app-message snapshots, concurrency domains, stop idempotency, and M2 or M3 extension seams. Out of scope: implementing the coordinator, repeating M0 engine or packet decisions, UI state design, UDP, lane scheduling, reconnect, and release packaging.

## Acceptance Criteria
1. A TASK-ID-scoped outcome defines every runtime component, owner, lifetime, dependency direction, and allowed cross-boundary call. 2. A sequence covers configuration load, SSH authentication, packet and DNS preparation, network settings, packet reads, usable-state publication, stop, and partial-start rollback. 3. A state table defines legal transitions, cancellation points, idempotency, error ownership, and when no routes may be installed. 4. Versioning and forward-compatibility rules cover configuration, commands, capabilities, diagnostics, and unknown fields or versions. 5. The contract names the exact M0 decision artifacts it consumes and keeps UDP, lanes, reconnect, and fail-closed routing behind explicit future seams.
