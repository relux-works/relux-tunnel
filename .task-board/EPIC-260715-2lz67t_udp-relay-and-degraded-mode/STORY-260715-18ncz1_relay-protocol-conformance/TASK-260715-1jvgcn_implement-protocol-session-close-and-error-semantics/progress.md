## Status
backlog

## Assigned To
(none)

## Created
2026-07-15T01:43:57Z

## Last Update
2026-07-20T11:53:31Z

## Blocked By
- TASK-260715-1y1g1u
- TASK-260715-89h7cw
- TASK-260715-516lhy

## Blocks
- TASK-260715-1q7u14
- TASK-260715-297gq6
- TASK-260715-2ywde4
- TASK-260715-159pcp
- TASK-260715-9h7pf8
- TASK-260715-22gz6h
- TASK-260715-xw5dxc
- TASK-260715-3e30tx

## Checklist
- [ ] Implement the message direction and failure-scope transition table in both peers
- [ ] Test duplicate crossed abrupt and late close sequences
- [ ] Constrain remote errors and health payloads to privacy-safe bounded forms

## Notes
TASK-260715-18owh7 decision ready for review: 0x0005 has two dispositions — violation (MSGLEN>1472): 0x0005 + CLOSE_ASSOCIATION; policy (local lowered cap): 0x0005 drop only. 0x0006 is edge-triggered: at most one per association per saturation episode, episode ends at <=50% per-assoc queue drain; drops always counted. Idle: relay 0x0009 when safe -> retire -> CLOSE_ASSOCIATION (120s); client closes first at 60s by design. Decision §4.2-§4.4.

## Precondition Resources
- [TASK-260715-1jvgcn_relay-binding-input.md](file://TASK-260715-1jvgcn/TASK-260715-1jvgcn_relay-binding-input.md) — Frozen TASK-260715-111tde relay binding decision; consume the task-specific artifact and validation map

## Outcome Resources
(none)
