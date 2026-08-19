# BUG-260819-8qf0s0 reviewer verdict

## Verdict

Changes requested. Route to `to-dev`.

## Blocking finding

`scripts/check-generated-provider-graph.py::verify_generated_project` checks only whether the global generated pbxproj text contains `ReluxTunnelMacOSAdapter` and `apple-bundle-input`. It does not prove that the `ReluxProxyMacTunnel` PBXNativeTarget owns the corresponding Frameworks and Resources build-phase edges.

Adversarial generated-project fixtures under `.temp/BUG-260819-8qf0s0-review/` removed every `ReluxTunnelMacOSAdapter in Frameworks` edge and, separately, every `apple-bundle-input in Resources` edge while retaining unrelated product/file-reference declarations. Both commands still printed `generated provider graph and relay resource contract passed` and exited 0:

- missing generated adapter build edge: exit 0
- missing generated relay resource build edge: exit 0

This violates the fail-closed generated-graph acceptance criterion and the explicit DoD requiring rejection of a missing adapter edge and missing relay resource. The negative regression test mutates only `Project.swift` and the relay filesystem, so it does not cover either malformed generated graph.

## Required rework

Parse or otherwise scope the generated pbxproj assertions to the `ReluxProxyMacTunnel` native target and its referenced Frameworks/Resources phases. Add negative fixtures that remove those generated build-phase edges while leaving global declarations present, and assert nonzero exits.

## Passing evidence

`make credential-free-validate LEGACY_ROOT=../relux-proxy` completed with exit 0 during review. Relay packaging, validation-contract tests, deterministic generation, unsigned macOS target builds/contracts, core boundaries, 443 Swift tests (25 documented known issues), Swift Release build, native packaging, and legacy preservation all passed. `swift format lint --strict` and `git diff --check` exited 0. No signing, installation, app/system-extension launch, VPN preference/tunnel, route, or DNS mutation was performed.