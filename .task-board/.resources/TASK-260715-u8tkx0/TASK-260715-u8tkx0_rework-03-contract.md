# Rework 03 contract

Use the exact fresh reviewer verdict TASK-260715-u8tkx0_reviewer-results-rework-02.md.

Required change:
- Make every documented mktemp parent valid in a genuinely fresh clone.
- At minimum create \`$REPO/.temp\` explicitly before the deterministic block calls \`mktemp -d "$REPO/.temp/TASK-260715-u8tkx0.full-release.XXXXXX"\`.
- Audit every other documented mktemp parent for the same assumption.
- Keep the coordinated ten-file rotation ordering and all previously accepted semantics unchanged.

Verification:
- Execute the affected fenced commands from a fresh no-local/no-hardlink clone without undocumented setup.
- Preserve exact 15/15 reproducibility, native 17/17, negative runtime gate, 10/10 rotation, focused suites, workspace/macOS target validation, link/task-ID/shell-block checks, and diff check.
- Keep this Mac build-only: no signing, notarization, provider/app launch, VPN preferences, routes, DNS, interfaces, or packet-filter changes.

Return to-review with a new task-scoped outcome. Do not commit or push.