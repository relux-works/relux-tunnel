# Platform and distribution specification

## Project shape

The current SwiftPM executable is insufficient for embedded Network Extension
targets and iOS distribution. The target project is a generated Xcode workspace
using Tuist 4.202.5, pinned exactly by repository-local Mise. Generation and CI
select an exact Xcode version and apply the deterministic comparison policy in
TASK-260715-3r0993; they do not consume an unversioned global Tuist installation.

Planned targets:

- `ReluxProxyMac` containing app;
- `ReluxProxyMacTunnel` packet-tunnel system extension for direct Developer ID
  distribution;
- `ReluxProxyIOS` containing app;
- `ReluxProxyIOSTunnel` packet tunnel extension;
- `ReluxTunnelCore` Swift package shared by both providers;
- `ReluxTunnelHarness` macOS CLI for fast packet/SSH/relay experiments;
- `relux-relay` portable remote executable and protocol test target.

The existing menu bar SOCKS app remains buildable until an explicit migration
task replaces it. Migration MUST preserve or deliberately retire its profile
defaults and release history.

## Apple capabilities

Both containing apps manage custom VPN configurations through
`NETunnelProviderManager`. Host and extension App IDs require the Network
Extension packet-tunnel entitlement and matching provisioning profiles. App
Groups and Keychain Sharing provide the minimum app/extension state boundary.

**Gate P0:** confirm Relux Works organization enrollment, bundle IDs, Network
Extension capability/profiles, and device installation before packet-plane work
is considered viable.

The app must be primarily a networking product and accurately disclose its
extension and VPN behavior. Apple App Review Guideline 5.4 requires VPN apps to
be offered by an organization and imposes privacy and regional-law obligations.

## Minimum platform policy

New generated Apple targets use iOS 18.0 and macOS 15.0. The shipped legacy
`ReluxProxy` SwiftPM product remains a separate macOS 14.0 compatibility lane
until its migration/retirement decision says otherwise. The baseline MUST
support:

- a current iOS release on a physical iPhone used for memory/lifecycle gates;
- a current macOS release on Apple silicon;
- the oldest iOS/macOS versions for which all selected Network Extension,
  Network.framework, Swift concurrency, signing, and dependency requirements can
  be tested in CI.

The dated evidence, named physical devices, minimum/current CI matrix, Xcode
pins, and upgrade ownership are recorded in
`.research/260720_task-260715-3r0993-project-generator-deployment-target-policy.md`.
Any later dependency that requires a higher target blocks generation until this
policy and ADR-016 are reviewed; it does not silently rewrite the manifest.

No deployment target is lowered by adding private API or fragile compatibility
shims.

## Signing and release channels

### macOS

Developer ID distribution uses hardened runtime, nested signing in inside-out
order, notarization, stapling, Gatekeeper validation, checksums, and provenance
attestation. The packet-tunnel system extension and containing app need
compatible entitlements/profiles and the same approved Team ID. A stable
`ReluxProxy.dmg` release asset may continue, but on a private repository it
requires authenticated GitHub access.

### iOS

iOS uses Apple Development for device spikes and Apple Distribution through
TestFlight/App Store. Developer ID and notarization do not apply to iOS.
TestFlight is required for lifecycle, entitlement, and review-preparation
iterations before App Store submission.

### macOS self-update

The macOS app ships the ADR-018 in-app update design so security fixes can reach
users without a manual re-download. This remains accepted design until the
integration, release pipeline, key ceremony, and physical gates pass.

#### Dependency and integration

- Pin official Sparkle **2.9.4** exactly through Swift Package Manager at tag
  commit `b6496a74a087257ef5e6da1c5b29a447a60f5bd7`; the official binary-target
  checksum is
  `cb6fdbdc8884f15d62a616e79face92b08322410fd2d425edc6596ccbf4ba3b0`.
  Ranges, branches, prereleases, and automatic dependency upgrades are
  prohibited. Ship the tagged complete `LICENSE`, including bundled licenses.
- Link and embed Sparkle only in the sandboxed, hardened-runtime
  `ReluxProxyMac` host. Use a host-owned `SPUStandardUpdaterController`; never
  link Sparkle into the packet-tunnel system extension, shared core, harness, or
  iOS.
- The sandboxed host enables `SUEnableInstallerLauncherService` and Sparkle's
  documented `<host-bundle-id>-spks` / `<host-bundle-id>-spki` Mach lookup
  exceptions. Because the host has outbound network-client access, Downloader,
  Installer Connection, and Installer Status XPC services stay disabled.
  Xcode Archive + Developer ID Export must re-sign the framework, both bundled
  XPC services, `Autoupdate`, and `Updater.app`; “Code Sign on Copy” alone is not
  release evidence.
- Hardened Runtime remains enabled on all executable code. Distribution has no
  `get-task-allow`, disabled library validation, unsigned/JIT executable-memory,
  or unreviewed exception entitlement.

#### Feed and updater settings

- `SUFeedURL` is
  `https://updates.relux.works/macos/appcast.xml`. The origin is public,
  read-only, ATS-compatible HTTPS; no repository credential or user secret is
  embedded in the app. Private GitHub releases remain the authenticated manual
  download channel and may mirror the exact same final DMG bytes.
- Pin the later ceremony's public key in `SUPublicEDKey`. Set
  `SUVerifyUpdateBeforeExtraction=YES`, `SURequireSignedFeed=YES`, and
  `SUSignedFeedFailureExpirationInterval=0`. Feed, release-note, payload, TLS,
  parse, version, or download failure has no unsigned, alternate-feed, website,
  or expiration fallback.
