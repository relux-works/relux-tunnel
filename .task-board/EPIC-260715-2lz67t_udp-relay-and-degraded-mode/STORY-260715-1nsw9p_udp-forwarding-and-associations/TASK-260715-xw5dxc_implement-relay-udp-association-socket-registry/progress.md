## Status
backlog

## Assigned To
(none)

## Created
2026-07-15T01:44:42Z

## Last Update
2026-07-20T18:42:16Z

## Blocked By
- TASK-260715-1jvgcn
- TASK-260715-18owh7

## Blocks
- TASK-260715-3xpc6b
- TASK-260715-z37ay7

## Checklist
- [ ] Implement bounded association socket timer and generation ownership
- [ ] Test duplicate exhaustion expiry crossed-close and session cleanup races
- [ ] Prove rootless nonblocking descriptors and no public relay listener

## Notes
TASK-260715-18owh7 decision ready for review: relay maxAssociations 256 [1,1024] checked before socket/state creation (0x0004 on excess, no state admitted); relay idle 120s (RFC 4787 REQ-5 floor): 0x0009 when safe -> retire -> CLOSE_ASSOCIATION. Reply recv into localMaxUDPPayload+1 buffer, oversize = silent counted drop. Per-association socket-buffer sizing stays relay-local config, out of protocol scope. Decision §4.3/§4.4.

## Precondition Resources
- [TASK-260715-xw5dxc_relay-binding-input.md](file://TASK-260715-xw5dxc/TASK-260715-xw5dxc_relay-binding-input.md) — Frozen TASK-260715-111tde relay binding decision; consume the task-specific artifact and validation map
- [TASK-260715-xw5dxc_protocol-v1-developer-contract.md](file://TASK-260715-xw5dxc/TASK-260715-xw5dxc_protocol-v1-developer-contract.md) — Accepted relay protocol v1 developer contract and compatibility gates from TASK-260715-2z9b4a

## Outcome Resources
(none)
