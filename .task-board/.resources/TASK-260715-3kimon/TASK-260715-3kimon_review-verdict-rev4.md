# TASK-260715-3kimon review verdict — CR revision 4

Verdict: accepted for CR-TASK-260715-3kimon-4 revision 4, candidate tree 5fabbe0b2a538cdcc1eb41026ea267aa4adccb33.

No blocking findings.

Revision 4 resolves the revision-3 negative-evidence request at production SSHReceiveWindowBudgetLedger.reserveAdjustment and permitInitial. The 32769 B outstanding-credit vector proves the reserved-window bound with exact invalidOutstandingCredit and unchanged ledger state. The 8-row pressure/class matrix proves pressure admits only control and relay, critical rejects every class, and rejection does not mutate reservations or budgets. Repeated replenishment reuses reserved capacity without growing lane/global/ledger totals; release is exact and idempotent without retained tombstones.

Architecture fit: pure value-semantic ReluxTunnelCore ledger; both libssh2_channel_open_ex callers use the single bounded conversion; consumer-driven adjustment remains explicitly unsupported and no out-of-scope protocol sending or engine change was introduced.

Reviewer validation:
- Focused policy plus selected-adapter tests: exit 0; 15 tests in 2 suites.
- Full swift test managed rerun: exit 0; 522 tests in 43 suites, 25 existing known ReluxNIOSSH-unavailable issues.
- Strict recursive Swift format: exit 0.
- Core boundary guard: exit 0.
- Swift build: exit 0.
- Exact-base diff check and candidate byte comparison: exit 0.
- Patch SHA-256: 26921dade94771c50be88a56f96bbe3c4c60228c6ee80dd03e268328eb8e5d1d, matched.

Logs: .temp/TASK-260715-3kimon/reviewer-*.log.