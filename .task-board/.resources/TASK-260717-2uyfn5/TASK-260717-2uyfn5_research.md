# macOS self-update mechanism decision

Date: 2026-07-21
Task: `TASK-260717-2uyfn5` — Select and record the macOS self-update mechanism
Status: binding decision proposed for independent review
Evidence access date: 2026-07-21

## Context

ADR-018 selected Sparkle 2 in principle but did not pin a release or define the
feed, signature, helper, sandbox, Network Extension, rollback, key, privacy, or
release contracts needed by implementation. This report verifies the volatile
facts against official Sparkle and Apple sources and records the exact decision.
It does not generate a key, integrate Sparkle, sign or notarize a build, publish
a feed, or claim that an update has been installed successfully.

## Highlights / key takeaways

- Pin Sparkle **2.9.4 exactly**, tag commit
  `b6496a74a087257ef5e6da1c5b29a447a60f5bd7`, through Swift Package
  Manager. The official SPM binary checksum is
  `cb6fdbdc8884f15d62a616e79face92b08322410fd2d425edc6596ccbf4ba3b0`.
- Enable both payload verification and signed-feed verification:
  `SUVerifyUpdateBeforeExtraction=YES`, `SURequireSignedFeed=YES`, and
  `SUSignedFeedFailureExpirationInterval=0`. A missing, stale, malformed, or
  invalidly signed feed or payload has no fallback path.
- Publish only a final Developer ID-signed, hardened-runtime, notarized and
  stapled DMG. Sparkle signs the final DMG bytes only after all Apple signing,
  notarization, and stapling steps are over; the appcast is published last.
- Use one public, read-only HTTPS appcast at
  `https://updates.relux.works/macos/appcast.xml`. Stable items use Sparkle's
  default channel; opt-in prereleases use `sparkle:channel` value
  `prerelease`. Private GitHub releases remain the authenticated manual-download
  channel and are not used as an authenticated in-app feed.
- Sparkle 2 removed downgrade support. Emergency rollback is a **forward
  rollback**: rebuild last-known-good source with a new, higher
  `CFBundleVersion`, then sign, notarize, staple, EdDSA-sign, and publish it.
  There is no rollback/downgrade channel.
- Direct Developer ID distribution of a macOS packet-tunnel provider requires a
  **system extension**, not a packet-tunnel app extension. Sparkle replaces and
  relaunches the containing app; the relaunched app must separately request
  activation/replacement of the embedded system extension. Approval and restart
  behavior remain OS-controlled and require physical validation.
- The host app is sandboxed and uses Sparkle's Installer XPC service. Sparkle is
  linked only into `ReluxProxyMac`, never into the packet-tunnel system
  extension, shared core, or iOS targets.
- Update checking uses Sparkle's second-launch consent prompt and 24-hour
  schedule. Automatic download/install and system profiling are disabled.

## Primary-source fact check

| Claim | Verified evidence | Result |
| --- | --- | --- |
| Current production release | Official release list and release API identify 2.9.4 as latest, non-draft, non-prerelease, published 2026-07-03 | Confirmed |
| Exact tag | Official Git ref resolves `2.9.4` to commit `b6496a74a087257ef5e6da1c5b29a447a60f5bd7` | Confirmed |
| SPM asset and floor | Tagged `Package.swift` declares macOS 10.13, tag 2.9.4, the official binary URL, and checksum `cb6f...3b0` | Confirmed; project macOS 15 floor is higher |
| Downloaded asset integrity | `shasum -a 256` and `swift package compute-checksum` over the official 2.9.4 SPM asset both returned `cb6f...3b0` | Confirmed locally without credentials |
| License | Tagged `LICENSE` contains the MIT-style top-level grant plus separate bundled third-party license terms | Confirmed; ship the complete file, not only an “MIT” label |
| Signed-feed availability | Sparkle documents `SURequireSignedFeed` as available from 2.9 and requiring `SUVerifyUpdateBeforeExtraction` | Confirmed |
| Fail-closed expiry | Sparkle documents `SUSignedFeedFailureExpirationInterval=0` as disabling signed-feed failure expiration | Confirmed |
| Channels | Sparkle documents default-channel inclusion, `sparkle:channel`, delegate-allowed channels, and that the default channel cannot be excluded | Confirmed |
| Downgrades | Sparkle's official upgrade guide says downgrade support was removed in Sparkle 2 | Confirmed |
| Sandboxed helpers | Sparkle documents required `Installer.xpc`, optional `Downloader.xpc`, the installer enable key, Mach lookup exceptions, archive/export re-signing, and hardened-runtime behavior | Confirmed |
| Notarization order | Apple requires Developer ID signing, hardened runtime, valid nested code signatures, and notarization; modifying signed code invalidates its signature | Confirmed |
| Direct packet-tunnel packaging | Apple TN3134 says macOS packet-tunnel app extensions are App Store only and direct distribution uses a system extension | Confirmed |
| System-extension update | Apple says activation of a new version is a separate replacement request, may need user approval, and may report that restart is required | Confirmed; exact UI and transition timing are not guaranteed |

