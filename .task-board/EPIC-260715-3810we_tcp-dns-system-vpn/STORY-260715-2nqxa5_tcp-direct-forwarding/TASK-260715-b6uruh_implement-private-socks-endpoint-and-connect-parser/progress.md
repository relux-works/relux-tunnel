## Status
backlog

## Assigned To
(none)

## Created
2026-07-15T01:16:47Z

## Last Update
2026-07-21T02:20:19Z

## Blocked By
- TASK-260715-1juybj
- TASK-260715-3ejhyy

## Blocks
- TASK-260715-1n9v9o
- TASK-260715-1mr9j2

## Checklist
- [ ] Implement generation-private endpoint admission and incremental CONNECT parsing
- [ ] Run valid fragmented malformed timeout sandbox and cleanup tests
- [ ] Attach task-scoped endpoint and parser evidence
- [ ] Replace SO_RCVTIMEO-only authentication with one injectable monotonic accept-to-auth deadline whose remaining budget spans all reads comparisons and replies
- [ ] Run deterministic slow-trickle wrong-credential reply-stall cancellation stale-generation slot-recovery and descriptor-cleanup rows for iOS and macOS

## Notes
Contract input: consume TASK-260715-1juybj_contract.md sections 2, 4, 6, and 10 plus its state/sequence diagrams. AC was refined to distinguish valid coalesced early payload from invalid leading bytes.

## Precondition Resources
(none)

## Outcome Resources
(none)
