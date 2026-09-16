# TASK-260715-3kimon review verdict — CR revision 3

Verdict: **changes requested** for `CR-TASK-260715-3kimon-3` revision 3, candidate tree `51945e046ba28941a5dac9c142a1db16c8af3b0f`.

## Finding

### P1 — Required negative evidence is incomplete for adjustment and pressure gates

Production call sites:
- `SSHReceiveWindowBudgetLedger.reserveAdjustment` at `Sources/ReluxTunnelCore/SSHReceiveWindowBudgetPolicy.swift:494-535`.
- `SSHReceiveWindowBudgetLedger.permitInitial` at `Sources/ReluxTunnelCore/SSHReceiveWindowBudgetPolicy.swift:674-685`.

Revision 3 adds a refusal at line 510 requiring `outstandingAdvertisedCreditBytes <= reservation.reservedWindowBytes`, but no shipped test calls the production method with an outstanding value above the reservation while still within the immutable channel cap. An exhaustive `rg` for `invalidOutstandingCredit` and invalid outstanding-credit inputs returned production occurrences only. The new gate therefore lacks the required negative test that fails if the bound is widened or removed.

The pressure test at `Tests/ReluxTunnelCoreTests/SSHReceiveWindowBudgetPolicyTests.swift:187-207` rejects only an ordinary initial open under `.pressure`, permits relay, and never invokes `.critical`. It does not prove the required per-class pressure matrix: a narrowing mutant that admits bulk under `.pressure`, or any class under `.critical`, is not bound by this suite. Acceptance criterion 5 requires every class and pressure coverage.

Required rework:
1. Add a production-call-site negative vector using an initially 32 KiB-reserved / 64 KiB-cap channel and report 32 KiB + 1 outstanding; require `.invalidOutstandingCredit` and byte-identical ledger state.
2. Add a table test over every class at `.pressure` and `.critical`: pressure permits only control/relay initial reservations and rejects ordinary/bulk; critical rejects every class. Assert rejected paths do not mutate reservations or ledger totals.
3. Rerun focused policy/selected-adapter tests, full `swift test`, strict format, core boundaries, build, and exact-OID diff check.

## Revision-3 fixes verified

- Repeated replenishment restores the immutable cap with `newlyReservedBytes == 0` after full reservation and stable lane/global/ledger totals.
- Release no longer retains UUID tombstones; the 10,000-channel churn test reconciles to zero.
- Patch resource SHA-256 matched `d39229ff653c8a135e5a1b0df9d64c7e55a246cedea248de39f9a2b4a86b0273`.
- Candidate file bytes match tree `51945e046ba28941a5dac9c142a1db16c8af3b0f`; exact-OID `git diff --check` passed.

## Reviewer validation

- `swift test --filter 'SSHReceiveWindowBudgetPolicyTests|LibSSH2WindowPolicyAdapterTests'`: exit 0; 13 tests in 2 suites.
- `swift test`: exit 0; 520 tests in 43 suites; 25 known ReluxNIOSSH-unavailable issues.
- `swift format lint --recursive --strict Sources Tests`: exit 0.
- `make check-core-boundaries`: exit 0.
- `swift build`: exit 0.
- Exact-OID `git diff --check`: exit 0.

The implementation appears architecturally sound, but the evidence contract and AC5 are not satisfied until the negative vectors above ship.