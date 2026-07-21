# TASK-260715-15vkvz accepted inputs

Implement the owned `NETunnelProviderManager` repository against the already accepted lifecycle contract and runtime codecs.

Authoritative inputs:

- `TASK-260715-1q4qhw_runtime-lifecycle-contract.md` and its accepted review.
- `TASK-260715-lovbdz` versioned runtime configuration/reference models and codecs.
- The task scope and AC are normative, especially the exact ownership predicate, zero-write behavior, explicit enable intent, 15-second operation tokens, one stale retry, and fail-closed production identity.

Execution constraints:

- Keep the implementation shared and injectable so iOS/macOS host seams compile without owning provider runtime state.
- Never store secrets in `providerConfiguration`; only the stable marker, contract version, and bounded opaque profile reference are allowed.
- Never edit/remove unrelated, lookalike, unmarked, wrong-type, or future-schema managers.
- Do not invent production identifiers while `TASK-260715-ypo7yo` / release bindings remain pending; production identity must fail closed and deterministic fixtures must remain injectable.
- Preserve the legacy product boundary and do not couple this work to the generated/signed provider workspace.
- Exercise behavior with deterministic callback-order, timeout, cancellation, stale-object, duplicate, and authorization tests. Run the relevant full core/boundary validation and attach task-scoped evidence.
- Work through producer handoff to `to-review`; do not self-accept.
