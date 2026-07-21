# TASK-260715-15vkvz rework 01

Address every blocking finding in `TASK-260715-15vkvz_review-01.md` without weakening the accepted lifecycle contract.

1. Preserve every positive future manager-contract version, including values above `UInt16.max` and `Int.max`-scale fixtures. Such managers are unsupported-future, never repairable corruption: `ensure`, remove, and duplicate repair must perform zero setter/save/remove calls. Use a representation/error path that cannot overflow.
2. Explicit enable must reject `.connecting`, `.reasserting`, and `.disconnecting` with a stable outcome and zero writes. An already-enabled manager must still follow the normative explicit user-intent save/reload verification path rather than returning early.
3. Add stale-object cases where the fresh reload becomes unrelated, unmarked, or future-owned and prove the fresh object receives zero mutations. Make the fake preference client return distinct post-save manager instances, then prove verification rejects noncanonical persisted fields and never trusts the stale pre-save object.

Re-run focused repository tests, the full core/boundary gate, strict format/diff/board validation, and iOS/macOS host-seam builds as relevant. Attach task-scoped rework evidence and return to `to-review`; do not self-accept.
