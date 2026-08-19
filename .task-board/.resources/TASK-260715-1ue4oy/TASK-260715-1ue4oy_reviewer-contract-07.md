# TASK-260715-1ue4oy fresh review 07

Independently review rework 06 only. Prior product-graph, archive, manifest, and broad Swift evidence remains valid; do not repeat it. Review the new descriptor-owned bounded cleanup and its focused regression.

## Acceptance checks

1. Reproduce reviewer-06's directory-to-directory replacement at the former lstat-to-rmtree boundary. The opened/owned stale directory may be emptied through its descriptor, but foreign replacement B and marker bytes at the pathname must survive and generation must fail closed.
2. Verify traversal never reopens the top-level pathname, refuses nested directories/symlinks/unsupported names, limits entries to the known relay bundle files, and closes all descriptors on success/error.
3. Verify top-level removal is parent-descriptor-relative and is preceded by identity verification after descriptor-owned traversal. Exercise a changed pathname before that verification; it must be preserved.
4. Re-run all publication-race tests, normal stale-bundle replacement, interruption cleanup, all manifest Python tests, `make relay-asset-manifest-test`, bundle check, Black, py_compile, and `git diff --check`.
5. Do not expand the threat model beyond concurrent replacement of the top-level cleanup pathname proven by reviewer 06; report unrelated general-purpose deletion hardening only as non-blocking because this helper is deliberately bounded to the generated relay bundle tree.

Accept only with independent evidence and checked reviewer items; do not commit. Otherwise attach exact evidence and route to `to-dev`.

No signing, installation, provider/app launch, VPN preference mutation, `startVPNTunnel`, route, DNS, interface, or firewall changes.
