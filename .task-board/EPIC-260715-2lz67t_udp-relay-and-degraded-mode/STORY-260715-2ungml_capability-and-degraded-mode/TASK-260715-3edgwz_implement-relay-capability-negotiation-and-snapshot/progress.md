## Status
backlog

## Assigned To
(none)

## Created
2026-07-15T01:45:00Z

## Last Update
2026-07-20T18:42:16Z

## Blocked By
- TASK-260715-30lv40
- TASK-260715-159pcp
- TASK-260715-9h7pf8
- TASK-260715-18owh7

## Blocks
- TASK-260715-ak0s72
- TASK-260715-1vg1mb
- TASK-260715-3gv53h
- TASK-260715-kq7vqf

## Checklist
- [ ] Publish versioned full degraded and failed snapshots from exact readiness predicates
- [ ] Serialize relay identity features limits health and reasons without sensitive data
- [ ] Test every input combination message version and stale-generation ordering

## Notes
TASK-260715-18owh7 decision ready for review: version RelayEffectiveLimits into the capability snapshot — effectiveMaxFrame u32, maxUDPPayload u16, maxAssociations u32, perAssociationQueuedBytes u32, aggregateQueuedBytes u32, controlReservedBytes u32, dnsPriorityWeight u8, idleTimeoutMilliseconds u32. One immutable snapshot per session generation, derived at handshake completion; local-only, never serialized to the peer in M0. Decision §4.6.

## Precondition Resources
- [TASK-260715-3edgwz_m1-snapshot-handoff.md](file://TASK-260715-3edgwz/TASK-260715-3edgwz_m1-snapshot-handoff.md) — M1 versioned model and diagnostics prerequisites for M2 snapshots
- [TASK-260715-3edgwz_relay-binding-input.md](file://TASK-260715-3edgwz/TASK-260715-3edgwz_relay-binding-input.md) — Frozen TASK-260715-111tde relay binding decision; consume the task-specific artifact and validation map
- [TASK-260715-3edgwz_protocol-v1-developer-contract.md](file://TASK-260715-3edgwz/TASK-260715-3edgwz_protocol-v1-developer-contract.md) — Accepted relay protocol v1 developer contract and compatibility gates from TASK-260715-2z9b4a

## Outcome Resources
(none)
