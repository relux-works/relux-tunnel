# TASK-260715-3kjhkw outcome

Implemented `MemoryWatermarkController` and `SystemMemoryPlatformSamplingService` in `Sources/ReluxTunnelCore/MemoryWatermarkController.swift`, with deterministic Swift Testing coverage in `Tests/ReluxTunnelCoreTests/MemoryWatermarkControllerTests.swift`.

## State and evidence contract

- Every accepted observation performs a fresh platform sample and records byte units, fixed provenance, a monotonic timestamp, configuration/state generations, physical current/peak footprint, ledger current/reserved/committed/peak values, and an advisory value or explicit unavailable reason.
- Inclusive maximum-signal entry is Normal -> Soft -> Pressure -> Critical. Recovery requires fresh complete evidence, action acknowledgement, strict-above exit floors, and configured dwell; it moves at most one state per observation.
- Cadence and event-trigger sampling are independently bounded start-to-start. Sampling duration has a configured ceiling, history is a ring capped at 1,024 records, metrics have fixed enum cardinality, and no traffic labels are accepted or retained.

## Reviewer rework and negative evidence

Reviewer revision 1 found that `MemoryWatermarkController.observe` -> `nextState` allowed a fresh memory warning to lower Pressure to Soft when all byte signals permitted recovery. The committed negative test `warningCannotRecoverBelowPressure` reproduced this before the fix with exit 1 and two exact failures: observed state `.soft` instead of `.pressure`, plus an unexpected `.pressure -> .soft` recovery transition.

`nextState` now clamps one-step recovery to the strongest entry signal in the same observation. A warning can still permit `.critical -> .pressure`, but cannot permit `.pressure -> .soft`; the regression test asserts both bounds. Before-fix log: `.temp/TASK-260715-3kjhkw/warning-floor-negative-before-fix.log`.

## Sampling cadence, state trace, and overhead

- Trace coverage: Normal -> Soft -> Pressure -> Critical; strict recovery Critical -> Pressure -> Soft -> Normal; warning floor Critical -> Pressure -> Pressure; stale/unavailable/unacknowledged evidence holds Pressure.
- Final macOS sampler probe: 256 samples, `0.000344125s` total, `0.000008792s` maximum.
- Concurrent test: 64 observations serialize to gap-free sequences `1...64` with one current state generation.

## Validation after rework

- `swift test --filter MemoryWatermarkControllerTests`: exit 0, 13 tests / 1 suite.
- `make validate-core`: exit 0, 519 tests / 43 suites; 25 existing known issues for the unavailable ReluxNIOSSH adapter; post-test `swift build` passed.
- `swift format lint --recursive Sources Tests Package.swift`: exit 0.
- `scripts/check-core-boundaries.sh`: exit 0.
- `xcodebuild -scheme ReluxTunnelCore -destination 'generic/platform=iOS Simulator' build`: exit 0, BUILD SUCCEEDED in 6.714s.
- `git diff --check`: exit 0.

Final logs are under `.temp/TASK-260715-3kjhkw/` with task-scoped names. The implementation is ready for review; review acceptance remains a separate role verdict.
