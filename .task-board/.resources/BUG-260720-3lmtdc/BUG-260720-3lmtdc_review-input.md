# BUG-260720-3lmtdc validation results

## Change

- Added `ADR-021` to `.spec/decisions.md` immediately after `ADR-020`.
- Copied the reviewer-approved wording from `TASK-260715-18owh7_decision.md` without altering any policy value.
- Preserved provenance as `TASK-260715-18owh7`.

## Provenance checks

- `TASK-260715-18owh7` board status: `done`, with reviewer verdict `accepted`.
- Accepted bug attachment is byte-identical to the canonical decision outcome resource (`cmp` passed).
- The normalized proposed row in decision section 8 is byte-identical to the destination table row (`diff -u` passed).
- ADR IDs are unique and sequential from `ADR-001` through `ADR-021` (`awk` check passed).

## Validation evidence

- `task-board validate`: `Board is valid. No issues found.`
- CI-equivalent required `.spec/*.md` presence check: `all required specs present`.
- `git diff --check`: passed.
- Targeted zero-context diff: exactly one added row in `.spec/decisions.md`.

No executable behavior changed, so no unit test or product build was applicable; the repository's board/spec validation is the relevant validation gate for this task.
