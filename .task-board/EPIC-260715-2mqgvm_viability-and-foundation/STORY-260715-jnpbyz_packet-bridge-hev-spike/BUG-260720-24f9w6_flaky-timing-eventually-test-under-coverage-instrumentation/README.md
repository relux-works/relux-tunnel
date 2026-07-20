# BUG-260720-24f9w6: flaky-timing-eventually-test-under-coverage-instrumentation

## Description
LOCALIZED by BUG-260720-2p4fln reviewer: PacketFlowBridgeFaultTests.swift:426 ("drop summaries are window-limited...") fails ~11-13% of full swift test runs; reproduced 4/30 on clean base commit 0d6836d in a worktree, so it predates and is independent of the HEV work — owner surface is the TASK-260715-3dn813 deliverable. Likely the LOGBOOK 1256 anomaly. FIX: make the window-limited drop-summary assertion deterministic (timing/ordering-independent — inject clock or await a signal instead of wall-clock/window race), prove stability across ~30 full swift test runs. Evidence: .temp/BUG-260720-2p4fln/review/full-run-*.log.

## Scope
(define bug scope / affected area)

## Acceptance Criteria
1. PacketFlowBridgeFaultTests.swift:426 (drop summaries are window-limited...) is deterministic: it no longer depends on wall-clock/window timing or ordering races; pass/fail is derived from injected-clock or awaited signals, not real-time polling. 2. The assertion's original intent (bounded/window-limited drop summary accounting) is preserved. 3. Stability proven across ~30 full swift test runs with zero failures of this test (and no new flake introduced). 4. swift build + validate-core stay green; no regression to the 3dn813 bridge fault-test deliverable. 5. If a failure recurs it reports observed-vs-expected for diagnosability.
