# TASK-260715-u8tkx0 fresh reviewer verdict after rework 03

Date: 2026-08-22
Role: reviewer
Verdict: changes requested (`to-dev`)

## Result

Rework 03 closes the three reported scratch-parent defects. All five documented
`mktemp` templates now have an explicit parent creation, and a genuinely fresh
`git clone --no-local --no-hardlinks` with no `.temp` directory passed the
deterministic, native-smoke, unsupported-runtime, coordinated-rotation, trusted
manifest, and mismatch paths.

The task is not accepted because AC1's historical trusted-bundle block is still
not copy-paste executable from a fresh clone that contains only the documented
prerequisite toolchains. The final default-bundle command at
`docs/relay-asset-release-runbook.md:255` exited `2`:

```text
python3 scripts/relay_asset_manifest.py generate \
        --archive ".task-board/.resources/TASK-260715-24icoz/TASK-260715-24icoz_portable-relay-assets.tar.gz" \
        --bundle ".build/relay/relay-assets-v1"
error: relay asset staging directory is not a sibling
make: *** [relay-asset-bundle-generate] Error 1
```

The fresh clone had no pre-existing `.build/relay/relay-assets-v1` bundle. The
generator creates an absolute staging path with `tempfile.mkdtemp` at
`scripts/relay_asset_manifest.py:1403`, then compares it with the relative
bundle parent at line 1247. A pre-existing valid default bundle returns before
that publication path, which masked this failure in earlier evidence.

Required correction: make the documented initial default-bundle generation
use an absolute destination (for example
`make relay-asset-bundle-generate RELAY_ASSET_BUNDLE="$REPO/.build/relay/relay-assets-v1"`)
or fix the generator to canonicalize its bundle parent before publication, and
then rerun the historical block in a clean clone without a pre-generated
default bundle. The proposed absolute-destination command was independently
tried in the same failed clone and exited `0`; its manifest compared exactly
with the independently generated historical manifest.

## Independent execution evidence

- Historical source/recipe overlay, eight target builds, two archives, retained
  archive comparison, and two explicit trusted bundles passed. The archive
  SHA-256 was exactly
  `1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e`.
  The final default-bundle initial publication then failed as quoted above.
- Rework-03 delta inspection matched the producer's patch: only three
  `mkdir -p "$REPO/.temp"` lines were added to the runbook at the historical,
  deterministic, and rotation boundaries. The other two `mktemp` parents were
  already created. Parent audit: `5/5`.
- Deterministic current-candidate block in a separate fresh clone: exit `0`,
  `relay reproducibility: identical=15/15`, archive SHA-256
  `09014b22e694b1ff4ab664c81d46b3afccd5a973f701cbd4625bfd88c093ab40`,
  and release-builder manifest SHA-256
  `ef5bd8b3cc41ce0e30c026bd088b370faeea30d789a7c6708631330afe8b049d`.
- Native Darwin/arm64 smoke: exit `0`, `17/17`. Native Linux/amd64 request on
  Darwin/arm64: expected tool exit `1`, enclosing assertions exit `0`,
  `native_runner_identity_mismatch`, no artifact observation, and no process
  start.
- Coordinated changed-candidate rotation: exit `0`; generation/audit, 21 and
  26 Python tests twice, four Swift manifest tests twice, bundle checks, exact
  comparisons, and `relay metadata rotation: changed-files=10/10` passed.
  The accepted main-tree rotation surfaces remained unchanged (`10/10`).
- Two trusted candidate bundles and manifests matched exactly. Copied-bundle
  size drift produced expected `make` exit `2` and the documented diagnostic;
  the copied executable was not run.
- Main-tree focused suites: exit `0`, 107 Python tests passed. Toolchain
  positive/negative, supply-chain audit, trusted bundle check, workspace
  validation, and macOS target validation all exited `0`; only the documented
  destination, product-name, deprecation, and linker warnings appeared.
- Runbook shell syntax `14/14`, local links `32/32`, live concrete board IDs
  `44/44`, sensitive/absolute-path scan, and `git diff --check` exited `0`.
- `task-board validate` process exit was `0`; it reported the existing
  `PARENT_STATUS_MISMATCH` for `EPIC-260715-2lz67t`, whose displayed aggregate
  follows this task's active review lifecycle.

## Acceptance assessment

- AC1: rejected. The historical default trusted-bundle command fails on its
  initial-publication path in a fresh clone.
- AC2: accepted. Strict order, deterministic 15/15 proof, coordinated 10-file
  rotation, and downstream gates remain intact.
- AC3: accepted. Exact-byte/manifest rollback, coexistence/replacement rules,
  and the prohibition on executing unverified remote bytes are unchanged.
- AC4: accepted. RACI still separates source/hash/notices from signing,
  notarization, attestation, approval, and containing-app ownership.
- AC5: accepted. Required failure modes, compromise handling, credential-safe
  evidence, M2/M5 boundaries, and concrete board links remain present and live.

## Safety

The review was rootless and build-only. It did not sign, notarize, attest,
publish, install, launch an app/provider, access credentials, configure or
start a VPN, change NetworkExtension preferences, or modify routes, DNS,
interfaces, or packet filters. No mismatched or remote executable was run.
