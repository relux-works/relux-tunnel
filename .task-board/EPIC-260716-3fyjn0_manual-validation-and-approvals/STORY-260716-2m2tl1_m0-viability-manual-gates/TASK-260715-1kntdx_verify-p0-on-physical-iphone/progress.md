## Status
blocked

## Assigned To
(none)

## Created
2026-07-15T00:58:02Z

## Last Update
2026-07-28T01:20:31Z

## Blocked By
- TASK-260715-1jckn0

## Blocks
- (none)

## Checklist
- [ ] The physical iPhone passes configuration, launch, message, and stop checks
- [ ] Lifecycle-loop and reinstall evidence contains no unexplained failure
- [ ] The redacted runbook and result bundle are attached

## Notes
DEFERRED 2026-07-28 by TASK-260728-3a2dnr under ADR-024 + ADR-027.
Constraint: iOS is deferred for this goal. Physical P0 and the prototype target are macOS-only on the current Apple-silicon Mac.
Evidence: ADR-024 in .spec/decisions.md; owner decision record TASK-260728-3a2dnr_owner-decisions-and-local-readiness.md.
Why blocked and not backlog: after the obsolete iOS coupling edges were removed this task became schedulable and a serial scheduler would have pulled deferred iOS work onto the macOS prototype path. Blocking it seals the branch while preserving its contract, links, and evidence unchanged.
Exact input needed to resume: an owner decision to start the iOS branch, which also re-arms Gate A0 and the physical-iPhone rows.

## Precondition Resources
(none)

## Outcome Resources
(none)
