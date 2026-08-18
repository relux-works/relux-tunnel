# TASK-260715-32umrc — Generated-project target and dependency architecture

- Status: Accepted for implementation review
- Date: 2026-08-19
- Decision owner: solution architecture
- Scope: macOS-only P0 workspace foundation; iOS extension points are defined
  but deferred under ADR-024/ADR-027
- Diagram: `diagrams/TASK-260715-32umrc_target-dependency-plan.dot`

## 1. Decision and constraints

Generate `ReluxTunnel.xcworkspace` from source-controlled Tuist manifests with
Tuist 4.202.5 pinned exactly by repository-local Mise. New Apple targets use
macOS 15.0 and iOS 18.0. The existing SwiftPM `ReluxProxy` product remains a
separate macOS 14.0 compatibility lane until a later, explicit migration and
retirement decision authorizes a change.

The macOS P0 path contains `ReluxProxyMac` and its embedded
`ReluxProxyMacTunnel` system extension. It consumes the existing local
`ReluxTunnel` Swift package and the relay build products; it does not absorb
their sources into an application target. Gate P0 is PASS for the approved
macOS development shape. That result is not App Review, notarization, release,
packet-forwarding, or iOS evidence. Gate A0 is deferred and is not an input.

The iOS host and provider keep fixed identifiers, target definitions, package
seams, and scheme names, but are not generated, built, provisioned, or scheduled
on the macOS-only path. Resuming iOS requires the owner input recorded by
ADR-024/ADR-027; no Mac result is reused as iPhone evidence.

## 2. Dependency rule and focused graph

Every arrow means **the source consumes or contains the destination**. The
graph is a DAG. Embedding is packaging ownership, not a reverse source-code
dependency.

```text
ReluxProxyMac --embeds/manages--> ReluxProxyMacTunnel
ReluxProxyMac ------------------> ReluxTunnelCore       (configuration models only)
ReluxProxyMacTunnel ------------> ReluxTunnelMacOSAdapter
ReluxTunnelMacOSAdapter --------> ReluxTunnelLibSSH2Adapter
ReluxTunnelMacOSAdapter --------> ReluxTunnelNativeAdapter
ReluxTunnel{MacOS,Native,LibSSH2}Adapter --> ReluxTunnelCore
ReluxTunnelHarness --> ReluxTunnelHarnessSupport --> adapter layer --> ReluxTunnelCore

relux-relay and relux-relay-protocol-test are Go build products. A verified,
versioned relay artifact is a provider resource input; it is not linked code.

[deferred] ReluxProxyIOS --embeds/manages--> ReluxProxyIOSTunnel
[deferred] ReluxProxyIOSTunnel --> ReluxTunnelIOSAdapter -->
           ReluxTunnelNativeAdapter --> ReluxTunnelCore
```

The checked-in DOT file is the focused authoritative view. The following rules
are binding and make the direction acyclic:

1. Containing apps own profile editing, persistence, VPN configuration,
   installation/activation requests, and user-visible status projection. They
   never own the live packet, SSH, relay, reconnect, memory, or route state.
2. Providers own the complete live tunnel state. They adapt
   `NEPacketTunnelProvider`, `NEPacketTunnelFlow`, and provider messaging to
   shared contracts and have no dependency on host UI or host implementation.
3. `ReluxTunnelCore` contains platform-neutral contracts and state machines. It
   imports neither SwiftUI/AppKit/UIKit nor NetworkExtension, application
   targets, generated project state, native C modules, or the relay executable.
4. Platform adapters are thin composition boundaries. Only the named iOS/macOS
   adapters import NetworkExtension. Native and SSH engines live behind named
   adapter modules that depend inward on Core; Core never depends outward on
   them.
5. The harness composes the same Core and adapter products without a Network
   Extension lifecycle. No harness-only behavior may become a provider
   prerequisite.
6. The relay is selected by manifest, hash-verified, bundled as a resource, and
   later uploaded over an authenticated exec/stdin channel. It is never a Swift
   or dynamic-library dependency.
7. The legacy `ReluxProxy` lane has no dependency edge to the generated app. It
   coexists beside it until an approved migration decision; coexistence does not
   imply shared defaults, bundle identity, source, or release artifacts.

## 3. Products, targets, packages, and ownership

### 3.1 macOS-only P0 generated products

