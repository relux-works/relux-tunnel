## Status
done

## Assigned To
[reviewer] reviewer (codex)

## Created
2026-07-15T01:16:19Z

## Last Update
2026-07-21T00:47:04Z

## Blocked By
- TASK-260715-1q4qhw
- TASK-260715-lovbdz

## Blocks
- TASK-260715-1rsqrh
- TASK-260715-3lab1f
- TASK-260715-3btpxm
- TASK-260715-6qqmsz

## Checklist
- [x] Implement idempotent owned-manager persistence with least data
- [x] Run unrelated-manager stale-object conflict and secret-exclusion tests
- [x] Attach task-scoped implementation and persistence evidence
- [x] Code written per task description and AC
- [x] Relevant tests written for new or changed behavior and passing
- [x] Lint clean
- [x] Relevant build/validation commands run after changes and build not broken
- [x] New outcome artifact attached on the board with a task-scoped name when the work produces notes, logs, screenshots, or other deliverables
- [x] Important findings, decisions, anomalies, or regressions recorded in logbook when relevant
- [x] Implementation matches AC
- [x] Solution fits project architecture
- [x] Tests green
- [x] If review does not accept the work — verdict evidence added and status routed by the explicit verdict branches

## Notes
spawn queued: [implementer] developer (codex) (run=RUN-260720-ed15eb, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260720-ed15eb)
Implemented shared injectable owned-manager repository with thin iOS/macOS NetworkExtension clients. Evidence: 18 focused tests; make validate-core passed 236 tests/24 suites plus build; strict recursive Swift format lint clean; iOS Simulator and macOS Xcode builds succeeded. Production identities intentionally fail closed pending TASK-260715-ypo7yo. Outcome summary and four validation logs attached; decision recorded in LOGBOOK.md.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-ed15eb, pid=93649, exit=0)
spawn queued: [reviewer] reviewer (codex) (run=RUN-260720-a43a43, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260720-a43a43)
REVIEW CHANGES REQUESTED 2026-07-21. Future manager-contract versions above UInt16.max are misclassified as repairable corruption and can be downgraded; explicit enable can save during connecting/reasserting/disconnecting and skips the normative save/reload path when already enabled; required unrelated stale-object and distinct reload-persistence tests are absent. Independent focused and full validation passed: 18 focused tests, 236 tests/24 suites, build, strict format lint, and diff check. Full evidence: TASK-260715-15vkvz_review-01.md.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-a43a43, pid=8924, exit=0)
spawn queued: [implementer] developer (codex) (run=RUN-260720-96679d, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260720-96679d)
Rework 01 addresses all reviewer findings: future manager versions retain full Int values through stable updateRequired errors; explicit enable rejects connecting/reasserting/disconnecting with zero writes and still saves/reloads when already enabled; stale replacements are freshly revalidated; and post-save verification uses distinct fake manager instances and rejects noncanonical persistence. Evidence: TASK-260715-15vkvz_rework-01-results.md. Validation: focused 23 tests, full 241 tests/24 suites plus build, strict format/diff/board checks, and iOS Simulator/macOS host-seam builds all pass.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-96679d, pid=12075, exit=0)
spawn queued: [reviewer] reviewer (codex) (run=RUN-260721-e35f00, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260721-e35f00)
REVIEW CHANGES REQUESTED 2026-07-21 (review 02). The prior review-01 findings are closed for the covered Int fixtures, transition paths, stale replacements, and distinct reload verification. Two P1 blockers remain: the actor is reentrant across preference callback awaits and therefore does not satisfy per-process operation serialization; and both Apple adapters coerce every non-Boolean NSNumber via intValue, so 1.5 becomes current version 1 and UInt64.max becomes repairable -1. Existing focused/full/build/lint gates pass, but deterministic concurrency and platform NSNumber seam tests are required. Full evidence: TASK-260715-15vkvz_review-02.md.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-e35f00, pid=20209, exit=0)
spawn queued: [implementer] developer (codex) (run=RUN-260721-ac0f5b, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260721-ac0f5b)
Rework 02 implemented: FIFO non-reentrant operation gate covers every repository entry point and concurrent zero-manager ensure; iOS/macOS seams exactly preserve signed/unsigned NSNumber manager versions and reject Bool/fractional type confusion with zero writes. Focused 27 tests, focused TSan 27 tests, make validate-core 245 tests/24 suites plus build, strict format/diff/board validation, and both platform builds pass. Evidence: TASK-260715-15vkvz_rework-02-results.md; decision/anomaly recorded in LOGBOOK.md.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-ac0f5b, pid=25521, exit=0)
spawn queued: [reviewer] reviewer (codex) (run=RUN-260721-035ab8, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260721-035ab8)
REVIEW CHANGES REQUESTED 2026-07-21 (review 03). Rework 02 closes operation serialization and exact NSNumber decoding, and all focused/TSan/full/lint/board/platform-build gates pass. One P1 callback-order race remains in both platform terminal-status observers: status is read before NEVPNStatusDidChange registration, so a terminal transition in that gap is lost and explicit disable/remove can falsely return stopTimedOut. Add race-safe registration/recheck plus deterministic ordering/retirement tests. Full evidence: TASK-260715-15vkvz_review-03.md.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-035ab8, pid=32479, exit=0)
spawn queued: [implementer] developer (codex) (run=RUN-260721-ac9326, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260721-ac9326)
Rework 03 closes the Apple terminal-status lost-notification race: both adapters register before the authoritative status read and retire a synchronously delivered pre-token callback exactly once. The two-platform deterministic matrix covers terminal-before/during registration, notification-first, duplicate/late delivery, cancellation, and retirement. Focused normal/TSan runs pass 33 tests; make validate-core passes 251 tests/24 suites plus build; strict format/diff/board checks and generic iOS Simulator/macOS builds pass. Evidence: TASK-260715-15vkvz_rework-03-results.md and attached logs.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-ac9326, pid=37383, exit=0)
spawn queued: [reviewer] reviewer (codex) (run=RUN-260721-00d25f, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260721-00d25f)
REVIEW ACCEPTED 2026-07-21 (review 04). Rework 03 closes the remaining iOS/macOS terminal-status lost-notification race with observer-before-read ordering and locked exactly-once token retirement. Independent focused normal and TSan runs pass 33 tests; make validate-core passes 251 tests/24 suites plus build; strict format, diff, and board checks pass; attached iOS/macOS build logs end in BUILD SUCCEEDED. Full evidence: TASK-260715-15vkvz_review-04.md.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-00d25f, pid=52279, exit=0)

