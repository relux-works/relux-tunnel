# TASK-260715-3o0co4 review — Implement the public socket-pair PacketFlowBridge

Verdict: **ACCEPTED** → `done`
Reviewer: reviewer role (Claude), 2026-07-20

## Scope reviewed

- `Sources/ReluxTunnelCore/PacketFlowBridge.swift` (lifecycle actor, run supervisor,
  forward/reverse pumps, run-scoped metrics actor, privacy-safe log fields)
- `Sources/ReluxTunnelCore/PacketFlowBridgeContracts.swift` (public error/seam/metric
  schema contracts, RunHandle, lifecycle states)
- `Sources/ReluxTunnelCore/DarwinPacketBridgeIO.swift` (production socketpair/fcntl/
  setsockopt/send/recvmsg/close I/O, DispatchSourceRead readiness)
- `Sources/ReluxTunnelCore/PacketContracts.swift` (configuration rename to
  maximumWorkCount/workTimeBudget + diagnosticsWindow; `PacketBridge.start` now
  returns `PacketFlowBridgeRunHandle`)
- Tests: `PacketFlowBridgeTests.swift` (8 tests), `PacketFlowBridgeBoundedTests.swift`
  (5 tests); docs: README, docs/core-adapter-boundaries.md, LOGBOOK entry 0510.

## Contract conformance (TASK-260715-p89bdj)

- **Ownership/ordering (§3, §6):** endpoint A bridge-owned; endpoint B exclusive
  scoped borrow via `DescriptorBorrowConsumer`; cleanup order is shutdown reads →
  cancel readiness → join both pumps → requestStop borrow once → join HEV return →
  close B exactly once → close A exactly once. `PacketBridgeOwnedDescriptor` makes
  close idempotent; failed close records `packet_bridge_cleanup_close_error_total`
  and a warning without the descriptor number. Verified by event-order assertions
  (`close.101` before `close.100`) in normal-stop, fatal, startup-failure, and
  startup-cancellation tests.
- **Task ownership (§4):** four stored tasks (forward, reverse, HEV-return watcher,
  supervisor), all joined; no `Task.detached` anywhere (grep clean). First-error-wins
  via a single one-shot `PacketBridgeRunControl`; later sibling errors only increment
  their own reason counters (verified by `firstErrorWins` test: EIO beats a later HEV
  return, `fatal_peer_eof_total == 0`, exactly one `packet_bridge.fatal` log).
- **State machine (§5):** idle/starting/running/stopping/failing/stopped/failed with
  restart from stopped/failed; `alreadyActive` typed error with no side effects;
  cancellation routes through the stopping path as success (`cancellation_total`,
  no terminal-failure counter) — verified by `startupCancellation`.
- **Framing (§8, §9):** forward emits exactly `[UInt32(AF).bigEndian][payload]` per
  valid packet, SDK-derived constants, byte-for-byte asserted for IPv4+IPv6; checked
  4+mtu ceiling with overflow-safe arithmetic; short/zero send is fatal. Reverse:
  one recvmsg → at most one packet, zero-length and 1–3-byte datagrams are malformed
  drops (not EOF, `fatal_peer_eof_total == 0` asserted), unknown family and
  nibble/family mismatch drop, order preserved, empty batches not written, no
  splitting/coalescing. Fixed `4+mtu` buffers in both pumps; no allocation from
  claimed lengths.
- **Error table (§10):** EAGAIN/EWOULDBLOCK normalized (Darwin defines them equal;
  test injects the EWOULDBLOCK spelling), ENOBUFS drop/no-retry both directions,
  EMSGSIZE real+synthetic fatal, PacketFlow write rejection fatal with
  `reverse_drop_write_rejected_packets_total` += batch and no retry
  (`writeAttemptCount == 1` asserted), unexpected HEV return → peer-EOF fatal,
  unclassified errno fatal. Would-block reverse uses a non-summary counter, forward
  drops feed the `drop_summary` aggregate — matches the per-row logging column.
- **Bounded work (§11):** count budget includes malformed work; time budget uses the
  injected monotonic clock only; verified deterministically with a fake scheduler and
  advancing clock (2 count-yields for 5 packets @ max 2; 2 time-yields @ 2s advance
  per send). No retry queue, no side buffer, no recursion.
- **Metrics (§12):** schema is exact — 30 counters + 12 gauges, keys asserted
  set-equal to `PacketBridgeMetricSchema`, run-scoped zero start, saturating
  arithmetic with one-shot saturation log, max-assign gauges, endpoint-specific
  requested/effective buffer gauges published before borrow.
- **Privacy (§13):** log fields are run_id, counts, byte sizes, errno
  symbol/number, buffer/MTU config, error category — no payload bytes, no
  addresses, no descriptor numbers. Required events all present, drop summaries
  window-gated by injected `diagnosticsWindow` and flushed at termination.
- **Prohibitions (§15):** greps for utun, `Task.detached`, `dup`/`dup2`,
  `SCM_RIGHTS`, fd reopen clean (only a doc comment and `gate.open()` match).
- **Adapter reuse (impl-inputs):** bridge consumes `any PacketFlow`; the
  TASK-260720-9xy8yx `PacketFlowAdapterBoundary` stays the only continuation/
  cancellation owner (iOS/macOS adapters wrap it); no reimplementation.
- **Darwin receive sizing:** public `SO_NREAD` (first-packet byte count) + one
  consuming `recvmsg` with `MSG_TRUNC` — a real-socket test proves full/truncated/
  zero-length reporting on the target SDK. Public API only.

## Independent verification (all rerun by reviewer)

- `swift build` — pass
- `swift test` — 39/39 tests in 5 suites pass
- `swift test --sanitize=thread --filter PacketFlowBridge` — 13/13 pass, zero
  ThreadSanitizer reports (`.temp/TASK-260715-3o0co4/review-tsan-01.log`)
- `swift format lint --strict --recursive Sources Tests Package.swift` — clean
- `make check-core-boundaries` — valid
- Prohibition greps (utun / detached / dup / SCM_RIGHTS / fd reopen) — clean

## Minor observations (non-blocking, no rework required)

1. `PacketFlowBridge.runEnded` has an `if reachedRunning` branch whose both arms
   set the same `.failed` state — dead branch, cosmetic only.
2. Reverse errno-EMSGSIZE reports `datagramBytes: maximumDatagramBytes` because a
   failed recvmsg exposes no observed size; acceptable approximation, the
   truncation path reports the exact observed size.
3. A `stop()` racing `start()` before the run is registered (two suspension points
   wide) is a silent no-op; providers that stop after `start` returns — the
   supported pattern — are unaffected.

## Coverage explicitly deferred to TASK-260715-3dn813 (per contract §16)

The follow-up fault-injection task must cover the rows this task's suite does not
exercise at bridge level: pre-send synthetic 4+mtu ceiling fatal (only the errno
path is bridge-tested), reverse truncation→fatal at bridge level (proved at the
Darwin IO layer only), readiness `peerClosed` and unexpected-HEV-return rows,
cancellation at every startup barrier stage (only `socketPairCreated` tested),
drop-summary window suppression/final flush, and saturation logging.
