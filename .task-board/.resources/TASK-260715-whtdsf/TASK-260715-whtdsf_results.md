# TASK-260715-whtdsf — Revision 4 accepted outcome

Independent reviewer verdict on 2026-08-30: **ACCEPTED** for Change Request
revision 4 (`f81f9fb166e451b886ee1c1f1120fee301564710`; patch SHA-256
`663ad6ec827ba878eb043dbc2b5a72a4dea206414bcc20d11b02eae10668d89a`).

The reviewer independently verified all five candidate blobs, diff hygiene,
26 complete inventory rows, nine exact required checks, 18 one-primary-check
trace rows, 27/27 referenced board owners, the GitHub platform premises, five
rejecting documentation mutants, and reproducible PlantUML source/SVG. Relevant
checks pass. The known board content failure (`valid=false` despite process exit
0) and unchanged macOS-vs-deferred-iOS scheme-test failure (exit 1) remain
explicit residuals and are not reported green; neither is introduced by this
five-path contract/diagram delta. Full evidence is in the task-scoped
`TASK-260715-whtdsf_review-verdict.md` outcome. The accepted handoff is
`to-review`; the commit-owning orchestrator, not this reviewer, owns commit
confirmation and final `done`.

Lifecycle evidence: the first `accept_cr` attempt with the pre-existing generic
verdict resource exited 1 (`change_request_evidence_missing`) because the current
run could not prove that resource's provenance. The reviewer then attached the
new current-run resource `TASK-260715-whtdsf_review-verdict-rev4.md`; `accept_cr`
revision 4 exited 0, recorded CR state `accepted`, reviewer run
`RUN-260830-735ea0`, and task status `to-review`. No `commit_ack` was supplied.

---

## Producer outcome retained below

# TASK-260715-whtdsf — Rework 6 outcome

Date: 2026-08-30 (Asia/Tbilisi)
Base: `b3422b05226253a17676b9b84c764071fe3dbe74`

## Result

Ready for exact-artifact independent agent review. Rework 6 closes the two
findings from the rework-5 `CHANGES REQUESTED` verdict.

- Release initiation now uses `issues: opened`, which GitHub binds to the last
  default-branch commit/ref, rather than `repository_dispatch`.
- The external requester App has exactly `Issues: write`. It can mutate only
  issue-plane request state; it has no Contents/ref, GitHub Release/asset,
  Actions/workflow, environment, secret, signing, or publication authority.
- Trusted workflow code binds the captured event payload digest and never
  refetches edited issue text as authority. Sender, issue/template/request ID,
  candidate SHA/version, and all issue contents remain untrusted.
- All 26 workflow/job inventory rows are self-contained: exact input source,
  token/environment/secrets, runner network capability plus authorized use,
  output/retention, and approval are present. Current seed retention that is not
  declared is explicitly unknown/non-promotable.
- Negative obligations exercise the real requester token permission manifest:
  Contents/ref, Release/asset, Actions/workflow, environment, and secret calls
  must be denied while issue-plane mutation demonstrates the bounded blast
  radius.

Gate A0, iOS/TestFlight/App Store workflows, workflow implementation,
production credentials, and a Linux-runner requirement for the macOS prototype
remain out of scope. Human governance ratification remains independently
tracked by `TASK-260717-2d308k`; it blocks publication, not downstream
implementation after agent acceptance.

## Artifacts and SHA-256

- `docs/TASK-260715-whtdsf_ci-trust-and-quality-gate-contract.md` —
  `92552e674576b1e7da0fae0a0cdc577afa73cfa89639555e3f75f5ec345be796`
- `diagrams/TASK-260715-whtdsf_ci-trust-boundary.puml` —
  `3aac6fc5784032e714e0a6a0feb538749d394ae6ab4ccbb440fad424126fa77f`
- `diagrams/artefacts/TASK-260715-whtdsf_ci-trust-boundary.svg` —
  `edceb9715a2f209943934274aa682e21e0047d6847c28be557be8961f609067c`
- `README.md` —
  `5a6d83659443b8d6a5f5dfbd0fb61938b9df767267e48ddfc1637a15037adc98`
