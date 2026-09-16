# TASK-260715-pa6evr outcome

Status: ready for solution-architect handoff to review. Independent draft review
ACCEPT; canonical CR acceptance, trunk integration and human ratification are
separate. Repository changes remain uncommitted in the assigned Story worktree.

## Deliverable

`docs/TASK-260715-pa6evr_relay-release-input-contract.md`, SHA-256
`0c2ecaf408bad5ea486a74752fc50c98ed5c0ce1a178764508aa42027521356f`.
README links the contract; UNRESOLVED_QUESTIONS.md records the existing policy
ratification and materialization owners. No source, build, protocol, workflow,
Apple signing, remote installation or VPN behavior changed.

## Acceptance criteria and checklist mapping

| AC | Evidence and disposition |
| --- | --- |
| 1: mutable inputs and immutable authority | Contract section 2 enumerates source/recipe/compiler/linker/stdlib/Syft pins plus the closed M5 lock schema for every remaining input class. Historical source 9/9 and recipe 3/3 file hashes independently reconciled with Git objects; 8/8 archive hash literals match authority. Actual future runner/auxiliary/scanner/advisory pins are not fabricated: existing 3e7noa/36gq4m/38atsq/nwcp1j tasks must materialize them before certification. |
| 2: targets, identity, boundaries, layout | Sections 3 and 5 define all four triples/names, CPU/runtime/linkage, CLI/identity/protocol, two manifest consumers and staging paths. 4/4 target rows checked against manifests. |
| 3: reproducibility | Section 4 specifies two isolated unsigned builds and no unexplained differences; each allowed normalization has a rationale and existing or required downstream test. Archive scope is exactly 11 release files; existing comparator also checks four protocol-test binaries. Six existing normalization/comparison tests rerun, all pass. No actual two-build or native-runtime proof claimed by this prose task. |
| 4: schemas/owners/consumers | Sections 5–8 define manifest, SPDX 2.3, notice map, scan, exception, reproducibility, conformance, provenance, staging/index and retention records. Existing machine schemas preserved; new schemas explicitly downstream specifications, not claimed implemented. Exception and staging hash references are acyclic. |
| 5: approvals or owned decisions | Section 8 supplies security/release/relay/legal-compliance ownership and concrete options. TASK-260717-2d308k remains the existing human ratification/publication boundary; no human approval claimed. Draft agent acceptance allows downstream implementation as explicitly instructed. |

No new board story, task, research question or diagram was created. Every
requirement maps to an existing atomic owner in section 8, using the inspected
Story children and blockedBy links. Policy-fill gaps and scope checks are
written there. Important input-pin gaps and review corrections are recorded in
the task notes as a logbook entry. This is the smallest decomposition: no change
to the already sufficient task graph.

## Commands and actual exit codes

Inspected baseline/worktree and fresh origin main:
`b3422b05226253a17676b9b84c764071fe3dbe74`; 0 commits behind. Commands
`git ls-remote --symref origin HEAD`, `git fetch origin refs/heads/main:refs/remotes/origin/main`,
`git rev-parse HEAD refs/remotes/origin/main`, `git rev-list --count HEAD..refs/remotes/origin/main`
all exited 0. No branch switch/rebase/merge/commit performed.

- Tool readiness: Git 2.50.1, Python 3.14.7, ripgrep 15.2.0 and task-board dev
  reported expected version output; exit 0. Task-specific log retained.
- `python3 .temp/TASK-260715-pa6evr/verify-pins.py`: exit 0, 9/9 historical
  source files, 3/3 historical recipe files, 8/8 archive hashes, 4/4 targets,
  matching go.mod and two parseable existing manifest schemas. Script and log
  attached. It verifies hashes against the local Git objects, not archive
  download availability or installed tool execution.
- Scoped test command below: exit 0, 6 tests, 0.280s. Actual producer rerun;
  reviewer inspected these results without rerunning them.
- `git diff --check`: exit 0. Final three-file scope reviewed; untracked
  Markdown files also read directly and reviewed by agent.
- Board status/resource/predecessor/dependency reads succeeded after syntax
  recovery. Initial `task(...)`, `acceptanceCriteria` projection, dry-run
  `check_item(... index=1)` and dry-run `add_log(...)` failed with exit 1
  (unknown operation/field/argument). Recovered through documented `get`,
  `check_item(... item=1)` and `set_notes`; these are CLI spelling errors,
  not passing release gates or external blockers.

```sh
python3 -m unittest \
  scripts.tests.test_relay_release.RelayReleaseTests.test_spdx_metadata_normalization_controls_time_uuid_and_json_order \
  scripts.tests.test_relay_release.RelayReleaseTests.test_spdx_normalization_rejects_invalid_missing_and_impossible_metadata \
  scripts.tests.test_relay_release.RelayReleaseTests.test_generate_sbom_normalizes_dynamic_syft_fields_before_verification \
  scripts.tests.test_relay_release.RelayReleaseTests.test_compare_covers_all_release_metadata_and_reports_json_and_raw_diff \
  scripts.tests.test_relay_release.RelayReleaseTests.test_compare_rejects_undeclared_bundle_input \
  scripts.tests.test_relay_release.RelayReleaseTests.test_compare_rejects_mode_raw_byte_and_symlink_drift
```

Existing source/toolchain/protocol and CI contracts were accepted as predecessor
inputs; their historical build/runtime statements were not rerun or promoted
into fresh release evidence. Current source/recipe file hashes were rerun as
listed. No broad test matrix was justified solely for this document.

## Independent review

Astra low reviewer `draft_review` independently inspected the draft, manifests,
normalizer/comparator, tests, identity/CLI, runbook, delivery deferrals and
accepted CI policy. Two findings were corrected: exception/input-lock hash
cycle; unspecified deterministic archive membership. Final verdict ACCEPT
binds the exact document hash above. Verdict attached as
`TASK-260715-pa6evr_agent-review.md`. This native draft review is deliberately
not a forged canonical board CR acceptance. The orchestrator owns routing the
normal immutable candidate after this producer's handoff.

## Attached artifacts

- `TASK-260715-pa6evr_relay-release-input-contract.md`: reviewed contract.
- `TASK-260715-pa6evr_agent-review.md`: independent accepted draft verdict.
- `TASK-260715-pa6evr_pin-reconciliation.log`: pin results and file hashes.
- `TASK-260715-pa6evr_verify-pins.py`: reproducible task-specific inspection.
- `TASK-260715-pa6evr_normalization-tests.log`: six-test results.
- `TASK-260715-pa6evr_base.log`: baseline equality.
- `TASK-260715-pa6evr_readiness.log`: tool readiness.
- This outcome: commands, AC mapping, corrections and residual risks.

## Residual release gates

M5 input-lock/schema/gate implementation and deterministic archive metamorphic
proof are downstream tasks, not shipped here. Final runner/scanner/advisory
pins are unset; native Linux execution is deferred; no fresh isolated build
comparison, vulnerability scan, signed attestation, remote staging or owner
approval was executed. These remain explicit release certification/publication
gates while accepted-draft implementation can proceed. No exceptions admit
unknown inputs, missing native certification or unexplained byte differences.

All files and board operations stayed within the assigned worktree and
exported authoritative board; no Shared Runtime worktree was accessed. No
secret values were read or persisted. All evidence was attached before role
handoff. A failed handoff must remain a failure with its exact reason retained;
no manual CR edits or integration workaround is authorized.
