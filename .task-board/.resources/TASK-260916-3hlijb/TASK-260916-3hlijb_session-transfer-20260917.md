# Relux Tunnel \u2014 parked session transfer, 2026-09-17

You are resuming the primary orchestrator for `/Users/iv/Developer/relux-tunnel`.
Read this as historical evidence, then verify current state. Do not assume any run is still active or restart a cancelled run automatically.

## User intent and current boundary
The user requested: finish and land active tasks, curate all pending changes without loss, obtain a clean synchronized working tree, publish a signed Git tag and GitHub prerelease explicitly marked WORK IN PROGRESS, and explain progress toward completing the macOS VPN epic. The latest instruction additionally requested an upstream issue for alias admission, then parking and a detailed transfer prompt.

The upstream issue is complete: https://github.com/relux-works/skill-project-management/issues/297 . The remaining delivery milestone is NOT complete. Work is parked with a real capacity blocker. No owned worker remains running. Do not start unrelated backlog. Resume execution only when the new session is instructed to continue; otherwise report the parked state.

Long-term goal: working signed/notarized macOS VPN client using NEPacketTunnelProvider, external authenticated SSH transport, libssh2 primary. iOS is deferred. SPM core, packet bridge/HEV/lwIP, TCP/internal SOCKS, fail-closed DNS, relay and runtime/provider composition are part of the broader roadmap. A working system VPN has NOT been demonstrated.

## Non-negotiable execution rules
- Read `/Users/iv/.codex/skills/project-management/SKILL.md` and relevant project instructions first.
- Use curator task-board from the original repository main checkout. Source tooling repo: `/Users/iv/Developer/ReluxWorks/skill-project-management`.
- Product commands MUST use `TASK_BOARD_CONFIG=/Users/iv/Developer/relux-tunnel/.temp/resume-20260916/task-board.config.json` until separately reviewed permanent synchronization lands. Root task-board.config.json remains stale (Sol-only and revoked commit windows).
- Do NOT carry the product TASK_BOARD_CONFIG into the tooling source repo. Use that repo's own configuration there.
- One owned worker at a time. Sequential producer \u2192 independent reviewer \u2192 rework \u2192 accepted. Implementation Muse Spark 1.3 max; reviewer Astra low or Fable 5.1 low. Lite context.
- `muse-spark` is the registered alias of `muse-spark-1.3-contributor`, with max effort. Alias use was verified against the launched versioned model; it is not a downgrade. Do not use unregistered `muse-spark-1.3`.
- Fresh spawn preflight with explicit task class, model/effort, snapshot digest and rationale where required. Avoid duplicate or blind recovery runs.
- Author Ivan Oparin <oparin@me.com>, SSH signing key `/Users/iv/.ssh/ivanopcode`, current timestamps. Explicit signed commits and signed tags; verify objects before publication.
- Branch \u2192 PR \u2192 actual hosting-platform review \u2192 real green required checks \u2192 exact signed-head landing. Preserve signed objects; no squash/rebase platform replacement, force default, fake statuses or weaker checks.
- NEVER install, configure, enable, connect or run an actual VPN on this Mac; NEVER change routing. Real VPN verification needs a dedicated host.
- Preserve all foreign changes, worktrees, stashes and evidence. No broad reset/clean/stage-all or hidden-stash claims of cleanliness. User authorizes coherent curation of accumulated changes, not loss.
- Cache cleanup only for proven disposable inactive targets, with exact target/size report. Do not clean unrelated home/Developer content or stop other users' workers.
- Never manually move managed Story refs or hand-commit on a managed Story branch. Use supported checkpoint/integrate/close-landed procedures and actual evidence.
- Source tooling is edited in its source repository, not installed ~/.agents or curator cache. Refresh only after reviewed signed delivery. Do not replace a session manager from a manager-hosted session.

## Product delivered state
Fresh remote read at parking confirmed main = origin main = `db89c1a555fd4cf57a1cba7fe7bf998f6951b1f2`.
PR #6: https://github.com/relux-works/relux-tunnel/pull/6 is MERGED at this exact signed head (2026-09-16 13:40:52 UTC).
Independent Astra platform COMMENTED review accepting exact head: https://github.com/relux-works/relux-tunnel/pull/6#pullrequestreview-5223410566 . COMMENTED is the actual mechanism because GitHub does not permit author self-approval; no invented identity.
Prelanding hosted run `35098918403`: 7/7 jobs succeeded.
Tree: `1c1ca7ad20e27e03f003cb3ea0bc466db45fe9e0`.
Seven introduced signed commits locally/remotely verified: db89c1a (native Xcode selection), d45c85d (weak let\u2192var), 310a560 (wifiAware SDK compiler guard), a46e2ba (Sendable/cancellation), 018c9d9 (CI diagnostics), 87451b5 (board), 6e8a198 (Shared Runtime), parent b3422b0.
The old wifiAware blocker IS FIXED AND LANDED; do not recreate it.

