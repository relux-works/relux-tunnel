# BUG-260819-8qf0s0 implementation results

## Outcome

Implemented the accepted production provider graph and mandatory reviewer rework. ReluxProxyMacTunnel consumes ReluxTunnelMacOSAdapter and the verified relay folder resource; the adapter production closure remains Core plus HEV/libssh2 through ReluxTunnelMacOSAdapter, while CReluxNativeFixture remains test evidence only.

The generated-project validator now resolves the unique ReluxProxyMacTunnel PBXNativeTarget, follows the PBXFrameworksBuildPhase and PBXResourcesBuildPhase IDs referenced by that target, dereferences build-file product/file references, and requires exactly one ReluxTunnelMacOSAdapter Frameworks edge and one apple-bundle-input Resources edge. Global declarations alone cannot satisfy either check.

## Regression coverage

The focused generated graph suite creates two adversarial project.pbxproj fixtures. One removes the adapter build-file ID from the provider Frameworks phase; the other removes the relay build-file ID from the provider Resources phase. Both retain global product/file/build-file declarations and both are required to exit nonzero. Existing missing source edge, missing relay payload, fixture leakage, unexpected dynamic library/loading symbol, manifest/checksum, bundle payload, and provider linkage checks remain active.

## Validation

- ./scripts/tests/test-generated-provider-graph.sh: exit 0
- make credential-free-validate LEGACY_ROOT=../relux-proxy: exit 0
- python3 -m py_compile scripts/check-generated-provider-graph.py: exit 0
- sh -n scripts/tests/test-generated-provider-graph.sh: exit 0
- swift format lint --strict --recursive Package.swift Project.swift Sources Tests: exit 0
- git diff --check: exit 0

The credential-free matrix passed relay tool bootstrap/packaging, validation contract tests, deterministic double generation, unsigned macOS target builds and contracts, core boundaries, Swift tests, Swift Release build, native packaging, and isolated legacy clone/test/build gates. Logs are under .temp/TASK-260715-sbrrp7/credential-free-validation/.

## Safety

No signing, app or system-extension installation or launch, VPN preference/tunnel activation, route mutation, or DNS mutation was performed.