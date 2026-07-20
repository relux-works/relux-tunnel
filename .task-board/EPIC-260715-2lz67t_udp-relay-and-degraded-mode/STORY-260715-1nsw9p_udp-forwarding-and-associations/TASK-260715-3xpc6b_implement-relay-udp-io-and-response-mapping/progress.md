## Status
backlog

## Assigned To
(none)

## Created
2026-07-15T01:44:42Z

## Last Update
2026-07-20T18:42:16Z

## Blocked By
- TASK-260715-xw5dxc
- TASK-260715-516lhy

## Blocks
- TASK-260715-28jdml
- TASK-260715-z37ay7
- TASK-260715-1ut6ot

## Checklist
- [ ] Send and receive byte-exact IPv4 IPv6 and bounded-domain datagrams
- [ ] Map oversize resolution socket pressure and cancellation outcomes deterministically
- [ ] Prove fair event-loop budgets source-endpoint preservation and log privacy

## Notes
TASK-260715-18owh7 decision ready for review: §4.4 numbered order is the normative pre-socket sequence — prefix/frameLength -> type/direction -> association admission (0x0004) -> HEV structural -> MSGLEN 1472/local cap (0x0005 violation-vs-policy) -> resolver-form rules -> queue credit (0x0006) -> only then socket/resolver. Decision resource TASK-260715-18owh7_decision.md.

## Precondition Resources
- [TASK-260715-3xpc6b_protocol-v1-developer-contract.md](file://TASK-260715-3xpc6b/TASK-260715-3xpc6b_protocol-v1-developer-contract.md) — Accepted relay protocol v1 developer contract and compatibility gates from TASK-260715-2z9b4a

## Outcome Resources
(none)
