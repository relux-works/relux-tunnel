## Status
backlog

## Assigned To
(none)

## Created
2026-07-15T01:43:57Z

## Last Update
2026-07-20T11:53:31Z

## Blocked By
- TASK-260715-2azda7

## Blocks
- TASK-260715-1jvgcn
- TASK-260715-1q7u14
- TASK-260715-297gq6
- TASK-260715-2ywde4
- TASK-260715-159pcp
- TASK-260715-3e30tx

## Checklist
- [ ] Cover every prefix and body split plus coalesced frame sequences
- [ ] Prove negotiated allocation ceilings before reading attacker-sized bodies
- [ ] Compile and run equivalent codec cases in Swift and relay targets

## Notes
TASK-260715-18owh7 decision ready for review: frameLength in [6, effectiveMaxFrame] with local hard-cap clamp before allocation; max legal v1 frame body 1733 (6 + HDRLEN 255 + MSGLEN 1472); maxFrame hard ceiling 65536 bounds worst per-frame allocation. See resource TASK-260715-18owh7_decision.md §4.1/§4.4.

## Precondition Resources
- [TASK-260715-89h7cw_relay-binding-input.md](file://TASK-260715-89h7cw/TASK-260715-89h7cw_relay-binding-input.md) — Frozen TASK-260715-111tde relay binding decision; consume the task-specific artifact and validation map

## Outcome Resources
(none)
