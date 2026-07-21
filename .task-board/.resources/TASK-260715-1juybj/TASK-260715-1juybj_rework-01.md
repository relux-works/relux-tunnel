# TASK-260715-1juybj rework 01

Resolve every blocking finding in `TASK-260715-1juybj_review-verdict.md` without weakening the accepted security or bounded-resource contract.

Required corrections:

1. Correct the source-backed admission claim. Current Darwin `SO_RCVTIMEO` is a per-receive inactivity timeout that can restart when bytes arrive; it is not an absolute accept-to-authentication deadline. Update the contract, M0 capability trace, validation, diagrams, hashes, and LOGBOOK wording wherever necessary so current evidence is stated exactly.
2. Preserve the production requirement as an explicit M1 decision/gap: the implementation task must enforce one injectable monotonic accept-to-auth absolute deadline spanning greeting, RFC 1929 auth reads, comparisons, and authentication replies; progress must not extend it. Pending admission remains bounded meanwhile, but a slow trickle must not retain a slot indefinitely after implementation.
3. Refine `TASK-260715-b6uruh` details/AC/checklist or dependencies as needed to require deterministic slow-trickle, wrong-credential, reply-stall, cancellation, stale-generation, and both-platform validation rows. Do not implement the fix in this specification task.
4. Replace the unreliable Smetana state layout, re-render the task-scoped SVG, inspect it on an opaque background, and ensure every state/transition label is legible and unclipped. Record the exact render and visual-validation evidence; update resource hashes.
5. Re-run the relevant focused rejection test, PlantUML syntax/render checks, opaque-background SVG conversion/inspection evidence, board validation, resource copy/hash verification, and `git diff --check`.

Retain all reviewer-passing contract clauses: byte-level negotiation/CONNECT/replies, remote destination and sanitized originator, exactly-one channel/no migration, bounded bidirectional pumps, EOF/half-close/reset/cancellation/cleanup, M0 memory accounting, aggregate privacy-safe metrics, and the M3 lane seam. Do not reopen engine selection or SSH observability scope.

Attach a rework evidence resource, update the task outcomes in place, and route to `to-review`; do not self-accept.
