# TASK-260830-1x524u — independent review of CR revision 2

Verdict: BLOCKED — acceptance transaction refused. Reviewer run RUN-260907-587288. Technical gates passed, but revision 2 is not accepted and cannot authorize integration.

## Exact candidate and scope

CR-TASK-260830-1x524u-2 is already published as `story_final`, state `ready` before acceptance. Base `b3422b05226253a17676b9b84c764071fe3dbe74`; candidate tree `0ca11378213cc02a78eeac937f94aef6c5209545`; complete delta 42 paths. Patch SHA-256 independently matches `3d83cba34a6917d95c34fdc68ff0435ba27e3ef70402e9d215f960f164f1c888`.

Fresh ls-remote/fetch confirms main at the base and remote Story at local HEAD `9bf4d0892db03035b989a4c040cfee37636ff8df`. All five introduced commit signatures verify (exit 0). Worktree exactly matches the CR tree before and after checks. The three pre-existing modified files remain untouched. No product edits, commits, branch switches, integration, or successor runs were performed.

All eleven preceding Story children and all three explicit blockers are done. Task and Story `isBlocked=false`. Story `isAdvisoryBlocked=true`: derived relations include backlog SSH profile Story (which itself depends on this Story) and reviewing architecture container; these are not unsatisfied explicit prerequisite tasks. Do not describe the whole board as terminal.

## Independently executed gates

- Configured `LEGACY_ROOT="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/../relux-proxy" make credential-free-validate`: exit 0. Every stage passed, including relay packaging, exact graph negative contracts, deterministic generation, unsigned macOS Debug/Release host/provider builds and target contracts, Core boundaries, native packaging, legacy preservation, migration isolation and negatives, legacy build/tests.
- Full Swift run inside completion: 514 tests, 44 suites, 25 known issues; exit 0. Physical-device investigations remain explicitly skipped. Known issues are not represented as clean production-device coverage.
- Focused eight requested filters: 105 tests across 9 reported suites, exit 0.
- `make m1-runtime-harness-test`: six tests plus seven fixtures, exit 0.
- `make m0-bindings-check m0-bindings-test`: binding gate and 32 negative tests, exit 0.
- Both shared iOS/macOS adapter target builds: exit 0 each. Compile evidence only.
- Changed Swift strict format lint, shell syntax, JSON parsing and exact-delta whitespace validation: exit 0.
- Five relevant Markdown documents: 52 local links checked, none unresolved (this reviewer parser count differs from producer's 58). PlantUML syntax/render: exit 0; all four SVG pages byte-identical.

## Independent gate-defeat evidence

Production chain: `validate-credential-free.sh` calls `tests/test-credential-free-validation.sh`, which invokes `check-workspace-schemes.sh`. In a scratch copy only, narrowed exact-set rejection to reject missing required schemes while admitting extras. The existing negative fixture for UnexpectedScheme then caused the real contract test to fail with exit 1 and `invalid scheme fixture unexpectedly passed`. This proves forbidden admission is detected, beyond the producer's earlier mutant that rejected a valid graph. Unmodified contract passed in completion. Product gate bytes were never edited.

M0 production-entry negatives additionally exercise malformed/duplicate/absent evidence, narrowed obligations, artifact/header byte drift and protected dependency closure. Runtime tests exercise manifest refusal before construction and absent-versus-unreadable errors. Existing implementation/review evidence for prior accepted Story children is retained; this review does not replace those reviews with a new broad source audit.

## Reused exact-tree evidence

Accepted attached `TASK-260830-1x524u_coverage-report-03.log`, cross-checked against producer candidate-integrity resource: selected Shared Runtime coverage 4673/5174 lines (90.32%), 1619/1921 regions (84.28%). This is aggregate selected-scope coverage, not an assertion every file exceeds 80%; SSH bootstrap is 65.79% lines. Coverage instrumentation was not rerun here. Earlier producer system-state comparison and CR validation were inspected as supporting provenance, not substituted for current test exits.

## Privacy and system boundary

Read actual PacketTunnelProvider.swift: lifecycle shell only; no MacOSProviderCompositionRoot wiring. Documentation explicitly agrees. No live system VPN claim, signing, install, configuration, connection, preference write, provider activation, route write or DNS write was performed. Executed tests use deterministic substitutes; unsigned Xcode checks build/test contracts without activating a provider.

Current DNS and VPN-list hashes remained equal. Whole routing-table hash differed; cause is UNKNOWN and no claim of machine-wide routing immutability is made. An additional seven-fixture harness run returned 0 with identical pre/post full-tunnel selectors (10 rows). The bounded read-only route monitor was stopped intentionally (exit -15), emitted no event records and no stderr; lack of emitted events alone is not proof of absence. Combined evidence supports that this review did not initiate system mutation; it does not attest unrelated OS/network activity. Raw system state was not persisted, only hashes/counts. Producer's stronger before/after NetworkExtension and selector evidence remains attached for the original candidate run.

## Handoff

Technical review applies only to revision 2 and its exact tree. Runtime/validation checks passed within the documented no-live-provider scope, but the final ownership/acceptance gate failed. Keep downstream real VPN, signing, physical execution and native Linux release rows separate. No successor started. Producer-bound integration must revalidate the exact accepted candidate according to the configured landing transaction; this review does not land it.

Companion resources use prefix `TASK-260830-1x524u_recovery-` and include current command logs, board/CR identity, diagram/link checks, negative mutant, state observations, and reused coverage provenance.

## Stop-The-Line: immutable producer ownership missing

Attempted exact authorized mutation:
`task-board m 'accept_cr(TASK-260830-1x524u, revision=2, evidence=TASK-260830-1x524u_review-verdict-rev2.md)'`

Actual exit: 1. Exact error:
`change_request_invalid_record: Change Request CR-TASK-260830-1x524u-2 has no complete immutable producer role/archetype binding; legacy or unreadable ownership cannot authorize integration (cr_id=CR-TASK-260830-1x524u-2, element_id=TASK-260830-1x524u)`.

Failed assumption: this older ready CR was still structurally acceptable to the current ownership gate. Its producer_run_id exists, but a run identifier is not the missing immutable role/archetype attestation. No acceptance was written. No synthetic ownership, board-file edit, commit acknowledgement or manual integration was attempted.

Clean path attempted: completed independent evidence and live checklist, then the named accept_cr transaction. The gate refuses before integration. Repeating the same mutation cannot supply missing provenance.

Required external input/action: owner/orchestrator must recover the original producer provenance through a supported CR migration/republish flow and issue a reviewable revision with complete immutable producer role and archetype, then route independent acceptance. Preferred option: supported provenance-preserving recovery/republish using original producer evidence. Alternative: a newly authorized producer run republishes unchanged candidate with valid binding, at the cost of a new revision and review handoff. Never hand-edit CR metadata or infer authority from this review. The current run is forbidden to start successors, and reviewer role cannot manufacture producer ownership.

Recommendation: retain the exact tree and all current evidence; repair only the CR provenance/control-plane lifecycle. Route this task blocked, not done or integrating. This is an ownership/platform gate, not a product-code defect. No user decision about VPN activation or implementation is needed.
