# Accepted rev3 delivery constraint

Outcome: NOT LANDED. Task remains integrating. No integration transaction was opened. No successor started.

## Independently observed
- Required initial set_status integrating returned exit 0 (integrating -> integrating).
- Story HEAD is 9bf4d0892db03035b989a4c040cfee37636ff8df. Candidate tree object 0ca11378213cc02a78eeac937f94aef6c5209545 exists. This run did not independently revalidate the full candidate tree or repeat technical suites; previous positive acceptance is inherited from the assignment, not a new review verdict.
- Existing modifications remain in LOGBOOK.md, scripts/tests/test-credential-free-validation.sh, and task-board.config.json. Preserved diff: .temp/TASK-260830-1x524u-delivery/preserved-diff-01.patch. No product edits, commits, branch switches, resets, pushes, VPN commands, route changes, or DNS changes were performed.
- Explicit TASK_BOARD_CONFIG remains /Users/iv/Developer/relux-tunnel/.temp/deadline-20260908/task-board.config.json.
- Git identity reads Ivan Oparin <oparin@me.com>, signing key /Users/iv/.ssh/ivanopcode. Signing was not exercised because no commit was authorized under the incompatible delivery semantics.
- task-board worktree transaction show STORY-260715-1y04r0 returned exit 0: No integration transaction is recorded.

## Exact incompatible contract
Command inspected (exit 0): task-board worktree integrate --help.
It lands ONE squash commit on trunk and a second board-only commit. Only one --commit-time argument exists.
Source repository: /Users/iv/Developer/ReluxWorks/skill-project-management, observed HEAD 14e2483be64c817a76a19ac8dd5608e717e56285. Installed CLI reports task-board version dev; source/build equivalence was not established, but installed help and installed skill agree on this contract.
- tools/board-cli/internal/integration/integrate.go:354-359 uses withDates(commitTime), then signed commit-tree of CandidateTreeOID with one trunk parent.
- integrate.go:387 persists that value as ResolvedCommitTime.
- integrate.go:818-823 uses withDates(txn.ResolvedCommitTime) for the signed board commit.
- Installed project-management/references/statuses.md:386-393 explicitly applies the same timestamp to both commits and discards internal checkpoints instead of replaying them.
- Installed references/tracked-background-spawn.md:709-715 confirms identical timestamps.

This cannot meet the requested >= 1 minute chronological spacing for every commit, nor preservation of reviewed signed checkpoint objects. The documented operation also advances local trunk before a canonical hosted PR acceptance sequence. No flag documented by the installed command provides a prepare/publish/review/exact-head-finalize mode.

No mutating integrate command was attempted: this is a preflight contract incompatibility, NOT a claimed runtime refusal. Changing dates after creation, manually editing transaction metadata, or hand-committing the Story would violate explicit instructions.

## Minimal supported recovery
Correct the shared tool at its source: add a durable prepare-and-finalize delivery route that preserves accepted signed ancestry, supports separately persisted chronological commit times with >=60 seconds spacing and the Tbilisi night-window gate, prepares a non-default branch for real PR review/checks, and finalizes only the exact verified signed head after authoritative landing. Preserve immutable producer binding, validation, foreign board paths, CAS and recovery semantics. Add negative tests for equal/reversed/out-of-window dates and head drift; retain signatures through publication.
Do not implement a project-local workaround. The active managed session must not install/replace the task-board runtime (project-management SKILL.md invariant 14); deployment must occur outside hosted sessions. No tool correction, installation, migration or successor was started in this run.

## Handoff
The latest delivery assignment requires keeping integrating and permits only the integration transaction to write done. AC delivery is unmet; ordinary producer handoff/republish was therefore not invoked, to preserve accepted rev3. Resume supported producer-bound delivery after the shared-tool contract is corrected. No human product decision or VPN action is needed. This is durable incomplete-delivery evidence, not completion or a fresh acceptance.

## Read failures
Initial unsupported query change_request(...) and invalid resources projection produced parse errors. Recovered with scoped schema and get overview/review; these failures are not evidence of missing CR/resources. No CR metadata was edited.