## Precondition Resources
- [TASK-260715-15vkvz_accepted-inputs.md](file://TASK-260715-15vkvz/TASK-260715-15vkvz_accepted-inputs.md) — Accepted manager lifecycle and runtime-model implementation inputs
- [TASK-260715-15vkvz_rework-01.md](file://TASK-260715-15vkvz/TASK-260715-15vkvz_rework-01.md) — Reviewer-required future-version, transition, and fresh-reload corrections
- [TASK-260715-15vkvz_rework-02.md](file://TASK-260715-15vkvz/TASK-260715-15vkvz_rework-02.md) — Reviewer-required non-reentrant operation gate and exact NSNumber decoding
- [TASK-260715-15vkvz_rework-03.md](file://TASK-260715-15vkvz/TASK-260715-15vkvz_rework-03.md) — Reviewer-required race-safe terminal status observation on both Apple seams

## Outcome Resources
- [TASK-260715-15vkvz_spawn-log_-implementer--developer--codex-.log](file://TASK-260715-15vkvz/TASK-260715-15vkvz_spawn-log_-implementer--developer--codex-.log) — System spawn log captured by task-board
- [TASK-260715-15vkvz_results.md](file://TASK-260715-15vkvz/TASK-260715-15vkvz_results.md) — Implementation summary and persistence evidence
- [TASK-260715-15vkvz_validate-core.log](file://TASK-260715-15vkvz/TASK-260715-15vkvz_validate-core.log) — Full core boundary, dependency, 236-test, and build validation
- [TASK-260715-15vkvz_ios-build.log](file://TASK-260715-15vkvz/TASK-260715-15vkvz_ios-build.log) — iOS Simulator host seam Xcode build
- [TASK-260715-15vkvz_macos-build.log](file://TASK-260715-15vkvz/TASK-260715-15vkvz_macos-build.log) — macOS host seam Xcode build
- [TASK-260715-15vkvz_swift-format-lint.log](file://TASK-260715-15vkvz/TASK-260715-15vkvz_swift-format-lint.log) — Strict recursive Swift format lint evidence
- [TASK-260715-15vkvz_spawn-log_-reviewer--reviewer--codex-.log](file://TASK-260715-15vkvz/TASK-260715-15vkvz_spawn-log_-reviewer--reviewer--codex-.log) — System spawn log captured by task-board
- [TASK-260715-15vkvz_review-01.md](file://TASK-260715-15vkvz/TASK-260715-15vkvz_review-01.md) — Independent reviewer changes-requested verdict and validation evidence
- [TASK-260715-15vkvz_rework-01-results.md](file://TASK-260715-15vkvz/TASK-260715-15vkvz_rework-01-results.md) — Reviewer-requested rework implementation and verification evidence
- [TASK-260715-15vkvz_review-02.md](file://TASK-260715-15vkvz/TASK-260715-15vkvz_review-02.md) — Independent reviewer changes-requested verdict for operation serialization and exact NSNumber version decoding
- [TASK-260715-15vkvz_rework-02-results.md](file://TASK-260715-15vkvz/TASK-260715-15vkvz_rework-02-results.md) — Rework 02 implementation, concurrency, exact NSNumber persistence, and validation evidence
- [TASK-260715-15vkvz_review-03.md](file://TASK-260715-15vkvz/TASK-260715-15vkvz_review-03.md) — Independent review 03 changes-requested verdict for platform terminal-status observer ordering
- [TASK-260715-15vkvz_rework-03-results.md](file://TASK-260715-15vkvz/TASK-260715-15vkvz_rework-03-results.md) — Race-safe Apple terminal observation implementation and verification evidence
- [TASK-260715-15vkvz_rework-03-focused.log](file://TASK-260715-15vkvz/TASK-260715-15vkvz_rework-03-focused.log) — Focused 33-test repository and Apple observation matrix
- [TASK-260715-15vkvz_rework-03-focused-tsan.log](file://TASK-260715-15vkvz/TASK-260715-15vkvz_rework-03-focused-tsan.log) — Focused 33-test Thread Sanitizer validation
- [TASK-260715-15vkvz_rework-03-validate-core.log](file://TASK-260715-15vkvz/TASK-260715-15vkvz_rework-03-validate-core.log) — Full 251-test core boundary and build validation
- [TASK-260715-15vkvz_rework-03-ios-build.log](file://TASK-260715-15vkvz/TASK-260715-15vkvz_rework-03-ios-build.log) — Generic iOS Simulator host-seam build
- [TASK-260715-15vkvz_rework-03-macos-build.log](file://TASK-260715-15vkvz/TASK-260715-15vkvz_rework-03-macos-build.log) — Generic macOS host-seam build
- [TASK-260715-15vkvz_rework-03-board-validate.log](file://TASK-260715-15vkvz/TASK-260715-15vkvz_rework-03-board-validate.log) — Strict board validation evidence
- [TASK-260715-15vkvz_review-04.md](file://TASK-260715-15vkvz/TASK-260715-15vkvz_review-04.md) — Independent accepted review after race-safe Apple terminal observation rework
