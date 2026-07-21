# Independent re-review after rework 01

Review the corrected `TASK-260721-3miqh4` artifacts and `TASK-260721-3miqh4_rework-01-results.md` independently. Do not rely on the producer's conclusions.

- Reproduce the maximum DNS-over-TCP wire-size success and one-byte-over rejection evidence.
- Verify M1 and M2 ready/cold timing equations, including UDP/relay, dispatch, same-endpoint TCP fallback, later endpoint promotion, and logical deadline validation vectors.
- Inspect the event-trace transaction owner: both family orders, real cancellation/tombstones, late callbacks, duplicate detection before deduplication, malformed no-shopping, all M2 triggers, exact attempt and terminal counts.
- Verify ownership cleanup is observed from counters and not assigned as a constant.
- Confirm the report and policy do not authorize local loopback/RSS candidates as production defaults. Check the exact dependencies on selected-engine direct-tcpip evidence (`TASK-260715-1gjxer`) and accepted ADR-009 residual DNS budget (`TASK-260715-1pn983`), plus the later physical startup/footprint gate.
- Decide the board outcome honestly: accept only if the task AC/DoD is satisfied; otherwise mark it blocked or changes-requested with an exact evidence packet. If the newly discovered dependencies are genuine, ensure dependency links/status and downstream gates reflect them without cycles.
- Re-run artifact/hash/privacy scans, including archive members. No raw spawn log or host/account/resolver/query/secret identifier may remain versionable.

Use only Codex Sol high. Do not delegate or use Claude.
