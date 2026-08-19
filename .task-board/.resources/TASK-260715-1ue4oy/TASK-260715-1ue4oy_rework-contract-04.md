# TASK-260715-1ue4oy focused rework 04

Resume the existing implementation; do not re-audit the whole task. Address only the blocking finding in `TASK-260715-1ue4oy_reviewer-results-04b.md` and regressions caused by the fix.

## Required behavior

- Remove the two-step `validate_bundle(...)` failure followed by pathname `os.lstat(...)` classification in `generate_bundle`.
- Obtain the destination's initial publication state from one parent-directory-descriptor-anchored observation before validation can race with a later classification.
- Carry that immutable publication intent through staging and publication.
- If the initial observation is absent, the entire attempt must remain atomic no-replace. A foreign destination created at any later point must survive unchanged and generation must fail closed.
- If the initial observation names an existing directory, replacement may occur only under the already reviewed identity/recovery rules. Symlinks and non-directories remain rejected.
- Preserve bounded descriptor-based reads, same-descriptor archive verification, fd ownership, atomic publication, interruption recovery, and owned-staging cleanup from prior reworks.

## Exact regression

Add a deterministic test that creates a foreign destination after the first missing observation but before the former `lstat`/reclassification point. Assert:

1. generation fails;
2. the foreign destination's device/inode is identical;
3. its marker bytes are identical;
4. no owned staging directory remains.

The test must fail against the current implementation and pass after the fix. Keep existing timing-window regressions.

## Focused verification

- Run the exact new regression and all `scripts.tests.test_relay_asset_manifest` tests.
- Run `make relay-asset-manifest-test`, formatter/compile checks, and `git diff --check`.
- Run only broader gates affected by the implementation. Do not repeat unrelated repository discovery.
- Do not sign/install/launch the app or provider, save/enable VPN preferences, call `startVPNTunnel`, or change routes, interfaces, DNS, or firewall state on this build host.

Return the task to `to-review` with a task-scoped result describing the fixed state transition and exact regression evidence.
