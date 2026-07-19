# TASK-260715-3r0993 — Project generator and deployment-target policy

**Research date:** 2026-07-20 (Asia/Tbilisi)  
**Decision scope:** generated Apple workspace foundation  
**Decision status:** handed off for review  
**Evidence toolchain:** Xcode 26.5 (17F42), Swift 6.3.2, macOS 26.5,
Apple silicon

## Key takeaways

1. Use **Tuist 4.202.5**, pinned exactly in repository-root `mise.toml`.
   This preserves the Relux Works Tuist convention and is the current stable
   Tuist CLI release as of the research date. Tuist's tagged source directly
   models application extensions, system extensions, entitlements, signing
   settings, copy phases, target dependencies, Swift packages, libraries, and
   XCFrameworks required by the planned graph.
2. Set the new Apple targets to **iOS 18.0** and **macOS 15.0** exactly.
   Apple APIs and current dependencies permit older targets, so these are not
   API guesses: they are the oldest major releases with a maintained, executable
   CI/runtime matrix and current physical-device evidence. GitHub's macOS 14
   hosted image entered deprecation on 2026-07-06 and becomes unsupported on
   2026-11-02; selecting macOS 14 for new work would immediately create an
   unowned oldest-OS test gap.
3. Preserve the shipped legacy `ReluxProxy` SwiftPM product at **macOS 14.0** in
   its independent compatibility lane. This decision neither raises nor lowers
   that product's deployment target and does not fold it into the generated
   workspace.
4. The required current physical baselines are an **iPhone 11 on stable iOS
   26.5** and an **Apple M3 Max MacBook Pro on macOS 26.5**. The oldest iOS
   physical compatibility device found is an **iPhone 15 on iOS 18.6.2**.
   iOS 18.6 simulator coverage and macOS 15.7 hosted execution provide the
   credential-free minimum-OS lanes; signed provider installation and lifecycle
   measurements remain Gate P0 evidence.
5. Pin CI to Xcode explicitly. Use **Xcode 26.5 (17F42)** for the current lane
   and **Xcode 16.4 (16F6)** for the minimum-OS compatibility lane. The GitHub
   macOS 26 image is scheduled to change its default from Xcode 26.5 to 26.6 on
   2026-07-21, so `macos-latest` or the image default is not a reproducible tool
   selection.

## Context and decision boundary

The target shape is two containing apps, two packet-tunnel providers,
`ReluxTunnelCore`, `ReluxTunnelHarness`, a portable `relux-relay`, and protocol
tests. The legacy inventory proves that the shipped product is instead a
dependency-free SwiftPM macOS 14 executable with no Network Extension target.
SwiftPM remains appropriate for the shared package, harness, portable relay,
and legacy lane, but it cannot alone express the containing-app/provider
embedding, entitlement, provisioning, archive, and distribution graph.

This task does not select the SSH engine, HEV tuning/fork, relay implementation,
or signing identities. It sets a support floor against which those later
choices must be checked. A later dependency may raise a deployment target only
through a reviewed ADR update with CI and physical-device evidence; it may not
silently rewrite these values.

## Generator comparison

