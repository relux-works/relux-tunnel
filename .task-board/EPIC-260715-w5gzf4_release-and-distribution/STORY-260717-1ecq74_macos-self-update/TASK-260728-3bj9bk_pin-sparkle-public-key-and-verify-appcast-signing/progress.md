## Status
backlog

## Review
required

## Task Class
code

## Estimate
estimated(fibonacci(3))

## Blocked By
- TASK-260717-ziprhs
- TASK-260717-xempiv
- TASK-260717-1mt4e7

## Blocks
- TASK-260715-1njthi
- TASK-260717-a8uhro

## Checklist
(empty)

## Notes
GAP JUSTIFICATION (created 2026-07-28 by TASK-260728-3a2dnr).
Spec requirement it serves: ADR-018 (EdDSA-signed payloads plus a signed appcast with pre-extraction verification) and ADR-026.
The gap: TASK-260717-ziprhs conflated a dependency-free key ceremony with integration work that depends on the generated macOS target and the appcast pipeline. Because ziprhs had no blockers, accepting it at the ceremony would have made downstream self-update signing look complete while SUPublicEDKey was unpinned and no appcast had ever been verified. No existing element owned the integration half with correct ordering.
Out-of-scope check before creation: reviewed all six tasks under STORY-260717-1ecq74. xempiv integrates the updater but does not pin the key; 1mt4e7 builds the appcast pipeline but explicitly defers the key ceremony; a8uhro tests integrity but presumes a pinned key. No duplicate created.
Independent review focus item 3 required exactly this split.

## Precondition Resources
(none)

## Outcome Resources
(none)

## Created
2026-07-28T01:14:44Z

## Last Update
2026-07-28T01:29:50Z
