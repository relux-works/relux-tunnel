# TASK-260715-3kimon results — rework validation 04

## Bounded formulas

All window quantities are binary bytes (`KiB = 1024 B`). Bandwidth is integer
bits/s and RTT is integer nanoseconds. Both measured inputs are capped before
multiplication:

```text
bulkBytes = clamp(
  ceil(cappedBandwidthBitsPerSecond * cappedRTTNanoseconds / 8_000_000_000),
  bulkMinimumWindowBytes,
  bulkMaximumWindowBytes)
```

The full-width calculation saturates before the configured maximum is applied.
Relay credit is bounded as follows:

```text
relayBytes = min(
  relayMaximumWindowBytes,
  saturatingAdd(
    relayControlWindowBytes,
    saturatingMultiply(
      relayBurstDatagramCount,
      max(4 + relayMaximumFrameBodyBytes, 64))))
```

Adjustment credit separates reusable reserved capacity from new ledger charge:

```text
reusable = reservedWindowBytes - outstandingAdvertisedCreditBytes
newlyReservable = min(
  channelCap - reservedWindowBytes,
  laneWindowHeadroom,
  globalWindowHeadroom,
  ledgerHeadroom)
adjustmentBytes = min(
  channelCap - outstandingAdvertisedCreditBytes,
  reusable + newlyReservable)
newlyReservedBytes = max(0, adjustmentBytes - reusable)
```

Only `newlyReservedBytes` grows per-lane, global-window, and global-ledger
totals. Initial admission atomically checks the immutable per-channel cap plus
all three ledger ceilings, including fixed read/write/metadata capacity.

## Vectors and reconciliation

- Control: `32768 B`; ordinary: `65536 B`.
- Bulk at `8_000_000 bits/s` and `64_000_000 ns`: `64000 B`.
- Relay: `32768 B` control plus four `1476 B` framed datagrams = `38672 B`.
- `UInt64.max` bandwidth and RTT saturate and clamp to `262144 B`; uncapped
  inputs produce the same result as their configured capped inputs.
- Four successive fully consumed replenishment cycles restore outstanding
  credit to the immutable cap. After initial expansion,
  `newlyReservedBytes == 0` and lane/global/ledger totals remain unchanged.
- `openFailure`, `normalClose`, `reset`, `cancellation`, `laneFailure`, and
  `lateCallback` use one idempotent release transition. First owned release
  returns exact bytes; absent and duplicate releases return zero. A deterministic
  10,000-channel churn vector finishes with zero active reservations.

## Reviewer-requested negative evidence

Production adjustment gate:
`SSHReceiveWindowBudgetLedger.reserveAdjustment` at
`Sources/ReluxTunnelCore/SSHReceiveWindowBudgetPolicy.swift:494`.

- A channel starts with a `32768 B` reservation and `65536 B` immutable cap.
  Reporting `32769 B` outstanding credit must throw
  `invalidOutstandingCredit`. The test asserts unchanged channel count,
  managed/global/lane window bytes, ledger bytes, and successful reservation
  metrics; only the refusal counter advances. Removing or widening the reserved
  window bound makes the test fail with the later `aboveLowWater` refusal.

Production initial-pressure gate:
`SSHReceiveWindowBudgetLedger.permitInitial` at
`Sources/ReluxTunnelCore/SSHReceiveWindowBudgetPolicy.swift:667`.

- The complete 8-row class-by-pressure table proves `.pressure` admits only
  control and relay while rejecting ordinary and bulk, and `.critical` rejects
  control, ordinary, bulk, and relay.
- Every rejected row asserts unchanged reservation count and exact
  managed/global/lane/ledger byte totals. A mutant admitting bulk under
  `.pressure`, or any class under `.critical`, fails the table.

Previously advertised credit is never represented as revoked. Pressure,
rekeying, failed/closing/closed lane state, stale generation, invalid or
above-low-water outstanding credit, and insufficient reservation withhold new
credit without a pending side queue.

## Validation run 04

- Focused policy and selected-adapter tests: exit `0`; 15 tests in 2 suites.
- Full `swift test` final rerun: exit `0`; 522 tests in 43 suites, with the 25
  existing known ReluxNIOSSH-adapter-unavailable issues and no unexpected
  failure.
- The first full run exited `1` on an unrelated libssh2 authentication-timeout
  cleanup assertion. The exact identifier rerun passed 1/1, and the full rerun
  passed; no task code touches that integration path.
- `swift format lint --recursive --strict Sources Tests`: exit `0`.
- `make check-core-boundaries`: exit `0`.
- `swift build`: exit `0`.
- Exact baseline `a4edb799331263a0f01629b7a2d9a5a9975d4537`
  `git diff --check`: exit `0`; repository delta is exactly `LOGBOOK.md`,
  `SSHReceiveWindowBudgetPolicy.swift`, and
  `SSHReceiveWindowBudgetPolicyTests.swift`.

Task-scoped logs are under `.temp/TASK-260715-3kimon/`:
`focused-tests-04.log`, `full-tests-04.log` (the recorded initial failure),
`unrelated-timeout-rerun-04.log`, `full-tests-rerun-04.log`, `format-04.log`,
`boundaries-04.log`, `build-04.log`, and `diff-check-04.log`.
