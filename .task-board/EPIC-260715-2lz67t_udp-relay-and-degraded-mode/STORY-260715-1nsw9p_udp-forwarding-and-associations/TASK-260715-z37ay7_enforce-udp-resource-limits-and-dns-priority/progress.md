## Status
backlog

## Assigned To
(none)

## Created
2026-07-15T01:44:42Z

## Last Update
2026-07-28T00:47:22Z

## Blocked By
- TASK-260715-18owh7
- TASK-260715-22gz6h
- TASK-260715-xw5dxc
- TASK-260715-3xpc6b
- TASK-260715-3e30tx
- TASK-260715-1pn983

## Blocks
- TASK-260715-1ut6ot
- TASK-260715-318m1v

## Checklist
- [ ] Derive one immutable effective limit snapshot from the approved protocol decision
- [ ] Enforce atomic reservations fairness and reason-specific pressure outcomes
- [ ] Reconcile every resource counter and observed maximum after cleanup

## Notes
TASK-260715-18owh7 decision ready for review: full §4.3 table is your input — per-assoc queued bytes client 32KiB/relay 64KiB [4KiB,256KiB]; aggregate per direction client 1MiB[..4MiB]/relay 4MiB[..16MiB]; controlReservedBytes client 16KiB/relay 64KiB; dnsPriorityWeight 4:1 WRR [1,16] starvation-free, scheduling only, no admission credit; charge max(4+frameLength,64) per queued frame, atomic reserve-before-enqueue, single release; 0x0006 edge-triggered per saturation episode (ends at <=50% drain); reply-direction oversize = silent counted drop; config outside [floor,ceiling] = fail-closed startup, no silent clamp. Decision §4.3-§4.5.

## Precondition Resources
- [TASK-260715-z37ay7_relay-binding-input.md](file://TASK-260715-z37ay7/TASK-260715-z37ay7_relay-binding-input.md) — Frozen TASK-260715-111tde relay binding decision; consume the task-specific artifact and validation map
- [TASK-260715-z37ay7_protocol-v1-developer-contract.md](file://TASK-260715-z37ay7/TASK-260715-z37ay7_protocol-v1-developer-contract.md) — Accepted relay protocol v1 developer contract and compatibility gates from TASK-260715-2z9b4a

## Outcome Resources
(none)