| Product / target | Kind and owner | Allowed direct dependencies | Packaging |
| --- | --- | --- | --- |
| `ReluxProxyMac` | macOS 15 containing app; host owns configuration and activation | `ReluxTunnelCore`; host-only dependencies such as pinned Sparkle are isolated here | `.app`; embeds exactly one `ReluxProxyMacTunnel` |
| `ReluxProxyMacTunnel` | macOS 15 packet-tunnel system extension; provider owns live state | `ReluxTunnelMacOSAdapter` and verified relay resources | `Contents/Library/SystemExtensions/works.relux.tunnel.mac.tunnel.systemextension` |
| `ReluxProxyMacTests` | host target tests | host configuration/presentation seams and Core test support | test bundle; never embedded |
| `ReluxProxyMacTunnelTests` | provider composition and bundle-contract tests | provider composition root and adapter test doubles | test bundle; never embedded |

The production identifiers are injected from the approved r12 matrix:
`works.relux.tunnel.mac` and `works.relux.tunnel.mac.tunnel`. Team
`262RZ595FP` is non-secret metadata. The generated project must not contain the
disposable `ReluxTunnelProbeMac*` targets; those remain separate Gate P0
evidence fixtures and must not become production dependencies.

### 3.2 shared Swift package

The root `Package.swift` remains source controlled and is referenced as one
local package named `ReluxTunnel`. Its product/target boundary is authoritative:

| Package product or internal target | Ownership |
| --- | --- |
| `ReluxTunnelCore` | platform-neutral contracts, packet/SSH/relay/lifecycle/memory state and protocol models |
| `ReluxTunnelNativeAdapter` | HEV and other static native packages behind Core contracts |
| `ReluxTunnelLibSSH2Adapter` | selected macOS libssh2 transport behind Core SSH contracts |
| `ReluxTunnelMacOSAdapter` | thin NetworkExtension and macOS system-keychain/provider composition |
| `ReluxTunnelIOSAdapter` | deferred thin NetworkExtension/iOS composition seam; no libssh2 dependency is authorized by this ADR |
| `ReluxTunnelHarnessSupport` | CLI composition, injected resources, cancellation, and deterministic reports |
| `ReluxTunnelHarness` | macOS command-line executable |
| `ReluxTunnelCoreTests`, `ReluxTunnelNativeAdapterTests`, `ReluxTunnelLibSSH2AdapterTests`, `ReluxLibSSH2PackagingTests`, `ReluxTunnelHarnessTests` | package-owned unit, contract, integration, packaging, and harness tests |

Static binary targets `CReluxNativeFixture`, `HevSocks5Tunnel`, and
`ReluxLibSSH2` remain package implementation details. They may be consumed only
through their named adapters. `APPLICATION_EXTENSION_API_ONLY=YES` is required
for provider graphs and their package dependencies.

### 3.3 relay package and build targets

`relay/` remains a separate standard-library-only Go module
`github.com/relux-works/relux-tunnel/relay`, pinned to Go 1.26.5 with
`CGO_ENABLED=0`. Its build targets are `relux-relay` and
`relux-relay-protocol-test` for Darwin/Linux on amd64/arm64. The canonical
Apple bundle input and manifest are produced by the existing Make/script
interface. Tuist references the verified output directory as a resource input;
it does not rebuild Go implicitly during an ordinary Xcode compile.

### 3.4 deferred iOS extension points

The dormant target definitions are `ReluxProxyIOS`, `ReluxProxyIOSTunnel`,
`ReluxProxyIOSTests`, and `ReluxProxyIOSTunnelTests`. Their fixed bundle IDs are
`works.relux.tunnel.ios` and `works.relux.tunnel.ios.tunnel`; the host embeds the
provider at `PlugIns/works.relux.tunnel.ios.tunnel.appex`. When ADR-024 is
explicitly resumed, the pair consumes `ReluxTunnelIOSAdapter`, Core, and the
same verified relay-resource contract. It does not consume legacy macOS
sources or `ReluxTunnelLibSSH2Adapter` without a separate accepted decision.

The approved matrix defines iOS App Group
`group.works.relux.tunnel` and Keychain group
`$(AppIdentifierPrefix)works.relux.tunnel.shared`; these are defined but not
provisioned on this path. They must not leak into the macOS targets, whose r12
matrix explicitly prohibits App Groups and Keychain Sharing.

## 4. Workspace, schemes, and configuration matrix

The source-controlled Tuist model produces one `ReluxTunnel.xcworkspace` and a
generated application project that references the local Swift package. Stable
shared schemes are:

| Scheme | Build/test responsibility | macOS-only path |
| --- | --- | --- |
| `ReluxProxyMac` | host, embedded system extension, host/provider target tests | required |
| `ReluxProxyMacTunnel` | direct provider compile and provider contract tests | required |
| `ReluxTunnelCore` | all shared Core/adapter/package tests | required |
| `ReluxTunnelHarness` | harness build, unit tests, and no-op smoke | required |
| `relux-relay` | explicit external Make build/smoke wrapper; never an implicit host build phase | required for relay validation/bundle staging |
| `relux-relay-protocol-test` | explicit protocol-test wrapper | required |
| `ReluxProxyIOS` | deferred host + embedded provider + target tests | defined, disabled/not generated in macOS-only mode |
| `ReluxProxyIOSTunnel` | deferred direct provider compile/contracts | defined, disabled/not generated in macOS-only mode |

Only `Debug` and `Release` Xcode configurations exist. Signing lanes are inputs,
not extra configurations, so settings cannot drift between artificial
`Unsigned`, `Development`, and `Distribution` configurations.

| Variant | Configuration | Destinations | Signing behavior | Required result |
| --- | --- | --- | --- | --- |
| credential-free | Debug and Release | macOS; deferred iOS simulator only after resume | `CODE_SIGNING_ALLOWED=NO`; no identity/profile lookup | compile, tests, graph/embed/plist/entitlement static checks; never reported as signed |
| P0 development | Debug | named physical Apple-silicon Mac | injected Apple Development team/profile inputs and development entitlement file | host/provider build, inside-out sign, install, launch, v1 message, stop |
| Developer ID candidate | Release archive | macOS | injected Developer ID Application identities/profiles; hardened runtime; developer-id entitlement file | archive and nested-sign inspection; notarization/release remain downstream |
| deferred iOS development | Debug | iOS simulator unsigned; physical device only after resume | injected Apple Development inputs and iOS entitlement file | not built on this path |
| deferred iOS App Store | Release archive | iOS device | injected Apple Distribution profiles/export settings | not built on this path; Gate A0/P0 and iOS delivery contract remain required |

The macOS development entitlement value is the unsuffixed
`packet-tunnel-provider`; Developer ID uses
`packet-tunnel-provider-systemextension`. Both host and provider carry the
channel-matched Network Extension value. Only the host carries
`com.apple.developer.system-extension.install`. The r12 matrix is authoritative
for all other entitlements and must be consumed, not retyped or broadened.

## 5. Source-control and generation policy

Checked in and reviewed:

- `mise.toml` (or the repository-standard Mise file) with exact Tuist 4.202.5,
  Tuist manifests/helpers, workspace-mode input, shared settings, schemes, and
  dependency declarations;
- `Package.swift`, resolved dependency locks, Go module/toolchain manifests,
  native source/revision/hash/flag/license manifests, and deterministic rebuild
  tools;
- all app/provider/package/relay sources, tests, plist templates, entitlement
  files, resources, privacy/license notices, and non-secret identifier/version
  inputs;
- static XCFrameworks only where ADR-019 requires the source-rebuilt,
  hash-locked exception; source, rebuild recipe, notices, and manifest remain
  the review authority;
- protocol schemas/vectors and their generated Swift/Go bindings when their
  existing drift checks prove deterministic regeneration.

Generated and ignored:

- `.xcodeproj`, `.xcworkspace`, derived schemes, `DerivedData`, `.build`, Tuist
  caches, local tool downloads, relay staging outputs, archives, result bundles,
  logs, and temporary generated sources;
- `Configuration/Signing.local.xcconfig` (or an equivalent generated local
  overlay) and every credential-bearing/export artifact.

The repository contains a non-secret signing example/schema, never a working
credential. A clean generation followed by a second clean generation must
produce the same normalized graph/settings/schemes and no unexplained tracked
diff. Developers edit manifests and source inputs, never generated Xcode state.

## 6. Identifier, signing, dependency, and version inputs

### 6.1 Identifiers and signing

The accepted `2026-07-28.r12` identifier/entitlement matrix is the single
non-secret identity authority. Tuist consumes a checked-in projection of that
matrix; target code does not contain identifier literals. Build settings expand
bundle IDs into plist, entitlement, embedding, and designated-requirement
checks. A validator fails on a target/matrix mismatch or an undeclared
entitlement.

