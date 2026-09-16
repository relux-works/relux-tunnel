# TASK-260916-p5tbh8 independent incident review: TASK-260908-34gi0y recovery loop

Reviewer: Fable 5.1 (tester role), read-only audit. No product, tooling, or board-file changes.
Scope: runs RUN-260916-b63447 -> RUN-260916-d674b7 -> RUN-260916-362667 -> RUN-260916-78331a on TASK-260908-34gi0y.
All times UTC, 2026-09-16. F = fact (cited evidence). H = hypothesis (not proven by evidence read here).

## 0. Verdict in three lines

- F: The loop was produced by the task-board runtime's specified recovery policy: a producer completion that "published no Change Request and reached no handoff branch" is hard-coded `Recoverable: true` and gets an identical successor up to 3 times (runtime.go:2090, 2232-2418 at the incident commit; unchanged on current origin/main).
- F: The worker behaved correctly in every run: honest unchecked gate, evidence attached, real `task-board handoff` attempted and refused (exit 1) four times with byte-identical text. Nothing changed between attempts; runs 2-4 produced no new commit, CI run, or board state.
- The parent's "mainly an orchestration error" claim is not proven as "mainly". The proximate mechanism is CLI policy plus a task definition whose DoD item 1 was unsatisfiable by the worker once CI turned red on a pre-existing defect outside the authorized scope. Orchestrator contribution is real but secondary, and the runtime gave the orchestrator no distinct signal to act on.

## 1. Timeline: facts vs hypotheses

Evidence: `.temp/spawn-runs/RUN-260916-*/{state,manifest}.json` + `events.jsonl`, `.temp/logwork/TASK-260908-34gi0y/*.log`, `.task-board/.activity/TASK-260908-34gi0y/events.ndjson`, task notes via `task-board q 'get(TASK-260908-34gi0y){status notes}'`, `.task-board/.resources/TASK-260908-34gi0y/*`.

| Time | Event | Kind |
| --- | --- | --- |
| 02:16:07 | curator installs `task-board` from skill commit `64d4763aac41` (`.csk-install.json`, recorded `ref: main`). | F |
| 02:26:30 | RUN-260916-b63447 queued by parent session `019f7fb5-...`; manifest: `start_status development`, `end_status to-review`, `require_outcome_artifact true`, explicit override `muse-spark-1.3-contributor:max`, timeout 40m, supervision `on_deadline park`. Run is not goal-bound (`task-board spawn directives` printed "Active Goal: none (run is not goal-bound)"). | F |
| 02:26:36 | worker `set_status(development)` (activity seq 8). | F |
| 02:27:22 | orchestrator nudge (cache cleanup) stored; `ack_state acknowledged` is a storage ack by the runtime, not worker observation. Worker did observe it later in run 1 (results file). | F |
| 02:29:24 / 02:29:28 | `a46e2ba` verified on GitHub; CI run 35048178384 starts; ends `failure`, 6/7 jobs green, `NWError.wifiAware` compile error in `MacOSSSHBootstrapErrorMapper.swift:37`. Original `:687` Sendable failure absent. | F (worker report + attached 685-line job log; not re-fetched from GitHub in this audit) |
| 02:37:05-02:37:13 | worker attaches `_results.md` + CI log, checks items 2,3,4, leaves item 1 unchecked (activity seq 11-15). | F |
| ~02:37:5x | `task-board handoff TASK-260908-34gi0y --role developer` -> `cannot hand off ...: unchecked checklist items [1] (...): handoff evidence missing`, `HANDOFF_EXIT:1` (log b63447, tool result). No activity/ledger event records this refusal. | F |
| 02:38:01-02:38:02 | provider exit 0. Launcher completion path: `evaluateProducerBranchPresence` fails -> signal `role_handoff_unsatisfied`, `recoverable:true` -> `handoffGoalSuccessor` clones the same manifest (same prompt file `260916-06-26-31_...md`, same model), `recovery_attempt 1/3`, predecessor marked `cancelled`, disposition `superseded_by_autonomous_recovery`; task note "spawn autonomous recovery: ... attempt 1/3". | F |
| 02:38:03-02:43:08 | RUN-260916-d674b7: fresh re-verification only, no publish, attaches `_reverify-20260916.md`, handoff refused `EXIT:1`, successor queued (2/3). | F |
| 02:43:08-02:46:18 | RUN-260916-362667: same; attaches `_reverify-run3-20260916.md` (updated once), handoff refused. Worker printed `exit=0` because it piped through `head` (pipe status); the refusal text is identical. Successor queued (3/3). | F |
| 02:46:18-02:49:22 | RUN-260916-78331a: same; attaches `_reverify-run4-20260916.md`, handoff refused `EXIT:1`. `RecoveryAttempt (3) >= maxRecoverySuccessorAttempts (3)` -> `recovery_parked`, run `failed`, element routed `development -> to-dev` (`actionableRecoveryStatus`), operator-action note appended. | F |
| now | TASK-260908-34gi0y status `to-dev`; PR6 open at `a46e2ba`; no wifiAware BUG exists on the board (worker grep in runs 2-4). | F |