Postlanding run `35103482648` failed 6/7: `LibSSH2BridgeTests.swift:380`, transport close with teardown ignoring cancellation observed 1.17695875 seconds versus required <1 second. 517 tests / 44 suites; 26 issues including 25 known. Builds/contracts passed. This separate regression is `BUG-260916-3t6wfs` (backlog under STORY-260715-anxje6). Do not blindly increase the threshold or label it harmless flakiness.
Evidence: `.temp/resume-20260916/post-landing-ci-failure-18.log`, `.temp/resume-20260916/post-landing-35103482648/logs/swift-testing.log`, artifact 10450071582 `credential-free-generated-project-35103482648`.

## Product pending scopes and preservation
- `TASK-260715-3t2v9w`, SSH bootstrap candidate in `.temp/STORY-260715-2wjwuf/worktree`, unreviewed/unpublished. Preserve, do not reimplement. Earlier local report: 540 tests / 46 suites passed with 25 known issues, 387 core and 5 new endpoint tests. This is local evidence, not acceptance.
  Changed files: SSHContracts.swift, LibSSH2Transport.swift, MacOSProductionSSHBootstrap.swift, MacOSProductionRuntimeOwnershipTests.swift, SSHTransportContractTests.swift, LibSSH2AdapterIntegrationTests.swift, new ProfileDrivenSSHBootstrapTests.swift.
  Backups `.temp/resume-20260916/bootstrap-parked-19.patch` and `ProfileDrivenSSHBootstrapTests.parked.swift`.
  RUN-260916-1e2630 cancelled on original user pause. RUN-260916-fcfd99 failed before execution due queued config propagation. No active product run at parking.
- `STORY-260916-1tc84x` under EPIC-260715-w5gzf4:
  `TASK-260916-3hlijb` owns curation, clean checkout, signed WIP release and progress report (backlog; not completed).
  `TASK-260916-39riah` separately reviews permanent config synchronization (backlog; not started).
- Root had 257 `git status --porcelain` records before final parking metadata additions. Recount; do not treat this number as immutable. All accumulated board changes remain.
- Two LOGBOOK-only stashes remain:
  `resume-20260916 preserve landing logbook before bootstrap spawn` and
  `resume-20260916 preserve delivery and audit logbook before managed spawn`.
  Backups `.temp/resume-20260916/logbook-preserved-07.patch`, `logbook-stash-08.txt`, `logbook-landing-preserved-16.patch`, `logbook-landing-stash-17.txt`. Compose and review, do not drop.
- All prior worktrees remain, including release reproducibility material `TASK-260715-pa6evr`.
- Historical obligations for done TASK-260715-135rr8 rev4, TASK-260715-2jatnd rev2, TASK-260715-intsjz rev1, TASK-260830-1x524u rev3 were reverified with supported close-landed. Results already done, evidence reverified, nothing written. Accepted ledger entries do not imply undelivered code. Do not manually clear them.
- No GitHub release exists as of the final read; no new WIP tag was created in this session.

## Active prerequisite tooling fix \u2014 now BLOCKED and parked
Source repo `/Users/iv/Developer/ReluxWorks/skill-project-management`.
Story `STORY-260916-26b6ba`, bug `BUG-260916-1r4nqj` (status blocked).
Root cause: spawnRunnerBoardEnvironment stripped TASK_BOARD_CONFIG and frozen runtime/control bindings before queued admission; queued runner read stale root policy rather than frozen explicit operational config.
Candidate restores existing `remoteconfig.RuntimeControlEnvironment` from `runtimeControlIdentityFromManifest` after selector stripping; 13 additions / 4 deletions in runtime.go plus two regression test files:
- tools/board-cli/internal/spawnruntime/runtime.go
- tools/board-cli/cmd/spawn_queued_frozen_config_test.go
- tools/board-cli/internal/spawnruntime/queued_frozen_identity_test.go
Worktree `.temp/STORY-260916-26b6ba/worktree` in the SOURCE repo.
No independent review, checkpoint, PR, landing or installed refresh has happened for this candidate.

Source baseline initially c88024a7862c3b9edd58a7fc91e5720bc430f61a. Source main moved concurrently to at least 027f1d20ea7462d7e14365d778c4e13b946ee089 due unrelated work; fetch/check current refs before any delivery. Preserve foreign source tasks/worktrees. Former branch codex/source-board-recovery-inputs was preserved.

Runs:
- RUN-260916-a0a99c: alias mismatch rejection before implementation.
- RUN-260916-b7816c: initial Muse producer, cancelled when its too-short 25-minute budget was expiring; candidate preserved.
- RUN-260916-44475a: continuation; scoped tests, mutant proof, build/vet passed. All 376 spawnruntime tests passed across four partitions (65/109/121/81). Handoff then triggered native full CR validation.
- CR-BUG-260916-1r4nqj-1 revision 1: native 15-command suite stopped at command 5 (`cmd /^Test[A-F]/`) with ENOSPC. Four commands passed, one failed, ten unexecuted. Manual scoped success is NOT full validation success.
- RUN-260916-4d06af: automatic recovery, cancelled by parent after overbroad disk inventory. No scope expansion accepted.
- RUN-260916-6f3865: bounded validation-only continuation, cancelled by parent at capacity risk; terminal, no automatic restart authorized.

