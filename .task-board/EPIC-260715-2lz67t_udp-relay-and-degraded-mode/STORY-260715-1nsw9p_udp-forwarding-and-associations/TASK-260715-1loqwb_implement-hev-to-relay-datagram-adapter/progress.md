## Status
backlog

## Assigned To
(none)

## Created
2026-07-15T01:44:42Z

## Last Update
2026-07-20T18:42:16Z

## Blocked By
- TASK-260715-22gz6h
- TASK-260715-516lhy
- TASK-260715-1vv52g

## Blocks
- TASK-260715-28jdml
- TASK-260715-1ut6ot
- TASK-260715-uh8kk6
- TASK-260715-3hxnbt

## Checklist
- [ ] Conform to the accepted private HEV UDP-in-TCP byte and admission contract
- [ ] Test split coalesced bidirectional error close and multi-association cases
- [ ] Bound adapter buffers and prove no public proxy or destination logging

## Notes

## Precondition Resources
- [TASK-260715-1loqwb_hev-udp-handoff.md](file://TASK-260715-1loqwb/TASK-260715-1loqwb_hev-udp-handoff.md) — Accepted HEV UDP-in-TCP prerequisite for the adapter
- [TASK-260715-1loqwb_protocol-v1-developer-contract.md](file://TASK-260715-1loqwb/TASK-260715-1loqwb_protocol-v1-developer-contract.md) — Accepted relay protocol v1 developer contract and compatibility gates from TASK-260715-2z9b4a

## Outcome Resources
- [TASK-260715-1loqwb_udp-data-path.puml](file://TASK-260715-1loqwb/TASK-260715-1loqwb_udp-data-path.puml) — Planning sequence diagram for HEV datagrams, relay associations, DNS priority, and responses
