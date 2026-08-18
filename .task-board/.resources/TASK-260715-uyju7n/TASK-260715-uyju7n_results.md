# TASK-260715-uyju7n developer outcome

The macOS host/provider implementation satisfies the task contract and is ready for review. Interactive Apple Development signing is intentionally not claimed here; `TASK-260819-2lu7p6` owns that execution edge.

## Delivered

- Generated `ReluxProxyMac` macOS 15 app with exactly one embedded `ReluxProxyMacTunnel` packet-tunnel system extension.
- Approved r12 identities `works.relux.tunnel.mac` and `works.relux.tunnel.mac.tunnel`, target-owned plists, and separate Development/Developer ID entitlement files.
- Target-specific Debug/Release xcconfig seams for host/provider entitlements and provisioning profiles. Credential-free defaults remain uncompromised; the ignored local signing overlay can enable Gate P0 without editing generated Xcode state.
- Minimal provider entry points only: NetworkExtension system-extension mode, empty start/stop, and version-message handling. No packet reads, routes, DNS, HEV, SSH, relay, or transport implementation was added.
- Automated Swift Testing contracts cover bundle embedding, identifiers, minimum platform, plist ownership/values, shared version compatibility, both entitlement variants, target-specific signing seams, and absence of App Groups/Keychain Sharing.
- The independent legacy SwiftPM product remains outside this workspace and retains package/target/executable name `ReluxProxy`.

## Validation evidence and real exit codes

- `make macos-targets-validate`: 0. Fresh generation; credential-free Debug and Release builds; 6 host tests and 5 provider tests; built-product inspection found exactly one provider with matching versions, macOS 15 floor, exact identifiers, and provider class.
- `make workspace-validate`: 0. Two clean generations were deterministic and the required six macOS-only schemes remained stable.
- `swift test`: 0. 443 tests in 37 suites passed; 25 existing declared known issues remain.
- `swift format lint --strict --recursive App Tests Sources Project.swift Package.swift`: 0.
- `mise exec -- tuist inspect dependencies --only implicit`: 0, no dependency issues.
- plist lint plus shell syntax, `git diff --check`, and `task-board validate`: 0.
- `make check-legacy`: 2 against the independently evolving `../relux-proxy` `v0.2.0-dirty` checkout. It fails the repository's older v0.1.0 byte/default baseline, but explicitly passes the acceptance-relevant boundaries: the SwiftPM executable remains `ReluxProxy`, deployment remains macOS 14, and this generated workspace claims none of its paths. The external checkout was not modified.

## Gate P0 evidence and scope

Generated development settings are target-specific: host/provider consume their own entitlement variables and profile specifiers in both Debug and Release, while `Signing.example.xcconfig` supplies Apple Development/automatic-signing defaults without credentials. Both entitlement channels preserve r12, and tests reject App Groups/Keychain Sharing.

Earlier non-interactive signed-build attempts retained under `.temp/TASK-260715-uyju7n/` exited 65 because the installed host provisioning/Keychain session was unusable; no capability was weakened. Actual interactive signed build execution is tracked separately by `TASK-260819-2lu7p6`, as required by the current acceptance contract.

## Important anomaly

Linking the out-of-scope live `ReluxTunnelMacOSAdapter` exposes an existing Xcode `ProcessXCFramework` output collision between `ReluxLibSSH2` and `CReluxNativeFixture` at `include/module.modulemap`. The compile-only provider therefore depends only on `ReluxTunnelCore`; later runtime integration owns resolving that packaging collision before adding transport composition.
