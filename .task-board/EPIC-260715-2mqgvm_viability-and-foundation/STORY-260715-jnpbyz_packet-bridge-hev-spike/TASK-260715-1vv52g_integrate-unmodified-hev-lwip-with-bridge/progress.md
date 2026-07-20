## Status
done

## Assigned To
[reviewer] reviewer (claude)

## Created
2026-07-15T01:01:35Z

## Last Update
2026-07-20T03:37:56Z

## Blocked By
- TASK-260715-uopycx
- TASK-260715-3o0co4
- TASK-260715-1g9cyt

## Blocks
- TASK-260715-35wctc
- TASK-260715-52h8i3
- TASK-260715-1loqwb

## Checklist
- [x] Pinned unmodified HEV builds in harness and all Apple target configurations
- [x] Fixed configuration and owned SOCKS boundary are enforced
- [x] Lifecycle, linkage, and notice evidence is attached
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
spawn queued: [implementer] developer (codex) (run=RUN-260720-7c958e, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260720-7c958e)
STOP-THE-LINE: pinned HEV silently raises task-stack-size 24576 to 35480 because default udp-copy-buffer-nums=10 contributes 15000 bytes to the unconditional stack minimum, including UDP-in-TCP. Recommend approving an additional injectable udp-copy-buffer-nums=2 baseline; alternatives and evidence are attached in TASK-260715-1vv52g_blocker.md. No hidden constant or HEV patch was added.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-7c958e, pid=46048, exit=0)
spawn queued: [implementer] developer (codex) (run=RUN-260720-9777af, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260720-9777af)
Integrated the checksum-locked unmodified HEV/lwIP XCFramework through ReluxTunnelNativeAdapter. Added scoped descriptor borrowing on a dedicated pthread, exact injectable ADR-020 configuration, authenticated loopback-only SOCKS adapter seam with external no-auth rejection, coordinated stop/join without descriptor ownership transfer, linkage smoke checks, and embedded notices traced to the manifest. Verification passed: strict swift-format, boundary checks, source/artifact/notice verification, Swift tests (47), HEV ThreadSanitizer tests (6), swift build, and make validate-native across iOS device/simulator and macOS provider/harness. The unchanged upstream archive emits non-fatal ld section-alignment reduction warnings; required-symbol and stripped-binary audits pass.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-9777af, pid=36134, exit=0)
spawn queued: [reviewer] reviewer (claude) (run=RUN-260720-f3e1c3, max_parallel=1)
spawn run started: [reviewer] reviewer (claude) (run=RUN-260720-f3e1c3)
REVIEW: changes requested -> to-dev. BLOCKING: reachable permanent shutdown deadlock — HEVDescriptorBorrowHandle.requestStop() calls hev_socks5_tunnel_quit() unconditionally; pinned upstream hev_socks5_tunnel_stop busy-waits forever for event_fds[1] >= 0, and event_task_fini resets both fds to -1 when HEV main returns (init failures never create them). Any ordering where main returns before requestStop (init failure, or the contract-modeled unexpected-main-return -> peer-EOF fatal -> supervisedCleanup at PacketFlowBridge.swift:1017) hangs cleanup on an infinite 100ms usleep loop: provider stop() never returns, descriptors never close (defeats AC4 on a designed-for path). Masked in tests because fakes never block and no test exercises main-returns-first ordering. FIX: guard runtime.requestStop() on context.returnCode == nil (deterministic in the reachable path — pthread joined before hevTask completes), add the main-returns-first ordering test, document the residual upstream-inherent quit-vs-spontaneous-return race (no HEV patch). SHOULD-FIX: close SOCKS listener fd via dispatch-source cancel handler instead of caller-context close in HEVLoopbackSOCKSBoundary.stop() (fd-reuse window vs accept loop). ALL ELSE VERIFIED by reviewer rerun: make validate-native exit 0, 47/47 tests, TSan clean, strict lint clean, hev-lwip verify pass, pinned checkout clean at ad760049, AC1/AC2/AC3/AC5 confirmed, ADR-020 recorded. Full evidence: TASK-260715-1vv52g_review-verdict.md
agent completed: [reviewer] reviewer (claude) (exit=0)
spawn run completed: claude (run=RUN-260720-f3e1c3, pid=77118, exit=0)
spawn queued: [implementer] developer (codex) (run=RUN-260720-54177b, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260720-54177b)
Rework 01: guarded HEV quit after main return, moved listener close to its dispatch-source cancel handler, and added both stop-order and listener-close regressions. Residual concurrent quit/spontaneous-return race is upstream-inherent and documented; no HEV patch. Verification: strict swift-format; 49 Swift tests; swift build; 8 HEV TSan tests; make validate-native. Evidence attached in TASK-260715-1vv52g_rework-01-results.md and rework logs.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-54177b, pid=86348, exit=0)
spawn queued: [reviewer] reviewer (claude) (run=RUN-260720-36bccd, max_parallel=1)
spawn run started: [reviewer] reviewer (claude) (run=RUN-260720-36bccd)
Rework-01 review: ACCEPTED. Fix 1 verified: requestStop() guards on context.returnCode and never issues hev_socks5_tunnel_quit after HEV main returned; bridge-path determinism re-verified (hevTask completes only after waitForReturn joins the pthread, then supervisedCleanup calls requestStop); residual quit-vs-spontaneous-return race documented in code + LOGBOOK as upstream-inherent. Ordering test covers both legs and fails on any late quit. Fix 2 verified: listener fd closed exactly once from the dispatch-source cancel handler on listenerQueue; stop() awaits cancellation, eliminating the accept-loop fd-reuse window; no double-close path found. Reviewer-rerun gates all green: strict lint, swift test 49/49, TSan HEV suite 8/8 clean, make validate-native exit 0 (full iOS/macOS matrix + stripped harness symbol audit), hev-lwip full source verify pass, pinned checkout clean at ad760049 with manifest submodule revisions (HEV unmodified). AC1-AC5 hold; AC4 deadlock ordering now covered. Verdict resource: TASK-260715-1vv52g_rework-01-review-verdict.md. Status -> done.
agent completed: [reviewer] reviewer (claude) (exit=0)
spawn run completed: claude (run=RUN-260720-36bccd, pid=96925, exit=0)

