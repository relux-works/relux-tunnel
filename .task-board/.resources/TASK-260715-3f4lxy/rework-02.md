# TASK-260715-3f4lxy focused rework 02

Implement only the public-documentation correction required by `TASK-260715-3f4lxy_review-verdict-02.md`.

- Update `Sources/ReluxTunnelCore/ReluxTunnelCore.docc/RuntimeMessages.md` so the start request is documented as the exact five-field bounded wire object: `protocolVersion`, `schemaVersion`, `kind=sshProfileSnapshotStart`, `configurationGeneration`, and `snapshotDigestSHA256`.
- Document exact-key rejection, generation plus exact stored canonical-byte digest matching, `profileGenerationMismatch`, and the contract-permitted nil-start-options behavior.
- Remove the superseded `configurationReference` and "no kind" statements.
- Do not change loader/runtime behavior unless a compile-only documentation reference requires it.
- Re-run the focused and full gates from the verdict and update task evidence before developer handoff.

Keep the delta documentation-only and hand off to review; do not accept the task yourself.
