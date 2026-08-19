# TASK-260715-1ue4oy fresh review 06

Independently review only rework 05 plus regression risk. The implementation now carries the initially observed existing directory identity and adds pre-exchange verification/rollback. Do not repeat broad product-graph or 450-test validation already established by prior reviews; inspect and exercise the filesystem publication state machine deeply.

## Required checks

1. Reproduce all three existing-destination replacement windows: immediately after initial observation, before publication, and immediately before exchange. Foreign directory B and its marker must survive; displaced stale directory A must survive; owned staging must be removed; generation must fail closed.
2. Verify validation reads directory A through a parent-fd-anchored no-follow descriptor and cannot silently validate B after path replacement.
3. Audit the check-to-exchange window. If the exchange displaces an identity other than A, rollback must restore that exact foreign inode to the destination before any cleanup; cleanup may remove only the known staged inode.
4. Re-run the absent-at-start races and interruption cleanup so rework 04 remains intact.
5. Run all manifest Python tests, `make relay-asset-manifest-test`, bundle check, Black/py_compile/diff checks. Broader Swift/product builds are not required unless the Python-only delta affects them.
6. Inspect error paths for descriptor leaks, foreign inode deletion, orphaned owned staging, or accidental replacement on symlink/non-directory/unavailable states.

Accept only with independent evidence and checklist reviewer items checked; do not commit. On failure, attach a precise reproduction and route to `to-dev`.

No signing, install, app/provider launch, VPN preferences, `startVPNTunnel`, routing, DNS, interface, or firewall changes.