Capacity evidence:
The exact failed A-F shard retried at 2026-09-16 20:04:40 UTC with 15 GiB free. While still running, free space fell to 9.2 then 4.0 GiB. The previous native suite already had real `no space left on device` failures. Parent stopped our run to avoid another full shared disk. The retry is INTERRUPTED, not passed. Other sessions were active and were not stopped. More than 11 GiB of shared free space disappeared during this interval; attribution and full-suite requirement are unknown.
External requirement: stable sufficient disk headroom or an authorized isolated matching validation environment. Do not blindly retry identical conditions or delete unrelated data. Do not invent a precise guaranteed capacity minimum.

Preserved source evidence:
- `.task-board/.resources/BUG-260916-1r4nqj/BUG-260916-1r4nqj_results.md`
- `BUG-260916-1r4nqj_change-request_rev1-validation.log`
- `BUG-260916-1r4nqj_capacity-blocker-and-park.md`
- `.temp/BUG-260916-1r4nqj/preserved-validation-logs/` (12 raw logs)
- `.temp/BUG-260916-1r4nqj/continuation/` earlier candidate backup
- `.temp/BUG-260916-1r4nqj/park-20260917/` latest tracked patch, both untracked test copies, incomplete A-F log and disk-after-cancel snapshot.
Read narrow logs; Muse JSON streams can be huge. Extract selected tool-result descriptions/output rather than dumping entire logs.

## Separate alias defect / issue #297
Local source BUG-260916-36p6qt remains backlog.
Preflight admits versioned muse-spark-1.3-contributor/max but live admission resolves equivalent registered muse-spark/max and raw string comparison reports workload_class_snapshot_stale. Selecting alias launched the exact same versioned model. This is DISTINCT from frozen-config propagation.
Issue proposes canonical authorized identity across preflight/queue/admission/argv, preserving requested spelling and canonical audit identity, deduplicating alias candidates without rotating explicit choices, binding registry/alias target to snapshots, and negative regressions for real provider/version/effort/policy drift. No guard removal, ad hoc replacement table or broadened allowlist. Do not implement it as part of current fix.

## Independent recovery-loop audit
TASK-260916-p5tbh8 is done; original Fable RUN-260916-557125 is not running. Read its `_incident-review.md` resource rather than rerun it.
Findings: contradictory parent DoD/scope was primary; CLI repeatedly retried unsatisfied role handoff. Three retries took about 11m19s. Audit proposes classifying transient/new-defect/scope-conflict, routing decisions to parent, bounded/idempotent retry chains and evidence. Audit did not require green product CI. No broad recovery redesign was implemented here.

## Progress assessment
Do not promote the earlier rough ~60% estimate to a measured figure.
EPIC-260715-3810we functional picture:
- Shared Runtime STORY-260715-1y04r0 delivered.
- SSH STORY-260715-2wjwuf partial; bootstrap candidate still unreviewed.
- TCP STORY-260715-2nqxa5 partial; private SOCKS/direct-channel composition remains.
- DNS STORY-260715-2bfjhn backlog.
- VPN lifecycle STORY-260715-eto58m partial; macOS provider TASK-260715-3dv8ea backlog.
Core/harness, packet bridge, HEV/lwIP and substantial SSH/runtime/relay work exist, but integrated provider, fail-closed DNS, real end-to-end VPN on a dedicated machine and signed/notarized distribution remain unproven. Completion is more than task counts.

## Safe next-session sequence if explicitly resumed
1. Read skill, primary goal (PRIMARY-GOAL-260728-3lhfz3 revision 15 at parking), operational config, worktree obligations, current run lists, git status/stashes and fresh remote main. No native goal API substitution.
2. Confirm no owned run still active and solve stable capacity before tests. Do not restart parked workers blindly.
3. Resume preserved tooling candidate with bounded validation, independent Astra low review, supported CR lifecycle, signed PR/checks/landing and curator refresh. Alias issue stays backlog.
4. Verify operational config propagation, then resume preserved product bootstrap candidate; independent review/rework/acceptance.
5. Diagnose/fix actual product close-time CI bug under its tracked task, review, real hosted checks. Separately synchronize stale root config.
6. Curate all accumulated board and LOGBOOK changes into coherent reviewed scope; preserve and reconcile other worktrees. Signed delivery to exact accepted main; final clean tree check.
7. Publish signed WIP tag and GitHub prerelease with explicit limitations and exact delivered head, never implying a proven production VPN.
8. Report milestone-based progress and park without taking unrelated backlog.

At the parked boundary, these remaining steps are obligations, NOT completed work. Do not claim the user's requested clean tree/release/active-task landing has been achieved.
