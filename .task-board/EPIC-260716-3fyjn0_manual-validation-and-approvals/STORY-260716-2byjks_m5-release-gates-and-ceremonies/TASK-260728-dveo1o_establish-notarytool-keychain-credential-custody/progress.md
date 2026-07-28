## Status
backlog

## Review
required

## Task Class
code

## Estimate
estimated(fibonacci(2))

## Blocked By
- TASK-260715-apc34w
- TASK-260728-q5kjta

## Blocks
- TASK-260715-3gkwn0

## Checklist
(empty)

## Notes
GAP JUSTIFICATION (created 2026-07-28 by TASK-260728-3a2dnr).
Spec requirement it serves: .spec/goal-macos-v1.md invariant "secrets only in the Keychain — never in providerConfiguration, logs, shell commands, or board resources", and ADR-025.
The gap: the owner readiness record states the notarization credential exists as a mode-0600 .p8 file. No existing board element owned bringing it into the Keychain-only form the invariant demands. TASK-260715-3gkwn0 owns the CI release environment, not local credential custody, and its AC assumes a usable credential already exists.
Out-of-scope check before creation: searched STORY-260716-2byjks and STORY-260716-2m2tl1 for an existing notarization-custody task - none. 3gkwn0 explicitly scopes out local Keychain custody. No duplicate created.
Independent review focus item 2 required exactly this resolution.
2026-07-28 replan round 3 (TASK-260728-3a2dnr): now blocked by TASK-260728-q5kjta (Ceremony C1). The interactive store-credentials run and the owner disposition decision moved into C1; this task verifies the named profile authenticates and that the stated disposition actually holds. ADR-025 Keychain-only custody is unchanged.

## Precondition Resources
(none)

## Outcome Resources
(none)

## Created
2026-07-28T01:14:19Z

## Last Update
2026-07-28T01:47:11Z
