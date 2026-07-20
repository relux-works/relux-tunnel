# BUG-260720-24f9w6 implementation results

## Root cause

`FakePacketBridgeSocketIO.sendDatagram` appends the attempted datagram before returning or throwing its configured outcome. The test's `eventually { sentDatagrams.count == ... }` therefore observed only syscall entry, not completion of the subsequent asynchronous `PacketBridgeRunMetrics.recordDrop` call. Under competing suite work, the logger assertion could run before the summary was emitted.

## Change

- Added an actor-backed `FakePacketFlow.waitForReadCallCount(_:)` signal.
- The drop-summary test waits until the forward pump requests its next read after each injected batch. Reaching that signal proves all processing for the preceding batch, including drop accounting and summary logging, has completed.
- Preserved the injected `ManualTunnelClock` and exact 10-second boundary.
- Strengthened accounting assertions: the window summary contains exactly two would-block drops and the stop flush contains exactly one no-buffer drop, with no cross-window carryover.

## Verification

- `swift test --filter PacketFlowBridgeFaultTests.dropSummaryRateLimiting`: passed.
- `swift format lint --strict --recursive Sources Tests Package.swift`: passed.
- `swift build`: passed.
- `make validate-core`: passed, 110 tests.
- 30 additional full `swift test` runs: 30 package passes, 30 target-test passes, 0 failures.
- `git diff --check`: passed.

Evidence logs:

- `.temp/BUG-260720-24f9w6/focused-test-01.log`
- `.temp/BUG-260720-24f9w6/swift-format-lint.log`
- `.temp/BUG-260720-24f9w6/swift-build.log`
- `.temp/BUG-260720-24f9w6/validate-core.log`
- `.temp/BUG-260720-24f9w6/stability/full-run-01.log` through `full-run-30.log`