- `LOGBOOK.md` —
  `0039eeea64373456b1db2ca227a59bc416fbe286bc8c58efae0c19ed7adc4a07`

## Validation and real exits

- Required `analysis` status mutation: exit 0.
- Tool readiness (`task-board`, `rg`, `git`, PlantUML 1.2026.6, `xmllint`,
  `jq`, `shasum`): exit 0.
- Official GitHub issue-event, issue API, repository-dispatch, Release/asset,
  and Git-ref permission research: exit 0; persisted at
  `.temp/TASK-260715-whtdsf/research-github-issue-trigger-rework6.md` and the
  task-scoped provenance outcome.
- Contract checker: exit 0; 26 six-field inventory rows, nine exact merge
  checks, 18 one-primary-check trace rows, all named threats, trusted issue
  entry, and row self-containment pass.
- Five narrowed contract mutations (repository dispatch, requester
  `Contents: write`, cross-row `Same`, missing retention, missing runner/network
  capability): all five rejected; test command exit 0.
- All 27 referenced task IDs resolve on the authoritative board: exit 0.
- PlantUML `-checkonly`, fresh SVG/PNG render, XML validation, committed-SVG
  byte comparison, and manual visual inspection: exit 0.
- `git diff --check`, untracked-source trailing-whitespace scan, and local
  authority/link readability: corrected rerun exit 0. The first combined probe
  was a shell-construction failure because zsh special variable `path`
  overwrote `PATH`, making `tee` unavailable; it is not counted as artifact
  evidence.
- `task-board validate --json`: process exit 0, content assertion exit 1;
  `valid=false` with one `PARENT_STATUS_MISMATCH` because the Story is
  temporarily `analysis` while its child aggregate is `to-review`. This must be
  rerun after reviewer and producer handoff and is not reported green.
- `scripts/tests/test-credential-free-validation.sh`: exit 1. It still expects
  `ReluxProxyIOSUITests` and `ReluxProxyMacUITests`, while the accepted active
  graph has six macOS-only schemes. The test, `Project.swift`, and
  `scripts/check-workspace-schemes.sh` are unchanged from `HEAD` (exit 0), so
  this is the existing cross-owner regression and is not attributed to or
  hidden by this documentation delta.
- Product Swift/Go builds were not rerun because rework 6 changes only the
  binding documentation, focused diagram/render, logbook, and board outcomes;
  it does not change product or workflow code.
- Reviewer spawn preflight selected the policy-admitted `gpt-5.6-sol/high` pair:
  exit 0. A reviewer spawn attempted before producer completion returned process
  exit 0 but a typed `change_request_candidate_drift` payload and created no
  RUN; it is not acceptance. `task-board worktree status` records CR3 as
  `stale`. The current producer completion hook must publish revision N+1 from
  the exact rework-6 tree, after which the external orchestrator routes the
  tracked reviewer. This lifecycle boundary is why the handoff is reported as
  ready for review rather than accepted completion.

## Acceptance mapping

1. Section 3 enumerates every current, PR, issue-request, preparation, release,
   and deferred workflow/job with the complete AC1 trust contract.
2. Sections 2–3 keep PR/fork jobs read-only, credential-free,
   environment-free, and non-publishing while truthfully recording public
   hosted-runner egress.
3. Sections 4–5 bind nine checks and map all 18 requirements to exactly one
   primary check plus downstream macOS/iOS/relay/review ownership.
4. Sections 7–8 cover fork, mutable action, cache, artifact, tag/workflow,
   rerun, cancellation, concurrency, and credential threats with rejecting
   fixtures at named production call sites.
5. Section 9 records autonomous agent review and separately accountable human
   ratification at `TASK-260717-2d308k`; no trust dispute is hidden.

## Residual risk

Workflow controls and real API-permission negative fixtures remain downstream
implementation. Human ratification blocks publication. Exact egress-control
technology for credentialed jobs remains a fail-closed policy-fill decision.
The pre-existing scheme-set test is red. CR3 is stale until this producer exits
and the completion hook publishes revision N+1; no reviewer acceptance is
claimed before that tracked review. `references/negative-evidence.md` remains
unavailable after repository/installed-skill checks; its content is unknown,
not inferred.