## Binding decision

### 1. Dependency and license contract

1. The generated Xcode workspace declares the official package URL
   `https://github.com/sparkle-project/Sparkle` with an **exact** requirement of
   `2.9.4`; version ranges, branches, moving tags, and prerelease/nightly builds
   are prohibited.
2. `Package.resolved` must resolve tag `2.9.4` at commit
   `b6496a74a087257ef5e6da1c5b29a447a60f5bd7`. The tagged binary-target
   manifest checksum is
   `cb6fdbdc8884f15d62a616e79face92b08322410fd2d425edc6596ccbf4ba3b0`.
3. Link product `Sparkle` only to `ReluxProxyMac` and embed/sign the framework.
   Do not link it into the packet-tunnel system extension,
   `ReluxTunnelCore`, the harness, or either iOS target. Release tools
   `generate_appcast` and `sign_update` are build/release tools, not application
   runtime dependencies.
4. The Sparkle package floor is macOS 10.13; Relux's accepted macOS 15.0 floor
   remains unchanged.
5. Bundle the complete tagged Sparkle `LICENSE` in third-party notices. Sparkle's
   main grant is MIT-style, while bundled bsdiff, sais-lite, Ed25519, and other
   files carry their own terms in the same license file.
6. Upgrade policy: remain on 2.9.4 until a dedicated dependency-upgrade change
   verifies the new production tag, commit, release/security notes, SPM
   checksum, license delta, deployment floor, helper layout, archive/export
   signing, and the physical old-to-new update matrix. Upgrades never happen
   automatically through a semver range.

### 2. Host, sandbox, helper, and hardened-runtime boundary

`ReluxProxyMac` uses `SPUStandardUpdaterController` with Sparkle's standard UI.
The host owns the updater for its lifetime. Initial settings live in
`Info.plist`; runtime changes are only user-driven.

The host app uses App Sandbox and Hardened Runtime. It has
`com.apple.security.network.client` for its own HTTPS feed access, so
`Downloader.xpc` is not enabled. Sandboxed installation uses the bundled
`Installer.xpc`:

- `SUEnableInstallerLauncherService=YES`;
- `SUEnableDownloaderService=NO`;
- `SUEnableInstallerConnectionService=NO`;
- `SUEnableInstallerStatusService=NO`;
- the host entitlements include only the Sparkle-documented global Mach lookup
  exceptions `<host-bundle-id>-spks` and `<host-bundle-id>-spki` in addition to
  independently approved product entitlements.

The official binary may retain its disabled Downloader XPC service; disabled
presence is not authority to launch it. Xcode Archive + Developer ID Export is
the required distribution path because Sparkle documents that ordinary “Code
Sign on Copy” does not re-sign all nested XPC services and helpers. Distribution
verification inspects `Sparkle.framework`, `Installer.xpc`, `Downloader.xpc`,
`Autoupdate`, and `Updater.app` as nested code.

Hardened Runtime remains enabled on the containing app, system extension, and
all nested executable code. Release signatures must not contain
`com.apple.security.get-task-allow`, disable library validation, unsigned
executable memory, or other hardened-runtime exceptions unless a separately
reviewed product requirement proves one. Sparkle's entitlements never propagate
to the packet-tunnel system extension, and system-extension entitlements never
propagate to Sparkle helpers.

### 3. Exact updater settings

