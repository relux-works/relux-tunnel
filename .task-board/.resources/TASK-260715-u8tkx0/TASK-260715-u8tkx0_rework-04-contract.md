# Rework 04 contract

Use exact fresh reviewer verdict TASK-260715-u8tkx0_reviewer-results-rework-03.md.

Required correction:
- Keep this a documentation-only fix unless evidence proves code must change.
- Make the historical default trusted-bundle command copy-paste executable when the bundle does not yet exist in a fresh clone.
- Use an explicit absolute destination, e.g. \`RELAY_ASSET_BUNDLE="$REPO/.build/relay/relay-assets-v1"\`, or an equivalently explicit correct command.
- Audit other documented default bundle generate/check commands for the same relative-parent initial-publication trap.
- Do not alter the already accepted deterministic/rotation/safety semantics.

Verification:
- From a fresh no-local/no-hardlink clone with pinned toolchains but no \`.temp\` and no pre-generated default bundle, execute the historical fenced flow exactly.
- Prove default generation/check exits 0 and its manifest matches the independently generated historical trusted manifest.
- Re-run syntax/link/task-ID/sensitive-path/diff gates and focused build-only validation.
- No commit/push and no signing, notarization, provider/app launch, VPN/system-network changes.

Return to-review with a new task-scoped outcome.