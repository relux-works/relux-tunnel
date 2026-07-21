# TASK-260715-zfg9ap review verdict — changes requested

## Verdict

Route to `to-dev`. The bounded registry passes the submitted normal, TSan, full-Core, format, boundary, privacy, and board gates, but AC 1, 3, and 5 are not fully satisfied or proven.

## Findings

### 1. Exported active-flow diagnostics do not reliably return to baseline under bounded-ingestion churn

`TCPAdmissionRegistry` emits `recordTCPFlowReserved()` and `recordTCPFlowReleased()` as separate diagnostics updates (`TCPAdmissionRegistry.swift` lines 393 and 563). `RuntimeDiagnosticsStore.enqueue` independently drops updates when its 256 slots are occupied (lines 808–820), while the two update cases increment/decrement the exported `tcp_active_flows` gauge independently (lines 833–846).

Independent public-API probe: create a one-flow registry with a real `RuntimeDiagnosticsStore`, perform 2,000 sequential reserve/release lifecycles, then snapshot. Across 20 fresh generations, registry `reservedFlows` returned to 0 in all 20, but exported `tcp_active_flows` remained nonzero in 13/20 runs (1–3 phantom active flows). Example: run 6 reported `local=0 diag_reserved=0 diag_active=3 opened=1986 closed=1983 drops=1409`. Full output is attached as `TASK-260715-zfg9ap_review-diagnostics-churn-probe.log`.

This violates the requested exact return-to-baseline evidence for active counts under churn. Rework should make current TCP gauges level-triggered/reconcilable from one authoritative absolute state (or use one atomic/coalesced typed TCP state update) so independently dropped deltas cannot leave a terminal phantom flow. Add a deterministic queue-saturation regression proving final active/flow/open/channel/queued-byte/buffer gauges are zero after all reservations are released; ingestion-drop accounting may still increase.

### 2. Reservation IDs wrap unchecked and permit ABA/collision corruption

`State.allocateID()` returns `nextID` and advances it with wrapping addition (`TCPAdmissionRegistry.swift` lines 310–313), without exhaustion or collision handling. After wrap, an ID can collide with a still-live handshake, flow, or opening token. A duplicate handshake ID creates two live tokens backed by one `Set` entry, defeating the live-reservation ceiling; a duplicate flow ID overwrites the record while queued-byte accounting is added again, after which releases can address the wrong record and leak or mis-release capacity.

Rework should fail closed on ID exhaustion or allocate only an identifier proven absent from every live namespace. Add an internal test seam that seeds allocation at `UInt64.max` and proves no collision, ABA, ceiling breach, or baseline leak across wrap/exhaustion.

### 3. Required adversarial lifecycle and fairness coverage is missing

The test named `terminalDuringOpen` is sequential (`flow.release` followed by `opening.finish`, test lines 359–378), not a concurrent release/finish race. The fairness test performs one rejection and then one admitted-flow update (lines 128–158), not sustained concurrent rejection pressure. There is no direct coverage for handshake/flow/open-token deinit rollback, double finish/release, concurrent late buffer/byte callbacks, session-health transitions racing admission, or checked queued-byte overflow at registry accumulation.

Add repeated concurrent/TSan tests for those paths, assert every gauge and reservation returns to the exact baseline, and prove an admitted flow continues making bounded progress while reject churn is active.

## Independent validation

- `swift test --filter TCPAdmissionRegistryTests` — PASS, 8 tests.
- `swift test --filter RuntimeDiagnosticsTests` — PASS, 9 tests; maximum encoded snapshot 13,499 bytes.
- Both focused suites with `--sanitize=thread` — PASS, no TSan report.
- `make validate-core` — PASS, 296 tests in 27 suites plus `swift build`.
- `swift format lint --strict --recursive Sources Tests Package.swift` — PASS.
- Core boundary, engine-import, prohibited-public-label, `git diff --check`, and `task-board validate` guards — PASS.

No product code was modified during review.
