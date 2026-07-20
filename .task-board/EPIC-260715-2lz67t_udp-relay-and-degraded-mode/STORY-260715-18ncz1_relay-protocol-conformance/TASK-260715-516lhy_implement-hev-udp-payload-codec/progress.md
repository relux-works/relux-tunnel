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
- TASK-260715-1loqwb
- TASK-260715-3xpc6b

## Checklist
- [ ] Verify byte-exact IPv4 IPv6 and domain vectors against HEV framing
- [ ] Test inconsistent inner and outer lengths before allocation or slicing
- [ ] Preserve response source endpoints and privacy-safe diagnostics

## Notes
TASK-260715-18owh7 decision ready for review: MSGLEN ceiling = fixed v1 constant 1472 (HEV UDP_BUF_SIZE 1500 reply bound: addrlen+datlen<=1500 is HEV-stream-fatal on overflow; worst IPv6 19+1472=1491). Violation (MSGLEN>1472) is association-fatal; policy (localCap<MSGLEN<=1472) is a drop. Swift adapter discards oversized HEV-ingress records with bounded skip + hevOversizedInbound counter, never frames them. Decision §4.2/§4.4.

## Precondition Resources
- [TASK-260715-516lhy_relay-binding-input.md](file://TASK-260715-516lhy/TASK-260715-516lhy_relay-binding-input.md) — Frozen TASK-260715-111tde relay binding decision; consume the task-specific artifact and validation map

## Outcome Resources
(none)
