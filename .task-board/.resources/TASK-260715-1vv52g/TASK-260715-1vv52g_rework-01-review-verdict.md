# TASK-260715-1vv52g rework-01 review verdict: accepted (done)

## Verdict

Both required fixes are implemented correctly, covered by the exact tests the
prior verdict demanded, and no accepted behavior regressed. All verification
gates independently re-run by this reviewer pass. Task accepted.

## Fix 1 (blocking): shutdown deadlock guard — verified

- `HEVDescriptorBorrowHandle.requestStop()`
  (Sources/ReluxTunnelNativeAdapter/HEVIntegration.swift:374-390) now checks
  `context.returnCode == nil` before `runtime.requestStop()`, so
  `hev_socks5_tunnel_quit()` is never issued after HEV main has returned.
  `boundary.stop()` and the `hev_stop_request_total` increment are preserved
  unconditionally, as required.
- Bridge-path determinism independently re-verified in
  Sources/ReluxTunnelCore/PacketFlowBridge.swift: on the peer-EOF path the
  supervisor is woken by `hevTask`, which only completes after
  `waitForReturn()` (pthread joined, `returnCode` stored), so the guard at
  `supervisedCleanup` (line 1017) observes a non-nil return code
  deterministically. Explicit stop with live HEV still issues quit normally.
- The residual quit-vs-spontaneous-return race is documented in the code
  comment at the guard and in LOGBOOK (upstream-inherent, same exposure as
  hev-jni.c; unfixable without a forbidden HEV patch). `cleanupBeforeSupervision`
  racing a just-dying HEV falls inside that documented window, which the prior
  verdict explicitly accepted.
- Test `descriptorBorrowStopOrderings`
  (Tests/ReluxTunnelNativeAdapterTests/HEVIntegrationTests.swift:141-189) uses
  `ReturnAwareHEVRuntime`, which `Issue.record`s any quit after `run` returned,
  and drives both orderings: main-return-first (asserts zero quit calls, stop
  metric still 1, boundary stopped once) and stop-first (asserts exactly one
  quit, no late quit, endpoint B still open). Matches the required test spec.

## Fix 2 (secondary): listener fd-reuse window — verified

- `HEVLoopbackSOCKSBoundary` (Sources/ReluxTunnelNativeAdapter/HEVSOCKSBoundary.swift:201-249)
  now closes the listener exactly once from the dispatch-source cancel handler,
  which GCD serializes on `listenerQueue` after any in-flight
  `acceptAvailableConnections()` event handler — the fd-reuse window is gone.
  `stop()` awaits `listenerCancellationGroup` before returning, so the port is
  provably closed when `stop()` completes; then awaits `authenticationGroup`
  (pending descriptors are shutdown first, so auth recv unblocks).
- Exactly-once close audit: stop() nils listener+source together; deinit after
  stop sees both nil (no second close); deinit without stop cancels the source
  (handler closes); startup failure closes via the `shouldClose` defer before
  the source exists. No double-close path found.
- Test `socksBoundaryStopClosesListener` (HEVIntegrationTests.swift:84-100)
  proves connect fails after stop() returns and double stop is safe.

## Reviewer-rerun gates (all pass)

- `swift-format lint --strict --recursive Sources Tests Package.swift` — clean.
- `swift test` — 49/49 in 7 suites.
- `swift test --sanitize=thread --filter ReluxTunnelNativeAdapterTests.HEVIntegrationTests` — 8/8, no TSan reports.
- `make validate-native` — exit 0 (.temp/TASK-260715-1vv52g/review02-validate-native.log):
  core-boundary guard, fixture verify, hev-lwip artifact-lock inspect
  ("static and extension-safe"), full 7-scheme xcodebuild matrix (iOS device,
  iOS simulator, macOS provider/adapters/harness), stripped SwiftPM release
  harness audit requiring hev main/quit/stats symbols, 49 tests, release build.
  Known non-fatal `__DATA,__common` alignment linker warning unchanged.
- `native-dependency-tool.py verify --dependency hev-lwip --source-dir
  .temp/TASK-260715-uopycx/hev-socks5-tunnel` — "source and packaging inputs
  are verified".
- Pinned checkout clean at ad7600497931205105b08367bd1b450048157e40 with all
  four submodules at manifest revisions — HEV remains unmodified.

## AC status

AC1-AC5 were independently confirmed in the first review; the rework touches
only the quit/join seam, the SOCKS listener close path, tests, and LOGBOOK, and
every gate re-run is green, so those confirmations stand. AC4 is now fully
satisfied: the previously reachable permanent shutdown deadlock ordering is
covered by the guard and regression tests.

## Routing

Status -> done.
