## Status
blocked

## Assigned To
(none)

## Created
2026-07-15T02:37:49Z

## Last Update
2026-07-28T01:23:07Z

## Blocked By
- TASK-260715-3btpxm
- TASK-260715-1y5r8p
- TASK-260715-1idq8c

## Blocks
- TASK-260715-2yywzw

## Checklist
- [ ] Deliver the stated scope while preserving every explicit non-scope boundary
- [ ] Verify every acceptance criterion with the specified automated or manual evidence
- [ ] Attach a TASK-260715-3ix830-scoped redacted outcome with commands artifacts and residual risks

## Notes
DEFERRED 2026-07-28 by TASK-260728-3a2dnr under ADR-024 + ADR-027.
Constraint: iOS is deferred; the prototype physical target is macOS-only on the current Apple-silicon Mac. This element is iOS/iPhone-specific and cannot be satisfied on the approved path.
Evidence: ADR-024 in .spec/decisions.md; owner decision record TASK-260728-3a2dnr_owner-decisions-and-local-readiness.md.
Why blocked and not backlog: its blockers are macOS work, so once that macOS work completes a serial scheduler would make this element eligible and an agent would have to either fake iPhone evidence or stop. Blocking it now makes the deferral explicit and keeps the contract, links, and evidence intact.
Exact input needed to resume: an owner decision to start the iOS branch plus provisioned iPhone hardware and profiles.

## Precondition Resources
(none)

## Outcome Resources
(none)
