# DNS evidence validator assertion fix

Use `TASK-260721-3miqh4_re-review-02-verdict.md` as the authoritative defect report. Modify only the disposable DNS evidence harness and its generated/published evidence artifacts.

Required fixes:

1. Replace each tautological timing boundary row with a mutation that is passed through the real `validate_policy` path. Cover default and hard M1/M2 ready/cold equations and prove one-under/one-over or exact equality as appropriate.
2. Extend policy verification so authority-critical structure is validated fail-closed: `productionAuthorization` must remain false, candidate/authority classification and blocker IDs must be exact, the later physical evidence gate must be declared, and missing/changed fields must fail. Add negative vectors.
3. For every reliability scenario, assert exact attempts, terminal owner/count, duplicate-before-dedup count, late-data disposition, cancellation/tombstone behavior, endpoint sequence, and zero cleanup ownership. Do not accept broad upper bounds where exact results are recorded.
4. Regenerate all affected raw runs, summaries, policy JSON, archives, hashes, report/README/spec/logbook statements, board outcome copies, and downstream copies atomically. Attach a new bug-scoped results outcome.
5. Keep `TASK-260721-3miqh4` blocked on `TASK-260715-1gjxer` and `TASK-260715-1pn983`; do not authorize production values or touch production runtime code.
6. Privacy is stop-the-line. Do not publish raw spawn logs or host/account/resolver/query/secret identifiers.

Run as Codex Sol high only, no delegation and no Claude. Route this bug to review only after its own outcome is attached and all checks pass.