| Setting | Binding value / behavior |
| --- | --- |
| `SUFeedURL` | `https://updates.relux.works/macos/appcast.xml` |
| `SUPublicEDKey` | Public key produced later by manual task `TASK-260717-ziprhs`; no value is generated here |
| `SUVerifyUpdateBeforeExtraction` | `YES` |
| `SURequireSignedFeed` | `YES` |
| `SUSignedFeedFailureExpirationInterval` | `0` (never expire a signed-feed validation failure) |
| `SUEnableAutomaticChecks` | Intentionally absent, preserving Sparkle's second-launch consent prompt |
| `SUScheduledCheckInterval` | `86400` seconds |
| `SUAutomaticallyUpdate` | `NO` |
| `SUAllowsAutomaticUpdates` | `NO`; every installation is user-confirmed |
| `SUEnableSystemProfiling` | `NO` |
| `SUEnableJavaScript` | `NO` |
| `SUShowReleaseNotes` | `YES`; notes are embedded in or signed with the signed feed |

A user can always invoke “Check for Updates…”. If the user declines automatic
checks, the application does not work around that choice. Feed, TLS, parsing,
signature, version, or download failures surface as an unavailable/failed update
and leave the installed application untouched; there is no unsigned, HTTP,
alternate-feed, website-download, or expiration fallback in the updater.

### 4. Feed, channels, versions, and cache contract

- The updater origin is public read-only HTTPS with valid ATS-compatible TLS.
  No repository token, cookie, client secret, signed query string, or user
  credential is embedded in the app. DNS/TLS provisioning is a release gate.
- Canonical feed: `https://updates.relux.works/macos/appcast.xml`.
- Canonical immutable payload shape:
  `https://updates.relux.works/macos/assets/<CFBundleVersion>/ReluxProxy-<CFBundleShortVersionString>-<CFBundleVersion>.dmg`.
- Stable items omit `sparkle:channel` and therefore use Sparkle's default
  channel. Prerelease items use exactly
  `<sparkle:channel>prerelease</sparkle:channel>`. Opt-in clients return
  `{"prerelease"}` from `allowedChannels(for:)`; they also continue to see the
  unexcludable default channel.
- A single globally monotonic integer `CFBundleVersion` sequence spans stable
  and prerelease builds. A later stable build must have a higher build number
  than every prerelease it supersedes. Appcast `sparkle:version` exactly matches
  `CFBundleVersion`; `sparkle:shortVersionString` exactly matches
  `CFBundleShortVersionString`; `sparkle:minimumSystemVersion` is `15.0.0` unless
  a reviewed release raises the accepted floor.
- Appcast and detached release-note responses use
  `Cache-Control: no-store`; immutable payloads use
  `Cache-Control: public, max-age=31536000, immutable`. Redirects and mutable
  “latest” payload URLs are prohibited. The signed appcast is replaced
  atomically only after every referenced asset is available.
- The authenticated private GitHub release may carry the same DMG for manual
  distribution. Its SHA-256 must match the public updater asset exactly. The
  private GitHub URL is not an enclosure URL.

Sparkle's EdDSA signature, not the SHA-256 published for operator convenience,
is the updater's payload trust check. The signed feed authenticates update
metadata and release notes; HTTPS supplies transport confidentiality and an
additional server-authentication layer.

### 5. Payload and publication ordering

The only baseline Sparkle payload is a DMG containing the regular app bundle.
Package installers and delta updates are not part of the first release. DMG is
also required for Sparkle's documented Developer ID fallback when rotating an
EdDSA key with pre-extraction verification enabled.

Release order is strict:

1. Build the exact tagged source with locked dependencies and produce provenance,
   SBOM, notices, versions, and entitlement manifests.
2. Sign nested code inside-out with Developer ID: packet-tunnel system extension,
   Sparkle XPC services/helpers/framework, containing app, then the distribution
   container as applicable. Host and system extension keep their approved bundle
   identifiers and same Team ID.
3. Verify all signatures and entitlements, Hardened Runtime, absence of debug or
   unapproved exception entitlements, embedded extension identity, and exact
   dependency resolution.
4. Notarize and staple the app; assemble/sign the DMG; notarize and staple the
   final DMG. Validate stapling and Gatekeeper behavior. No file inside the app or
   DMG changes afterward.