- Leave `SUEnableAutomaticChecks` absent so Sparkle asks on second launch; set a
  86,400-second schedule, `SUAutomaticallyUpdate=NO`,
  `SUAllowsAutomaticUpdates=NO`, `SUEnableSystemProfiling=NO`, and
  `SUEnableJavaScript=NO`. A user may check manually and a declined automatic
  check preference is respected.
- Stable appcast items omit `sparkle:channel`. Opt-in prereleases use exactly
  `prerelease`; prerelease clients also see Sparkle's unexcludable default
  channel. One monotonically increasing integer `CFBundleVersion` sequence spans
  both channels. Appcast version strings match the app exactly and the baseline
  `sparkle:minimumSystemVersion` is `15.0.0`.
- Appcast and detached release notes use `Cache-Control: no-store`; versioned
  payloads use `Cache-Control: public, max-age=31536000, immutable`. Enclosure
  URLs are immutable, same-origin, and non-redirecting. Publish verified assets
  first and atomically replace the signed appcast last.

#### Signed, already-notarized payload invariant

The baseline enclosure is a DMG, not ZIP, PKG, or delta. Build and sign all
nested code inside-out, verify exact identities/entitlements and Hardened
Runtime, notarize and staple the app, assemble/sign/notarize/staple the final
DMG, and only then run Sparkle 2.9.4 signing tools over the final immutable DMG
bytes. Any later mutation invalidates publication and requires rebuilding the
Apple and Sparkle evidence. A missing signing input, failed notarization/stapling,
identity or entitlement drift, signature failure, wrong version/channel/floor,
remote digest/header mismatch, or premature feed publication fails CI closed.

#### System-extension lifecycle

Apple TN3134 requires a system extension for a directly distributed macOS
packet-tunnel provider. The host must confirm an orderly tunnel stop before
allowing update installation. Sparkle then replaces/relaunches only the
containing app. On relaunch the host separately requests activation/replacement
of the embedded same-Team-ID, same-bundle-ID system extension and does not claim
the new provider active until the OS reports success. The baseline does not
auto-reconnect after update.

Apple documents that new-version activation can require user approval and can
return restart-required. Exact approval reuse, UI, timing, active-provider, and
managed-system behavior are OS-controlled and remain unknown. Physical clean
install and old-to-new update evidence, including denial, restart, relaunch,
provider-version proof, and manual reconnect, is mandatory under
`TASK-260715-1r48pc` and `TASK-260715-2aessv`.

#### Withdrawal, rollback, keys, and privacy

- Withdrawal republishes a valid signed feed without the affected item and
  removes/denies its asset. It prevents new discovery after a fresh check but
  cannot recall already downloaded or installed software.
- Sparkle 2 does not support downgrades. Emergency rollback publishes
  last-known-good source as a newly signed/notarized release with a higher
  `CFBundleVersion`; true downgrade is a separate manual recovery path. There is
  no rollback channel.
- `TASK-260717-ziprhs` owns the human EdDSA key ceremony. The private key exists
  only in a protected release environment plus separately controlled encrypted
  escrow; two custodians approve import, use, rotation, and destruction. No
  secret enters source, PR jobs, logs, artifacts, the feed origin, or board
  resources.
- Planned EdDSA rotation uses an old-key-signed Developer ID DMG bridge that pins
  the new public key while the Developer ID identity stays unchanged. Developer
  ID and EdDSA identities never rotate in the same update. There is no remote
  revocation of a key pinned in installed apps; unsupported recovery remains a
  manual notarized download.
- Update requests carry no Sparkle system profile, custom identifier parameters,
  traffic/destination/DNS data, analytics, JavaScript, or tracking content. The
  origin may keep access-controlled security/availability logs for at most seven
  days, never join them to product profiles, and must be disclosed before
  production.

The dated authority, sources, human release gates, and downstream contracts are
in [`.research/260721_macos-self-update.md`](../.research/260721_macos-self-update.md).

## CI/CD contract

Pull requests run documentation/board validation plus builds and tests available
without production credentials. Release workflows use GitHub Environments and
least-privilege secrets; no certificate, private key, issuer credential, or
provisioning secret is committed.

Required pipelines:

1. shared-core unit and protocol conformance tests on macOS;
2. macOS host/system-extension build, entitlement inspection, nested signing,
   notarization/stapling, final-DMG verification, Sparkle 2.9.4 payload/feed
   signing, asset-first/feed-last publication, cache/privacy probes, checksums,
   and stable manual-download asset;
3. iOS host/extension archive, entitlement/provisioning inspection, and
   TestFlight upload;
4. reproducible relay cross-build matrix, tests, checksums, manifest generation,
   and bundling into Apple targets;
5. dependency license/SBOM and secret scanning;
6. semantic version/tag validation and release notes.

Production release jobs are serialized. Build artifacts retain exact source
commit, dependency lockfiles, relay manifest, protocol version, bundle versions,
and signing identity metadata.

## App Review package

The submission package includes:

- an accurate VPN data-flow explanation and test SSH host instructions;
- in-app VPN data disclosure and public privacy policy;
- Network Extension entitlement purpose;
- regional licensing notes or excluded storefronts;
- explanation that users provide their own SSH exit host;
- degraded-mode behavior and system-excluded traffic disclosure;
- review account/profile or reproducible setup that does not expose private
  production credentials.
