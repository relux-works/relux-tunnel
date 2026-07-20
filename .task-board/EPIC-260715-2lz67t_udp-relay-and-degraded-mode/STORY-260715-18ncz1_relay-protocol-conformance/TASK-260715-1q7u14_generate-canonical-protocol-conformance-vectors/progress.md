## Status
backlog

## Assigned To
(none)

## Created
2026-07-15T01:43:57Z

## Last Update
2026-07-20T11:53:45Z

## Blocked By
- TASK-260715-1y1g1u
- TASK-260715-89h7cw
- TASK-260715-516lhy
- TASK-260715-1jvgcn

## Blocks
- TASK-260715-297gq6

## Checklist
- [ ] Cover every message address type boundary and failure-scope branch
- [ ] Audit vector bytes independently from production codecs
- [ ] Attach corpus provenance format and deterministic regeneration evidence

## Notes
TASK-260715-18owh7 decision ready for review: add boundary vectors — MSGLEN 1472 accept / 1473 violation(association-fatal); frame body 1733 accept / 1734 reject at floor maxFrame 2048; hello maxFrame 2047 reject / 2048 accept / 65536 accept / 65537 reject. Limits metadata must reference schema constants (2azda7), never literal copies. Decision §6.

## Precondition Resources
- [TASK-260715-1q7u14_relay-binding-input.md](file://TASK-260715-1q7u14/TASK-260715-1q7u14_relay-binding-input.md) — Frozen TASK-260715-111tde relay binding decision; consume the task-specific artifact and validation map

## Outcome Resources
(none)