| Choice | Deterministic source and output | Extension targets and signing | Dependency/native integration | CI maintenance | Relux Works fit | Decision |
|---|---|---|---|---|---|---|
| **Tuist 4.202.5** | Swift manifests are compiled and graph-validated. Exact CLI, Xcode, configuration, and dependency locks can be pinned. Generated output still requires a repeat-generation comparison because Tuist documents environment/Swift-version sensitivity. | Tagged `Product` includes `.appExtension` and `.systemExtension`; `Target` carries entitlements, settings, copy phases, and dependencies. Signing helpers cover automatic and manual profile settings. | Supports local targets, system SDKs, libraries, frameworks, XCFrameworks, and SwiftPM. `tuist install` separates dependency resolution from generation. | Official Mise pinning and CI guidance; no server account is required for local generation. Current CLI source requires Swift tools 6.1 and macOS 15, matching the selected CI host floor. | Default specified by Relux Works; nearby Relux Works projects already use Tuist, `tuist install`, `tuist generate`, and exact `.mise.toml` pins. | **Selected.** Strongest typed graph and least organizational divergence. |
| XcodeGen 2.46.0 | Human-readable YAML/JSON and exact executable pin; generated projects can be omitted from Git. Schema/default changes and YAML composition are validated only by generation, not Swift compilation. | Can describe extensions, settings, entitlements, schemes, dependencies, and packages. It is viable, not unsafe. | Supports Swift packages and arbitrary build settings; native seams remain largely build-setting/spec work. | Current stable release exists and runs on macOS 11+, but adopting it creates a second generator convention and separate helpers/CI ownership for no material safety gain. | Not the specified Relux Works default. | Rejected: viable but not materially safer than Tuist. |
| Checked-in native Xcode project/workspace | Xcode is authoritative, but `project.pbxproj` churn, opaque identifiers, and manual edits weaken reproducible review and clean regeneration. | Full first-party feature coverage. | Full Xcode integration. | No generator install, but merge repair, drift detection, and graph normalization become repository maintenance. | Conflicts with the requested generated-workspace convention. | Rejected for reproducibility and reviewability. |
| SwiftPM-only | Deterministic manifest and lockfile for packages. | Does not provide the complete app/provider embedding, entitlement, provisioning, archive, and distribution workspace required here. | Excellent for shared/core/CLI code; insufficient as the workspace generator. | Low for package-only work, but would require a second manual project layer for Apple products. | Preserved as a component and legacy lane, not the workspace generator. | Rejected as the sole generator. |

No Bazel/rules_xcodeproj migration is justified: this repository has no Bazel
graph or remote-build investment, and introducing both a new build system and a
project projection layer would expand CI and native-dependency ownership without
solving a support gap demonstrated in Tuist.

## Exact generator and bootstrap policy

Repository pin:

```toml
# mise.toml
[tools]
tuist = "4.202.5"
```

Bootstrap from a clean checkout:

```sh
mise install
mise exec -- tuist version
mise exec -- tuist install
mise exec -- tuist generate --no-open
```

Required invariants:

- `tuist version` must equal `4.202.5`; do not use `latest`, a `4.x` range,
  Homebrew's unversioned formula, or a pre-release/canary channel.
- Commit `mise.toml`, Tuist manifests, dependency manifests and lockfiles,
  checksummed binary-target metadata, and pinned native-source revisions.
  Do not commit fetched dependencies, credentials, profiles, DerivedData, or
  generated `.xcodeproj`/`.xcworkspace` output.
- Generation uses local features only at foundation time. Tuist server cache,
  registry, or analytics authentication is not a bootstrap dependency.
- Manifests must not encode user-home paths, timestamps, unordered external
  input, machine names, or secret-dependent graph branches.
- CI generates into two clean checkout copies with the same Tuist/Xcode pair,
  compares `tuist graph --format json`, scheme/build-setting inventories, and
  generated `project.pbxproj` files, then performs a clean third generation for
  builds. Any unexplained difference is a failure.
- CI sets `DEVELOPER_DIR` to an exact installed Xcode path and records
  `xcodebuild -version`, `swift --version`, SDK versions, Tuist version, graph,
  schemes, deployment targets, and dependency-lock digests.

The current local `/opt/homebrew/bin/tuist` is 4.118.1. That global executable is
evidence of drift, not the project tool selection; every documented and CI
command must execute through Mise.

## Deployment-target evidence

### API and Swift floors

The installed Xcode 26.5 SDK headers/interfaces show:

| Capability | Verified availability | Effect on decision |
|---|---:|---|
| `NEPacketTunnelProvider`, `NEPacketTunnelFlow`, `NETunnelProviderManager` | macOS 10.11 / iOS 9.0 | Does not force either selected floor. |
| `NWConnection`, `NWParameters`, `requiredInterface` | macOS 10.14 / iOS 12.0 | Does not force either selected floor. |
| `NWParameters` QUIC initializer | macOS 12.0 / iOS 15.0 | Below the selected floor; current QUIC policy does not require a newer API. |
| Xcode 26.5 deployment support for submitted apps | macOS 11–26.5 / iOS 15–26.5 | Both selected targets remain inside Apple's supported deployment range. |
| Xcode 26.5 SDK concurrency runtime markers | macOS 12.0 / iOS 15.0 | Async/await does not require raising macOS 15 or iOS 18. |

The policy forbids using iOS/macOS 26-only Network builder APIs without guarded
fallbacks. The current architecture's `NWConnection`, `NWParameters`, and
`requiredInterface` needs are available below the chosen targets.

### Dependency floors

| Dependency or choice | Current evidence | Effect on decision |
|---|---|---|
| SwiftNIO SSH 0.14.1 candidate | Tagged `Package.swift` declares macOS 10.15 and iOS 13; Swift tools 6.1. | Below selected targets. Production acceptance remains ADR-014, but this candidate does not raise the floor. |
| libssh2 1.11.1 candidate | Portable C library with no Apple product deployment minimum in its release contract. | No evidence requiring a target above 15/18; final packaging remains separately gated. |
| HEV/lwIP | Upstream explicitly builds an Apple XCFramework for iOS/macOS and documents iOS low-memory tuning. | No declared higher minimum; exact revision and package seam remain owned by the HEV pin/integration tasks. |
| Sparkle 2.9.4 | Runtime requirement macOS 10.13+; package declares macOS 10.13. | Below macOS 15. |
| Tuist 4.202.5 (generator host) | Tagged package uses Swift tools 6.1 and declares macOS 15. | Requires generation hosts/CI on macOS 15+, but does not itself set product deployment targets. |

Because ADR-014 is open, neither SSH candidate is treated as selected product
code here. Both known candidates fit within iOS 18/macOS 15. If the eventual
pin, HEV fork, relay binding, or another selected package declares a higher
minimum, generation must remain red until ADR-016 is reviewed and updated; the
manifest must not speculate around it with private API or compatibility shims.

### Device and CI evidence

Read-only `devicectl` and host inventory on 2026-07-20 found:

| Policy lane | Required baseline | Evidence and use |
|---|---|---|
| Current stable iOS physical | iPhone 11 (`iPhone12,1`), iOS 26.5 | Paired/available and on the current stable OS. Required for current-release provider lifecycle, path-change, and memory gates after Gate P0 signing/provisioning. |
| Minimum iOS physical | iPhone 15 (`iPhone15,4`), iOS 18.6.2 | Paired and on the selected minimum major. Required for minimum-OS signed smoke/lifecycle before a release claims iOS 18 support. Developer disk image mounting was unavailable during inventory, so P0 must repair and prove this lane; it is not counted as already passing. |
| Current macOS physical | MacBook Pro (`Mac15,9`), Apple M3 Max, macOS 26.5 | Required for current macOS provider lifecycle, routing/DNS, signing, and resource tests. No serial, UDID, or hardware UUID belongs in retained evidence. |
| Beta canary | iPhone Air (`iPhone18,4`), iOS 27.0 beta | Optional forward-compatibility signal only. A beta device cannot replace either stable required lane. |
| Minimum hosted CI | `macos-15` arm64, currently macOS 15.7.7; Xcode 16.4 (16F6); iOS 18.5/18.6 simulator runtimes | Runs macOS tests on the oldest supported major and iOS 18 simulator tests. Xcode 16.4 provides Swift 6.1, matching Tuist's manifest tools floor. |
| Current hosted CI | `macos-26` arm64; Xcode 26.5 (17F42); iOS/macOS 26.5 SDKs and iOS 26.5 simulator | Matches the local current toolchain and stable physical OS. Select Xcode 26.5 explicitly because the image default changes independently. |

