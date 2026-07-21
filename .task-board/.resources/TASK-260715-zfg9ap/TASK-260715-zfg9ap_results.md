# TASK-260715-zfg9ap implementation and rework evidence

## Delivered behavior

- `TCPAdmissionRegistry` is the single generation-scoped mutex authority for non-waiting handshake, flow, channel-open, channel, fixed queued-byte, live-buffer, phase, byte-total, peak, pressure, and terminal accounting.
- Every physical ceiling remains caller-injected. `maximumReservedFlows` is validated against both `measuredSafeMaximumFlows` and `hevMaximumSessionCount`; no M0 measurement is promoted to a hardcoded product value.
- Pressure rejection is synchronous, retains no waiter or side queue, maps to SOCKS5 `REP=01`, and sets `shouldOpenSSHChannel=false`.
- Handshake, flow, and opening tokens use once-only atomic claims plus deinit rollback. Late callbacks are discarded without releasing capacity twice.
- Reservation identifiers are monotonically allocated without reuse. After allocating `UInt64.max`, the namespace is exhausted permanently for the generation and all later allocations fail closed as finite `identifier_capacity` pressure.
- Queued-byte reservation construction and registry accumulation use checked arithmetic; overflow fails as `queued_byte_capacity` without mutating capacity.
- Runtime diagnostics expose 139 fixed counters, 75 fixed gauges, two fixed 12-bucket histograms, and 11 finite error codes. The maximum populated encoding measured 13,568 bytes of the 65,536-byte wire limit.
- Current TCP gauges publish to a fixed-size generation-scoped atomic coalescer. Snapshot reconciliation reads one coherent absolute registry state even when the 256-slot event lane drops intermediate counter/histogram events. Stale generation publishers own an isolated cell. Counters and histogram buckets remain saturating monotonic totals of successfully ingested events, and `diagnostics_ingestion_drop_total` signals conservative undercount.
- No public TCP admission or diagnostics API accepts a destination, hostname, address, port, payload, credential, per-flow/channel identifier, engine text, or free-form label.

## Capacity, churn, race, and fairness evidence

- Global flow race: exactly 16 of 256 requests admitted at the injected ceiling; peak reserved flows 16 and peak reserved bytes 128; 240 deterministic fast rejects; exact baseline after release.
- Opening race: exactly 4 openings across 16 admitted flows at the injected ceiling; 12 deterministic fast rejects; exact baseline after release.
- Handshake race: exactly 8 of 128 reserved; 120 deterministic rejects; exact baseline after release.
- Independent queued-byte race: a 32-byte ceiling with 8-byte reservations admits exactly 4 of 128; 124 deterministic rejects; exact baseline after release.
- Terminal churn: all 16 finite terminal reasons exercised for 20 cycles each (320 lifecycles), returning flow/open/channel/queued/live-buffer state to zero after every lifecycle.
- Adversarial lifecycle coverage: 500 concurrent flow-release/channel-open-completion races, 500 concurrent release/buffer/byte/half-close callback races, 250 explicit-release/last-reference-deinit ownership races, all three token deinit rollbacks, duplicate finish/release, and deterministic late callbacks.
- Identifier exhaustion seam starts at `UInt64.max - 2`, allocates one handshake, one flow, and one opening without collision, then rejects while live and after retirement without wrap, reuse, ABA, or baseline loss.
- Accumulation overflow reserves `Int.max` queued bytes in one flow and deterministically rejects a second positive reservation without overflow or leak.
- Session-health toggling races 8,000 admissions while preserving linearized gates, configured peaks, and exact baseline.
- Sustained pressure uses 8 workers and 8,000 deterministic flow-capacity rejects while the already-admitted flow completes 2,000 buffer/byte progress steps; rejected work records zero SSH opens and leaves no pending handshake or side queue.
- Diagnostics saturation holds snapshot construction and the bounded queue while 2,000 complete open/buffer/release lifecycles run. Local and every exported current flow/open/channel/queued/buffer gauge return to exact baseline. The regression passed 20/20 fresh executions.

## Exact verification commands and results

- `swift test --filter TCPAdmissionRegistryTests` — PASS, 18 tests in 1 suite.
- `swift test --filter RuntimeDiagnosticsTests` — PASS, 9 tests in 1 suite.
- `for run_index in {1..20}; do swift test --skip-build --filter TCPAdmissionRegistryTests.boundedDiagnosticsGaugeConvergence || exit 1; done` — PASS, 20/20 runs.
- `swift test --sanitize=thread --skip-build --filter TCPAdmissionRegistryTests` — PASS, 18 tests, no Thread Sanitizer report.
- `swift test --sanitize=thread --skip-build --filter RuntimeDiagnosticsTests` — PASS, 9 tests, no Thread Sanitizer report.
- `make validate-core` — PASS: Core boundary gate, native dependency verification, 306 tests in 27 suites, then `swift build`.
- `swift format lint --strict --recursive Sources Tests Package.swift` — PASS.
- `./scripts/check-core-boundaries.sh` — PASS.
- `rg -n '^import (NIO|NIOSSH|CSSH|CLibSSH|ReluxNIOSSH|ReluxLibSSH2)' Sources/ReluxTunnelCore/TCPAdmissionRegistry.swift` used as a fail-on-match guard — PASS, no match.
- `rg -n 'public (func|init).*?(destination|hostname|address|port|payload|credential|flowID|channelID|label)' Sources/ReluxTunnelCore/TCPAdmissionRegistry.swift` used as a fail-on-match guard — PASS, no match.
- `git diff --check` — PASS.
- `task-board validate` — PASS.

No platform, API, ownership, or architecture conflict was found. The implementation is ready for review.
