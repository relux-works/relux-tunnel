# TASK-260720-9xy8yx — Review verdict: ACCEPTED

Reviewer: [reviewer] reviewer (claude), run RUN-260720-5108ff, 2026-07-20.
Scope reviewed: `Sources/ReluxTunnelCore/PacketFlowAdapterBoundary.swift` (new),
`Sources/ReluxTunnelCore/PacketContracts.swift`,
`Sources/ReluxTunnelIOSAdapter/IOSProviderCompositionRoot.swift`,
`Sources/ReluxTunnelMacOSAdapter/MacOSProviderCompositionRoot.swift`,
`Tests/ReluxTunnelCoreTests/PacketFlowAdapterTests.swift` (new), plus mock updates
in `ProviderAdapterContractTests.swift` and `HarnessTests.swift`.

## AC-by-AC verdict

1. **Exactly-once resume, safe late callback — PASS.** The continuation lives in
   `CurrentRead.continuation` behind one `NSLock`; callback, cancellation, and
   shutdown each atomically take-and-nil it, so exactly one resumes. Cancellation
   or shutdown that wins before `commitRegistration` removes the pending read and
   prevents the platform registration entirely. A committed registration survives
   cancellation/shutdown as a payload-free tombstone; the late callback path
   guards on a nil continuation *before* any batch inspection, performs no bridge
   work, and never schedules a replacement read. Verified by code trace of every
   interleaving window (pre-commit cancel, post-commit cancel, cancel/shutdown
   between callback-take and resume) and by the deterministic tests.
2. **Single-flight, order, typed cardinality mismatch — PASS.** A second
   `readPackets` while one is pending (including the tombstone and the
   synchronous inspection window before `finishCallback`) gets typed
   `readAlreadyPending`. Batch results are built index-ordered; mismatched
   packet/protocol arrays throw `packetProtocolCardinalityMismatch(packetCount:protocolCount:)`
   — the old `zip(...).compactMap` truncation in both adapters is deleted.
3. **Family/version mapping and privacy — PASS.** `AF_INET`/`AF_INET6` map to
   typed packets only when the first payload nibble is 4/6 respectively;
   unsupported family, empty payload, and version mismatch become typed
   `PacketReadAnomaly` values carrying only family/version metadata, feeding
   `packet_bridge_forward_drop_malformed_total` via `PacketFlowMetricIncrement`
   (counter name + amount only). No logging exists in these paths; grep sweep
   found no payload/destination logging, no `print`/`os_log`.
4. **Shared conformance, public API only — PASS.** Both adapters delegate to the
   shared `PacketFlowAdapterBoundary`; the platform drivers touch only
   `NEPacketTunnelFlow.readPackets`/`writePackets(_:withProtocols:)` and public
   Darwin `AF_INET`/`AF_INET6`. Grep confirms no utun, descriptor scanning, or
   FD reopening.
5. **Deterministic test coverage and leak proof — PASS.** Swift Testing covers
   callback-first, cancellation-first, shutdown-first, late-callback (both after
   cancel and after shutdown, including a would-throw mismatched late batch that
   must only retire the registration), mismatched-array, unsupported-family,
   empty/version-mismatch payloads, IPv4, IPv6, single-flight, write mapping,
   and write rejection — all parameterized over both platform adapters, plus
   100-iteration callback/cancellation and callback/shutdown races per platform.
   Synchronization uses a waiter-based registration counter, no sleeps or
   wall-clock. Registration baseline (`outstandingCount == 0`) is asserted after
   every scenario; checked continuations trap double-resume; a leaked
   continuation would hang the awaited task deterministically.

## Independent verification (this review, logs in `.temp/TASK-260720-9xy8yx/`)

- `swift build` — clean (review-build-01.log)
- `swift test` — 26/26 passed in 3 suites (review-test-01.log)
- `swift format lint --strict --recursive Sources Tests` — exit 0 (review-lint-01.log)
- `swift test --sanitize=thread --filter PacketFlowAdapterTests` — 14/14 passed,
  no TSan reports (review-tsan-01.log)
- Prohibition greps: no utun/sleep/payload-logging in changed sources or tests.

## Non-blocking observations for follow-on tasks

- `PacketFlowAdapterBoundary.writePackets` does not gate on `isShutDown`; a
  write after shutdown still reaches the driver. Contract section 7 does not
  require write gating, and the bridge (TASK-260715-3o0co4) owns write
  lifecycle, but the bridge pump should not write after stop by construction.
- `PacketFlowError.metricIncrements` counts a cardinality mismatch as
  `packetCount` malformed drops; a mismatch with zero packets but nonzero
  protocols increments nothing. Defensible (no packets were dropped); the
  bridge's metric wiring task can revisit if the contract's counting rules need
  an event-level counter instead.
- After a cancelled-but-committed read, new reads return `readAlreadyPending`
  until NetworkExtension fires the old callback. This is the honest model of an
  API without deregistration and matches the contract's single-registration
  rule; the bridge pump must treat it as expected during shutdown.
