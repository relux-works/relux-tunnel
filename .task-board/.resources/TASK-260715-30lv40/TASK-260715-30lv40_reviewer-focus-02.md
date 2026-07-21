# Independent re-review after capability-contract rework 01

Re-review `TASK-260715-30lv40` against the original verdict and `TASK-260715-30lv40_rework-01-results.md`.

Prove the four prior findings are closed:

1. A retired waiting timer or running attempt is stale immediately because its live registration is cleared before cleanup/publication/reschedule; numeric generation equality alone must never make it current. Trace late callbacks in the window before N+1 exists.
2. `degraded` has exactly one bounded local re-entry into relay-only reprobe after automatic eligibility or an accepted local relay-policy revision, with a fresh relay-work/attempt identity and no overlap with M3. Exhaustion must not create an automatic loop.
3. Successful connecting activation uses the finite local `activation_ready` outcome through atomic publication, distinct from unavailable/failure reasons.
4. The lifecycle diagram visibly distinguishes registered Waiting and Running phases and matches the contract/table; the ownership diagram remains single-purpose and unchanged where appropriate. Re-render and visually inspect both.

Recount all states, 32 transitions, reason rows and retry classes; audit M1/M2/M3/UI ownership, production readiness gates, all 16 byte-identical downstream copies, PlantUML/source-render hashes, privacy, board/diff, Swift/Go/protocol/release regression gates. Examine the logged broad `plan(... related)` cycle anomaly only enough to confirm this rework introduced no dependency edge and `task-board validate` remains clean.

Use only Codex `gpt-5.6-sol` high, no delegation and no Claude. Accept/done only if the retirement/re-entry model is unambiguous and implementable without hidden loops; otherwise return exact bounded rework.
