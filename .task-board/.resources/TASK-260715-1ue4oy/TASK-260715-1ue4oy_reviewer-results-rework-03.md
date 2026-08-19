# TASK-260715-1ue4oy fresh reviewer results — rework 03

Date: 2026-08-19
Role: reviewer
Verdict: changes requested
Route: to-dev

## Blocking finding

Initial publication still overwrites a foreign destination that appears after generate_bundle has already observed the destination absent but before publish_staged_bundle performs its second stat. The initial absence is observed at scripts/relay_asset_manifest.py:1060-1074, then discarded. A race injected at the existing before_publish hook at line 1115 creates the foreign directory before the stat at lines 1010-1015. publish_staged_bundle therefore misclassifies it as an existing stale bundle, takes the exchange branch at line 1037, and deletes the displaced foreign directory at line 1043.

Independent reproduction exited 1: result=publish_succeeded; foreign_identity=(16777232,714336157); current_identity=(16777232,714336151); foreign_inode_preserved=False; foreign_marker_preserved=False; staging_paths=[]. This violates rework-contract-02 requirement 1: a destination appearing in the absent-case race must retain its inode/content while publication fails closed or retries safely. The current test_initial_publication_race_preserves_foreign_destination injects only at before_initial_publish, after the second stat, and therefore misses this earlier race window.

Required rework: carry the initial destination state or publication intent into publish_staged_bundle and use parent-descriptor-anchored atomic no-replace for the whole initially-absent attempt, regardless of a later pre-publication stat. Add the exact before_publish race regression proving nonzero/failure, unchanged foreign inode and marker, and owned staging cleanup. Preserve the already-passing exchange, interruption, archive, and descriptor tests.

## Independently passing evidence

- python3 -m unittest scripts.tests.test_relay_asset_manifest -v: exit 0, all 19 tests. The same-descriptor archive test, hostile PAX/oversize bounds, post-stat no-replace race, and all three fdopen failure paths pass.
- black --check for all three modified Python files, py_compile, and git diff --check: exit 0.
- make relay-asset-manifest-test: exit 0, 19 Python plus 4 Swift manifest tests. make relay-asset-bundle-check: exit 0.
- Accepted archive SHA-256 is 1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e. Independent USTAR inspection found exactly four ordered 0755 members with sizes and SHA-256 values 2623664/783b94982e90f0ceed0af0fa11662d11a333e244b87256cbfa0f7d21695f3290, 2487362/8ac45b257099c9d2079b0bd2cb9ae489acfb86e443ba7ca7e4b4b2a56380d64c, 2592894/ddcb22ed4d4a978992a04096abae8adc58d0b8bf3bcdc0c0a006775797e2941f, and 2556030/908b3d9ea3543b6144e2c99407c9aa02cc69e86c1cce80364d32dbdc3de8e0dc. Two fresh accepted-archive generations were byte-identical. Native arm64 and Rosetta amd64 identity commands exited 0 with the exact seven-field protocol-v1 identities.
- Static/fake-libc audit confirmed Darwin RENAME_EXCL=4 and RENAME_SWAP=2, Linux RENAME_NOREPLACE=1 and RENAME_EXCHANGE=2, both source and destination anchored to the same parent descriptor; unsupported platforms fail with AssetManifestError.
- Generated provider graph negatives, swift build targets ReluxTunnelIOSAdapter and ReluxTunnelMacOSAdapter, make workspace-validate, and make macos-targets-validate: exit 0. Unsigned host/provider products contained the exact validated relay resources.
- make check-core-boundaries and make relay-protocol-check: exit 0. swift test: exit 0, 450 tests passed with 25 existing known issues; no HEV timing failure reproduced.

## Safety and scope

No signing, installation, app/provider launch, startVPNTunnel, NetworkExtension preference mutation, route/DNS change, upload, network fetch, or real VPN-state operation was performed. Builds were unsigned and rootless identity executions used only accepted local relay assets.