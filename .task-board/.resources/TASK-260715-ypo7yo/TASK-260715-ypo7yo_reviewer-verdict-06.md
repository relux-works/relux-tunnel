# TASK-260715-ypo7yo — independent architecture review verdict 06

Verdict: **CHANGES REQUESTED**.
Review route: **analysis**.
Reviewed 2026-07-28 as reviewer. No portal mutation is authorized by this
verdict.

Revision `2026-07-28.r6` closes verdict 05's two findings. The four production
identifiers and reciprocal containment, probe justification, least-privilege
target rows, signing-channel/profile rules, Team/App-ID-prefix handling,
environment rules, legacy no-repurposing rule, and downstream portal mutation
task are otherwise acceptable. One live authorization-contract inconsistency
remains.

## Blocking finding F1 — Ceremony C1 names a rejected, superseded matrix revision

The authoritative JSON says:

```text
revision = 2026-07-28.r6
supersedes = 2026-07-28.r5
humanAuthorizationNode = TASK-260728-q5kjta
```

But the live scope of `TASK-260728-q5kjta` says the operator authorizes the
macOS entries in the approved matrix **revision `2026-07-28.r5`**. Revision r5
received verdict 05 `CHANGES REQUESTED`; it was never the independently accepted
matrix required by AC5. Revision r6 is the current candidate.

Independent freshness gate:

```sh
task-board q 'get(TASK-260728-q5kjta) { scope }' |
  jq -e --arg revision \
    "$(jq -r .revision TASK-260715-ypo7yo_apple-identifier-entitlement-matrix.json)" \
    '.scope | contains($revision)'
```

Output: `false`. Exit code: **1**.

The exact four App IDs, Network Extensions-only capability set, four Mac
Development profiles, App Group/Keychain negatives, iOS exclusion, and legacy
exclusion in the C1 board record do match r6 today. That does not make the stale
revision harmless: C1 is the human authorization node named by AC5 and by the
matrix itself. It currently asks the operator to approve a revision that was
rejected, while the r6 gate added for verdict 05 checks only
`TASK-260715-3jloqy`, the unattended portal consumer. A future contract-only
revision could drift in the same unguarded edge.

This is autonomous metadata/contract rework, not a human decision and not a
Stop-The-Line condition.

### Required rework

1. Update `TASK-260728-q5kjta` so its scope authorizes the current authoritative
   matrix revision `2026-07-28.r6` (or a machine-resolved immutable matrix
   resource digest plus revision), without changing the already-correct exact
   mutation set.
2. Extend the board-contract gate to check both live consumers named by the
   matrix: the authorization node `TASK-260728-q5kjta` and the portal mutation
   task `TASK-260715-3jloqy`. The authorization-node check must require the
   current revision and the exact `c1AuthorizationScope`.
3. Add a negative gate that restores a superseded revision in the C1 board
   contract and fails.
4. Correct the rationale's one stale harness reference
   `TASK-260715-ypo7yo_check-portal-consumer.sh` to the actual attached
   `TASK-260715-ypo7yo_check-portal-consumer.py`.

## Independent gates

- contract self-check: **975 checks**, exit **0**;
- parsed-object/document mutation harness: **117/117** negative gates hold,
  exit **0**;
- portal consumer gate for `TASK-260715-3jloqy`: **20 checks**, exit **0**;
- `scripts/check-legacy-preservation.sh`: exit **0**;
- `task-board validate`: exit **0**;
- `swift test`: **335 tests in 29 suites**, exit **0**;
- C1 current-revision freshness gate: **FAIL**, output `false`, exit **1**.

No diagram was needed: the containment model is explicit, reciprocal, and
machine-checked; the defect is a direct revision/authorization edge mismatch.
