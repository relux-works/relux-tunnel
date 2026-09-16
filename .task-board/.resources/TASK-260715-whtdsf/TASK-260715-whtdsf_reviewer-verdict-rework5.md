# TASK-260715-whtdsf independent review — rework 5

Verdict: CHANGES REQUESTED

Reviewed exact worktree base: `b3422b05226253a17676b9b84c764071fe3dbe74`.

Reviewed candidate paths and SHA-256:

- `README.md`: `5a6d83659443b8d6a5f5dfbd0fb61938b9df767267e48ddfc1637a15037adc98`
- `LOGBOOK.md`: `04c6ae145b5b8fb68abcdf110fe54e28671aba5f9d85bad6d66bd752d967f55c`
- `docs/TASK-260715-whtdsf_ci-trust-and-quality-gate-contract.md`: `41393dfb9e8f202d772e5d3d659ecab36117624f189ad8880c2f090317c41f36`
- `diagrams/TASK-260715-whtdsf_ci-trust-boundary.puml`: `b48705c50d466338ed9dffd9bdda201b59703bd8980a703f2414e92163f3b67b`
- `diagrams/artefacts/TASK-260715-whtdsf_ci-trust-boundary.svg`: `6386ca77f9bc389bf9c5595c63e879ba2b46ba35f1b567ac870e9e78fd0f7845`

## Blocking findings

### 1. The dispatch credential is still described as unable to publish, but its required permission grants publication APIs

The default-branch `repository_dispatch` execution boundary correctly fixes CR
revision 3's candidate-controlled tag-workflow problem: GitHub loads
`release-prepare.yml` from the default branch, payload fields remain untrusted,
and no tag/push, selectable-ref dispatch, or candidate-controlled upstream
workflow starts release preparation.

The credential boundary around that design is materially false, however.
Contract lines 191–203 correctly record that creating the dispatch requires a
repository-scoped GitHub App installation token with `Contents: write`, but then
say that the App has no publication permission and that compromise cannot
publish. Threat row 411 repeats that claim. Diagram lines 7 and 31 reduce the
credential to a short-lived requester that produces a request receipt only, and
the LOGBOOK rework-5 entry repeats the same bounded-authority conclusion.

GitHub's official REST contracts use that same `Contents: write` permission for
creating and updating GitHub Releases and for updating/uploading release assets.
The dispatch client calling only `/dispatches` is intended behavior, not an
enforced ceiling on a stolen installation token. A compromised token can call
the other APIs directly; protected branch/tag rules do not by themselves prevent
editing/deleting an existing release or replacing release assets. Therefore the
current contract understates a low-privilege credential's publication and
availability blast radius, failing AC1's truthful token inventory and AC4's
compromised-credential scenario.

Official evidence:

- Repository dispatch requires `Contents: write`: https://docs.github.com/en/rest/repos/repos#create-a-repository-dispatch-event
- Creating/updating/deleting releases uses `Contents: write`: https://docs.github.com/en/rest/releases/releases
- Updating/uploading/deleting release assets uses `Contents: write`: https://docs.github.com/en/rest/releases/assets

Bounded rework: either replace the trigger/authentication design with a boundary
that does not hand the requester a raw repository credential overlapping release
publication, or truthfully classify this App token as publication-capable and
add compensating controls matching that authority. Update §§2–3, the
credential-threat row, negative fixtures, diagram, LOGBOOK, provenance, and
outcome together. Negative evidence must exercise the actual credential/API
boundary by attempting release create/update/delete, asset upload/update/delete,
and relevant ref/tag mutations; a test that only rejects a bad dispatch payload
does not prove the credential bound.

### 2. Several job inventory rows do not enumerate the complete input/network/retention contract promised by AC1

The six-column shape is present, but shape is not a complete inventory:

