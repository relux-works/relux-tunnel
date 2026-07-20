## Status
done

## Assigned To
[tester] tester (codex)

## Created
2026-07-15T01:01:36Z

## Last Update
2026-07-20T10:17:05Z

## Blocked By
- TASK-260715-3dn813
- TASK-260715-1vv52g
- BUG-260720-2p4fln

## Blocks
- TASK-260715-gyg51r
- TASK-260715-135rr8

## Checklist
- [x] Real HEV integration covers IPv4, IPv6, stream lifecycle, and SOCKS framing
- [ ] Stall and repeated lifecycle behavior remains bounded
- [ ] Integration test matrix and passing evidence are attached
- [ ] Tests written and passing
- [ ] Coverage target ~80%+ for affected code
- [ ] Lint clean
- [ ] New task-scoped outcome artifact attached on the board for reports, logs, screenshots, or other produced evidence
- [ ] Important findings, decisions, anomalies, or regressions recorded in logbook when relevant

## Notes
spawn queued: [tester] tester (codex) (run=RUN-260720-84ec8c, max_parallel=1)
spawn run started: [tester] tester (codex) (run=RUN-260720-84ec8c)
STOP-THE-LINE: New real macOS PacketFlowBridge -> pinned HEV/lwIP -> authenticated SOCKS tests compile; UDP-in-TCP/ingress test passes and the concurrent IPv4/IPv6 TCP test completes handshake, bidirectional data, half-close, and reset. It then exposes a production observability defect: HEVDescriptorBorrowHandle reads stats only after join, but pinned HEV fini clears all traffic globals before main returns, so completed-run HEV packet gauges are always zero. Regression preserved; evidence attached. Created and linked BUG-260720-2p4fln Preserve HEV traffic statistics before fini. Recommendation: snapshot while HEV is active without patching HEV or weakening assertions; then resume full matrix/coverage/lint/TSan.
agent completed: [tester] tester (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-84ec8c, pid=1955, exit=0)
CLOSED by orchestrator: deliverable = HEVBridgeIntegrationTests.swift (real PacketFlow<->bridge<->HEV/lwIP<->SOCKS matrix: concurrent IPv4/IPv6 TCP, bulk/half-close/reset, UDP-in-TCP, unauthorized ingress, stall/drop accounting, ADR-020 gauges, 100 lifecycle cycles, fault teardown). It surfaced real HEV bugs (double-stop, stats-zeroing) fixed under BUG-260720-2p4fln. The FULL 35wctc matrix was verified as BUG-2p4fln AC4 by the claude-fable reviewer: green + 20x repeatable + ThreadSanitizer 13/13 clean. Separate re-review of the same test file is redundant, so closed here. HEV unchanged.

## Precondition Resources
- [TASK-260715-35wctc_inputs.md](file://TASK-260715-35wctc/TASK-260715-35wctc_inputs.md) — HEV-bridge integration test coverage

## Outcome Resources
- [TASK-260715-35wctc_spawn-log_-tester--tester--codex-.log](file://TASK-260715-35wctc/TASK-260715-35wctc_spawn-log_-tester--tester--codex-.log) — System spawn log captured by task-board
- [TASK-260715-35wctc_stop-line.md](file://TASK-260715-35wctc/TASK-260715-35wctc_stop-line.md) — Real HEV integration test result, blocking counter regression, evidence, and resolution options
- [TASK-260715-35wctc_real-hev-counter-regression.log](file://TASK-260715-35wctc/TASK-260715-35wctc_real-hev-counter-regression.log) — Focused real IPv4/IPv6 HEV integration run; data path passes and post-stop traffic gauges fail at zero
