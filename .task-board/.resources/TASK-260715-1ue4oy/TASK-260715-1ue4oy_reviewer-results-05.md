# TASK-260715-1ue4oy fresh reviewer results 05

Date: 2026-08-19
Role: reviewer
Verdict: changes requested
Route: to-dev

## Blocking finding

The existing-destination publication branch does not preserve the identity observed at the start of generation. scripts/relay_asset_manifest.py:669-692 reduces the parent-descriptor-anchored observation to REPLACE_EXISTING and discards st_dev/st_ino. After staging, scripts/relay_asset_manifest.py:1055-1088 stats whichever directory currently occupies the destination and atomically exchanges and deletes that directory without proving it is the initially observed directory.

A deterministic temporary-fixture reproduction started with stale directory A, then at before_publish renamed A aside and created foreign directory B with marker bytes. Generation exited successfully instead of failing closed. Foreign B identity was (16777232,714958901), the final identity was (16777232,714958895), identity_preserved=False, marker_preserved=False, staging_count=0; the safety assertion exited 1. A second injection immediately after initial observation reproduced the same deletion with exit 1. This violates reviewer-contract-05 blocking check 3.

The current 21 tests cover only initially absent destination races. scripts/tests/test_relay_asset_manifest.py:573-661 has no symmetric existing-A-to-foreign-B regression.

Required rework: carry the exact initially observed existing-directory identity through validation/publication and ensure a changed destination cannot be exchanged or deleted. The fix must close the check-to-exchange race as well as comparing a pre-exchange stat. Add deterministic after-observation and before-publish existing-destination identity-race coverage asserting failure, exact B device/inode and marker preservation, and cleanup only of owned staging. Preserve the current absent-case, exchange interruption, descriptor, archive-bound, and fdopen regressions.

## Independent checks

- python3 -m unittest scripts.tests.test_relay_asset_manifest -v: exit 0, 21 tests.
- make relay-asset-manifest-test: exit 0, 21 Python tests and 4 Swift tests.
- make relay-asset-bundle-check: exit 0.
- black --check on all three Python surfaces: exit 0. An attempted python3 -m black used a Python installation without the module and exited 1; the installed Black executable was then invoked directly and passed.
- python3 -m py_compile: exit 0.
- git diff --check: exit 0.
- Accepted archive SHA-256 independently reproduced as 1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e; source contract has the exact four expected identities, protocol 1, relay version 0.1.0, and source commit 58676a23e2e0fb3fcc1b5005d59c6ed56d3c0096.
- Descriptor/no-follow bounded reads, same-descriptor archive hash/rewind/USTAR parse, fd ownership, initial no-replace, interruption recovery, and identity-checked owned-staging cleanup remain covered by passing focused tests and code audit. Broader Apple/provider suites were not repeated because rework 04 changed only the Python publisher/test path and the blocking publication defect already requires rework.

## Safety

No signing, installation, app/provider launch, VPN preference mutation, startVPNTunnel call, route, interface, DNS, firewall, upload, network-fetch, or real VPN-state operation was performed.