Why not lower the new targets:

- iOS 15–17 have API/toolchain compatibility but no current maintained hosted
  simulator lane in the selected runner matrix and no verified available
  physical device that closes the required provider lifecycle/memory loop.
- macOS 14 remains a valid legacy product target, but its GitHub-hosted runner
  entered deprecation and is scheduled for removal. A new macOS 14 support claim
  would therefore require a named self-hosted/external runner and owner that do
  not exist in current project evidence.
- A lower number that only compiles is not supported. The minimum means the
  oldest major on which the required unit/integration suite runs continuously
  and the signed provider receives physical lifecycle coverage before release.

## Required build and test matrix

| Gate | Generator/toolchain | Required checks |
|---|---|---|
| Determinism/current | Tuist 4.202.5; macOS 26 runner; Xcode 26.5 | Double clean generation and graph/project diff; build every credential-free host/provider/core/harness scheme; current iOS 26.5 simulator tests; legacy `swift test`/build lane; record locks and versions. |
| Minimum iOS | Tuist 4.202.5; macOS 15 runner; Xcode 16.4; iOS 18.6 simulator | Generate from source, assert `IPHONEOS_DEPLOYMENT_TARGET=18.0` for host and provider, build both, run all simulator-capable tests, and reject any unguarded newer API. Signed iPhone 15/iOS 18.6.2 smoke is a release/P0 gate. |
| Minimum macOS | Tuist 4.202.5; macOS 15 runner; Xcode 16.4 | Assert `MACOSX_DEPLOYMENT_TARGET=15.0` for new host/provider/core/harness, build and run all credential-free macOS tests on macOS 15. The separate legacy lane asserts macOS 14.0 without requiring Tuist. |
| Current physical | Xcode 26.5 until upgraded by policy | iPhone 11/iOS 26.5 and M3 Max Mac/macOS 26.5 provider install, lifecycle, path, DNS/routing, memory, stop/restart, and cleanup gates after P0. |

Simulator success never substitutes for Network Extension entitlements,
installation, lifecycle, memory, or routing behavior on physical hardware.

## Upgrade policy and ownership

**Owner:** the Relux Works Apple Platform/CI maintainer. During foundation work,
the implementation owner of **TASK-260715-2btjwm — Create the reproducibly
generated workspace foundation** owns the initial pin. After bootstrap, owners
of `mise.toml`, Tuist manifests, and Apple CI workflows jointly own upgrades;
**TASK-260715-3mk4hs — Validate generated workspace determinism and the preserved
SwiftPM product** enforces the recurring gate.

- Review stable Tuist and Xcode patch releases monthly and security releases
  immediately. Automation may open a proposal but may not widen or rewrite the
  pin automatically.
- Upgrade Tuist in a dedicated PR by changing one exact version. Preserve the
  old pin as the control, regenerate with old/new versions under the same exact
  Xcode, compare graphs, schemes, build settings, entitlements, embed phases,
  package locks, and generated projects, then run the full minimum/current
  matrix.
- Upgrade Xcode separately. Record build number, Swift version, SDK versions,
  deployment range, runner-image availability, generator compatibility, and
  generated diff. Do not combine a Tuist and Xcode upgrade unless a documented
  incompatibility makes it unavoidable.
- Keep Xcode 26.5 explicit while testing 26.6 in a non-required compatibility
  lane. Promote 26.6 only after deterministic generation, all credential-free
  builds/tests, and required physical smoke pass. The same rule applies to
  future `macos-latest` migrations.
- Revisit iOS/macOS minimums at least annually and before dropping a CI image or
  physical device. Raising requires device/usage/support impact review; lowering
  requires a maintained runner, physical provider evidence, and all API and
  dependency floors. Neither direction is a drive-by manifest edit.

## Evidence gaps and explicit gates

