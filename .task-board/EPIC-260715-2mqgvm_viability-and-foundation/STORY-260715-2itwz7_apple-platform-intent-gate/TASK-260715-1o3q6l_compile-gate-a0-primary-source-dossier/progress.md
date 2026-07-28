## Status
blocked

## Assigned To
(none)

## Created
2026-07-15T00:55:57Z

## Last Update
2026-07-28T01:18:35Z

## Blocked By
- (none)

## Blocks
- TASK-260715-12avq0

## Checklist
- [ ] Primary-source traceability covers every disclosed data-path behavior
- [ ] Facts and inferences are labeled and the TN3120 ambiguity is explicit
- [ ] The dated dossier is attached as a TASK-ID-scoped outcome resource

## Notes
DEFERRED 2026-07-28 by TASK-260728-3a2dnr under ADR-013 (re-scoped) + ADR-027.
Constraint: Gate A0 is an App Store / App Review release gate, not a gate for the macOS protocol prototype. The owner decision of 2026-07-28 states explicitly that Apple-policy research must not run on the prototype critical path.
Evidence: ADR-013 re-scope in .spec/decisions.md; owner decision record TASK-260728-3a2dnr_owner-decisions-and-local-readiness.md.
Why blocked and not backlog: this task has no blockers and was schedulable, so an autonomous scheduler would have pulled the whole A0 dossier chain (1o3q6l -> 12avq0 -> 1i6bh7 -> x4h9n1 -> 1828xy) onto the prototype path. Blocking the chain head seals the branch without deleting any evidence or link.
Exact input needed to resume: an owner decision to start the iOS / App Store release branch, or a macOS public-distribution claim that depends on Apple intended-use guidance.

## Precondition Resources
(none)

## Outcome Resources
(none)
