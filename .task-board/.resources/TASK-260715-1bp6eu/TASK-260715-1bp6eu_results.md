# TASK-260715-1bp6eu implementation evidence

## Implementation

- Replaced the minimal provider lifecycle adapter with one shared actor that owns generation-safe start, message, stop, and provider-failure joining for both thin platform roots.
- Added strict read-only v1 routing for `getProtocolCapabilities`, `getRuntimeSnapshot`, `getCapabilities`, and `getDiagnostics`. Provider requests require UUID correlation, active/recent request memory is fixed-size, duplicate and retired work is rejected, and every non-nil Apple response handler has one once-only gate.
- Added a fixed 64-handle generation cleanup registry. Stop rejects new work, retires pending message gates before late source completion, fans out cancellation, joins one runtime stop, and force-closes registered controllable handles when the injected ten-second budget expires.
- Added injected 60-second startup timeout, stop-wins-start ordering, raw Apple stop-reason mapping, stable provider NSError mapping, and once-only `cancelTunnelWithError` handoff whose later system stop joins the existing cleanup.
- Connected `LatestRuntimeSnapshotStore` and `RuntimeDiagnosticsStore` to the provider router. Cleanup expiry records a fixed counter, raw-reason gauge, and finite redacted `cleanup_deadline_exceeded` error; diagnostics v1 now has 97 counters, 57 gauges, and 11 finite codes across the existing 10 domains.
- Registered coordinator-owned controllable SSH, TCP, DNS, and packet-plane handles with the shared cleanup registry. Updated both iOS/macOS composition roots and DocC; recorded the decision in `LOGBOOK.md` entry 0320.

## Shared adapter coverage

- Both iOS and macOS seams run the same ten Swift Testing cases.
- Coverage includes all four commands, 300-request rolling bounded history, malformed/oversized/duplicate-key/future/mutating/missing-request inputs, concurrent duplicates, nil handlers, stop-retired late callbacks, all Apple raw reasons 0...17 plus future 99, startup mapping for reasons 7/14, start-before-stop gate order, injected startup and cleanup deadlines, force close, provider fatal failure, deallocation, and 100 cycles per seam.
- Existing `TunnelRuntimeCoordinatorTests` retain deterministic coverage for every internal startup acquisition/cancellation point, reverse cleanup, settings non-commit/commit/uncertainty, route-clear failure, late callbacks, and 100 generation baselines.

## Verification

- `swift test --filter ProviderAdapterContractTests`: 10 tests passed through both seams.
- `swift test --sanitize=thread --filter ProviderAdapterContractTests`: 10 tests passed with no Thread Sanitizer report.
- `make validate-core`: boundary/native verification passed; 218 tests in 23 suites passed; post-test `swift build` passed.
- `swift-format lint --strict --recursive Sources Tests Package.swift`: passed.
- `git diff --check`: passed.
- Correctness-sleep audit of provider source/tests: passed.
- `task-board validate`: passed.

The recurring linker section-alignment warning is pre-existing and non-fatal.
