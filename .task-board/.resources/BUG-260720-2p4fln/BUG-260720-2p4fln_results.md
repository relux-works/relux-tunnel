# BUG-260720-2p4fln — implementation results

## Product changes

- `HEVDescriptorBorrowHandle.requestStop()` captures `HEVTrafficStatistics` while HEV main is still active, immediately before calling upstream quit.
- `waitForReturn()` publishes the preserved snapshot after join. Spontaneous return still skips quit, retaining the reviewed quit-after-return deadlock guard and endpoint-B ownership order.
- Boundary teardown is coalesced through one shared task, so intentional stop and join cleanup await one physical `boundary.stop()` invocation.

Pinned HEV/lwIP sources and the checked-in XCFramework were not modified.

## Regression and matrix changes

- Unit runtime resets its synthetic counters on stop, proving the gauges come from the pre-stop snapshot rather than a post-join read.
- Unit lifecycle tests assert one boundary stop invocation across intentional-stop and spontaneous-return orderings.
- Real traffic tests close transferred SOCKS channels before HEV teardown.
- The bridge-fault regression now triggers reverse PacketFlow rejection through real UDP-in-TCP traffic, avoiding a deliberately half-open TCP PCB at HEV fini while preserving the product fatal-path assertion.
- The stall regression retains exact send/drop accounting but no longer assumes a stalled SOCKS peer must force Darwin endpoint-B backpressure; native HEV may legitimately drain every packet.

## Decisions

- `starts=1, stops=2` was a product teardown defect, not a test counting error.
- The lwIP assertion was test lifecycle discipline: the harness retained owned channels / a synthetic half-open TCP flow across HEV teardown. Production endpoint-B ownership was not changed.
- The stall zero-drop schedule was a test expectation error; exact accounting remains mandatory.

## Verification

- `swift test --filter HEVIntegrationTests`: 13/13 passed in five consecutive final runs.
- `swift test --sanitize=thread --filter HEVIntegrationTests`: 13/13 passed, no ThreadSanitizer report.
- `make validate-core`: dependency and boundary checks passed; full package 110/110 passed; `swift build` passed.
- `swift format lint --recursive Sources Tests Package.swift`: clean.
- `git diff --check`: clean.

Primary logs:

- `.temp/BUG-260720-2p4fln/swift-test-hev-tsan-03.log`
- `.temp/BUG-260720-2p4fln/swift-test-hev-final-repeat-1.log` through `-5.log`
- `.temp/BUG-260720-2p4fln/make-validate-core-02.log`
- `.temp/BUG-260720-2p4fln/swift-format-lint-04.log`
