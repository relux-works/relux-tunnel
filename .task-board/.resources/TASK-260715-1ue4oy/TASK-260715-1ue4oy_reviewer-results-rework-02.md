# TASK-260715-1ue4oy fresh reviewer results — rework 02

Date: 2026-08-19
Role: reviewer
Verdict: changes requested
Route: to-dev

## Blocking findings

1. Initial publication can overwrite a raced foreign destination. `publish_staged_bundle` checks `lstat(bundle)` and, when absent, later calls `os.replace(staging, bundle)` (`scripts/relay_asset_manifest.py:883-906`). An injected race created an empty foreign directory immediately before the real replace; publication returned success and the final device/inode differed from the held foreign directory. The adversarial safe-publication check exited 1 with `foreign_destination_overwritten=True`. This violates the ownership-aware race contract. Use an atomic no-replace primitive for the absent case, keep the parent directory descriptor-owned, and retry or fail closed if a destination appears. Add a regression that proves the raced foreign path/inode is preserved.

2. Archive verification still reopens a mutable pathname. `read_archive_assets` hashes one no-follow descriptor through `sha256_file`, closes it, then calls `tarfile.open(archive)` by pathname (`scripts/relay_asset_manifest.py:400-405`). An injected replacement changed that pathname to a symlink after hashing; all four assets were accepted and the adversarial check exited 1 with `symlink_replacement_accepted=True`. This is a TOCTOU gap and removes the digest-before-parse bound because a different archive can reach `getmembers()`. Hash, rewind, and parse the same descriptor/file object; preserve no-follow ownership through the whole operation and add symlink/replacement plus bounded hostile-metadata regressions.

3. Descriptor ownership is incomplete on `fdopen` failures. Injected `os.fdopen` errors left the descriptors opened by both `sha256_file` (`scripts/relay_asset_manifest.py:125-139`) and `write_new_file_at` (`scripts/relay_asset_manifest.py:779-800`) live; the adversarial close-path check exited 1 with both `sha256_file_descriptor_leaked=True` and `write_new_file_at_descriptor_leaked=True`. Retain explicit descriptor ownership until `fdopen` succeeds (or avoid the conversion), close on every failure, and add fault-injection regressions. Prefer descriptor-based mode changes rather than reopening the output name.

The existing 15-test suite does not cover these three cases. The fixed implementation must add them without weakening the existing oversize, no-follow bundle validation, exchange cleanup, interruption, stale replacement, and deterministic checks.

## Independent passing evidence

- Attached task contract byte counts and SHA-256 digests matched the prompt exactly.
- `python3 -m unittest scripts.tests.test_relay_asset_manifest -v`: exit 0, 15 tests.
- `black --check scripts/relay_asset_manifest.py scripts/tests/test_relay_asset_manifest.py scripts/check-generated-provider-graph.py`: exit 0.
- `git diff --check`: exit 0.
- Accepted archive independently streamed as exact ordered members with SHA-256 `1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e`; member sizes/hashes were 2623664/783b9498..., 2487362/8ac45b25..., 2592894/ddcb22ed..., and 2556030/908b3d9e....
- `make relay-asset-bundle-check`: exit 0. Native arm64 and Rosetta amd64 `--identity --protocol 1` commands both exited 0 and matched schema 1, protocol 1, version 0.1.0, source commit `58676a23e2e0fb3fcc1b5005d59c6ed56d3c0096`, tuple, and self hash. Linux identities remain tied to the independently verified accepted bytes and embedded identity validation, not misreported native execution.
- `swift test --filter RelayAssetManifestTests`: exit 0, 4 Swift Testing tests; `swift build --target ReluxTunnelIOSAdapter`: exit 0; `swift build --target ReluxTunnelMacOSAdapter`: exit 0.
- `./scripts/tests/test-generated-provider-graph.sh`: exit 0.
- `make workspace-validate`: exit 0.
- `make macos-targets-validate`: exit 0; unsigned host/provider products and exact embedded relay resources validated.
- `make check-core-boundaries`: exit 0.
- `make relay-protocol-check`: exit 0; 58 Swift protocol tests plus Go/schema/vector/negative/drift gates passed.
- `swift test`: exit 0; 450 tests passed with the existing 25 known issues. The preserved historical HEV timing failures did not reproduce and no unrelated HEV change is requested.
- Developer and reviewer preflights both resolve Codex-only `gpt-5.6-sol` high with `max_parallel: 1`; the config and policy documents agree.

## Safety and scope

No signing, installation, app/provider launch, `startVPNTunnel`, NetworkExtension preference mutation, route change, DNS change, upload, network fetch, or real VPN-state operation was performed. Builds were unsigned and all adversarial checks used temporary local directories.
