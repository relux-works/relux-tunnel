# TASK-260715-1ue4oy independent reviewer results — local build integrity 04b

Date: 2026-08-19
Role: reviewer
Verdict: changes requested
Route: to-dev

## Blocking finding

Initial publication still has a validation-to-lstat race in scripts/relay_asset_manifest.py:1073-1088. generate_bundle first calls validate_bundle. If that call observes the destination missing, a foreign directory can appear before the follow-up os.lstat. The later lstat sets destination_existed_at_start=true, so publish_staged_bundle enters the exchange path and deletes the foreign directory even though generation began by observing no destination.

Independent temporary-fixture reproduction injected the foreign directory immediately after validate_bundle failed on the missing destination and before generate_bundle called lstat. It exited 1 with: injected=True; result=publish_succeeded; foreign_identity=(16777232,714574908); current_identity=(16777232,714574910); foreign_inode_preserved=False; foreign_marker_preserved=False; staging_paths=[].

This violates reviewer-contract-04 and 04b: an initially absent destination must remain a no-replace publication intent for the entire attempt, and a raced foreign inode and marker must survive unchanged while generation fails closed. The checked-in before_publish and before_initial_publish tests both occur after the vulnerable reclassification window.

Required rework: eliminate the two-step missing-validation then pathname-lstat classification. Capture initial publication intent from the first parent-descriptor-anchored destination observation and carry it unambiguously through publication. If that observation is absent, use atomic no-replace for the entire attempt regardless of every later path state. Add the exact regression that creates the foreign destination after the initial missing observation but before the current lstat/reclassification point, asserting failure, exact device/inode and marker preservation, and owned-staging cleanup.

## Independently passing evidence

- python3 -m unittest scripts.tests.test_relay_asset_manifest -v: exit 0, 20 tests.
- make relay-asset-manifest-test: exit 0, 20 Python tests plus 4 Swift manifest tests.
- black --check on scripts/relay_asset_manifest.py, scripts/tests/test_relay_asset_manifest.py, and scripts/check-generated-provider-graph.py: exit 0.
- python3 -m py_compile for the same files and git diff --check: exit 0.
- Accepted archive SHA-256: 1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e.
- Two fresh generations were byte-identical; make relay-asset-bundle-check exited 0.
- Exact four identities were re-derived: darwin/amd64 2623664 783b94982e90f0ceed0af0fa11662d11a333e244b87256cbfa0f7d21695f3290; darwin/arm64 2487362 8ac45b257099c9d2079b0bd2cb9ae489acfb86e443ba7ca7e4b4b2a56380d64c; linux/amd64 2592894 ddcb22ed4d4a978992a04096abae8adc58d0b8bf3bcdc0c0a006775797e2941f; linux/arm64 2556030 908b3d9ea3543b6144e2c99407c9aa02cc69e86c1cce80364d32dbdc3de8e0dc. All use protocol 1, relay version 0.1.0, and source commit 58676a23e2e0fb3fcc1b5005d59c6ed56d3c0096. Native arm64 and Rosetta amd64 identity commands exited 0.
- scripts/tests/test-generated-provider-graph.sh: exit 0.
- swift build --target ReluxTunnelIOSAdapter and ReluxTunnelMacOSAdapter: exit 0.
- make workspace-validate: exit 0.
- make macos-targets-validate: exit 0; unsigned host/provider products and relay resources validated.
- make check-core-boundaries: exit 0.
- make relay-protocol-check: exit 0; 89 deterministic vectors and 58 Swift protocol tests passed.
- swift test: exit 0; 450 tests passed with 25 known ReluxNIOSSH availability issues.

## Descriptor and recovery audit

The prior descriptor fixes remain sound in exercised paths: O_NOFOLLOW opens, fstat size gates, the 64 KiB manifest cap, 16 MiB asset cap, same-descriptor archive hash/rewind/USTAR parse, streaming bundle digest and identity validation, explicit fd ownership around all fdopen conversions, fchmod on owned output descriptors, randomized sibling staging, atomic exchange, interruption recovery, and identity-checked staging cleanup all passed their focused regressions.

## Safety

No signing, installation, app/provider launch, startVPNTunnel call, NetworkExtension preference mutation, route or DNS change, upload, network fetch, or real VPN-state operation was performed. Builds were unsigned and local identity execution used only accepted bundled Darwin relay assets.