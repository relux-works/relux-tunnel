# TASK-260715-whtdsf review verdict — CR revision 2

Verdict: CHANGES REQUESTED.

Reviewed candidate tree: `baaedc1c9ec6806cf6dc78895426ee5e4f3cb870`.
Reviewed patch SHA-256:
`1c8df2ae9bad31449b248a27433cf74a258e01386fb497ed5cb724c6abd80942`.

## Blocking finding

The release entry-point trust boundary is asserted but not implementably bound.
Contract lines 167–170 make `release-prepare.yml` run on a `v*` tag push or
`workflow_dispatch`, while asserting that preparation loads workflow code from
the protected default branch. GitHub Actions instead uses the workflow version
present at the event's associated commit SHA/ref. A tag outside protected
history can therefore supply the very `candidate-identity` / `review-gate`
workflow code that is expected to reject that tag; `workflow_dispatch` can also
select a non-default ref. The contract names no default-branch entry point,
`github.workflow_sha`/policy-digest binding, reusable-workflow SHA pin, or
protected deployment-ref rule that makes the claim true.

This defeats trust invariants 1–3 and leaves the tag-spoofing negative fixture
self-protecting: the untrusted workflow ref can remove or forge the guard before
it runs. GitHub's documented execution model is that each run uses the workflow
version from the event's associated SHA/ref:
https://docs.github.com/en/actions/concepts/workflows-and-actions/workflows .
For `push`, `GITHUB_SHA` is the tip commit pushed to the tag/ref:
https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#push .
GitHub documents `workflow_run` as a default-branch privileged split, while
warning never to execute untrusted code or trust its artifacts:
https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_run .

Required rework:

1. Choose and specify a realizable trusted entry point. Recommended: an
   unprivileged tag-intake workflow may emit only the requested ref/event
   identity, then a protected-default-branch `workflow_run` (or equivalent
   default-branch-only dispatcher) independently resolves and validates the tag
   and candidate; it must not execute or trust intake code, caches, or
   artifacts. Alternatively remove tag-push preparation and allow only a
   default-branch-bound dispatch whose workflow provenance is independently
   verified.
2. Bind every credential-capable reusable workflow to an exact reviewed
   protected-branch workflow SHA/policy digest; a local reusable-workflow path
   resolved from an arbitrary tag/caller ref is not sufficient.
3. Add the production-call-site negative fixtures: a tag outside protected
   history whose tagged workflow deletes the guard, `workflow_dispatch` against
   a non-default ref, mismatched/missing `github.workflow_sha` or policy digest,
   and a reusable workflow resolved from the candidate/tag ref. Each must fail
   before candidate acceptance or protected-environment access.
4. Update the trigger/job inventory, threat row, diagram, traceability, and
   LOGBOOK wording so the source of executed workflow code is explicit and the
   invariant is mechanically testable.

## Passing evidence

- Exact CR patch digest matched the assignment; patch bytes matched
  `git diff --binary` and reverse applicability passed: exit 0.
- All five candidate paths matched the candidate tree byte-for-byte.
- `git diff --check`: exit 0.
- PlantUML `-checkonly`, SVG render, committed-SVG comparison, PNG render, and
  manual visual inspection: exit 0; the diagram is legible and single-purpose.
- Corrected structural contract probe: exit 0; 26 inventory rows have the six
  required fields, nine unique required checks are present, PR rows are
  credential-free/read-only, and all required threat names are present.
- All 27 task IDs referenced by the contract resolve on the authoritative
  board: exit 0.

## Failing and residual evidence

- Release-trigger trust probe: exit 1 for the blocking finding above.
- `task-board validate --json`: process exit 0 but `valid=false` with one
  `PARENT_STATUS_MISMATCH` caused by the active reviewer status; this is failing
  content and independently reproduces the raw-validator fail-open behavior
  already recorded by the candidate.
- `scripts/tests/test-credential-free-validation.sh`: exit 1 on the known
  six-versus-eight scheme mismatch. The test, production checker, and
  `Project.swift` are unchanged between base and candidate (diff exit 0), so the
  failure is not attributed to this documentation delta and remains a residual
  cross-owner regression.
- Two early reviewer structural probes exited 1 because their table/phrase
  matchers were too broad; the corrected production-document probe exited 0.
- One candidate-integrity probe accidentally reused zsh's special `path`
  parameter, causing `git`/`cmp` lookup failures; the corrected probe exited 0.
- The required installed `references/negative-evidence.md` is unavailable.
  Its current contents remain unknown; the assignment's explicit negative-gate
  rules and the last retained board-run copy were used without treating the
  failed read as absence of requirements.

