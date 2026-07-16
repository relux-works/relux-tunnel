# Platform and distribution specification

## Project shape

The current SwiftPM executable is insufficient for embedded Network Extension
targets and iOS distribution. The target project is a generated Xcode workspace,
using the Relux Works Tuist convention unless the project migration task records
a better supported choice.

Planned targets:

- `ReluxProxyMac` containing app;
- `ReluxProxyMacTunnel` packet tunnel extension;
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

Exact deployment targets are selected during project migration from current
API/support evidence. The baseline MUST support:

- a current iOS release on a physical iPhone used for memory/lifecycle gates;
- a current macOS release on Apple silicon;
- the oldest iOS/macOS versions for which all selected Network Extension,
  Network.framework, Swift concurrency, signing, and dependency requirements can
  be tested in CI.

No deployment target is lowered by adding private API or fragile compatibility
shims.

## Signing and release channels

### macOS

Developer ID distribution uses hardened runtime, nested signing in inside-out
order, notarization, stapling, Gatekeeper validation, checksums, and provenance
attestation. The packet tunnel extension and containing app need compatible
entitlements/profiles. A stable `ReluxProxy.dmg` release asset may continue, but
on a private repository it requires authenticated GitHub access.

### iOS

iOS uses Apple Development for device spikes and Apple Distribution through
TestFlight/App Store. Developer ID and notarization do not apply to iOS.
TestFlight is required for lifecycle, entitlement, and review-preparation
iterations before App Store submission.

### macOS self-update

The macOS app ships an in-app self-update channel so security fixes reach users
without a manual re-download (ADR-018). Constraints:

- Sparkle 2.x with an EdDSA (ed25519) signed appcast; the public key is pinned in
  `Info.plist` (`SUPublicEDKey`), the private key is a CI secret held in the same
  custody as the Developer ID / notarization credentials.
- Every update payload is an already-notarized Developer ID build, so hardened
  runtime, Gatekeeper, and stapling guarantees are preserved end to end. The
  updater embeds without introducing notarization-breaking entitlements.
- The appcast and update assets are published from the same authenticated GitHub
  release channel as the notarized DMG; a missing or invalid signature fails
  closed, downgrades are refused outside an explicit rollback channel, and a
  payload whose team identifier does not match is rejected.
- iOS is out of scope for self-update: the App Store owns iOS updates.
- Key custody, rotation, appcast withdrawal, emergency stop, and rollback are
  documented in the self-update runbook and referenced by the threat model
  (supply-chain adversary, §4.E).

## CI/CD contract

Pull requests run documentation/board validation plus builds and tests available
without production credentials. Release workflows use GitHub Environments and
least-privilege secrets; no certificate, private key, issuer credential, or
provisioning secret is committed.

Required pipelines:

1. shared-core unit and protocol conformance tests on macOS;
2. macOS host/extension build, entitlement inspection, signing verification,
   notarization, DMG publication, checksums, and stable-name asset;
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
