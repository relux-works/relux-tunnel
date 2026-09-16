# TASK-260715-whtdsf review verdict — CR revision 3

Verdict: CHANGES REQUESTED.

Reviewed base commit: `b3422b05226253a17676b9b84c764071fe3dbe74`.
Reviewed candidate tree: `703d3528770a9f94b3a5f446c0ecc133f710c456`.
Reviewed patch SHA-256:
`b3c32dfba14b111b897364109f8ed439574675a9d952b54a1dcc6d9e92d9bf32`.

## Blocking finding: tag intake is not externally constrained to the declared permissions or network boundary

The revision fixes the previous self-protecting candidate-acceptance guard by
moving candidate acceptance into a default-branch `workflow_run`. That protected
side is directionally sound. The upstream `v*` tag workflow is still described
as externally guaranteed to be unprivileged, however, while the contract also
acknowledges that GitHub loads arbitrary tagged workflow code:

- trust invariant 4 (contract lines 53–60) says repository Actions settings
  enforce a read-only default so tagged workflow code cannot self-elevate;
- §3.3 lines 176–194 says arbitrary tagged code has only `contents: read`, no
  cache/artifact upload, no publication permission, and `Network: None`;
- the PlantUML edge repeats “arbitrary tagged workflow code / no secrets,
  cache, artifacts, or authority.”

Those are not enforceable properties of a standard same-repository tag-push
workflow. GitHub's workflow syntax says token permissions start from the
repository/organization default and are then adjusted by the workflow and job
`permissions` keys. GitHub's repository settings documentation is explicit that
a repository writer may add or remove `GITHUB_TOKEN` access in workflow YAML.
The fork-PR write downgrade does not apply to a same-repository tag push. A
tagged workflow can therefore replace `contents: read` with write scopes; the
restricted repository setting is a default, not a hard ceiling. Standard
GitHub-hosted runners also have public Internet access by default, so `Network:
None` cannot be guaranteed by the cited settings. Arbitrary tagged steps can
also attempt cache/artifact or external output even if the trusted downstream
correctly refuses to consume it.

Official platform evidence:

- Workflow code is loaded from the event-associated SHA/ref:
  https://docs.github.com/en/actions/concepts/workflows-and-actions/workflows
- Token permissions are calculated from defaults and then adjusted by workflow
  and job YAML:
  https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#how-permissions-are-calculated-for-a-workflow-job
- Repository settings are defaults and writers can modify permissions in
  workflow YAML:
  https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository#setting-the-permissions-of-the-github_token-for-your-repository
- Standard GitHub-hosted runners have public Internet access by default:
  https://docs.github.com/en/enterprise-cloud@latest/actions/concepts/runners/private-networking#about-github-hosted-runners-networking

Impact: acceptance criterion 1's network/token inventory and the stated tag
spoofing trust boundary are materially false. A malicious or mistaken tag at a
commit with modified workflow YAML can obtain the GitHub token permissions
allowed to that push workflow and network access before the protected
`workflow_run` boundary. Ignoring its outputs prevents candidate substitution,
but does not make the intake itself read-only, output-free, or network-free.

Required rework:

1. Use a trigger whose workflow code is loaded only from a trusted default-branch
   revision (for example a tightly authenticated `repository_dispatch` release
   request), or document a separate externally enforced tag-creation/runner/token
   control that actually caps same-repository tag runs. A repository default
   permission setting alone is insufficient.
2. If tag-push intake remains, inventory its real worst-case capabilities and
   make every cache, artifact, token, network, and runner effect explicitly
   untrusted and non-authoritative. Do not claim those capabilities are absent.
3. Add negative fixtures that mutate tagged YAML to request `write-all`, select
   an unauthorized runner, contact an arbitrary endpoint, and upload/cache
   attacker-controlled bytes. Prove either that an external control rejects the
   run before execution or that every effect remains outside all protected
   release and publication authorities.
4. Update trust invariant 4, §3.3, the threat row, diagram, traceability, and
   LOGBOOK together.

## Secondary consistency finding

Trust invariant 4 says every permission other than `contents: read` is `none`
and that a job elevates one named permission only after protected-environment
approval. `release/candidate-identity` (line 218) instead grants
`contents: read` plus `actions: read` with no protected environment. The latter
is a reasonable read-only metadata permission for the GitHub Actions API, but
the invariant must distinguish additional read-only metadata scope from write
elevation so the contract has one testable rule.

## Passing evidence

- Exact candidate/object/file integrity and assigned patch digest: exit 0; all
  five working-tree paths match candidate-tree blobs byte-for-byte.
- `git diff --check` for the exact base-to-tree delta: exit 0.
- Contract structural audit: exit 0; 27 inventory rows have the required table
  shape, nine exact merge checks are present, 18 trace rows each name one primary
  check, and all nine required threat scenarios are named.
- All 27 task IDs referenced by the contract resolve on the authoritative board:
  exit 0. The four named deferred iOS owners remain explicitly `blocked` with
  evidence/options/recommendation/resume input.
- PlantUML `-checkonly`, SVG render, committed-SVG byte comparison, and PNG
  render: exit 0. Manual visual review found a focused, legible diagram; its
  tag-intake label repeats the blocking false boundary above.
- Local authority and diagram links are readable: exit 0.
- The protected `workflow_run` and full-SHA reusable-workflow provenance claims
  match current official GitHub documentation.

## Failing and residual evidence

- `task-board validate --json`: process exit 0, but content is `valid=false`
  with one `PARENT_STATUS_MISMATCH` for `STORY-260715-anxje6` (`analysis` versus
  child aggregate `to-review`). This is failing content, not green validation;
  it is outside the five-path candidate delta and independently confirms the raw
  validator fail-open problem the contract records.
- `scripts/tests/test-credential-free-validation.sh`: exit 1 because the
  expected scheme set includes `ReluxProxyIOSUITests` and
  `ReluxProxyMacUITests`, while the active generated graph has six macOS-only
  schemes. The test and `Project.swift` are unchanged by this candidate, so this
  is recorded as a pre-existing cross-owner regression, not attributed to the
  documentation delta and not reported green.
- `references/negative-evidence.md` is unavailable in the repository and
  installed skill trees; its contents remain unknown. The assignment's explicit
  negative-evidence contract was applied without inferring from the failed read.
- Product Swift/Go builds were not rerun because the exact candidate changes
  only documentation, diagram source/render, README, and LOGBOOK.

Route: `to-dev` for bounded contract/diagram rework. This is not a human-only or
external Stop-The-Line blocker; the platform behavior and viable correction are
known.