5. Hash the final DMG, then run Sparkle 2.9.4 `generate_appcast`/`sign_update` over
   those final bytes. Generate the signed appcast and signed or embedded release
   notes. Any mutation requires regeneration and re-signing.
6. Validate the appcast offline: XML, feed signature, release-note signature,
   enclosure EdDSA signature, length, version fields, channel, minimum system
   version, immutable URL, and exact final-DMG digest.
7. Upload the immutable DMG and release notes; verify remote bytes and headers;
   publish the appcast last by atomic replacement.
8. Perform a public-origin smoke check without release credentials. Promotion
   remains pending until human and physical gates below pass.

CI fails closed on a missing signing input, inaccessible key, checksum mismatch,
notarization/stapling failure, unexpected identity/entitlement, appcast signature
failure, mutable/cross-origin enclosure, wrong cache header, nonmonotonic version,
or any attempt to publish the appcast before the asset-verification gate.

### 6. Packet-tunnel system-extension and relaunch lifecycle

Apple TN3134 is binding for this direct Developer ID product: the macOS packet
tunnel is packaged as a Network Extension **system extension**. The system
extension is embedded under the containing app and signed with the same Team ID;
Sparkle does not load into or update the provider process directly.

Installation lifecycle:

1. Before accepting app termination for an update, the host requests an orderly
   VPN stop and waits for the system-authoritative inactive state. If it cannot
   confirm stop, it does not allow update installation and keeps the current app.
2. Sparkle replaces the containing app bundle and relaunches the host. That
   proves only host replacement, not provider replacement.
3. On relaunch, the host submits an `OSSystemExtensionRequest` activation for the
   embedded provider. For the same team and bundle identifiers with changed
   version identifiers, the delegate compares the installed and embedded
   `CFBundleVersion` values and returns `.replace` only for the reviewed newer
   candidate.
4. The host reports pending approval, failure, or restart-required results
   accurately. It does not claim the new provider active until the system reports
   activation success and a subsequent tunnel smoke uses that version.
5. Baseline behavior does not automatically reconnect the VPN after an app
   update. The user reconnects after activation/readiness is clear.

Apple documents that a new version activation may ask the user to resolve the
replacement and may require a restart. It does not provide a universal promise
about exact UI, timing, whether prior approval is reused, active-tunnel behavior,
or behavior across every supported macOS patch and management state. Those facts
remain unknown until physical evidence exists. `TASK-260715-1r48pc` must cover
clean install, old-to-new Sparkle update, active-tunnel deferral, denied/pending
approval, restart-required handling, host relaunch, provider-version proof, and
manual reconnect on the accepted oldest and current macOS baselines.

### 7. Withdrawal, rollback, and downgrade

- **Withdrawal before installation:** remove the item from the signed appcast,
  re-sign the feed, atomically publish it, and remove/deny the affected asset.
  This prevents new discovery after a fresh feed fetch. It cannot recall an
  already downloaded or installed update; operators must not claim otherwise.
- **Emergency stop:** replace the feed with a valid signed feed containing no
  affected item. Do not publish an unsigned or malformed feed as a stop signal.
- **Rollback:** build last-known-good source as a new release with a strictly
  higher `CFBundleVersion`, preserving data/schema compatibility, then pass the
  entire signing/notarization/EdDSA/publication process. This is a forward
  rollback.
- **Downgrade:** Sparkle 2 does not support it. No appcast channel, environment
  flag, or test exception may offer a lower `CFBundleVersion`. A true downgrade
  is a separately documented manual reinstall/recovery operation and cannot be
  advertised as safe until application data and system-extension behavior are
  physically validated.
- **Ticket/certificate incident:** Apple documents that a developer can work
  with Apple to revoke notarization tickets for unauthorized software signed
  with an exposed Developer ID key. This is an external incident-response step,
  not an appcast feature.

### 8. EdDSA generation, custody, rotation, and revocation boundary

No secret is generated or stored by this task. `TASK-260717-ziprhs` owns the
manual ceremony using the Sparkle 2.9.4 `generate_keys` tool.

The ceremony must produce exactly one production keypair, record only the public
key in source, place the private signing material in a protected release
environment secret, and create a separately controlled encrypted offline escrow.
At least two authorized custodians approve production key import, use, rotation,
and destruction. Pull-request jobs, forks, developer builds, logs, artifacts,
board resources, and the update origin never receive private material. Release
jobs receive it only after protected-environment human approval and erase their
ephemeral copy after signing.

