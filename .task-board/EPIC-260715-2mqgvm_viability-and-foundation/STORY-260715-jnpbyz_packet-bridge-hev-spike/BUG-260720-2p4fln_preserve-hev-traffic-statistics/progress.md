## Status
done

## Assigned To
[reviewer] reviewer (claude)

## Created
2026-07-20T09:20:00Z

## Last Update
2026-07-20T10:16:10Z

## Blocked By
- (none)

## Blocks
- TASK-260715-35wctc

## Checklist
- [x] Capture HEV statistics before upstream fini clears counters
- [x] Preserve quit/join safety and endpoint-B ownership
- [x] Pass real HEV counter regression and TSan
- [x] Completed-run HEV counters snapshotted before fini, nonzero, quit-safety preserved
- [x] Double-stop (stops=2) resolved as product or test fix, documented
- [x] lwIP active-pcb-not-CLOSED assertion eliminated; full 35wctc matrix green + TSan clean
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
spawn queued: [implementer] developer (codex) (run=RUN-260720-079fc7, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260720-079fc7)
Implemented pre-quit HEV statistics snapshot and one coalesced boundary stop. Double-stop was a product defect; lwIP assertion was corrected test lifecycle discipline (close transferred channels and avoid a synthetic half-open TCP fault PCB); stalled SOCKS zero-drop timing was a test expectation error while exact accounting remains enforced. Final evidence: 5x HEV matrix 13/13, TSan 13/13 clean, make validate-core full package 110/110 + build, strict format and diff checks clean. Pinned HEV unchanged.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-079fc7, pid=35671, exit=0)
spawn queued: [reviewer] reviewer (claude) (run=RUN-260720-503251, max_parallel=1)
spawn run started: [reviewer] reviewer (claude) (run=RUN-260720-503251)
REVIEW: changes requested -> to-dev. ACCEPTED on evidence: AC1 stats snapshot before fini (unit-proven + real nonzero gauges), AC2 double-stop fixed product-side via coalesced stopBoundaryOnce (documented), AC3 lwIP assertion resolved as test discipline (documented), AC5 HEV unmodified + 1vv52g contract preserved; TSan clean, strict lint clean, boundaries clean; filtered HEV matrix 13/13 deterministic (45+ green runs). REWORK (narrow, AC4): HEVBridgeIntegrationTests.swift:275 (and same pattern at :230) openDescriptorCount()==baseline equality races cross-suite parallelism in full-package runs — 2 failures in ~93 full swift test runs incl. reviewer first make validate-core; hev-flake-85.log shows fuzz suite live at baseline capture. Fix: make both descriptor-baseline checks isolation-safe (assert harness-owned resource release, report delta on failure), then re-demonstrate ~30x full swift test with zero HEV-suite failures. OUT OF SCOPE: pre-existing PacketFlowBridgeFaultTests.swift:426 drop-summary flake (~11-13%/full run, 4/30 on clean base 0d6836d) — recommend coordinator file a separate bug; do not fix here. Full evidence: BUG-260720-2p4fln_review-verdict.md + .temp/BUG-260720-2p4fln/review/ + LOGBOOK 1349/1351.
agent completed: [reviewer] reviewer (claude) (exit=0)
spawn run completed: claude (run=RUN-260720-503251, pid=70908, exit=0)
spawn queued: [implementer] developer (codex) (run=RUN-260720-aa72ed, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260720-aa72ed)
Rework 01: replaced both process-global descriptor equality gates with isolation-safe harness-owned teardown assertions. The recorder now proves one boundary start/stop, no live SOCKS channels, no queued/outstanding packet-flow work, both endpoint-close lifecycle stages, and zero cleanup close errors; global baseline/observed/delta is diagnostic only. HEV suite passed 30/30 full-package runs and 13/13 under TSan. Full runs 13 and 28 failed solely at excluded BUG-260720-24f9w6. Strict format, boundary/dependency verification, Swift build, and diff check passed. Evidence attached as rework-01 outcomes.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-aa72ed, pid=92081, exit=0)
spawn queued: [reviewer] reviewer (claude) (run=RUN-260720-932789, max_parallel=1)
spawn run started: [reviewer] reviewer (claude) (run=RUN-260720-932789)
agent completed: [reviewer] reviewer (claude) (exit=0)
spawn run completed: claude (run=RUN-260720-932789, pid=12566, exit=0)
spawn queued: [reviewer] reviewer (claude) (run=RUN-260720-5b6895, max_parallel=1)
spawn run started: [reviewer] reviewer (claude) (run=RUN-260720-5b6895)
REVIEW 2: ACCEPTED -> done. Rework-01 design verified correct: both descriptor gates (HEVBridgeIntegrationTests.swift fault + 100-cycle) now assert release of harness-owned resources only (boundary starts/stops 1/1, live SOCKS channels 0, queued batches/outstanding reads 0, both endpoint-close lifecycle stages reached, cleanup-close errors 0) with process-global baseline/observed/delta demoted to failure diagnostics — isolation-safe under parallel suites, leak-detection intent preserved, diagnosable on failure. Accepted product fixes intact: AC1 pre-fini stats snapshot under lock w/ spontaneous-return fallback (unit-proven via post-stop zeroed runtime), AC2 coalesced stopBoundaryOnce (stopInvocationCount==1 both orderings), AC3 lwIP discipline, AC5 HEV unmodified + 1vv52g contract. Reviewer re-ran on exact tree: swift build clean, full swift test 110/110 (HEV 13/13 incl. 100-cycle), TSan HEV 13/13 zero reports (exit 0, grep-verified), strict lint clean, boundary + native-dependency checks clean. Repeatability per established evidence: 30x (implementer) + 20x (orchestrator) full runs, 0 HEV-suite failures. Pre-existing PacketFlowBridgeFaultTests.swift:426 flake excluded (BUG-260720-24f9w6). Evidence: BUG-260720-2p4fln_review2-verdict.md, BUG-260720-2p4fln_review2-tsan.log, LOGBOOK 1415.
agent completed: [reviewer] reviewer (claude) (exit=0)
spawn run completed: claude (run=RUN-260720-5b6895, pid=21283, exit=0)

