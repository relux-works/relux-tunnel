## Status
blocked

## Assigned To
(none)

## Created
2026-07-15T01:16:19Z

## Last Update
2026-07-28T01:23:08Z

## Blocked By
- TASK-260715-3lab1f
- TASK-260715-3f4rhy
- TASK-260715-336ljl
- TASK-260715-1gvdtz
- TASK-260717-1dsqnj

## Blocks
- TASK-260715-2qr5aj

## Checklist
- [ ] Execute the full lifecycle matrix on a named physical iPhone
- [ ] Capture UI-termination continuity repeated-cycle and cleanup evidence
- [ ] Attach task-scoped runbook environment and redacted results

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