No unsupported assumption is converted into configuration:

- Gate P0 still owns Apple organization enrollment, App IDs, Network Extension
  entitlements/profiles, and actual provider installation on the named devices.
  This research defines required lanes but does not claim P0 has passed.
- The iPhone 15/iOS 18.6.2 developer disk image did not mount during read-only
  inventory. Before iOS 18 physical support is claimed, P0 must restore the
  developer-service connection and retain signed install/lifecycle evidence.
- ADR-014 and the HEV pin task must supply exact selected revisions. If either
  chosen artifact declares a minimum above iOS 18/macOS 15, the dependent
  generated-project work is blocked pending an ADR-016 update; it must not add a
  shim or lie in build settings.
- GitHub's macOS 14 removal date is known, but no self-hosted macOS 14 owner or
  runner is evidenced. Therefore macOS 14 is preserved only for the existing
  SwiftPM product's build compatibility, not adopted for the new application.

These are downstream evidence gates, not reasons to leave ADR-016/ADR-017 open:
the generator and support policy can be selected without claiming signing or
physical-provider success.

## Fact-check commands

```sh
xcodebuild -version
swift --version
xcodebuild -showsdks
plutil -p "$(xcrun --sdk iphoneos --show-sdk-path)/SDKSettings.plist"
plutil -p "$(xcrun --sdk macosx --show-sdk-path)/SDKSettings.plist"
xcrun devicectl list devices
xcrun devicectl device info details --device DEVICE_IDENTIFIER
system_profiler SPHardwareDataType
tuist version
curl -fsSL 'https://api.github.com/repos/tuist/tuist/releases?per_page=100'
curl -fsSL 'https://api.github.com/repos/apple/swift-nio-ssh/releases?per_page=100'
curl -fsSL 'https://api.github.com/repos/sparkle-project/Sparkle/releases?per_page=100'
```

Device identifiers, serial numbers, ECIDs, UDIDs, host UUIDs, and personal
device names were inspected only to distinguish real hardware. They are
deliberately omitted from this artifact and must not enter CI logs.

## References

- [Tuist 4.202.5 release](https://github.com/tuist/tuist/releases/tag/4.202.5)
- [Tuist 4.202.5 package platform/tools declaration](https://github.com/tuist/tuist/blob/4.202.5/Package.swift#L1801-L1804)
- [Tuist 4.202.5 product types](https://github.com/tuist/tuist/blob/4.202.5/cli/Sources/ProjectDescription/Product.swift)
- [Tuist installation and project-local Mise pinning](https://tuist.dev/en/docs/guides/install-tuist)
- [Tuist dependency graph and package integration](https://tuist.dev/en/docs/guides/features/projects/dependencies)
- [Tuist deterministic-hash debugging guidance](https://tuist.dev/en/docs/guides/features/projects/hashing)
- [Tuist signing settings API](https://docs.tuist.dev/en/references/project-description/extensions/settingsdictionary)
- [XcodeGen 2.46.0 release](https://github.com/yonaskolb/XcodeGen/releases/tag/2.46.0)
- [XcodeGen project specification overview](https://github.com/yonaskolb/XcodeGen)
- [Apple Xcode support matrix](https://developer.apple.com/support/xcode/)
- [GitHub-hosted runner image/support policy](https://github.com/actions/runner-images)
- [GitHub macOS 15 arm64 image inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md)
- [GitHub macOS 26 arm64 image inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)
- [SwiftNIO SSH 0.14.1 package platforms](https://github.com/apple/swift-nio-ssh/blob/0.14.1/Package.swift)
- [HEV/lwIP Apple build and platform support](https://github.com/heiher/hev-socks5-tunnel)
- [Sparkle runtime/build requirements](https://github.com/sparkle-project/Sparkle)
- [Legacy inventory](./260720_legacy-inventory.md)
- [Existing platform upstream verification](./260715_platform-upstream-verification.md)

