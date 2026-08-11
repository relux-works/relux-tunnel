## Status
backlog

## Assigned To
(none)

## Created
2026-07-15T00:46:59Z

## Last Update
2026-08-11T21:24:50Z

## Blocked By
- STORY-260715-l2i2oo

## Blocks
- STORY-260715-2indo6
- STORY-260715-1zzt0c
- STORY-260715-tx1tbz
- STORY-260715-2etfkl
- STORY-260716-d37sts
- STORY-260715-18ncz1
- STORY-260715-1y04r0
- STORY-260715-2bfjhn

## Checklist
(empty)

## Notes
M0 SSH-ENGINE COMPARATIVE FINDING (orchestrator, 2026-07-20): Both engines fail the public client-rekey gate (audit-predicted). RESOLVED DIFFERENTLY: (NIOSSH) forked _rekey()+window+signer+keepalive+algo (nzdzv3, 34d4du) but the adapter (1af33i) STILL hit two unresolved mismatches — frame-delivery vs consumer-driven receive credit, and neutral fakeable byte-seam vs NIOSSH channel/socket ownership — needing a contract-seam revision + more fork; DEFERRED. (libssh2) composes cleanly with the neutral byte-seam (custom send/recv callbacks), consumer-driven credit (public window API), and external signer; its ONLY gap is client-rekey, resolvable by ONE bounded fork exporting the existing ssh2_kex_exchange (TASK-260720-3vwls7). NET: strong architecture evidence favoring libssh2 as the engine. This does NOT make the selection (TASK-260715-1gjxer, P0-gated); it records the comparative cost for that gated decision. Building the libssh2 candidate now; NIOSSH 1af33i stays deferred as viability evidence.

## Precondition Resources
(none)

## Outcome Resources
(none)