Planned rotation while the old key remains controlled:

1. Keep the Developer ID identity unchanged.
2. Publish a bridge DMG signed by the old EdDSA key whose embedded app pins the
   new public key. With `SUVerifyUpdateBeforeExtraction=YES`, the bridge must be a
   Developer ID-signed DMG.
3. After accepted adoption evidence, publish later releases with the new key and
   retire the old CI secret under two-person control.

Sparkle documents that a regular app update may change either the Developer ID
certificate or the EdDSA key, but not both in one update. Therefore Developer ID
rotation keeps the current EdDSA key, and EdDSA rotation keeps the current
Developer ID identity.

There is no magic remote revocation of a public key pinned in already installed
apps. If an EdDSA key is lost while signed-feed failure expiration is disabled,
or both trust roots cannot support a valid bridge, the in-app path stays closed;
recovery is a newly notarized manual download with explicit user action. If a key
is suspected compromised, withdraw the feed/assets, disable the signing secret,
preserve audit evidence, begin incident response, and do not rotate or republish
until a human security approver selects a supported recovery path.

### 9. Privacy and telemetry

- `SUEnableSystemProfiling=NO`; do not implement `feedParametersForUpdater` or
  add device, hardware, locale, profile, tunnel, destination, DNS, or stable user
  identifiers to requests.
- Automatic checks begin only after Sparkle's consent prompt; manual checks are
  user initiated. Automatic download/install remains disabled.
- The update origin is a distribution boundary, not product analytics. It may
  receive ordinary HTTPS metadata such as source IP, time, URL, transport/user
  agent, and response status. Logs are security/availability-only, access
  controlled, not joined to product profiles, not used for behavioral analytics
  or advertising, and retained for at most seven days unless a documented
  security incident requires a legal hold.
- Appcast, release notes, and assets contain no user-specific URL or query data.
  There is no third-party analytics tag, JavaScript, tracking pixel, or telemetry
  callback. Privacy documentation must disclose the update request boundary and
  retention before enabling the production origin.

### 10. Human release gates

No stable appcast publication occurs until all gates have recorded evidence:

1. **Dependency gate:** independent reviewer accepts the exact Sparkle version,
   lock, checksum, license/notices, and any upgrade delta.
2. **Key gate:** two custodians accept the manual EdDSA ceremony/escrow and the
   protected environment proves signing without exposing private material.
3. **Candidate gate:** release owner approves source tag, monotonic versions,
   channel, release notes, provenance, SBOM, dependency lock, and rollback/data
   compatibility statement.
4. **Apple integrity gate:** release operator and independent approver inspect
   nested signatures, Team/bundle identifiers, entitlements, Hardened Runtime,
   notarization log, stapling, Gatekeeper assessment, and final DMG digest.
5. **Update integrity gate:** independent approver verifies the feed/release-note
   signatures, enclosure EdDSA signature and length, version/channel/floor,
   cache headers, remote digest, and asset-first/feed-last publication plan.
6. **Physical lifecycle gate:** `TASK-260715-1r48pc` and the independent matrix
   `TASK-260715-2aessv` accept clean install and prior-stable update on named Macs,
   including system-extension approval/replacement/restart cases, tunnel stop,
   host relaunch, provider version, manual reconnect, interruption, and rollback
   rehearsal.
7. **Privacy gate:** reviewer confirms profiling/analytics are off, request URLs
   have no identifier parameters, origin logs follow the seven-day policy, and
   disclosures match observed requests.
8. **Promotion gate:** a human release approver selects prerelease or stable and
   authorizes the atomic appcast change. Final release cadence remains a separate
   product decision.

## Threat-model and downstream CI impact

The update boundary has two independent trust roots: Sparkle EdDSA authenticates
the feed, release notes, and final archive bytes; Developer ID, Hardened Runtime,
notarization, stapling, and the system-extension activation checks provide the
Apple distribution boundary. HTTPS and origin controls are defense in depth.
Compromise of source, dependency resolution, either signing authority,
notarization credentials, CI publication authority, DNS/TLS, or operator review
can affect the result and must remain separately auditable.

