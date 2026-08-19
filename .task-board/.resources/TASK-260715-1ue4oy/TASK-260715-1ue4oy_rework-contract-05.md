# TASK-260715-1ue4oy focused rework 05

Resume the current implementation. Address only the reviewer-05 existing-destination identity race and regressions introduced by the fix. Do not repeat broad repository discovery.

## Required state model

- Replace the enum-only `REPLACE_EXISTING` intent with an immutable observation that includes the initially observed directory identity `(st_dev, st_ino)`.
- Keep `INITIAL_NO_REPLACE` behavior unchanged.
- For an existing destination, validation and final exchange must apply to the same initially observed directory identity. Immediately before exchange, compare the parent-fd-anchored destination identity with the captured identity. If absent, changed, unsafe, or unavailable, fail closed.
- Never exchange or delete a foreign destination that appeared after the initial observation.
- Keep the already reviewed atomic exchange/no-replace, owned-staging cleanup, bounded descriptor reads, fd ownership, and interruption recovery behavior.

## Exact regression

Start with stale directory A so replacement is required. Immediately after the initial observation, rename A aside and create foreign directory B with exact marker bytes. Assert:

1. generation raises `AssetManifestError`;
2. B retains the exact device/inode;
3. B retains the exact marker bytes;
4. no owned staging remains;
5. A remains outside the destination path and is not deleted by the attempt.

Also preserve the absent-at-start regressions from rework 04.

## Focused verification

- Run the new exact regression plus all manifest Python tests.
- Run `make relay-asset-manifest-test`, formatter/compile/diff checks, bundle check, and only broader gates affected by the delta.
- Do not repeat unsigned Apple builds or the 450-test suite unless the delta unexpectedly reaches product graph/Swift code.
- No signing, installation, provider launch, VPN preference mutation, `startVPNTunnel`, or network-state changes.

Attach focused result evidence and route to `to-review`.
