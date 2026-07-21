# TASK-260715-zfg9ap rework 01 evidence

## Reviewer finding closure

1. Diagnostics convergence: replaced independently queued registry gauge updates with one fixed-size generation-scoped atomic absolute-state publication. Snapshots reconcile this state after draining or dropping queued events. A deterministic held-lane test and 20-run probe prove every current TCP gauge returns to exact baseline while ingestion drops remain nonzero.
2. Identifier exhaustion: replaced wrapping allocation with an optional monotonic cursor. `UInt64.max` is allocated at most once and transitions the generation permanently to exhausted; no retired identifier is reused. The test seam proves handshake, flow, and opening allocation at the boundary, fail-closed behavior while live and after retirement, no collision/ABA, and exact recovery.
3. Lifecycle races: added repeated concurrent release/open-finish, release/buffer/byte/half-close, explicit-release/deinit ownership, all-token deinit rollback, duplicate release/finish, deterministic late-callback, stale-generation, and session-health/admission coverage. Legitimate late work increments the bounded late-event counter rather than a release violation.
4. Overflow: added a deterministic `Int.max + positive` aggregate queued-byte attempt, proving checked rejection and exact baseline recovery.
5. Sustained pressure: 8 rejecting workers issue 8,000 deterministic flow-capacity rejects while one admitted flow records all 2,000 progress steps. Rejections create zero SSH opens, no side queue, and no retained handshake.

Focused normal, 20-run churn, focused Thread Sanitizer, full Core/build, strict format, boundary, engine-import, privacy, diff, and board gates all pass. Full command and measured evidence is in `TASK-260715-zfg9ap_results.md`.
