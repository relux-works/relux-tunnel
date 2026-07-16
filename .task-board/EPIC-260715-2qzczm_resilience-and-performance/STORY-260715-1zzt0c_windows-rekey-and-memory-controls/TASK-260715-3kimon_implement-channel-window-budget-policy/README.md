# Implement per-channel receive-window and budget policy

## Description
Implement the pure policy that selects bounded initial receive windows and WINDOW_ADJUST credit for control, ordinary, bulk, and relay channels from class, measured BDP, ledger reservations, lane state, and memory pressure.

## Scope
In scope: 32 KiB and 64 KiB candidates; capped BDP input; relay control and UDP burst credit; integer overflow safety; global and per-lane window budgets; initial reservation; adjustment eligibility; low-water thresholds; withholding under pressure or rekey; release on close; metrics; deterministic configuration validation. Out of scope: SSH engine selection or patching, sending protocol messages outside the selected adapter, memory sampling, lane assignment, final tuned constants, revoking previously advertised credit, or transport reconnect.

## Acceptance Criteria
1. For every channel class and valid configuration the policy returns an initial window and adjustment rule that fit per-channel, per-lane, and global ledger ceilings. 2. Bulk BDP calculations use documented bandwidth and RTT units, saturating arithmetic, minimum and maximum bounds, and cannot multiply an uncapped value by session limits. 3. Pressure, lane failure, closing, stale generation, and insufficient reservation prevent new credit, while existing advertised credit is never represented as revoked. 4. Reservation and release are idempotent and reconcile exactly across open failure, normal close, reset, cancellation, rekey, and late callbacks. 5. Table, boundary, randomized, and selected-engine adapter tests cover every class, 32 KiB, 64 KiB, capped BDP, overflow, saturation, pressure, and ledger invariant.
