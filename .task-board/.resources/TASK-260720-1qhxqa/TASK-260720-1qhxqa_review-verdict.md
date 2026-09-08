# TASK-260720-1qhxqa review verdict — CR revision 1

Verdict: CHANGES REQUESTED. Route the task to `to-dev`; do not accept
`CR-TASK-260720-1qhxqa-1` revision 1.

The review covered candidate tree
`beec5d90af9a1eda8efdab59e5bc477524a47747` against base
`b3422b05226253a17676b9b84c764071fe3dbe74`. All seven working-copy files
were byte-identical to the candidate tree. The recomputed binary patch SHA-256
was `93b90e314b54cf2e804342cab84263bc1c2f012dfe04391c94c608d2bf5f5096`,
matching the Change Request record.

## Blocking findings

1. **Fail-open normalized-binding validation (AC 2–4; negative-evidence gate).**
   `scripts/validate-m0-production-bindings.py` only requires non-empty
   `sourceOrBinaryPins` / `bindings` at lines 358–364 and accepts compatibility
   rows when their known IDs say `pass` and carry any non-empty condition at
   lines 371–382. It does not validate the exact accepted MTU, batching,
   obligations, or compatibility semantics. A production-entry-point narrowing
   mutant changed MTU `1500 -> 1501`, packet budget `64 -> 1`, the packet notice
   obligation to `no notices required`, and `M1-BOUND-VALUES.condition` to
   `unchecked`. With the real board projection and exact upstream resources,
   the validator exited 0 and emitted
   `productionCompositionPermitted=true`, zero failures. This admits values and
   obligations not authorized by the reviewer-accepted M0 outcomes. Evidence:
   attached outcomes `TASK-260720-1qhxqa_review-mutant-bindings.json`,
   `TASK-260720-1qhxqa_review-mutant-validation.json`, and
   `TASK-260720-1qhxqa_review-mutant-validation.log`.

   Required rework: make the production validator enforce the complete known
   schema and exact normalized value/obligation/trigger contract (or validate a
   deterministic canonical derivation from the accepted resources), then add a
   production-CLI negative test that narrows at least one numeric binding and
   one obligation/compatibility condition and requires exit 1 with permission
   false. A test that merely asserts the checked-in manifest's values is a
   positive fixture check, not gate coverage.

2. **Declared lint/diff gate is failing.** `git diff --check` against the exact
   CR base and candidate exits 2 because
   `docs/TASK-260720-1qhxqa_m0-production-bindings.md` lines 3 and 4 contain
   trailing whitespace. This contradicts the checked lint-clean DoD item and
   the producer handoff's claimed `git diff --check` exit 0. Evidence:
   attached outcome `TASK-260720-1qhxqa_review-diff-check.log`.

## Passing evidence retained

- All eight accepted upstream outcome/verdict resource SHA-256 values match the
  manifest. The repository manifest, owning task outcome attachment, and
  `TASK-260715-3ejhyy` sole-source precondition copy are byte-identical at
  SHA-256 `39b3428d6cf778fa6b682bb0853a177d6b85f03b8062309f0d198dcdfd49fae6`.
- `make m0-bindings-test`: exit 0, 11 tests passed.
- `make m0-bindings-check TASK_BOARD_RESOURCES="$TASK_BOARD_DIR/.resources"`:
  exit 0 for the unmodified candidate, permission true, zero failures.
- Python compile: exit 0.
- `git diff --check`: exit 2 (blocking, reported above).

Independent digest and candidate identity logs are attached as
`TASK-260720-1qhxqa_review-resource-sha256.log` and
`TASK-260720-1qhxqa_review-candidate-tree-byte-match.log`.

No repository files were changed during review. No M0 matrix, VPN lifecycle,
network setting, route, DNS, signing, installation, staging, commit, rebase,
merge, or branch switch was performed. Reviewer supplied no `commit_ack`.
