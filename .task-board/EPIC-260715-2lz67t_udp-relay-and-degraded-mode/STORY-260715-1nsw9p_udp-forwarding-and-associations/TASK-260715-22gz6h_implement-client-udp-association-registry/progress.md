## Status
backlog

## Assigned To
(none)

## Created
2026-07-15T01:44:41Z

## Last Update
2026-07-20T18:42:15Z

## Blocked By
- TASK-260715-1jvgcn
- TASK-260715-18owh7

## Blocks
- TASK-260715-1loqwb
- TASK-260715-3e30tx
- TASK-260715-z37ay7
- TASK-260715-ak0s72

## Checklist
- [ ] Implement and test the complete association and generation state table
- [ ] Bound admission allocation search timers and wraparound behavior
- [ ] Prove ID non-reuse until terminal cleanup and stale-generation isolation

## Notes
TASK-260715-18owh7 decision ready for review: client maxAssociations 256 [1,1024] enforced locally with typed fast failure before any wire bytes; client idle GC 60s (deliberately shorter than relay 120s so client closes first — shrinks crossed-expiry reopen race; convention, not cross-peer invariant). Queue charge rule max(4+frameLength, 64) against per-assoc 32KiB + aggregate 1MiB per direction. Decision §4.3.

## Precondition Resources
- [TASK-260715-22gz6h_relay-binding-input.md](file://TASK-260715-22gz6h/TASK-260715-22gz6h_relay-binding-input.md) — Frozen TASK-260715-111tde relay binding decision; consume the task-specific artifact and validation map
- [TASK-260715-22gz6h_protocol-v1-developer-contract.md](file://TASK-260715-22gz6h/TASK-260715-22gz6h_protocol-v1-developer-contract.md) — Accepted relay protocol v1 developer contract and compatibility gates from TASK-260715-2z9b4a

## Outcome Resources
(none)