## Precondition Resources
- [BUG-260720-2p4fln_inputs.md](file://BUG-260720-2p4fln/BUG-260720-2p4fln_inputs.md) — HEV teardown/stats fix scope + repro
- [BUG-260720-2p4fln_rework-01.md](file://BUG-260720-2p4fln/BUG-260720-2p4fln_rework-01.md) — Rework 01: descriptor-count parallel-suite isolation
- [BUG-260720-2p4fln_repeatability-evidence.md](file://BUG-260720-2p4fln/BUG-260720-2p4fln_repeatability-evidence.md) — Repeatability confirmed; issue verdict without re-looping

## Outcome Resources
- [BUG-260720-2p4fln_spawn-log_-implementer--developer--codex-.log](file://BUG-260720-2p4fln/BUG-260720-2p4fln_spawn-log_-implementer--developer--codex-.log) — System spawn log captured by task-board
- [BUG-260720-2p4fln_results.md](file://BUG-260720-2p4fln/BUG-260720-2p4fln_results.md) — Implementation decisions and verification summary
- [BUG-260720-2p4fln_tsan.log](file://BUG-260720-2p4fln/BUG-260720-2p4fln_tsan.log) — Exact-tree HEV ThreadSanitizer run: 13 tests passed
- [BUG-260720-2p4fln_validate-core.log](file://BUG-260720-2p4fln/BUG-260720-2p4fln_validate-core.log) — Core validation, full 110-test package, and Swift build log
- [BUG-260720-2p4fln_spawn-log_-reviewer--reviewer--claude-.log](file://BUG-260720-2p4fln/BUG-260720-2p4fln_spawn-log_-reviewer--reviewer--claude-.log) — System spawn log captured by task-board
- [BUG-260720-2p4fln_review-verdict.md](file://BUG-260720-2p4fln/BUG-260720-2p4fln_review-verdict.md) — Review verdict: product changes verified correct; to-dev for descriptor-baseline test-isolation fix in 35wctc matrix; pre-existing drop-summary flake documented out-of-scope
- [BUG-260720-2p4fln_rework-01-results.md](file://BUG-260720-2p4fln/BUG-260720-2p4fln_rework-01-results.md) — Rework 01 implementation and verification summary
- [BUG-260720-2p4fln_rework-01-full-swift-test-30-runs.tar.gz](file://BUG-260720-2p4fln/BUG-260720-2p4fln_rework-01-full-swift-test-30-runs.tar.gz) — Thirty full-package Swift test logs; HEV suite passed 30/30
- [BUG-260720-2p4fln_rework-01-tsan-hev.log](file://BUG-260720-2p4fln/BUG-260720-2p4fln_rework-01-tsan-hev.log) — Rework exact-tree HEV ThreadSanitizer run: 13 tests passed, no report
- [BUG-260720-2p4fln_rework-01-validation.log](file://BUG-260720-2p4fln/BUG-260720-2p4fln_rework-01-validation.log) — Strict format, boundary and dependency verification, Swift build, and diff check
- [BUG-260720-2p4fln_review2-verdict.md](file://BUG-260720-2p4fln/BUG-260720-2p4fln_review2-verdict.md) — Review 2 verdict: rework-01 accepted, all AC verified, task done
- [BUG-260720-2p4fln_review2-tsan.log](file://BUG-260720-2p4fln/BUG-260720-2p4fln_review2-tsan.log) — Reviewer-2 confirming TSan run of HEV suite: 13/13, zero race reports
