# TASK-260715-1vv52g rework 01 evidence

## Changes

- `HEVDescriptorBorrowHandle.requestStop()` now observes the synchronized HEV main return code and skips `hev_socks5_tunnel_quit()` after main has returned. Boundary shutdown and `hev_stop_request_total` remain unchanged.
- Added a return-aware fake runtime test covering both main-return-first and stop-first orderings. It records a test issue if quit is requested after main return.
- `HEVLoopbackSOCKSBoundary` now closes its listener exactly once from the dispatch-source cancel handler on `listenerQueue`; `stop()` waits for the handler before returning.
- Added listener-stop coverage proving the port is closed when `stop()` returns and repeated stop remains safe.
- Documented the residual upstream-inherent quit-versus-spontaneous-return race. Removing that concurrent window would require a forbidden HEV source patch.

## Verification

- `swift-format lint --strict --recursive Sources Tests Package.swift` — pass.
- `swift test` — 49 tests in 7 suites pass.
- `swift build` — pass.
- `swift test --sanitize=thread --filter 'ReluxTunnelNativeAdapterTests.HEVIntegrationTests'` — 8 tests pass with no ThreadSanitizer report.
- `make validate-native` — pass, including the iOS device/simulator and macOS provider/harness linkage matrix, 49 tests, and final build.

The unchanged pinned HEV archive continues to emit its known non-fatal `__DATA,__common` alignment-reduction linker warning; all required gates pass.
