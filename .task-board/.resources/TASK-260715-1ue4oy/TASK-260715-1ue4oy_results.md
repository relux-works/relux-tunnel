# TASK-260715-1ue4oy fresh reviewer results 07

Date: 2026-08-19
Role: reviewer
Verdict: accepted
Route: done

## Scope and audit

Independently reviewed rework 06 only, as required by the latest contract. The descriptor-owned cleanup at scripts/relay_asset_manifest.py lines 1020-1111 opens the top-level target relative to an already-open parent with O_NOFOLLOW and O_DIRECTORY, compares fstat identity to the expected device/inode, scans and unlinks children only through the owned descriptor, permits only the manifest plus the four canonical relay assets, rejects nested directories, symlinks, duplicate/unsupported names and unsupported types, rechecks the pathname identity after traversal, and removes the top-level entry with parent-relative rmdir. Publication invokes this helper on the displaced identity at lines 1253-1263. All descriptors close through success and error finally paths.

The exact post-open directory-to-directory replacement regression at scripts/tests/test_relay_asset_manifest.py lines 748-798 passes: generation fails closed, foreign B retains exact identity and marker bytes, displaced stale A survives aside after descriptor-owned emptying, and the published bundle remains valid. Existing absent/existing publication races, normal stale replacement, same-descriptor archive verification, hostile archive bounds, fdopen failures, and interruption cleanup also pass. No blocking findings. No source edits or commit were made by this reviewer.

## Independent execution evidence

- python3 -m unittest scripts.tests.test_relay_asset_manifest -v: exit 0; 26 tests.
- Reviewer hostile cleanup probe for nested directory, allowed-name symlink, and unsupported filename: exit 0; each rejected, target preserved, both opened descriptors closed.
- Reviewer successful cleanup descriptor probe: exit 0; exact five-file owned tree removed and both opened descriptors closed.
- make relay-asset-manifest-test: exit 0; 26 Python tests and 4 Swift relay manifest tests.
- make relay-asset-bundle-check: exit 0; accepted TASK-260715-24icoz archive and generated bundle/identity check passed.
- black --check scripts/relay_asset_manifest.py scripts/tests/test_relay_asset_manifest.py scripts/check-generated-provider-graph.py: exit 0.
- python3 -m py_compile for the same three Python files: exit 0.
- git diff --check: exit 0.

Prior product-graph, unsigned Apple product, core/protocol, and broad Swift evidence remains valid and was intentionally not repeated under reviewer-contract-07 and rework-contract-06 because this delta is Python-only.

## Safety

No signing, installation, app/provider launch, NetworkExtension preference mutation, startVPNTunnel, tunnel start, route, DNS, interface, firewall, upload, or network-fetch operation was performed.