Credential-free builds perform no automatic-signing repair and do not fall back
from a requested identity to ad hoc signing. Credentialed development and
Developer ID lanes obtain the team, identity selector, and profile specifiers
from environment/Keychain-backed CI inputs rendered into the ignored local
overlay. Missing or mismatched requested inputs fail before build/signing.
Secrets, profile contents, private keys, and notarization credentials never
enter Tuist manifests, source control, board resources, logs,
`providerConfiguration`, or generated project files.

The host signs after all inner code is final: static inputs are linked first,
then the relay resource is hash-verified, the system extension is signed, and
the containing app is signed last. Release notarization, DMG publication, and
Sparkle signing are downstream release-pipeline concerns and are not declared
complete here.

### 6.2 Dependency pins

Every dependency is exact and reviewable. Tuist is 4.202.5 through Mise; Go is
1.26.5 and Syft is 1.48.0 through the relay toolchain manifest; Sparkle is
2.9.4 at the accepted commit/checksum and host-only; native inputs use the
ADR-019 revision/hash/flag/license manifests; `ReluxLibSSH2` uses the recorded
libssh2/OpenSSL pins and source-rebuild path. Ranges, branches, implicit
upgrades, runtime downloads, local `replace`, opaque binary replacement, and
unreviewed dynamic libraries are prohibited. A dependency whose floor exceeds
macOS 15/iOS 18 stops generation pending ADR-016 review.

### 6.3 Version propagation

One checked-in, machine-readable version input owns
`MARKETING_VERSION`, integer `CURRENT_PROJECT_VERSION`, and relay/protocol
compatibility references. Tuist maps the first two to both host and provider
plists; a generated build-identity source exposes the same values plus source
commit to app-message diagnostics. The provider and host must report an exact
compatible schema/version tuple before the host presents the provider as live.

Relay build scripts receive the same marketing version and exact source commit
explicitly and record them in identity output and manifest; protocol version
continues to come from the checked-in protocol schema/generated constants.
Release mode rejects missing, dirty, malformed, non-monotonic, or inconsistent
inputs. Signed outputs need not be byte-reproducible, but their source,
dependency locks, unsigned inputs, resource hashes, and version mapping must be
traceable. The legacy `ReluxProxy` version/build mapping remains independent
until the later migration contract deliberately joins or retires it.

## 7. Test ownership and acceptance gates

| Test surface | Owner and placement |
| --- | --- |
| Core state/protocol/diagnostic contracts | Swift Testing in `ReluxTunnelCoreTests` |
| thin platform adapters and shared lifecycle/version behavior | package adapter tests using injected provider/packet-flow seams; direct provider target tests only for composition/bundle glue |
| native/static linkage and extension safety | native adapter/packaging tests plus archive scripts; inspect architectures, load commands, paths, symbols, notices, and hashes |
| macOS host/provider ownership | generated target tests for bundle IDs, embedding, plist, entitlements, version compatibility, configuration ownership, and absence of live state in the host |
| harness | `ReluxTunnelHarnessTests` plus deterministic no-op/cancellation/cleanup smoke |
| relay | Go unit/race/vet/protocol tests and both explicit relay schemes/Make gates; four-target manifest/SBOM/checksum validation |
| generated workspace | clean double-generation, normalized graph/settings/scheme diff, Debug/Release credential-free builds, and forbidden-edge/import checks |
| signing | static unsigned checks in PR; development/Developer ID archive inspection only in credentialed lanes and never reported as passed when skipped |
| legacy | existing SwiftPM build/tests, Make/app/DMG guards, defaults/SSH/bundle/artifact regression checks remain in the legacy lane |
| deferred iOS | simulator and target-contract tests are defined but disabled with the targets; physical lifecycle/signing tests re-arm only when iOS resumes |

An app build is not a substitute for a direct package test, and a simulator or
unsigned build is not signing/lifecycle evidence. `TASK-260715-nphtib` accepts
the architecture only after the enumerated target graph exactly matches this
ADR and all applicable credential-free rows pass from a clean checkout.

## 8. Legacy coexistence and migration sequence

M0 is coexistence, not migration:

1. Preserve the current `ReluxProxy` SwiftPM executable, `ReluxProxyTests`,
   macOS 14 floor, `works.relux.proxy` bundle/defaults domain, system-SSH
   behavior, scripts, artifact names, and release path exactly as recorded by
   `TASK-260715-1fv4z1` and enforced by `TASK-260715-14lk3y`.
