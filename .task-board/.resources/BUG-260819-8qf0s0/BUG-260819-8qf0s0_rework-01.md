# Rework instruction — generated PBX target-scoped edges

Read the reviewer outcome BUG-260819-8qf0s0_review-results.md. The blocking finding is confirmed: verify_generated_project currently searches global pbxproj substrings. The reviewer removed all generated ReluxTunnelMacOSAdapter in Frameworks build edges while leaving product/file declarations and the validator exited 0. The reviewer separately removed all apple-bundle-input in Resources build edges while leaving declarations and the validator exited 0.

Required implementation:
1. Parse or otherwise scope checks to the ReluxProxyMacTunnel PBXNativeTarget and the PBXFrameworksBuildPhase/PBXResourcesBuildPhase referenced by that target.
2. Require the adapter product build-file edge in that exact Frameworks phase.
3. Require the relay folder build-file edge in that exact Resources phase.
4. Add negative fixtures that remove each exact generated edge while global declarations remain, and assert nonzero.
5. Run these focused adversarial tests before any full matrix.
6. Preserve all existing source graph, relay manifest/checksum, linkage, no-dlopen, no-fixture, credential-free, and build-only-host gates.

No signing, app/system-extension installation or launch, VPN preference/tunnel, route, or DNS mutation.