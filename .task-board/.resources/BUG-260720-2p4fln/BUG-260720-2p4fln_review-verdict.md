# BUG-260720-2p4fln — review verdict: changes requested (to-dev)

Reviewer independently re-ran every gate. Product-side work is correct and accepted on
evidence; the task bounces on one narrow test-harness defect in the delivered 35wctc
matrix that breaks AC4's "passes deterministically (repeatably)" in full-package runs.

## What was verified and PASSES

- **AC1 (stats snapshot):** `HEVDescriptorBorrowHandle.requestStop()` snapshots all four
  counters under lock while HEV main is still active (before `hev_socks5_tunnel_fini`
  clears globals), `waitForReturn()` publishes the snapshot after join with a
  spontaneous-return fallback to a live read. Quit-after-main-return guard and
  endpoint-B ownership are intact (code review + the two 1vv52g ordering tests, now
  strengthened). Unit runtime zeroes its synthetic counters on stop, proving gauges come
  from the pre-stop snapshot; real matrix asserts nonzero tx/rx gauges after real traffic.
- **AC2 (double stop):** confirmed product defect — `requestStop()` and `waitForReturn()`
  each called `boundary.stop()`. Fixed with a lock-coalesced `stopBoundaryOnce()` task;
  unit tests assert `stopInvocationCount == 1` in both orderings, integration asserts
  `starts == stops == 1` per cycle. Decision documented (product side) in results + LOGBOOK.
- **AC3 (lwIP assertion):** resolved as test lifecycle discipline (channels closed before
  teardown; fault test redesigned to UDP-in-TCP reverse-write rejection instead of a
  half-open TCP PCB). Documented. Zero `tcp_slowtmr` assertions across ~140 reviewer
  suite executions.
- **AC5 (HEV unmodified, 1vv52g contract):** git status shows only Swift-side changes
  (HEVIntegration.swift, tests, Package.swift test-target dep). `check-native-dependencies`
  and `check-core-boundaries` pass. All 8 original HEV unit tests preserved and extended;
  all 1vv52g-era suites (the "49 tests" = whole package at 1vv52g acceptance) are inside
  the current 110 and green.
- **Gates re-run by reviewer:** filtered HEV matrix 13/13 green 6 consecutive runs
  (4 plain + 2 TSan); TSan zero reports (grep-verified); `swift format lint --strict` clean;
  boundary + native-dependency verify clean; full package green in 88 of 93 runs (see below).

## Why to-dev (rework scope — narrow)

**AC4 determinism fails in full-package runs because of the delivered matrix itself.**
Reviewer's first `make validate-core` failed in suite "Pinned HEV integration"; hunting it
down: `HEVBridgeIntegrationTests.swift:275` —
`#expect(await eventually(timeout: .seconds(5)) { openDescriptorCount() == baseline })`
failed 2× in ~93 full-package runs (~2%), 0× in 45+ filtered runs (implementer + reviewer).

Root cause (evidence: `.temp/BUG-260720-2p4fln/review/hev-flake-85.log`):
`openDescriptorCount()` is process-global, and Swift Testing runs *suites* in parallel —
the flake log shows the fuzz suite still running when the 100-cycle test captured its
baseline. Any concurrent suite's descriptor delta between baseline capture and the final
check makes exact equality unreachable; the 5s poll then burns out (suite duration 5.5s
in both observed failures matches). `.serialized` only serializes within the HEV suite.
The same fragile pattern exists at `HEVBridgeIntegrationTests.swift:230` (fault test, 3s).

Required rework:
1. Make both descriptor-baseline assertions (lines ~230 and ~275) isolation-safe under
   full-package parallel runs while keeping their leak-detection intent — e.g. assert
   release of harness-owned resources/descriptors instead of global-count equality, or a
   design of equivalent strength. At minimum, a failure must report the observed
   count vs baseline so the next flake is diagnosable.
2. Re-demonstrate repeatability in the context the project actually gates on: a loop of
   full `swift test` runs (reviewer used ~30×) with zero failures in the HEV suite.
   Failures of `PacketFlowBridgeFaultTests.swift:426` are excluded — see below.

## Out-of-scope finding (do NOT fix in this task)

Pre-existing flake: `PacketFlowBridgeFaultTests.swift:426` ("drop summaries are
window-limited...") fails ~11-13% of full runs — reproduced 4/30 on clean base commit
`0d6836d` in a worktree, so it predates this bug and is outside its scope (bridge
counters/tests explicitly excluded). It likely explains the unresolved LOGBOOK 1256
anomaly. Recommend the coordinator file a separate bug (owner surface:
TASK-260715-3dn813 deliverable). Evidence: `.temp/BUG-260720-2p4fln/review/full-run-*.log`.

## Evidence index

- Reviewer flake logs: `.temp/BUG-260720-2p4fln/review/` (hev-flake-85.log,
  full-run-14/22/37/39.log kept, base-worktree runs summarized above)
- Implementer logs verified green as claimed: `.temp/BUG-260720-2p4fln/*.log`
- LOGBOOK entries 1349 + 1351 (2026-07-20) record both findings.
