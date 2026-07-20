## Status
backlog

## Assigned To
(none)

## Created
2026-07-15T01:43:57Z

## Last Update
2026-07-20T11:53:16Z

## Blocked By
- TASK-260715-2azda7

## Blocks
- TASK-260715-1jvgcn
- TASK-260715-1q7u14
- TASK-260715-297gq6
- TASK-260715-2ywde4
- TASK-260715-159pcp

## Checklist
- [ ] Implement and test the hello state machine in both peers
- [ ] Prove every version status limit timeout and cancellation failure mapping
- [ ] Record negotiated feature and frame summaries without remote-controlled text

## Notes
TASK-260715-18owh7 decision ready for review: maxFrame accept range [2048,65536], default advertise 4096, effective=min(client,server,local hard cap) clamped before any body-sized allocation; out-of-range -> server status 0x0002, client unreasonableMaxFrame close, no downgrade guess. Build RelayEffectiveLimits snapshot (fields in decision §4.6) at handshake completion. Floor rationale: max legal v1 frame body = 6+255+1472 = 1733 <= 2048, so every accepted hello carries every legal frame.

## Precondition Resources
- [TASK-260715-1y1g1u_relay-binding-input.md](file://TASK-260715-1y1g1u/TASK-260715-1y1g1u_relay-binding-input.md) — Frozen TASK-260715-111tde relay binding decision; consume the task-specific artifact and validation map

## Outcome Resources
(none)
