# TASK-260715-whtdsf review verdict — CR revision 4

Verdict: **ACCEPTED**.

Reviewed base commit: `b3422b05226253a17676b9b84c764071fe3dbe74`.
Reviewed candidate tree: `f81f9fb166e451b886ee1c1f1120fee301564710`.
Reviewed patch SHA-256: `663ad6ec827ba878eb043dbc2b5a72a4dea206414bcc20d11b02eae10668d89a`.

## Acceptance findings

1. The 26 workflow/job inventory rows cover the current seed, PR/merge checks, trusted release preparation, relay staging, macOS release, and deferred iOS registry. Each active job states actor/input trust, token/environment/secrets, real runner network capability plus authorized use, outputs/retention, and approval.
2. Pull-request and merge-queue jobs are consistently `contents: read`, environment-free, secret-free, credential-free, and non-publishing. Public hosted-runner egress is truthfully inventoried rather than claimed absent.
3. Nine exact merge-blocking checks are named. The 18-row traceability matrix assigns exactly one primary blocking check per epic requirement and names downstream plus macOS/iOS/relay/security/review ownership. All 27 referenced task IDs resolve on the authoritative board and the dependency from this task to accepted architecture task `TASK-260715-32umrc` is satisfied.
4. Forked code, mutable actions, cache poisoning, artifact substitution, tag/workflow spoofing, reruns, cancellation/runner loss, concurrent releases, and compromised low-privilege credentials all have fail-closed behavior and named production call sites with rejecting fixtures.
5. Revision 4 closes the revision 3 blocker. Release preparation no longer has tag/push, `repository_dispatch`, selectable-ref dispatch, or candidate-controlled upstream-workflow authority. It starts from default-branch `issues: opened`; the external requester is bounded to `Issues: write`; mutable issue fields remain untrusted; event bytes, sender/App identity, request identity, candidate ancestry, tag absence, workflow SHA, and policy digest are independently bound before candidate acceptance. Current official GitHub documentation supports the default-branch event, issue permission, external-App trigger, token-default, hosted-runner egress, and full-SHA reusable-workflow premises.
6. Gate A0, Linux-runner requirements for the macOS prototype, iOS/TestFlight/App Store execution, and workflow implementation remain explicitly out of scope. Human ratification stays decoupled at `TASK-260717-2d308k` and blocks publication, not downstream implementation of the accepted draft.

## Reviewer-run evidence and real exits

- Required reviewer status mutation: exit 0.
- First `accept_cr` attempt with the pre-existing generic verdict resource: exit
  1 with `change_request_evidence_missing`; the board correctly refused evidence
  whose current-run provenance was not recorded. This revision-scoped verdict is
  newly produced and attached by the current reviewer run for the retry.
- Tool readiness (`task-board`, `git`, `rg`, PlantUML 1.2026.6, `xmllint`): exit 0.
- Exact patch materialization and SHA-256: exit 0; digest matches the assigned revision.
- Candidate integrity: exit 0; all five working-tree blobs equal their candidate-tree blobs.
- `git diff --check base tree`: exit 0.
- Contract checker: exit 0; `inventory_rows=26`, `required_checks=9`, `trace_rows=18`, trusted entry/threat/self-contained-row checks pass.
- Negative contract harness invoked correctly with `sh`: exit 0; five narrowed mutants were rejected (repository dispatch, requester `Contents: write`, cross-row `Same`, missing retention, and missing runner/network capability). A prior direct execution attempt returned exit 126 because the scratch script has no executable bit; it is not counted as gate evidence.
- Referenced task resolution: exit 0; 27/27 IDs resolve.
- PlantUML `-checkonly`, independent SVG and PNG renders, XML validation, and fresh-to-candidate SVG byte comparison: exit 0. Manual inspection found the diagram focused, internally consistent, and readable at original resolution. A first combined multi-format render produced only PNG and therefore XML/compare exits 1/2; separate format invocations corrected the command and are the accepted evidence.
- Local authority and diagram link readability: exit 0.
- Independent current GitHub documentation verification: pass; notes and exact primary links are in `.temp/TASK-260715-whtdsf/review-rev4/platform-evidence.md`.

## Residuals, explicitly not reported green

- `task-board validate --json`: process exit 0, but content is `valid=false` with one `PARENT_STATUS_MISMATCH` for `STORY-260715-anxje6` (`analysis` versus child aggregate `to-review`). This is external board lifecycle state, not a candidate-path change; it directly validates the contract's requirement that `policy/board-spec` parse content and reject reported issues instead of trusting process exit.
- `sh scripts/tests/test-credential-free-validation.sh`: exit 1 because the unchanged test expects deferred `ReluxProxyIOSUITests` and `ReluxProxyMacUITests`, while the accepted active graph exposes six macOS-only schemes. The script, graph, and workflow implementation are outside the five-path documentation/diagram delta. Relevant contract and diagram checks are green; no product build/test result is inferred.
- `references/negative-evidence.md` is absent from the repository and installed skill trees. Its content remains unknown. The assignment's explicit negative-evidence rules were applied directly, and section 8 binds downstream tests to actual production validators/jobs rather than treating the documentation mutants as implementation evidence.
- Workflows, real API-permission denials, protected environments, endpoint egress controls, and publication remain downstream implementation and test obligations. Human ratification remains mandatory before publication.

Disposition: accept Change Request revision 4 using this revision-scoped evidence
and park `TASK-260715-whtdsf` at `to-review` for the commit-owning orchestrator.
Reviewer supplies no `commit_ack`.
