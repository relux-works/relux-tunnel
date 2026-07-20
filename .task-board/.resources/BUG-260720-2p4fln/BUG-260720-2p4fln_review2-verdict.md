# BUG-260720-2p4fln — review 2 verdict: ACCEPTED (done)

Scope of this pass (per BUG-260720-2p4fln_repeatability-evidence.md): verify rework-01 design correctness and confirm gates without re-running long loops; repeatability was already established (implementer 30x full swift test HEV 30/30; orchestrator 20x full swift test 0 HEV-suite failures; HEV TSan 13/13 clean).

## Rework-01 design — verified correct

Both former process-global gates (fault test and 100-cycle, previously openDescriptorCount() == baseline at HEVBridgeIntegrationTests.swift:230/275) are replaced by expectHarnessOwnedResourcesReleased(harness, descriptorBaseline:), which polls OwnedResourceSnapshot.allReleased built ONLY from per-harness signals: boundary starts == 1 and stops == 1 (access recorder), live SOCKS channels == 0 (adapter sessions + stalled channels), queued packet batches == 0 and outstanding reads == 0 (driver), both hevDescriptorClosed and bridgeDescriptorClosed lifecycle stages reached (lifecycle recorder), and packet_bridge_cleanup_close_error_total == 0.

- Isolation-safe: no process-global state participates in the pass/fail condition, so concurrent suites cannot perturb it.
- Leak-detection intent preserved: every descriptor class the harness/product owns is verified closed via its own tracking; a close that is never attempted fails the lifecycle-stage predicate, a close that errors fails the cleanup-error predicate, an unclosed SOCKS channel fails the live-channel predicate.
- Diagnosability requirement met: the failure message prints the full owned-resource snapshot plus process-global baseline/observed/delta as diagnostics only.

## Accepted product fixes — intact (diff re-inspected)

- AC1: HEVDescriptorBorrowHandle snapshots all four counters under lock before runtime.requestStop() (HEV still ACTIVE, pre-fini); waitForReturn() publishes the snapshot, falling back to a live read on spontaneous return. Quit-after-main-return guard and endpoint-B ownership unchanged.
- AC2: stopBoundaryOnce() lock-coalesced task; unit tests assert stopInvocationCount == 1 in both stop orderings; integration asserts starts == stops == 1 per cycle.
- AC1 proof hardened: BlockingHEVRuntime now zeroes statistics after stop, so nonzero published gauges provably come from the pre-stop snapshot (statisticsAfterStopCallCount == 0).
- AC3: no lwIP tcp_slowtmr assertion in any observed run.
- AC5: pinned HEV untouched; only Swift-side changes (HEVIntegration.swift, unit/integration tests, Package.swift test-target dep on ReluxTunnelMacOSAdapter); 1vv52g-era tests green within the 110.

## Gates re-run by this reviewer on the exact tree

- swift build: clean.
- Full swift test (single run, the parallel full-package context where the flake lived): 110/110 in 12 suites, Pinned HEV suite 13/13 incl. 100-cycle.
- swift test --sanitize=thread --filter HEVIntegrationTests: 13/13, exit 0, zero ThreadSanitizer/data-race reports (grep-verified; log attached as BUG-260720-2p4fln_review2-tsan.log).
- swift format lint --strict: clean. make check-core-boundaries check-native-dependencies: clean.

## Verdict

All five AC satisfied. Status → done. Pre-existing PacketFlowBridgeFaultTests.swift:426 flake stays excluded, tracked as BUG-260720-24f9w6. LOGBOOK entry 1415 records the acceptance.