## Precondition Resources
- [TASK-260715-1vv52g_packet-flow-descriptor-contract.md](file://TASK-260715-1vv52g/TASK-260715-1vv52g_packet-flow-descriptor-contract.md) — Descriptor borrow, HEV join, and close-order contract
- [TASK-260715-1vv52g_inputs.md](file://TASK-260715-1vv52g/TASK-260715-1vv52g_inputs.md) — HEV integration wiring + config
- [TASK-260715-1vv52g_approved-decision.md](file://TASK-260715-1vv52g/TASK-260715-1vv52g_approved-decision.md) — Approved config decision (ADR-020)
- [TASK-260715-1vv52g_rework-01.md](file://TASK-260715-1vv52g/TASK-260715-1vv52g_rework-01.md) — Rework 01: shutdown deadlock guard + SOCKS fd-reuse fix

## Outcome Resources
- [TASK-260715-1vv52g_spawn-log_-implementer--developer--codex-.log](file://TASK-260715-1vv52g/TASK-260715-1vv52g_spawn-log_-implementer--developer--codex-.log) — System spawn log captured by task-board
- [TASK-260715-1vv52g_effective-config-probe.log](file://TASK-260715-1vv52g/TASK-260715-1vv52g_effective-config-probe.log) — Executable proof of the pinned HEV effective low-memory values
- [TASK-260715-1vv52g_blocker.md](file://TASK-260715-1vv52g/TASK-260715-1vv52g_blocker.md) — Stop-the-line evidence, options, and exact decision required
- [TASK-260715-1vv52g_results.md](file://TASK-260715-1vv52g/TASK-260715-1vv52g_results.md) — Implementation and verification evidence
- [TASK-260715-1vv52g_validate-native.log](file://TASK-260715-1vv52g/TASK-260715-1vv52g_validate-native.log) — Native Apple matrix, tests, lint, and build evidence
- [TASK-260715-1vv52g_spawn-log_-reviewer--reviewer--claude-.log](file://TASK-260715-1vv52g/TASK-260715-1vv52g_spawn-log_-reviewer--reviewer--claude-.log) — System spawn log captured by task-board
- [TASK-260715-1vv52g_review-verdict.md](file://TASK-260715-1vv52g/TASK-260715-1vv52g_review-verdict.md) — Review verdict: changes requested — reachable shutdown deadlock in HEV quit path; all ACs otherwise verified
- [TASK-260715-1vv52g_rework-01-results.md](file://TASK-260715-1vv52g/TASK-260715-1vv52g_rework-01-results.md) — Rework implementation and verification evidence
- [TASK-260715-1vv52g_rework-validate-native.log](file://TASK-260715-1vv52g/TASK-260715-1vv52g_rework-validate-native.log) — Rework native Apple matrix, Swift tests, and build log
- [TASK-260715-1vv52g_rework-hev-tsan.log](file://TASK-260715-1vv52g/TASK-260715-1vv52g_rework-hev-tsan.log) — Rework HEV integration ThreadSanitizer log
- [TASK-260715-1vv52g_rework-01-review-verdict.md](file://TASK-260715-1vv52g/TASK-260715-1vv52g_rework-01-review-verdict.md) — Rework-01 review verdict: accepted, all gates reviewer-rerun green