2. Add the generated workspace beside that lane. Generated products use their
   own identifiers, plist/entitlement files, state stores, artifacts, and docs;
   they neither read nor delete legacy defaults and do not overwrite legacy
   outputs.
3. Validate both lanes together. Generated-workspace success cannot hide a
   legacy regression, and legacy success is not evidence for the provider.
4. A later approved migration decision must define coexistence namespace,
   migration version, data/default conversion, release-channel and stable-name
   takeover, rollback, uninstall, user communication, and support/EOL dates.
5. Only implementation and verification tasks downstream of that decision may
   retire legacy code, tests, scripts, assets, history, or release jobs.

No generated-project task is authorized to reuse the unsandboxed legacy
`/usr/bin/ssh` child process inside a provider or to silently reinterpret its
defaults as VPN configuration.

## 9. Downstream traceability and dependency order

No new Story, Task, Bug, research task, or planning artifact is needed. The
existing board is the smallest decomposition that covers the supplied spec;
all elements below are literal consumers of requirements already present in
the task/story/specs. Therefore no justified-gap record is applicable and no
research question remains open.

| Downstream owner | ADR sections consumed |
| --- | --- |
| `TASK-260715-2btjwm` generated workspace foundation | §§1, 4–6, 8 |
| `TASK-260715-uyju7n` macOS host/provider targets | §§2–4, 6–7 |
| `TASK-260715-33oofa` deferred iOS host/provider targets | §§1–4, 6–7; remains blocked under ADR-027 |
| `TASK-260715-2nfz7w` Core/adapters | §§2–3, 7 (already accepted implementation evidence) |
| `TASK-260715-pmww4f` harness | §§2–4, 7 (already accepted implementation evidence) |
| `TASK-260715-1g9cyt` native packaging | §§2–3, 5–7 (already accepted implementation evidence) |
| `TASK-260715-1ccx3l` relay shells | §§2–7 (already accepted implementation evidence) |
| `TASK-260715-14lk3y` legacy preservation | §§1, 5, 7–8 (already accepted implementation evidence) |
| `TASK-260715-sbrrp7` credential-free validation | §§4–7 and both-lane rule in §8 |
| `TASK-260715-nphtib` independent architecture verification | entire ADR, especially §§2, 4–8 |
| `TASK-260715-d6x51z` developer workflow docs | §§3–8 |
| `TASK-260715-2hhh7x` profile/key ownership contract | §§1–3, 6.1, 8 |
| `TASK-260715-whtdsf` CI trust/quality contract | §§4–7; macOS-only scope in §1 |
| `TASK-260715-2759wy` semantic version gate | §6.3 and legacy boundary §8 |
| `TASK-260715-1tzaed` macOS release identity/migration contract | §§1–6 and §8; release details remain downstream |
| `TASK-260715-3661ps` deferred iOS delivery contract | §§1, 3.4, 4, 6–7; Gate A0/P0 remain required after resume |

The implementation order remains acyclic:

```text
this ADR -> workspace foundation -> macOS targets -> credential-free validation
         -> independent architecture verification -> developer documentation
```

Core/adapters, native packaging, harness, relay shells, and legacy preservation
are already accepted prerequisites/parallel inputs. iOS and its delivery branch
remain explicitly blocked, not silently schedulable.

## 10. Consequences and verification

This decision creates a reproducible manifest-owned workspace while keeping
runtime ownership unambiguous and the shared core reusable. It costs explicit
scheme/configuration plumbing, two signing entitlement variants on macOS, and a
separate relay staging step. Those costs are preferred to generated-state
edits, dependency cycles, accidental credential use, or conflating the legacy
and provider products.

Review must reject any implementation that introduces a reverse dependency,
adds a macOS App Group/Keychain Sharing entitlement contrary to r12, generates
or builds the deferred iOS branch on the macOS-only path, treats unsigned work
as signing evidence, changes a pin without its owner policy, or retires legacy
behavior without the later migration decision.

Primary evidence: `.spec/architecture.md`, `.spec/platform-distribution.md`,
`.spec/decisions.md` ADR-016/017/019/024/027, the accepted r12 Apple matrix,
`TASK-260715-1fv4z1`, `TASK-260715-3r0993`, `TASK-260715-3bdplx`, and the
2026-08-19 accepted macOS Gate P0 disposition `TASK-260715-2ayxqn`.
