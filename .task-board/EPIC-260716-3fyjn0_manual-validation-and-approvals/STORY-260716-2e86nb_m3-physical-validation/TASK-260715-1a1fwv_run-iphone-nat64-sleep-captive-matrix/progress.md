## Status
blocked

## Assigned To
(none)

## Created
2026-07-15T02:12:45Z

## Last Update
2026-07-28T01:23:08Z

## Blocked By
- TASK-260715-npvvmd
- TASK-260715-3hvz8n
- TASK-260715-gfptap
- TASK-260715-3nkhry

## Blocks
- (none)

## Checklist
- [ ] Execute every supported named iPhone network, family, lifecycle, captive, and mode row
- [ ] Verify actual endpoints, exact routes, DNS and traffic safety, memory, and cleanup
- [ ] Attach task-scoped capture and raw-reference manifest with red or unavailable rows

## Notes
DEFERRED 2026-07-28 by TASK-260728-3a2dnr under ADR-024 + ADR-027.
Constraint: iOS is deferred; the prototype physical target is macOS-only on the current Apple-silicon Mac. This element is iOS/iPhone-specific and cannot be satisfied on the approved path.
Evidence: ADR-024 in .spec/decisions.md; owner decision record TASK-260728-3a2dnr_owner-decisions-and-local-readiness.md.
Why blocked and not backlog: its blockers are macOS work, so once that macOS work completes a serial scheduler would make this element eligible and an agent would have to either fake iPhone evidence or stop. Blocking it now makes the deferral explicit and keeps the contract, links, and evidence intact.
Exact input needed to resume: an owner decision to start the iOS branch plus provisioned iPhone hardware and profiles.

## Precondition Resources
- [TASK-260715-1a1fwv_m3-evidence-protocol-v1.md](file://TASK-260715-1a1fwv/TASK-260715-1a1fwv_m3-evidence-protocol-v1.md)

## Outcome Resources
(none)