Durations: whole chain 22m51s; successor runs 2-4 total 11m19s (02:38:03 -> 02:49:22). Successors did zero state-changing work by design of their own instructions ("do not reimplement", "no new product fixes").

Hypotheses (not verifiable from local evidence): H1 the parent session was alive but not polling run status between 02:27 and 02:49 (no directive, cancel, or board write from the parent in that window; absence of action is not proof of absence). H2 the parent saw only the per-run "spawn autonomous recovery" notes, whose text is identical each time and carries no link to the refusal cause.

## 2. Responsibility matrix

Source read at the incident binary commit `64d4763` (fetched as `refs/pull/278/head`) and compared with `origin/main` `ef6ee162`. Local clone HEAD `b47b0b34` is 104 commits behind origin/main and does not contain `64d4763`; "source main today" below means origin/main.

| Actor | What it did | Defect or specified policy | Evidence |
| --- | --- | --- | --- |
| CLI runtime: signal classification | `evaluateProducerBranchPresence` returns an error for any producer that ends at `development` with no CR and no to-review; caller wraps it as `role_handoff_unsatisfied` with literal `Recoverable: true`. Same literal at the two sibling sites (goal handoff eval, CR construction). | Specified policy, documented: tracked-background-spawn.md "unmet producer handoff status/evidence ... automatically queue a successor" and "capped at three successors ... recovery_parked". Tests pin it: `TestUnsatisfiedDeliveryAcceptanceCreatesAutonomousSuccessor`, `TestRecoverySuccessorChainParksAtBoundThroughExecute`. Design gap: the policy cannot distinguish "worker never tried to hand off" from "worker tried, CLI refused an honestly unchecked gate with evidence attached". | goal_acceptance.go:310-362; runtime.go:1995, 2018, 2090; spawn.go:860 |
| CLI runtime: successor selection | `handoffGoalSuccessor` clones the predecessor manifest unchanged, increments `RecoveryAttempt`, spends shared budget (3) per chain root, appends a note per attempt, parks at the cap and routes to `to-dev`. No precondition fingerprint, no comparison of predecessor vs successor outcome, no check for an identical refusal message. | Specified (budget, parking, routing are tested). Missing behavior: no "changed preconditions" gate. Defect by omission. | runtime.go:2232-2418, 2433-2446, 2650 |
| CLI: `handoff` command | Refuses correctly with typed `ErrHandoffEvidenceMissing`, exit 1. The refusal is not persisted on the run or ledger; runtime later infers "no handoff" from board state only. | Gate correct. Observability defect: the most informative fact in the incident exists only in the worker's transcript. | pkg/board/errors.go:40; activity ledger has no refusal event |
| CLI: notification | Parent gets one board note per attempt with identical wording plus a final operator-action note; element status flips to `to-dev` only at the end. No run-level marker links the note to the unchecked item or to the attached evidence. | Specified. Weak: duplicate-looking notes, no evidence links, no early routing. | task notes; runtime.go:2384-2396 |
| Skill instructions (SKILL.md item 5, statuses.md item 6) | "Early exits and intermediate parked states are retried, or rerouted through a focused child; routine work is never handed to the human." No rule that a retry needs changed preconditions. `blocked` (item 6) is reserved for an "external blocker or human-only decision"; a discovered pre-existing compile defect outside the authorized delta is not named as a qualifying case. | Instruction gap, not contradiction. | SKILL.md:96-108; statuses.md:76-77, 117 |
| Orchestrator (parent) | Authored DoD item 1 = "hosted green on exact head" while the same assignment forbids new product code and says "Stop at to-review". Once CI went red on `wifiAware`, `to-review` was unreachable without falsifying the gate. Chose explicit override muse:max, no goal binding, no directive or cancel during the chain. | Scope contradiction in task design (a dependency the worker was not allowed to fix). Not an "orchestration error" in the runtime sense: no runtime knob lets a parent opt this producer out of autonomous recovery except cancelling the run. | prompt file DoD + resume-delivery.md; state.json `goal_run_signal` |
| Worker (Muse, 4 runs) | Published exact reviewed tree, verified signatures, gathered real CI, attached evidence, left item 1 unchecked, attempted handoff, reported the refusal as the lifecycle constraint the prompt asked for. Runs 2-4 correctly declined to redo work. Minor: run 3 reported `exit=0` for a refused handoff (pipe artifact); did not try `set_status(blocked)` with an evidence packet (H: unclear whether the prompt's "Stop at to-review" permitted that). | No defect. | results/reverify resources; handoff tool results |

## 3. Clean current workaround (supported operations only)

Goal: preserve the reviewed signed head `a46e2ba`, keep the red gate red, stop the unchanged-condition loop, and route the real dependency.

1. Orchestrator creates a scoped BUG for the `NWError.wifiAware` compile failure (own diagnosis/review/green cycle), with the 685-line job log as precondition resource.
2. `link(TASK-260908-34gi0y, blocked_by=BUG-...)` and `set_status(TASK-260908-34gi0y, status=blocked)` with a notes packet: constraint (exact-head CI red from pre-existing blob `5b47bd80`, outside authorized delta), evidence (run 35048178384, job 104642534222), attempts (4 runs, identical refusals), options (repair BUG then republish PR6 with a new signed head -> new exact-head review -> new CI). `any -> blocked` is allowed for anyone per statuses.md; `blocked` lifts automatically when the last blocker is done. Checklist item 1 stays unchecked; acceptance of 34gi0y is not altered.
3. Do not spawn another developer on 34gi0y until the BUG is done. The next producer run then has genuinely changed preconditions (new commit on PR6) and a reachable to-review.
4. Do not use `check_item(1)`, `set_status(to-review)`, or a local mirror as a substitute for hosted green. Do not cancel/rewrite the signed head.

## 4. Minimal P0/P1 changes

P0 (CLI, `tools/board-cli/internal/spawnruntime`, `pkg/board`):
- P0-1 Persist the handoff refusal. When `task-board handoff` refuses inside a spawned run (`TASK_BOARD_RUN_ID` set), write a typed run marker `handoff_refused{unchecked_items, evidence_present, outcome_digest, refusal_text_sha256}` (reuse the existing run-marker mechanism covered by `handoff_marker_test.go`) and a ledger event on the element.
- P0-2 Typed producer dispositions instead of one `role_handoff_unsatisfied`: `handoff_missing` (no attempt, no marker) stays recoverable; `handoff_refused_unchecked_gate` (marker present, new outcome attached) is non-recoverable: route element to `to-dev` immediately with a note that names the unchecked items and the attached evidence, no successor. `dependency_discovered` / `scope_contradiction` are worker-declared (see skill P0-3) and map to `blocked` with the packet; `transient_failure` remains recoverable.
- P0-3 No-progress fingerprint before cloning a successor: (prompt digest, element status, checklist check-state, set of outcome resource names+digests, CR revision, refusal_text_sha256). If equal to the predecessor's terminal fingerprint, park at attempt 1 with `recovery_parked_no_progress`. Limitation: the fingerprint cannot see external state (CI rerun, remote refs); therefore keep an explicit escape: `task-board spawn restart RUN --transient-retry "reason"` records the justification and bypasses the fingerprint once. Budget stays shared per `recovery_root_run_id` (already implemented).
- P0-4 Idempotent escalation: one operator-action note per chain (keyed by root run id), updated in place with attempt count and links, instead of N similar notes.

P0 (skill text):
- SKILL.md item 5: "retry only when a precondition changed (new commit, new evidence, new dependency state) or with an explicitly justified transient retry; an identical refusal is a routing fact, not a retry trigger."
- Worker guidance (roles.md / sub-agent-templates.md): when a DoD gate depends on an external state that is red for a cause outside the authorized scope, attach evidence, then move to `blocked` with the packet and name the dependency (the runtime already treats `blocked`+new evidence as a Stop-The-Line boundary in `evaluateGoalStopBoundary`).
- Orchestrator guidance: on a `role_handoff_unsatisfied` note, read `task-board spawn status RUN` and the last outcome before letting recovery continue; cancel the chain when the refusal is evidence-backed.

P1:
- `task-board spawn status RUN` / TUI: show chain fingerprint, refusal marker, attempt n/3, and links to the outcome resources.
- Resume: `task-board spawn resume-chain ROOT-RUN --reason` that requires a changed fingerprint or explicit transient justification.
- Parent notification through the terminal-notice path (commit `64d4763` itself is "deliver terminal notices in-turn to a hosted Codex primary"); whether that notice reached the parent here is unknown (no notice artifact found locally; not the same as "not delivered").

## 5. Regression matrix

| # | Scenario | Expected after P0 | Negative test |
| --- | --- | --- | --- |
| R1 | Provider crash exit non-zero, no handoff attempt, no marker | recoverable, successor 1/3 | must NOT park with `no_progress` |
| R2 | Worker finished, attached outcome, forgot `handoff` | `handoff_missing`, recoverable, successor; successor's fingerprint differs (no marker vs marker) | |
| R3 | Handoff refused for unchecked gate, new evidence attached (this incident) | `handoff_refused_unchecked_gate`, no successor, element -> to-dev, single note | test fails if a successor is queued |
| R4 | Handoff refused, identical refusal twice in a row after an authorized transient retry | park at once with `no_progress` | |
| R5 | Handoff refused, then remote ref / CR revision changed before completion | fingerprint differs, successor allowed | |
| R6 | Worker declared `blocked` + evidence packet (dependency discovered) | Stop-The-Line boundary, no successor, no `to-dev` routing | must fail if recovery clones a successor |
| R7 | Worker set `blocked` without new evidence | refused as today ("requires a new or updated task-scoped evidence packet") | |
| R8 | New code defect: worker produced a new CR revision, validation fail-sticky | existing `changes_requested` path, recoverable retry naming the transcript resource | |
| R9 | Unreadable board / missing marker file | report unknown, keep run queued/failed with read error; never infer "no handoff" | |
| R10 | Parent offline during chain | element routed and single note written idempotently; a second routing attempt does not duplicate the note | |
| R11 | Duplicate notes: 3 attempts | exactly one operator-action note per chain root | |
| R12 | agy or provider-limit signals | unchanged: no successor via this path | |

## 6. Rollout and first implementation slice

Compatibility: no `q`/`m` grammar change; new run-state fields are additive JSON; old runs without the marker keep today's behavior (`handoff_missing`). Config: `spawn.recovery.require_changed_preconditions` default `true` in the next release with a one-release opt-out; fits `spawn-policy-v4` without schema break.

First slice (no generic framework):
1. `pkg/board` handoff error already typed; add marker write in the `handoff` command when `TASK_BOARD_RUN_ID` is set (call site: cmd handoff -> spawnruntime marker store).
2. `evaluateProducerBranchPresence` reads the marker; return a typed `producerHandoffRefused` error; at runtime.go:2088 map it to `Recoverable: false` and `failSpawnRunAndRouteElement` with the note.
3. Tests: R3 (negative: no successor), R2 (positive: successor still queued), R11 (one note). Prove the bound by narrowing: a marker without `evidence_present` must still be treated as `handoff_missing`.
4. Skill text edits from P0 (skill) above, in the same PR.

## 7. Are the "11 minutes wasted" and blame claims proven?

- 11m19s of successor wall clock (02:38:03 -> 02:49:22) is proven. That runs 2-4 changed no repository, CI, or board gate state is proven. Calling it waste is fair for the gate; the reverify reports do have marginal evidentiary value (fresh remote checks), so "100% waste" overstates.
- Token or cost waste: unproven. The four run logs contain no usage records (0 matches for usage/token fields). Do not claim savings.
- Blame: worker not at fault. CLI policy is the proximate mechanism and is specified, tested, and unchanged on current origin/main. Orchestrator contributed an unsatisfiable DoD under the given scope and did not intervene, but had no runtime signal distinguishing this case from a crashed worker. "Mainly orchestration error" is therefore not proven; "specified runtime policy meeting a scope contradiction" fits the evidence.

## Provenance notes

- Installed binary: `/Users/iv/.curator/global/bin/task-board` -> cache `605a05c7...`, built from skill commit `64d4763aac410cb4104e368553dfd1aefa1b0f01` (PR #278 head, ancestor of origin/main, 9 commits behind `ef6ee162`). `.csk-install.json` records `ref: main`, which is imprecise. `task-board --version` prints `dev`.
- Skill source clone `/Users/iv/Developer/ReluxWorks/skill-project-management`: clean, branch main at `b47b0b34`, 104 commits behind origin/main; the incident commit was fetched read-only for this audit. Recovery sites diff-clean between `64d4763` and `origin/main`.
- Worker-side facts on PR6/CI were taken from attached resources and transcripts; GitHub was not re-queried here.