`TASK-260717-xempiv` consumes the exact dependency, target, settings,
sandbox/XPC, lifecycle, and system-extension boundaries. `TASK-260717-1mt4e7`
consumes the final-DMG input contract, signed-feed settings, channel/version
schema, cache/origin policy, asset-first/feed-last ordering, and fail-closed CI
checks. The concise handoff is in
`.research/TASK-260717-2uyfn5_downstream-handoff.md`.

The current `TASK-260717-a8uhro` description is stale in two ways and must be
refined before execution: Sparkle 2 has no explicit rollback channel for lower
versions, and the test must not assume Sparkle rejects every Developer ID Team
ID change because Sparkle documents supported Developer ID key rotation. CI
should instead enforce the product's approved host/system-extension identity and
test forward rollback plus Apple/Sparkle signature failures.

## Unknowns and residual gates

- Exact macOS approval UI, reuse of prior approval, active-provider replacement,
  restart timing, MDM differences, and behavior on every supported patch release
  are not established by the cited API contracts.
- `updates.relux.works` DNS, TLS, storage, access controls, headers, and privacy
  operations do not exist as evidence in this task.
- No production EdDSA public/private key, Developer ID identity, notarized DMG,
  signed feed, or working updater exists yet.
- No clean-install or prior-stable physical update has been performed. The
  later manual tasks remain blocking release gates.

## Primary sources

All sources were accessed 2026-07-21.

### Sparkle

- [Sparkle 2.9.4 release](https://github.com/sparkle-project/Sparkle/releases/tag/2.9.4)
- [Official latest-release API](https://api.github.com/repos/sparkle-project/Sparkle/releases/latest)
- [Official 2.9.4 tag ref](https://api.github.com/repos/sparkle-project/Sparkle/git/ref/tags/2.9.4)
- [Tagged Swift Package manifest](https://raw.githubusercontent.com/sparkle-project/Sparkle/2.9.4/Package.swift)
- [Tagged license and bundled notices](https://raw.githubusercontent.com/sparkle-project/Sparkle/2.9.4/LICENSE)
- [Official 2.9.4 SPM binary asset](https://github.com/sparkle-project/Sparkle/releases/download/2.9.4/Sparkle-for-Swift-Package-Manager.zip)
- [Basic setup, EdDSA, signed feeds, key rotation, distribution, and checks](https://sparkle-project.org/documentation/)
- [Custom settings and fail-closed feed controls](https://sparkle-project.org/documentation/customization/)
- [Publishing, versions, system floors, channels, and feed generation](https://sparkle-project.org/documentation/publishing/)
- [Sandboxing, XPC services, and code signing](https://sparkle-project.org/documentation/sandboxing/)
- [Programmatic setup and updater API expectations](https://sparkle-project.org/documentation/programmatic-setup)
- [Upgrade guide, including removal of downgrade support](https://sparkle-project.org/documentation/upgrading/)
- [System profiling request contents](https://sparkle-project.org/documentation/system-profiling/)
- [Updater install-on-quit lifecycle API](https://sparkle-project.org/documentation/api-reference/Protocols/SPUUpdaterDelegate.html)

### Apple

- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Resolving common notarization issues](https://developer.apple.com/documentation/security/resolving-common-notarization-issues)
- [Hardened Runtime](https://developer.apple.com/documentation/security/hardened-runtime)
- [Creating distribution-signed code for macOS](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac/)
- [TN3134: Network Extension provider deployment](https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment)
- [System Extensions overview](https://developer.apple.com/documentation/systemextensions)
- [Installing and updating system extensions](https://developer.apple.com/documentation/systemextensions/installing-system-extensions-and-drivers)
- [System-extension activation request lifecycle](https://developer.apple.com/documentation/systemextensions/ossystemextensionrequest/activationrequest%28forextensionwithidentifier%3Aqueue%3A%29)
- [System-extension replacement delegate](https://developer.apple.com/documentation/systemextensions/ossystemextensionrequestdelegate/request%28_%3Aactionforreplacingextension%3Awithextension%3A%29)
- [Packet tunnel provider](https://developer.apple.com/documentation/networkextension/packet-tunnel-provider)
- [Network Extensions entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.networkextension)
