# TASK-260715-u8tkx0 rework 04 results

Date: 2026-08-22
Role: doc-writer
Verdict: PASS — ready for independent review
Scope: documentation-only correction to historical default trusted-bundle publication; no commit or push

## Result

The remaining AC1 fresh-clone defect is closed. The historical trusted-bundle
block now passes the repository-absolute `.build/relay/relay-assets-v1`
destination to both `relay-asset-bundle-generate` and
`relay-asset-bundle-check`, then compares the independently rebuilt historical
manifest to that explicit default bundle. This avoids the relative-parent
initial-publication mismatch when the bundle does not already exist.

The other documented default checks were audited. The coordinated rotation
path first creates the default bundle through `relay_asset_manifest.py`'s
repository-absolute default during supply-chain generation, so its later Make
checks are not initial-publication paths. Candidate and mismatch paths already
pass explicit absolute task-scoped destinations. No implementation,
deterministic metadata, rotation, rollback, incident, RACI, M2/M5, ownership,
or downstream-consumer semantics changed.

## Fresh-clone historical evidence

- Created a genuine `git clone --no-local --no-hardlinks` under a fresh
  task-scoped temporary parent. Before execution, assertions proved that
  neither `.temp` nor `.build/relay/relay-assets-v1` existed. Only the already
  checksum-pinned Go 1.26.5 and Syft 1.48.0 toolchain trees were provisioned,
  as allowed by the prerequisite contract.
- Pinned tool identity, full-history checks, and
  `make relay-supply-chain-audit`: exit `0`.
- Retained `TASK-260715-24icoz` archive retrieval and SHA-256 verification:
  exit `0`,
  `1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e`.
- Two independent source clones, split source/recipe overlay verification,
  eight clean four-target builds, two normalized archives, cross-run
  comparison, and retained-byte comparison: aggregate exit `0`. Both archives
  matched exactly at SHA-256
  `1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e`.
- Two explicit task-scoped trusted bundles generated, checked, and compared:
  exit `0`; both generation and check success tokens were present.
- The corrected initial default-bundle generation from an absent destination
  exited `0`; the new explicit default-bundle check exited `0`; `cmp` proved
  its `relux-relay-assets-v1.json` was byte-identical to the independently
  rebuilt historical manifest.
- Rework 04 remains build-only and documentation-only. The previously
  independently accepted deterministic `identical=15/15`, native `17/17`,
  unsupported-runtime rejection, mismatch rejection, coordinated `10/10`
  rotation, rollback, compromise, and manifest-role evidence is unchanged by
  this focused command correction.

## Main-tree gates

- Four focused Python suites: exit `0`, 107 tests passed.
- `swift test --filter RelayAssetManifestTests`: exit `0`, four tests passed.
- Toolchain check, supply-chain audit, and trusted-bundle check: aggregate exit
  `0`.
- `make workspace-generate workspace-validate`: exit `0`; generated
  provider/resource graph and workspace foundation validation passed.
- `make macos-targets-validate`: exit `0`; provider/resource contract and
  macOS host/provider target validation passed. Only the documented Xcode
  destination and variable product-name warnings appeared.
- Runbook shell syntax: exit `0`, 14/14 blocks.
- Runbook local links: exit `0`, 32/32.
- Live concrete board IDs: exit `0`, 44/44.
- Sensitive/host-absolute-path scan: exit `0`.
- `git diff --check`: exit `0`.
- `task-board validate`: process exit `0`; it reports the known
  `PARENT_STATUS_MISMATCH` for `EPIC-260715-2lz67t` while this task's active
  lifecycle aggregate is development.

## Evidence-recording retry

The first inline `update_resource` attempt was malformed by shell
interpretation of Markdown backticks. It did not update the outcome, triggered
an unintended workspace validation, and was interrupted with exit `130`.
This file-based resource update is the corrective retry. The earlier required
workspace validation had already completed successfully with exit `0`; no
source or system-network state was changed by the failed evidence command.

## Logbook and safety

LOGBOOK records the fresh initial-publication anomaly, absolute-destination
correction, exact retained archive hash, and independent manifest comparison.

All execution was rootless and build-only. It did not sign, notarize, attest,
publish, install, launch an app/provider, access credentials, configure or
start a VPN, change NetworkExtension preferences, routes, DNS, interfaces, or
packet filters, or execute a remote or mismatched asset.
