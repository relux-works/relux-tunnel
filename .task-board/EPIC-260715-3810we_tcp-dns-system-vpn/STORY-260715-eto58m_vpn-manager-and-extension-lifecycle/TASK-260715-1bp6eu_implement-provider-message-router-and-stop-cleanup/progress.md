## Status
done

## Assigned To
[reviewer] reviewer (codex)

## Created
2026-07-15T01:16:19Z

## Last Update
2026-07-20T23:35:28Z

## Blocked By
- TASK-260715-1q4qhw
- TASK-260715-lovbdz
- TASK-260715-3tlgwm

## Blocks
- TASK-260715-2hiabd
- TASK-260715-3dv8ea
- TASK-260715-3lab1f
- TASK-260715-bf3a2d
- TASK-260715-3btpxm
- TASK-260715-2o2oq0

## Checklist
- [x] Implement bounded versioned provider routing and once-only stop cleanup
- [x] Run malformed concurrent timeout and late-callback tests on both adapters
- [x] Attach task-scoped message and cleanup evidence
- [x] Code written per task description and AC
- [x] Relevant tests written for new or changed behavior and passing
- [x] Lint clean
- [x] Relevant build/validation commands run after changes and build not broken
- [x] New outcome artifact attached on the board with a task-scoped name when the work produces notes, logs, screenshots, or other deliverables
- [x] Important findings, decisions, anomalies, or regressions recorded in logbook when relevant
- [x] Implementation matches AC
- [x] Solution fits project architecture
- [x] Tests green
- [ ] If review does not accept the work — verdict evidence added and status routed by the explicit verdict branches

## Notes
spawn queued: [implementer] developer (codex) (run=RUN-260720-883391, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260720-883391)
Implemented a shared generation-safe provider v1 router and cleanup owner in ReluxTunnelCore; both iOS/macOS seams delegate through it. Added bounded strict read-only routing, exactly-once callback gates, raw stop-reason mapping, stop-wins-start ordering, injected 10-second cleanup with cancellation fan-out/force-close, fatal-failure cancel handoff, privacy-safe diagnostics, and dynamic cleanup handle registration. Shared tests pass through both seams, including malformed/oversized/duplicate/concurrent/late inputs, all stop reasons, startup cancellation and timeout, deadline force-close, failure join, deallocation, and 100-cycle baselines. Verification: focused provider 10/10; provider TSan 10/10; make validate-core 218 tests in 23 suites plus build; strict recursive swift-format lint; git diff --check. Evidence is attached as task-scoped outcome resources; design decisions recorded in LOGBOOK.md entry 0320.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-883391, pid=49626, exit=0)
spawn queued: [reviewer] reviewer (codex) (run=RUN-260720-6f6704, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260720-6f6704)
REVIEW ACCEPTED 2026-07-21. Independent review confirmed all five AC and shared-core architecture fit. Revalidation: provider suite 10/10 PASS; provider TSan 10/10 PASS; make validate-core PASS with 218 tests in 23 suites plus build; strict swift-format lint PASS; git diff --check PASS; task-board validate PASS. Verdict and reviewer logs attached as TASK-260715-1bp6eu_review.md and task-scoped review log resources.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-6f6704, pid=83836, exit=0)

## Precondition Resources
- [TASK-260715-1bp6eu_accepted-inputs.md](file://TASK-260715-1bp6eu/TASK-260715-1bp6eu_accepted-inputs.md) — Accepted lifecycle, models, coordinator, and diagnostics inputs

## Outcome Resources
- [TASK-260715-1bp6eu_spawn-log_-implementer--developer--codex-.log](file://TASK-260715-1bp6eu/TASK-260715-1bp6eu_spawn-log_-implementer--developer--codex-.log) — System spawn log captured by task-board
- [TASK-260715-1bp6eu_results.md](file://TASK-260715-1bp6eu/TASK-260715-1bp6eu_results.md) — Provider routing, cleanup, coverage, and verification summary
- [TASK-260715-1bp6eu_swift-test-provider.log](file://TASK-260715-1bp6eu/TASK-260715-1bp6eu_swift-test-provider.log) — Shared iOS/macOS provider routing and cleanup test evidence
- [TASK-260715-1bp6eu_swift-test-provider-tsan.log](file://TASK-260715-1bp6eu/TASK-260715-1bp6eu_swift-test-provider-tsan.log) — Thread Sanitizer evidence for shared provider seams
- [TASK-260715-1bp6eu_validate-core.log](file://TASK-260715-1bp6eu/TASK-260715-1bp6eu_validate-core.log) — Full core validation and post-test build evidence
- [TASK-260715-1bp6eu_swift-format.log](file://TASK-260715-1bp6eu/TASK-260715-1bp6eu_swift-format.log) — Strict recursive Swift format lint evidence
- [TASK-260715-1bp6eu_spawn-log_-reviewer--reviewer--codex-.log](file://TASK-260715-1bp6eu/TASK-260715-1bp6eu_spawn-log_-reviewer--reviewer--codex-.log) — System spawn log captured by task-board
- [TASK-260715-1bp6eu_review.md](file://TASK-260715-1bp6eu/TASK-260715-1bp6eu_review.md) — Independent reviewer verdict with AC, architecture, and validation evidence
- [TASK-260715-1bp6eu_review-provider-tests.log](file://TASK-260715-1bp6eu/TASK-260715-1bp6eu_review-provider-tests.log) — Independent shared iOS/macOS provider test rerun
- [TASK-260715-1bp6eu_review-provider-tests-tsan.log](file://TASK-260715-1bp6eu/TASK-260715-1bp6eu_review-provider-tests-tsan.log) — Independent Thread Sanitizer provider test rerun
- [TASK-260715-1bp6eu_review-validate-core.log](file://TASK-260715-1bp6eu/TASK-260715-1bp6eu_review-validate-core.log) — Independent full core validation and build rerun
- [TASK-260715-1bp6eu_review-swift-format.log](file://TASK-260715-1bp6eu/TASK-260715-1bp6eu_review-swift-format.log) — Independent strict Swift format lint output (empty on success)
