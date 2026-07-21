## Status
done

## Assigned To
[reviewer] reviewer (codex)

## Created
2026-07-15T01:16:19Z

## Last Update
2026-07-21T01:42:00Z

## Blocked By
- TASK-260715-1q4qhw
- TASK-260715-15vkvz
- TASK-260715-lovbdz

## Blocks
- TASK-260715-3lab1f
- TASK-260715-bf3a2d
- TASK-260715-2a1cp7
- TASK-260715-3btpxm

## Checklist
- [x] Implement session commands and combined state projection without app-owned forwarding state
- [x] Run race stale-snapshot relaunch and version-compatibility tests
- [x] Attach task-scoped state mapping and verification evidence
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
spawn queued: [implementer] developer (codex) (run=RUN-260721-9b4c51, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260721-9b4c51)
Implemented generation-retired host session control over freshly reloaded exact-owned sessions; system status remains the sole session authority and correlated fresh provider snapshots the sole capability authority. Added deterministic status/error/deadline/race/relaunch/version matrices, thin iOS/macOS adapters, docs, and task-scoped evidence. Focused normal 57/57, focused TSan 23/23, full core 275/275, strict format/diff/board checks, and both adapter builds pass.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-9b4c51, pid=60073, exit=0)
spawn queued: [reviewer] reviewer (codex) (run=RUN-260721-3fcce3, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260721-3fcce3)
REVIEW VERDICT — changes requested. Production iOS/macOS VPNHostSession adapters forward raw NETunnelProviderSession.startTunnel NSError values, but VPNSessionController maps only VPNPreferencePlatformError/VPNPlatformError and otherwise erases the real domain/code to reflected type + code 0. This violates accepted lifecycle section 7 synchronous-start mapping; the current fake-only test injects pre-normalized errors and misses both platform boundaries. Required: normalize errors in both thin adapters (or a shared injectable translator), preserve unknown domain/code, add both-platform adapter tests for the three known NEVPN start errors plus unknown error, cover the disabled-manager production path, rerun all gates, and return for another review. Evidence: TASK-260715-1rsqrh_review.md. Independent gates reproduced green: focused 57/57, focused TSan 23/23, full core 275/275 + build, format, diff, board validate, and sequential iOS/macOS builds.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-3fcce3, pid=82584, exit=0)
spawn queued: [implementer] developer (codex) (run=RUN-260721-722219, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260721-722219)
Rework 01: normalized synchronous start errors at both production Apple seams through VPNPreferencePlatformError, preserving unknown NSError domain/code; normalized disabled fresh-manager preflight to the stable controller result with zero start calls. Added independent iOS/macOS error matrices and real repository-to-controller disabled coverage. Focused normal and TSan 58/58, make validate-core 276/276 plus build, strict format/diff/board checks, and sequential iOS/macOS adapter builds pass. Attached TASK-260715-1rsqrh_rework-01-results.md and task-scoped rework logs.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-722219, pid=90417, exit=0)
spawn queued: [reviewer] reviewer (codex) (run=RUN-260721-a9c508, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260721-a9c508)
REVIEW VERDICT — accepted. Rework 01 closes the production start-error boundary on both Apple adapters: known public NEVPN start errors map to the accepted stable results, unknown NSError domain/code is preserved, and the real disabled exact-owned manager path returns configurationDisabled without a system start or preference mutation. Authority, deadlines, generation retirement, observer/task release, race behavior, and relaunch recovery remain intact. Independent reviewer gates: focused normal 58/58, focused TSan 58/58 with no race report, make validate-core 276/276 plus build, strict format/diff/board checks, and sequential iOS/macOS adapter builds all pass. Evidence: TASK-260715-1rsqrh_review-02.md.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-a9c508, pid=97669, exit=0)

## Precondition Resources
- [TASK-260715-1rsqrh_accepted-inputs.md](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_accepted-inputs.md) — Accepted lifecycle, repository, runtime-message, authority, deadline, and validation inputs
- [TASK-260715-1rsqrh_rework-01.md](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_rework-01.md) — Reviewer-required production start-error normalization on both Apple seams

## Outcome Resources
- [TASK-260715-1rsqrh_spawn-log_-implementer--developer--codex-.log](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_spawn-log_-implementer--developer--codex-.log) — System spawn log captured by task-board
- [TASK-260715-1rsqrh_results.md](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_results.md) — Authority/state mapping, implementation summary, and verification index
- [TASK-260715-1rsqrh_focused-normal.log](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_focused-normal.log) — Focused controller and repository test evidence: 57 tests passed
- [TASK-260715-1rsqrh_focused-tsan.log](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_focused-tsan.log) — Focused controller Thread Sanitizer evidence: 23 tests passed
- [TASK-260715-1rsqrh_validate-core.log](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_validate-core.log) — Full core validation evidence: 275 tests and build passed
- [TASK-260715-1rsqrh_ios-build.log](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_ios-build.log) — iOS Simulator adapter xcodebuild evidence
- [TASK-260715-1rsqrh_macos-build.log](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_macos-build.log) — macOS adapter xcodebuild evidence
- [TASK-260715-1rsqrh_swift-format.log](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_swift-format.log) — Strict Swift format lint evidence
- [TASK-260715-1rsqrh_board-validate.log](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_board-validate.log) — Strict board validation evidence
- [TASK-260715-1rsqrh_spawn-log_-reviewer--reviewer--codex-.log](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_spawn-log_-reviewer--reviewer--codex-.log) — System spawn log captured by task-board
- [TASK-260715-1rsqrh_review.md](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_review.md) — Independent reviewer verdict, blocking production-boundary finding, required rework, and reproduced validation evidence
- [TASK-260715-1rsqrh_rework-01-results.md](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_rework-01-results.md) — Production start-error normalization, disabled-manager mapping, and rework verification summary
- [TASK-260715-1rsqrh_rework-focused-normal.log](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_rework-focused-normal.log) — Rework focused controller/repository evidence: 58 tests passed
- [TASK-260715-1rsqrh_rework-focused-tsan.log](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_rework-focused-tsan.log) — Rework focused Thread Sanitizer evidence: 58 tests passed
- [TASK-260715-1rsqrh_rework-validate-core.log](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_rework-validate-core.log) — Rework full core validation evidence: 276 tests and build passed
- [TASK-260715-1rsqrh_rework-swift-format.log](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_rework-swift-format.log) — Rework strict Swift format lint evidence
- [TASK-260715-1rsqrh_rework-diff-check.log](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_rework-diff-check.log) — Rework git diff whitespace validation evidence
- [TASK-260715-1rsqrh_rework-board-validate.log](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_rework-board-validate.log) — Rework task-board validation evidence
- [TASK-260715-1rsqrh_rework-ios-build.log](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_rework-ios-build.log) — Rework iOS Simulator adapter build evidence
- [TASK-260715-1rsqrh_rework-macos-build.log](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_rework-macos-build.log) — Rework macOS universal adapter build evidence
- [TASK-260715-1rsqrh_review-02.md](file://TASK-260715-1rsqrh/TASK-260715-1rsqrh_review-02.md) — Second reviewer verdict accepting production error normalization and full task implementation
