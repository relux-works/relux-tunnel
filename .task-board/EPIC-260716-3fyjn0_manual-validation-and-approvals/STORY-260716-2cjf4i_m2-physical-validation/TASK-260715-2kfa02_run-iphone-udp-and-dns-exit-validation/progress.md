## Status
blocked

## Assigned To
(none)

## Created
2026-07-15T01:44:42Z

## Last Update
2026-07-28T01:23:09Z

## Blocked By
- TASK-260715-1ut6ot
- TASK-260715-cqm7m5
- TASK-260715-mocqmr

## Blocks
- TASK-260715-3nkhry

## Checklist
- [ ] Run representative IPv4 IPv6 domain UDP and DNS rows on a named iPhone
- [ ] Capture exit-host egress and zero ordinary physical DNS or UDP fallback
- [ ] Attach device revision limit memory pressure and cleanup evidence

## Notes
DEFERRED 2026-07-28 by TASK-260728-3a2dnr under ADR-024 + ADR-027.
Constraint: iOS is deferred; the prototype physical target is macOS-only on the current Apple-silicon Mac. This element is iOS/iPhone-specific and cannot be satisfied on the approved path.
Evidence: ADR-024 in .spec/decisions.md; owner decision record TASK-260728-3a2dnr_owner-decisions-and-local-readiness.md.
Why blocked and not backlog: its blockers are macOS work, so once that macOS work completes a serial scheduler would make this element eligible and an agent would have to either fake iPhone evidence or stop. Blocking it now makes the deferral explicit and keeps the contract, links, and evidence intact.
Exact input needed to resume: an owner decision to start the iOS branch plus provisioned iPhone hardware and profiles.

## Precondition Resources
- [TASK-260715-2kfa02_m1-iphone-baseline.md](file://TASK-260715-2kfa02/TASK-260715-2kfa02_m1-iphone-baseline.md) — Physical iPhone M1 routing and leak baseline prerequisite

## Outcome Resources
(none)
