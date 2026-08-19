# TASK-260715-1ue4oy fresh reviewer results 06

Date: 2026-08-19
Role: reviewer
Verdict: changes requested
Route: to-dev

## Blocking finding

The successful existing-bundle exchange still has a pathname cleanup race that can delete a foreign directory. `scripts/relay_asset_manifest.py:1021-1041` checks the staging path with `os.lstat`, then calls `shutil.rmtree(path)` as a separate pathname operation. `scripts/relay_asset_manifest.py:1183-1189` uses that helper to remove the displaced stale bundle after exchange. A local process can replace the checked path between the ownership check and `rmtree`; the recursive delete then opens and deletes the replacement rather than the checked inode. `shutil.rmtree.avoids_symlink_attacks` does not bind its internally opened directory to the earlier application-level `(st_dev, st_ino)` ownership observation.

Independent deterministic reproduction injected the replacement at the `shutil.rmtree` conversion point during `generate_bundle`: stale directory A was atomically displaced to the staging name, then moved aside and foreign directory B with marker bytes was placed at that name before the real `rmtree` call. Generation returned successfully, the published bundle validated, A survived aside, but B and its marker were deleted. Reproduction output:

```text
outcome=returned
race_injected=True
foreign_marker_locations=[]
displaced_stale_survives=True
published_bundle_valid=True
```

The reproduction assertion exited 1. This violates reviewer-contract-06 requirements that cleanup remove only the known staged/displaced inode and that no error path delete a foreign inode.

Required rework: make recursive cleanup descriptor-owned and parent-descriptor-anchored all the way through deletion, with an identity check on the same opened directory used for traversal. Unlink/rmdir entries relative to owned descriptors and remove the top-level name only if it still resolves to the same owned inode. Add the exact directory-to-directory replacement regression at the post-check/pre-recursive-delete boundary. Do not weaken the existing symlink, interruption, or publication-race gates.

## Independent checks

- `python3 -m unittest scripts.tests.test_relay_asset_manifest -v`: exit 0, 24 tests. This independently re-ran all three existing-destination windows, both absent-at-start races, interruption cleanup, archive bounds/no-follow, and fdopen leak cases.
- `make relay-asset-manifest-test`: exit 0, 24 Python tests and 4 Swift manifest tests.
- `make relay-asset-bundle-check`: exit 0.
- `black --check scripts/relay_asset_manifest.py scripts/tests/test_relay_asset_manifest.py scripts/check-generated-provider-graph.py`: exit 0.
- `python3 -m py_compile` over the same three Python files: exit 0.
- `git diff --check`: exit 0.
- Integrated foreign-directory cleanup race reproduction: exit 1, because generation returned and deleted the foreign marker.

The new immutable publication intent, initial identity capture, descriptor-anchored no-follow validation of A, pre-exchange identity check, and wrong-inode exchange rollback all match rework 05 and their focused regressions pass. Acceptance is blocked only by the cleanup race above.

## Safety

No signing, installation, app/provider launch, NetworkExtension preference mutation, `startVPNTunnel`, tunnel start, route, DNS, interface, firewall, upload, or network-fetch operation was performed. No source code was edited and no commit was created.