- Lines 104–107 use `Same` for the seed jobs. That inherits the first row's
  pinned legacy-repository commit even though `validate`, `relay-toolchain`, and
  `relay-portable-runtime` do not consume that input. The latter two consume
  relay manifests/tool inputs and matrix targets instead.
- The `relay-toolchain` row names a job-log output without a retention period,
  and `release/revalidate` (line 226) names fresh results without a retention
  class/period.
- Lines 89–91 promise that every Network cell records both runner capability and
  authorized use. Several release rows (245–267) state only an allowlisted or
  enforced use and do not state the underlying runner capability. The finalizer
  row also does not explicitly state environment/secrets absence, despite AC1
  requiring those fields per job.

Bounded rework: make each row self-contained and factually specific—exact input
sources, GitHub token plus non-GitHub credential scope, environment/secrets,
runner network capability plus authorized endpoints, outputs, retention, and
approval. Do not use a cross-row `Same` reference when the inherited input is not
actually shared.

## Passing review evidence

- CR revision 3 trigger-code issue: fixed. `repository_dispatch` default-branch
  execution and explicit public runner egress are now stated truthfully.
- Contract structural checker: exit 0; 26 six-field table rows, nine exact merge
  checks, 18 trace rows, and required threat names. The checker validates shape
  and phrase presence, not the two semantic findings above.
- Primary-check traceability: all 18 rows contain exactly one primary check in
  the primary-check cell and identify downstream plus platform/review ownership.
- Required-check policy remains nine exact blocking names; skipped, cancelled,
  stale, missing, neutral, timed-out, and unknown results fail closed.
- Negative obligations name the production call sites and rejection outcomes
  for forked code, mutable actions, cache poisoning, artifact substitution,
  tag/workflow spoofing, reruns, cancellation, concurrency, and scoped release
  credentials. The missing dispatch-token publication fixture is the blocking
  exception above.
- Pull-request rows remain `contents: read`, without production environments or
  production secrets/publication permissions, and correctly acknowledge public
  Internet egress. AC2 passes.
- Gate A0 remains deferred, iOS/TestFlight/App Store remain deferred, no Linux
  runner is required for the macOS prototype path, and workflow implementation
  remains out of scope.
- PlantUML `-checkonly`: exit 0. SVG render: exit 0. SVG XML validation: exit 0.
  Fresh SVG is byte-identical to the checked-in SVG: `cmp` exit 0. Fresh PNG
  render and manual visual inspection: exit 0; the view is legible, but it omits
  the dispatch token's real publication blast radius.
- `git diff --check` for tracked paths: exit 0. For the three untracked candidate
  files, `git diff --no-index --check` returns 1 because the files differ from
  `/dev/null` while emitting zero diagnostics; a direct trailing-whitespace scan
  reports none. The initial combined check command was invalid after a zsh loop
  variable shadowed `PATH`, causing subsequent probes to exit 127; the corrected
  commands above are the accepted evidence.
- SHA-256 recomputation: exit 0 and matches the producer outcome exactly.

## Known failing gates and residual risks

- `scripts/tests/test-credential-free-validation.sh`: exit 1. It still expects
  `ReluxProxyIOSUITests` and `ReluxProxyMacUITests`; the active accepted graph has
  only the six macOS schemes. This unchanged cross-owner failure is not reported
  green and is not attributed to the documentation candidate.
- `task-board validate --json`: process exit 0, but content assertion exit 1:
  `valid=false` with one `PARENT_STATUS_MISMATCH` for
  `STORY-260715-anxje6` (`analysis` versus child aggregate `to-review`). Board
  state was not mutated during this review.
- `references/negative-evidence.md` remains unavailable; its content is unknown,
  not inferred from absence.
- Workflows and rejecting fixtures remain downstream implementation. Human
  ratification remains independently tracked at `TASK-260717-2d308k` and blocks
  publication, not bounded implementation after a future accepted draft.

Route: bounded solution-architecture rework, then a fresh independent review.
This is not a human-only or external Stop-The-Line blocker.
