# TASK-260715-1fv4z1 — Legacy project inventory and migration invariants

**Status:** research handoff for review  
**Verified:** 2026-07-20 (Asia/Tbilisi)  
**Legacy source (read-only):** `/Users/iv/Developer/relux-proxy`  
**Destination:** `/Users/iv/Developer/relux-tunnel`  
**Shipped baseline:** signed annotated tag `v0.1.0`, commit
`2557aba1c030d0643d76e0bc3b185f6d5fd172e1`  
**Current legacy HEAD:** `7e6f25b` (`main`, `origin/main`)

## Key takeaways

1. The shipped product is one dependency-free SwiftPM macOS 14 executable,
   `ReluxProxy`, one XCTest target, and a manually assembled menu-bar app/DMG.
   It is not a system VPN and contains no Network Extension target or
   entitlement.
2. M0 must keep the entire legacy lane reproducible and separate: SwiftPM
   product and tests, system-SSH behavior, `AppStorage` keys/defaults, manual
   SOCKS instructions, bundle identity, app/DMG scripts, and the v0.1.0 release
   lineage. None belongs implicitly in `ReluxProxyMac`, a packet-tunnel
   provider, or `ReluxTunnelCore`.
3. The app is Developer ID signed with hardened runtime but has **no App Sandbox
   entitlement**. `/usr/bin/ssh` relies on the user's home SSH configuration,
   keys, agent, known-host state, and optional `ProxyJump`. A sandboxed child
   inherits its parent's sandbox, so adding App Sandbox or moving this process
   path into a provider cannot silently preserve that behavior.
4. The authoritative v0.1.0 binary baseline is the GitHub release, not ignored
   local `dist/` output. The published DMGs have SHA-256
   `5159c07c25f9c46df33462d256cab8a10eb79d677ad2e9b182e9e4188363c20d`,
   a stapled notarization ticket, a valid Developer ID signature, Gatekeeper
   acceptance, and a GitHub build-provenance attestation.
5. Coexistence, replacement, profile conversion, release-asset takeover,
   support horizon, and retirement remain explicit later decisions owned by
   `TASK-260715-35nc5m`. This inventory authorizes none of them.

## 1. Evidence boundary and provenance

The source, test, packaging, and workflow files listed below have identical Git
blob IDs at `v0.1.0`, current `HEAD`, and the current worktree: `Package.swift`,
all five files under `Sources/ReluxProxy`, the sole test file, `Info.plist`,
`Makefile`, all three scripts, and both GitHub workflows. Thus the tagged source
is also the authoritative current product source.

Current documentation is broader than the tag: since v0.1.0, `README.md` gained
the future-VPN boundary and private-repository download note, and
`CONTRIBUTING.md`, `SECURITY.md`, `docs/current-state.md`, and
`docs/project-management.md` were added. These current documents are part of
the migration inventory but are not claimed to have shipped inside v0.1.0.

The legacy worktree contains unrelated uncommitted specification/task-board
work. No in-scope product path is modified. All build/test verification was
therefore run from a temporary, detached clone of `v0.1.0`; the legacy checkout
was not modified.

Verification:

```sh
git -C /Users/iv/Developer/relux-proxy tag -v v0.1.0
git -C /Users/iv/Developer/relux-proxy diff --name-status \
  v0.1.0..HEAD -- Package.swift Sources Tests Resources Makefile scripts \
  .github README.md SECURITY.md CONTRIBUTING.md LICENSE docs
git -C /Users/iv/Developer/relux-proxy status --short -- \
  Package.swift Sources Tests Resources Makefile scripts .github \
  README.md SECURITY.md CONTRIBUTING.md LICENSE docs
```

Expected: the tag verifies for `oparin@me.com` with ECDSA key fingerprint
`SHA256:V6JiKG7J29mjsvikcLoSVp0bLa77VTsFy12gnLO81cM`; the committed diff contains
only the five documentation changes described above; the scoped worktree status
is empty.

## 2. Authoritative current-state inventory

### 2.1 SwiftPM manifest, products, and targets

| Item | Current contract | Evidence | Verification command |
|---|---|---|---|
| Tools/language | Swift tools 5.10; Swift language mode 5 | `Package.swift:1,24` | `swift package dump-package` |
| Platform | macOS 14.0 minimum | `Package.swift:7-9` | `swift package dump-package` and inspect `.platforms` |
| Package/product | Package `ReluxProxy`; executable product `ReluxProxy` | `Package.swift:5-12` | `swift package dump-package` |
| Executable target | `ReluxProxy` at `Sources/ReluxProxy` | `Package.swift:13-17` | `swift package dump-package` |
| Test target | `ReluxProxyTests` at `Tests/ReluxProxyTests`, depending on `ReluxProxy` | `Package.swift:18-22` | `swift package dump-package` |
| Dependencies/resources | No package dependencies and no SwiftPM resources | complete manifest | `swift package dump-package` |
| Lockfile | No `Package.resolved` is required because there are no dependencies | repository tree | `git ls-tree -r --name-only v0.1.0` |

Clean verification on 2026-07-20 with Xcode 26.5 / Swift 6.3.2 succeeded:
`swift test` ran four XCTest cases with zero failures, `swift build` succeeded,
and the release build produced both arm64 and x86_64 slices. The requirement
documented to users remains macOS 14+ and Xcode 15.3+; the newer verification
toolchain does not redefine that lower bound.

### 2.2 Source ownership by file

| Source area | Owned behavior | Must-preserve M0 boundary | Verification command |
|---|---|---|---|
| `Sources/ReluxProxy/ReluxProxyApp.swift` | SwiftUI `@main`; singleton controller; `MenuBarExtra` in window style; menu-bar accessibility label; shutdown on app termination | Remains the legacy app entry point, not a generated provider or shared-core entry point | `nl -ba Sources/ReluxProxy/ReluxProxyApp.swift` |
| `Sources/ReluxProxy/MenuContentView.swift` | Three persisted fields, endpoint display, validation/failure text, status icon/color, Connect/Disconnect state, Firefox hint, Quit command, 360-point panel | Preserve legacy UX and defaults until an approved migration/retirement decision | `nl -ba Sources/ReluxProxy/MenuContentView.swift` |
| `Sources/ReluxProxy/TunnelConfiguration.swift` | Whitespace normalization, SSH target rendering, loopback endpoint, validation messages/rules | Remains legacy profile semantics; it is not the new VPN profile schema | `nl -ba Sources/ReluxProxy/TunnelConfiguration.swift` |
| `Sources/ReluxProxy/SSHCommandBuilder.swift` | Absolute `/usr/bin/ssh` path and exact fixed argument vector | Preserve exact legacy command contract; do not reuse it as a hidden provider transport | `nl -ba Sources/ReluxProxy/SSHCommandBuilder.swift` |
| `Sources/ReluxProxy/TunnelController.swift` | Child-process lifecycle, loopback port probe, readiness polling, stderr diagnostics, stop escalation, status model | Preserve legacy process behavior; provider lifecycle is separately owned | `nl -ba Sources/ReluxProxy/TunnelController.swift` |

There are no other shipped source directories or targets at v0.1.0.

### 2.3 Test suite

The only suite is `Tests/ReluxProxyTests/TunnelConfigurationTests.swift`, class
`TunnelConfigurationTests`, containing four XCTest cases:

| Test | Contract asserted | Verification command |
|---|---|---|
| `testBuildsTargetWithAccount` | trims host/account; renders `administrator@relux` and `127.0.0.1:1080`; configuration is valid | `swift test --filter TunnelConfigurationTests.testBuildsTargetWithAccount` |
| `testBuildsTargetWithoutAccount` | empty account renders host-only target | `swift test --filter TunnelConfigurationTests.testBuildsTargetWithoutAccount` |
| `testRejectsInvalidValues` | rejects empty host, whitespace in host, `@` in account, and port 70000 | `swift test --filter TunnelConfigurationTests.testRejectsInvalidValues` |
| `testSSHArgumentsMatchHardenedTunnelSetup` | asserts the complete SSH argument vector byte-for-byte as Swift strings | `swift test --filter TunnelConfigurationTests.testSSHArgumentsMatchHardenedTunnelSetup` |

M0 destination: retain the suite under the legacy `ReluxProxyTests` target and
keep `swift test` as a required compatibility check. It must not be counted as
coverage for `ReluxTunnelCore` or either provider. New targets need their own
tests; deleting or moving these four tests requires the explicit legacy
retirement decision.

Known coverage boundary: there are no automated tests for `TunnelController`,
menu UI/AppStorage, app termination, live SSH, port readiness/timeout,
disconnect escalation, bundle assembly, DMG layout, or signing/notarization.
Existing CI supplies compile/packaging evidence for some of those paths, not
unit coverage.

### 2.4 Persisted defaults and validation semantics

`@AppStorage` uses the packaged app's standard defaults domain. Because the
bundle identifier is `works.relux.proxy` and no custom suite is supplied, the
legacy storage namespace is the `works.relux.proxy` application domain. This is
an inference from the source plus bundle metadata, not an explicit suite name in
code.

| Key | Type | Initial value when absent | Current validation/normalization | Verification command |
|---|---|---:|---|---|
| `sshHost` | String | `relux` | trims outer whitespace/newlines; must be nonempty; any remaining whitespace is rejected | `rg -n '@AppStorage|normalizedHost|SSH host' Sources/ReluxProxy` |
| `sshAccount` | String | `administrator` | trims outer whitespace/newlines; may be empty; remaining whitespace or `@` is rejected | `rg -n '@AppStorage|normalizedAccount|SSH account' Sources/ReluxProxy` |
| `localPort` | Int | `1080` | must be in `1...65535`; endpoint is always `127.0.0.1:<port>` | `rg -n '@AppStorage|localEndpoint|65_535' Sources/ReluxProxy` |

The validator does not impose a broader hostname/account grammar. For example,
it does not explicitly reject punctuation other than the rules above. That is
current behavior, not a recommendation.

After launching and editing a packaged app, storage can be inspected without
changing it:

```sh
defaults read works.relux.proxy sshHost
defaults read works.relux.proxy sshAccount
defaults read works.relux.proxy localPort
```

M0 invariant: preserve the three key names, types, absence defaults, application
domain, and validation behavior. Do not silently copy them into an App Group,
new bundle defaults, Keychain, or a new VPN profile. Mapping, idempotency,
unrepresentable values, deletion, downgrade, and coexistence namespaces belong
to `TASK-260715-35nc5m` and its downstream migration task.

### 2.5 Exact system-SSH contract

Executable:

```text
/usr/bin/ssh
```

Exact argument order for defaults:

```text
-N
-C
-D 127.0.0.1:1080
-o ExitOnForwardFailure=yes
-o ServerAliveInterval=30
-o ServerAliveCountMax=3
-o ConnectTimeout=15
-o BatchMode=yes
-o LogLevel=ERROR
administrator@relux
```

Source: `SSHCommandBuilder.swift:3-23`; exact regression assertion:
`TunnelConfigurationTests.swift:29-48`.

Consequences that are part of current behavior:

- `-D` creates a SOCKS dynamic forward bound explicitly to IPv4 loopback, not a
  public listener.
- `-N` runs no remote command; `-C` enables SSH compression.
- `BatchMode=yes` suppresses interactive password/passphrase/host-key prompts.
  Successful use therefore depends on noninteractive system-SSH facilities and
  the user's existing configuration/trust/authentication state.
- No `-F`, identity, proxy, known-hosts, or algorithm override is supplied.
  Normal system OpenSSH resolution of aliases, keys, `ProxyJump`, agent, and
  `~/.ssh/config` remains visible.
- Host-key verification is not disabled or weakened by the app.
- Standard input and output are `/dev/null`; stderr alone is captured.

Verification:

```sh
swift test --filter TunnelConfigurationTests.testSSHArgumentsMatchHardenedTunnelSetup
rg -n 'executableURL|standardInput|standardOutput|standardError' \
  Sources/ReluxProxy
```

### 2.6 Tunnel process and state behavior

| Behavior | Current result | Evidence | Verification command |
|---|---|---|---|
| Singleton/one process | `TunnelController.shared`; a second `connect` is ignored while `process != nil` | `TunnelController.swift:43-56` | `rg -n 'static let shared|guard process == nil' Sources/ReluxProxy` |
| Initial state | `disconnected`, empty diagnostic | lines 46-47 | `rg -n '@Published' Sources/ReluxProxy/TunnelController.swift` |
| Preflight | Validates profile, then tests whether `127.0.0.1:<port>` can be bound | lines 55-62, 173-193 | `rg -n 'isLocalPortAvailable|localPortInUse' Sources/ReluxProxy/TunnelController.swift` |
| Launch | Sets `connecting`, starts `/usr/bin/ssh`, and polls the local port | lines 63-95 | source inspection plus `pgrep -alf '/usr/bin/ssh.*-D 127.0.0.1:'` during a controlled run |
| Readiness | 100 attempts at 200 ms; connected after a TCP connect to the loopback port; approximately 20-second outer readiness window | lines 128-148 | `rg -n '0..<100|200_000|canConnect' Sources/ReluxProxy/TunnelController.swift` |
| Failure | Launch errors or unexpected termination become `failed(last stderr line)`; fallback reports SSH exit status | lines 96-101, 202-220 | controlled invalid alias and source inspection |
| Diagnostic bound | Captured stderr retains at most the last 4,000 characters | lines 195-199 | `rg -n '4_000|suffix' Sources/ReluxProxy/TunnelController.swift` |
| User disconnect | SIGTERM via `Process.terminate()`, then SIGKILL after 2 seconds if still running | lines 104-120 | controlled run plus `ps`/`pgrep` observation |
| Quit/app termination | requests SIGTERM; Quit calls shutdown before terminating; app delegate also calls shutdown | controller lines 122-126; app lines 4-7; menu lines 94-98 | `rg -n 'shutdown|terminate|SIGTERM|SIGKILL' Sources/ReluxProxy` |
| Stop result | requested stop clears diagnostics and returns to `disconnected`; unexpected stop becomes `failed` | lines 202-220 | controlled SSH fixture or source inspection |

The bind preflight and later SSH bind are separate, so a time-of-check/time-of-use
race is possible. This is an observed code property and a regression caveat, not
authorization to change it in the inventory task.

### 2.7 User-visible/manual SOCKS behavior

| Surface | Current behavior | Verification command |
|---|---|---|
| Application form | Menu-bar window labeled “Relux Proxy” with SSH host, Account, and SOCKS port fields | `rg -n 'Relux Proxy|SSH host|Account|SOCKS port' Sources/ReluxProxy/MenuContentView.swift` |
| Endpoint | Selectable monospace `127.0.0.1:<port>` | `rg -n 'Proxy endpoint|localEndpoint|textSelection' Sources/ReluxProxy` |
| Statuses | Disconnected, Connecting…, Connected, Disconnecting…, Connection failed; matching SF Symbols and gray/orange/green/red treatment | `rg -n 'Disconnected|Connecting|Connected|Disconnecting|Connection failed|symbolName|statusColor' Sources/ReluxProxy` |
| Editing | Disabled while connecting, connected, or disconnecting; enabled when disconnected or failed | `rg -n 'preventsEditing|disabled' Sources/ReluxProxy` |
| Primary action | Connect when disconnected/failed; Disconnect when connected; disabled during transitions or invalid disconnected/failed configuration | `rg -n 'connectionButtonTitle|connectionButtonDisabled|toggleConnection' Sources/ReluxProxy/MenuContentView.swift` |
| Error display | Last failure message in red; local validation message in orange | `rg -n 'failed\(message\)|validationError|foregroundStyle' Sources/ReluxProxy/MenuContentView.swift` |
| Manual proxy | App does not alter system or browser proxy settings. It instructs Firefox users to select SOCKS v5 and proxy DNS manually | `rg -n 'Firefox|Manual proxy|SOCKS v5|proxy DNS' README.md Sources/ReluxProxy` |
| Menu-only app | `LSUIElement=true`; `MenuBarExtra` window style; no ordinary Dock application UI | `plutil -p Resources/Info.plist` and source inspection |
| Accessibility | Menu-bar label is “Relux Proxy: <status>” | `rg -n 'accessibilityLabel' Sources/ReluxProxy` |
| Quit | Quit button with Command-Q shortcut, tunnel shutdown first | `rg -n 'Quit|keyboardShortcut|shutdown' Sources/ReluxProxy/MenuContentView.swift` |

There is no automatic system VPN, system proxy mutation, DNS configuration,
autoconnect, launch-at-login behavior, profile list, iOS UI, password UI, or
interactive host-trust UI in the legacy source.

### 2.8 Bundle configuration (`Resources/Info.plist`)

| Key | Value/invariant | Verification command |
|---|---|---|
| `CFBundleDisplayName` / `CFBundleName` | `Relux Proxy` | `plutil -p Resources/Info.plist` |
| `CFBundleExecutable` | `ReluxProxy` | same |
| `CFBundleIdentifier` | `works.relux.proxy` | same |
| `CFBundleIconFile` | `ReluxProxy` (`ReluxProxy.icns` in bundle resources) | same plus `find dist/ReluxProxy.app/Contents` |
| `CFBundleShortVersionString` | template `0.1.0`; overwritten by build script | same plus packaged plist inspection |
| `CFBundleVersion` | template `1`; overwritten by build script | same plus packaged plist inspection |
| `LSMinimumSystemVersion` | `14.0` | same |
| `LSUIElement` | `true` | same |
| `NSHighResolutionCapable` | `true` | same |
| Development region | `en` | same |
| Copyright | `Copyright © 2026 Relux Works, LLC. All rights reserved.` | same |

There is no entitlements file and the published app's decoded entitlements are
empty. In particular, there is no `com.apple.security.app-sandbox`, App Group,
Keychain Sharing, or Network Extension entitlement.

### 2.9 Makefile and scripts

#### Makefile entry points

| Target | Exact current path | Effect | Verification command |
|---|---|---|---|
| `test` | `swift test` | builds debug product/tests and runs XCTest | `make test` |
| `build` | `swift build` | debug SwiftPM build | `make build` |
| `app` | `scripts/build-app.sh` | release app assembly and signing | `SIGN_IDENTITY=- make app` |
| `dmg` | depends on `app`, then `scripts/create-dmg.sh` | rebuilds app and packages DMG | `SIGN_IDENTITY=- make dmg` |
| `run` | depends on `app`, then `open dist/ReluxProxy.app` | rebuilds and launches app | `make -n run`; use `SIGN_IDENTITY=- make run` only for manual validation |
| `clean` | `rm -rf .build dist` | removes both build/output trees | `make -n clean`; run only in a disposable checkout |

`make -n test build app dmg run clean` inventories all six paths without running
them.

#### `scripts/build-app.sh`

- Fixed output: `dist/ReluxProxy.app` with `Contents/MacOS` and
  `Contents/Resources`.
- Defaults: `VERSION=0.1.0-dev`; leading `v` removed; short version is text before
  the first `-`; `BUILD_NUMBER` is Git commit count with fallback `1`.
- Release build is universal by default (`UNIVERSAL=1`) using
  `--arch arm64 --arch x86_64`; any other `UNIVERSAL` value produces the native
  build but does not change downstream DMG naming.
- Copies the SwiftPM `ReluxProxy` executable and plist, generates
  `ReluxProxy.icns`, then writes short/build versions with PlistBuddy.
- Default signing identity is exactly
  `Developer ID Application: Relux Works, LLC (262RZ595FP)`.
- `SIGN_IDENTITY=-` forces ad-hoc signing. If the requested non-`-` identity is
  absent, the script warns and falls back to ad-hoc signing. If present, it adds
  hardened runtime and a secure timestamp.
- Always runs `codesign --verify --deep --strict --verbose=2` after signing.

Verification:

```sh
VERSION=v0.1.0 BUILD_NUMBER=1 SIGN_IDENTITY=- scripts/build-app.sh
plutil -p dist/ReluxProxy.app/Contents/Info.plist
lipo -info dist/ReluxProxy.app/Contents/MacOS/ReluxProxy
codesign -dv --verbose=4 dist/ReluxProxy.app
codesign --verify --deep --strict --verbose=2 dist/ReluxProxy.app
codesign -d --entitlements - dist/ReluxProxy.app
```

#### `scripts/generate-icon.swift`

Generates ten PNG representations from 16 px through 1024 px in a temporary
iconset, then invokes `/usr/bin/iconutil -c icns`. The build output is
`Contents/Resources/ReluxProxy.icns`. There are no checked-in image assets.

Verification:

```sh
swift scripts/generate-icon.swift /tmp/ReluxProxy.icns
file /tmp/ReluxProxy.icns
```

#### `scripts/create-dmg.sh`

- Requires `dist/ReluxProxy.app`.
- Defaults `VERSION=0.1.0-dev`, strips a leading `v`, and always names output
  `dist/ReluxProxy-v${VERSION}-universal.dmg`.
- Recreates `.build/dmg-root`, copies the app, and adds an `Applications` symlink
  to `/Applications`.
- Uses `hdiutil create`, volume name `Relux Proxy`, overwrite mode, and compressed
  read-only `UDZO` format.
- Does not sign, notarize, staple, or Gatekeeper-check the DMG; the release
  workflow owns those steps.

Verification:

```sh
VERSION=v0.1.0 scripts/create-dmg.sh
hdiutil imageinfo dist/ReluxProxy-v0.1.0-universal.dmg
```

### 2.10 Artifact and identity inventory

| Artifact/identity | Current name/value | Producer/owner | Verification command |
|---|---|---|---|
| SwiftPM executable product | `ReluxProxy` | SwiftPM | `swift build --show-bin-path` |
| App bundle | `dist/ReluxProxy.app` | `build-app.sh` | `find dist/ReluxProxy.app -maxdepth 4 -print` |
| App executable | `ReluxProxy.app/Contents/MacOS/ReluxProxy` | SwiftPM copied by script | `file` and `lipo -info` |
| Icon | `ReluxProxy.app/Contents/Resources/ReluxProxy.icns` | `generate-icon.swift` | `file` |
| Bundle ID | `works.relux.proxy` | `Info.plist` | `codesign -dv --verbose=4` / `plutil -p` |
| Display/product name | `Relux Proxy` | `Info.plist` and UI | `plutil -p` / source inspection |
| DMG volume | `Relux Proxy` | `create-dmg.sh` | `hdiutil imageinfo` / mount read-only |
| Versioned DMG | `ReluxProxy-v<version>-universal.dmg` | `create-dmg.sh`, release workflow | `gh release view v0.1.0 --json assets` |
| Stable DMG | `ReluxProxy.dmg` | release workflow copy | same |
| Checksums | `SHA256SUMS` | release workflow | download and `shasum -a 256 -c SHA256SUMS` from its directory |
| Stable URL | `https://github.com/relux-works/relux-proxy/releases/latest/download/ReluxProxy.dmg` | GitHub Releases | authenticated `gh release view` while repository is private |
| Team ID | `262RZ595FP` | Developer ID certificate | `codesign -dv --verbose=4` |
| Signing identity | `Developer ID Application: Relux Works, LLC (262RZ595FP)` | release secret/certificate | `codesign -dv --verbose=4` |

### 2.11 Signing modes and release packaging

| Mode | App signature | DMG signature/notary | Intended path |
|---|---|---|---|
| Local/CI credential-free | ad-hoc, no team ID, no hardened-runtime flag when `SIGN_IDENTITY=-` | unsigned/unnotarized if DMG is built | development and PR CI |
| Local identity missing | warning, then ad-hoc fallback | downstream notarization would not establish a valid release | developer convenience; not release proof |
| Developer ID release | Developer ID, team `262RZ595FP`, hardened runtime, timestamp, no entitlements | Developer ID signed and timestamped, notarized with `notarytool`, stapled, Gatekeeper-validated | tag workflow |

The published app is universal arm64/x86_64 and its signature has runtime flag
`0x10000`. Its entitlements output is empty. The DMG itself is signed but does
not use hardened-runtime flags; the nested app does.

### 2.12 CI workflow (`.github/workflows/ci.yml`)

| Property | Current behavior | Verification command |
|---|---|---|
| Triggers | push to `main`; every pull request | `nl -ba .github/workflows/ci.yml` |
| Permissions | `contents: read` | same |
| Runner | `macos-15` | same |
| Checkout | `actions/checkout@v7` | same |
| Test gate | `swift test` | same / inspect GitHub run |
| Packaging gate | `SIGN_IDENTITY=- scripts/build-app.sh` | same / inspect GitHub run |

It does not build a DMG, notarize, inspect entitlements, run UI/live-SSH tests,
or publish artifacts. The universal app build is the packaging/architecture
compile check.

### 2.13 Release workflow (`.github/workflows/release.yml`)

| Stage | Exact current behavior | Verification command |
|---|---|---|
| Trigger | push of any `v*` tag | `nl -ba .github/workflows/release.yml` |
| Permissions | contents write, ID token write, attestations write | same |
| Concurrency | group `release-${{ github.ref }}`, never cancel in progress | same |
| Checkout | `actions/checkout@v7`, full history (`fetch-depth: 0`) | same |
| Certificate import | base64 `MACOS_CERT_P12` to temporary file; temporary keychain; P12 import password is empty; authorizes `/usr/bin/codesign` | same |
| App build | `VERSION=github.ref_name`; `BUILD_NUMBER=github.run_number`; exact Developer ID identity; universal default | same |
| DMG | `create-dmg.sh`, then Developer ID sign with timestamp | same |
| Notary auth | base64 `ASC_KEY_P8`, `ASC_KEY_ID`, `ASC_ISSUER_ID` | same |
| Notary checks | submit `--wait`, staple, staple validate, Gatekeeper `spctl` | same |
| Stable/checksum assets | copy versioned DMG to `ReluxProxy.dmg`; hash both into `SHA256SUMS` | same |
| Provenance | `actions/attest-build-provenance@v4` over `dist/ReluxProxy*.dmg` | same plus `gh attestation verify` |
| Publication | `softprops/action-gh-release@v3`, generated release notes, versioned DMG + stable DMG + checksums | same plus `gh release view` |

Required repository secrets: `MACOS_CERT_P12`, `ASC_KEY_ID`, `ASC_ISSUER_ID`,
and `ASC_KEY_P8`. The certificate and App Store Connect key are base64 encoded.
The workflow assumes the imported certificate has no P12 password because it
passes `-P ""`.

### 2.14 v0.1.0 release-history compatibility

The v0.1.0 release is public evidence inside the private repository:

- signed annotated tag `v0.1.0` -> commit `2557aba1c030d0643d76e0bc3b185f6d5fd172e1`;
- successful release run
  [29274001137](https://github.com/relux-works/relux-proxy/actions/runs/29274001137);
- non-draft, non-prerelease GitHub release published 2026-07-13 at 18:20:45Z;
- `ReluxProxy-v0.1.0-universal.dmg`, 1,775,722 bytes;
- `ReluxProxy.dmg`, byte-identical to the versioned asset;
- `SHA256SUMS`, 179 bytes;
- both DMGs hash to
  `5159c07c25f9c46df33462d256cab8a10eb79d677ad2e9b182e9e4188363c20d`;
- both release names are covered by the successful provenance step;
- downloaded versioned DMG has a stapled ticket and is accepted by Gatekeeper as
  “Notarized Developer ID” from Relux Works;
- mounted DMG contains `ReluxProxy.app` and the `/Applications` symlink; app plist
  is version `0.1.0` build `1`, minimum macOS `14.0`, universal arm64/x86_64,
  Developer ID signed with hardened runtime and no entitlements.

These historical bytes, names, tag, checksums, URLs, and attestations must never
be rewritten. A future stable `ReluxProxy.dmg` may be reassigned only by the
explicit release/migration decision with rollback and support ownership.

### 2.15 Documentation inventory and destination

| Document | Current ownership/content | M0 destination/obligation | Verification command |
|---|---|---|---|
| `README.md` | current/manual SOCKS use; defaults; authenticated stable download; development and release commands; explicit future-VPN boundary | Preserve manual-product instructions and release URL while legacy is supported; generated-VPN docs must not imply these steps configure a system VPN | `nl -ba README.md`; compare `git diff v0.1.0..HEAD -- README.md` |
| `SECURITY.md` | private vulnerability reporting; shipped SOCKS app is only implemented product; future-VPN security invariants | Keep supported-product statement accurate through coexistence/cutover; never claim planned VPN is shipped | `nl -ba SECURITY.md` |
| `CONTRIBUTING.md` | macOS/Xcode baseline; `make test`/`make app`; board/spec workflow; credential prohibitions | Retain the legacy commands as compatibility gates while adding generated-workspace guidance separately | `nl -ba CONTRIBUTING.md` |
| `LICENSE` | MIT, Relux Works 2026 | Preserve license/history with source | `nl -ba LICENSE` |
| `docs/current-state.md` | concise legacy/future boundary and missing-capability list | This detailed task artifact becomes the regression authority; keep the summary linked/consistent | `nl -ba docs/current-state.md` |
| `docs/project-management.md` | board/runtime setup and planning contract | Project operations documentation; not product runtime behavior | `nl -ba docs/project-management.md` |

## 3. Migration ownership and destination map

The generated target names below are planned in `.spec/platform-distribution.md`
and the target-dependency plan, but remain subject to the not-yet-approved
architecture ADR `TASK-260715-32umrc`. The mapping therefore separates the
binding preservation destination from provisional future consumers.

| Existing asset/behavior | M0 owner and destination | Explicit later owner/decision |
|---|---|---|
| `ReluxProxy` product, five source files, `Package.swift` | Preserve as a standalone legacy SwiftPM compatibility lane, with the same product/target identity and commands. `TASK-260715-14lk3y` owns coexistence with the generated workspace. Do not fold into `ReluxProxyMac` or `ReluxTunnelCore`. | `TASK-260715-35nc5m` may authorize coexistence, replacement, or retirement; implementation follows only afterward. |
| `ReluxProxyTests` and four XCTest cases | Stay attached to the legacy SwiftPM lane and run in credential-free CI. `TASK-260715-14lk3y` owns the regression gate. | `TASK-260715-32umrc` defines new-target test placement; it cannot silently reclassify or delete legacy tests. |
| `sshHost`, `sshAccount`, `localPort` in `works.relux.proxy` defaults | Remain owned by the legacy bundle. No implicit App Group, provider configuration, Keychain, or VPN-profile migration. | `TASK-260715-35nc5m` decides conversion/coexistence/deletion/rollback; downstream migration task implements approved behavior. |
| `/usr/bin/ssh` + `~/.ssh/config`/agent/keys/ProxyJump inheritance | Remains only in the unsandboxed legacy process boundary during M0. | `TASK-260715-35nc5m` decides user impact/support. The future provider transport is a separate architecture concern; compatibility may not be faked. |
| Manual loopback SOCKS endpoint and Firefox instructions | Remain legacy-product behavior/documentation. | Product migration decision owns whether it coexists, is replaced, or is retired and how users are told. |
| `Info.plist`, bundle ID `works.relux.proxy`, LSUIElement app identity | Preserve unchanged for legacy output; generated targets must use separately injected identifiers/plists and not overwrite it. `TASK-260715-14lk3y` owns the boundary. | `TASK-260715-32umrc` defines generated identities; `TASK-260715-35nc5m` defines legacy cutover identity behavior. |
| `Makefile`, app/DMG/icon scripts | Preserve their current entry points and relative outputs in the legacy lane. | `TASK-260715-14lk3y` may add coexistence wrappers/regression checks but is out of scope to rewrite behavior; retirement needs approval. |
| CI test/ad-hoc app path | Preserve as a named compatibility job/check after generated CI appears. | Continuous-integration tasks may harden actions/permissions, but removal needs the legacy decision. |
| Developer ID/notary release workflow | Continue as the legacy release path until a separately approved cutover. Preserve team/signature/notary evidence. | macOS release architecture tasks own future nested extension signing; `TASK-260715-35nc5m` and release-contract task own stable-channel takeover/rollback. |
| v0.1.0 tag/release/assets/checksums/attestation | Immutable release history in `relux-works/relux-proxy`; use as regression evidence, never regenerate or overwrite. | Later release decision owns support horizon and stable “latest” routing, not historical bytes. |
| README/security/contributing/current-state docs | Preserve accurate legacy instructions/status alongside new-product docs. | Product/support/release owners update cutover/EOL language only after the explicit decision. |

## 4. Migration invariants

### 4.1 Must preserve through M0

- [ ] A clean checkout can still run `swift test` and `swift build` for the
  `ReluxProxy` package without generating the Xcode workspace.
- [ ] `Package.swift` still exposes exactly the legacy executable
  `ReluxProxy` and test target `ReluxProxyTests` with macOS 14 / Swift 5 mode.
- [ ] All five legacy source areas and four existing tests remain owned and
  reachable by the legacy package.
- [ ] `make test`, `make build`, `make app`, `make dmg`, `make run`, and
  `make clean` retain their documented entry-point meanings.
- [ ] The app bundle remains `ReluxProxy.app`, executable `ReluxProxy`, display
  name `Relux Proxy`, bundle ID `works.relux.proxy`, LSUIElement menu-bar app,
  and minimum macOS 14.
- [ ] `sshHost=relux`, `sshAccount=administrator`, and `localPort=1080` remain
  absence defaults under the legacy application domain; validation/normalization
  stays unchanged.
- [ ] System SSH path, exact argument order/options, loopback-only endpoint,
  config/agent/ProxyJump inheritance, BatchMode behavior, and manual SOCKS setup
  remain reproducible.
- [ ] Status, editing, error, connect/disconnect, timeout, shutdown, and Quit
  behavior remain the legacy user-visible baseline.
- [ ] Credential-free packaging remains ad-hoc and universal by default; release
  packaging remains Developer ID hardened-runtime, timestamped, notarized,
  stapled, Gatekeeper-valid, and universal.
- [ ] Versioned `ReluxProxy-v<version>-universal.dmg`, stable `ReluxProxy.dmg`,
  `SHA256SUMS`, volume layout, GitHub release URL, and provenance publication
  remain reproducible for the legacy channel.
- [ ] v0.1.0 tag, release assets, hashes, attestations, and URLs remain immutable.
- [ ] Documentation continues to distinguish the shipped manual SOCKS app from
  the unimplemented system-VPN architecture.

### 4.2 Requires a later explicit retirement/migration decision

The following must not happen as an incidental workspace-generation change:

- renaming, removing, or merging the `ReluxProxy` SwiftPM product or tests;
- changing macOS 14 or universal arm64/x86_64 legacy support;
- changing the bundle ID, product/display name, storage domain, or default keys;
- importing defaults into a new profile/App Group/Keychain, deleting them, or
  interpreting arbitrary OpenSSH configuration;
- replacing `/usr/bin/ssh`, losing `~/.ssh/config`/ProxyJump/agent/key behavior,
  changing host-trust behavior, or keeping only a misleading subset;
- hiding/removing the manual SOCKS endpoint or changing the Firefox/DNS guidance;
- sandboxing the legacy app or adding entitlements that change its child process;
- redirecting `ReluxProxy.dmg` to a different product or repository;
- ending Developer ID/notary support, removing checksums/provenance, or dropping
  the existing support/download documentation;
- deleting legacy release assets, tags, workflows, scripts, or history.

The deciding artifact must state coexistence namespace, migration version,
unrepresentable input behavior, user consent/message, idempotency, rollback and
downgrade, data retention/deletion, release-channel ownership, and support
horizon.

## 5. Unsandboxed system SSH versus future sandbox/entitlement targets

| Boundary | Current evidence | Conflict/invariant |
|---|---|---|
| App Sandbox | Published app has no entitlements; current README explicitly says it is intentionally unsandboxed | Enabling `com.apple.security.app-sandbox` is a behavior change, not packaging cleanup. It requires a separate decision and regression proof. |
| Child process rights | Apple documents that a helper launched by `Process`/fork+exec inherits the launching app's sandbox capabilities | A sandboxed `/usr/bin/ssh` child does not recover the unsandboxed user's rights merely because it is a system binary. |
| User home/SSH files | Apple documents that a sandboxed app lacks unrestricted access to the user's home folder | `~/.ssh/config`, known_hosts, private-key paths, control sockets, and related includes cannot be assumed available. Do not add hidden temporary exceptions or broad file grants to imitate current behavior. |
| Network access | Apple requires `com.apple.security.network.client` for outgoing connections from a sandboxed app | A future sandboxed host needs declared capabilities; the current no-entitlement signature cannot be copied as proof that it will work. |
| Provider architecture | Apple defines a packet tunnel provider as an app extension that owns the tunnel connection and receives packets; it requires the Network Extensions entitlement | The legacy host-launched dynamic SOCKS child is not a packet-tunnel provider implementation. It cannot satisfy iOS, and it must not be smuggled into a provider as a compatibility shortcut. |
| Deployment/signing | Planned macOS/iOS containing apps embed provider targets with App IDs, profiles, App Groups/Keychain boundaries, and Network Extension entitlements | Generated plist/entitlement/signing inputs must be separate from the legacy plist/signing script. Future nested signing is inside-out; legacy script signs one outer app with no nested code. |
| State ownership | Legacy host process owns live state; future architecture says provider owns live state and host only manages configuration | `TunnelController` is not a reusable provider state machine. Keeping it as legacy is compatible; silently making it authoritative for a provider is not. |

This inventory does not select an SSH engine, new UX, entitlement workaround, or
migration policy. Clean options are evaluated later; no compatibility claim may
be made until the selected target passes its real sandbox/provider environment.

Primary Apple sources:

- [Protecting user data with App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)
- [Discovering and diagnosing App Sandbox violations](https://developer.apple.com/documentation/security/discovering-and-diagnosing-app-sandbox-violations)
- [`com.apple.security.network.client`](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.network.client)
- [Packet tunnel provider](https://developer.apple.com/documentation/networkextension/packet-tunnel-provider)
- [Network Extensions entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.networkextension)
- [`NEPacketTunnelProvider`](https://developer.apple.com/documentation/networkextension/nepackettunnelprovider)
- [TN3134: Network Extension provider deployment](https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment)

## 6. Reviewer regression checklist

Run destructive build/clean commands only in a disposable clone. The following
creates one without modifying the legacy checkout:

```sh
audit_checkout="$(mktemp -d /tmp/relux-legacy-review.XXXXXX)"
git clone --no-hardlinks /Users/iv/Developer/relux-proxy "$audit_checkout"
git -C "$audit_checkout" checkout --detach v0.1.0
cd "$audit_checkout"
```

### Provenance and inventory

- [ ] `git tag -v v0.1.0` verifies the signed annotated tag and resolves to
  `2557aba1c030d0643d76e0bc3b185f6d5fd172e1`.
- [ ] `swift package dump-package` shows one executable product/target and one
  test target, macOS 14, Swift tools 5.10/language 5, no dependencies.
- [ ] `find Sources Tests Resources scripts .github/workflows -type f | sort`
  contains every path named in this inventory and no unknown shipped source
  area is left unclassified.

### Build and tests

- [ ] `make test` passes all four XCTest cases.
- [ ] `make build` succeeds.
- [ ] `VERSION=v0.1.0 BUILD_NUMBER=1 SIGN_IDENTITY=- make app` succeeds.
- [ ] `lipo -info dist/ReluxProxy.app/Contents/MacOS/ReluxProxy` reports arm64
  and x86_64.
- [ ] `codesign --verify --deep --strict --verbose=2 dist/ReluxProxy.app`
  succeeds, and `codesign -dv --verbose=4` reports ad-hoc for this credential-free
  build.
- [ ] `plutil -p dist/ReluxProxy.app/Contents/Info.plist` matches the bundle table
  and shows version 0.1.0/build 1 for the explicit command above.

### Source/default/behavior contract

- [ ] `swift test --filter TunnelConfigurationTests` passes target rendering,
  validation, endpoint, and exact SSH argument assertions.
- [ ] `rg -n '@AppStorage' Sources/ReluxProxy/MenuContentView.swift` finds only
  `sshHost`, `sshAccount`, `localPort` with defaults `relux`, `administrator`,
  and `1080`.
- [ ] `rg -n '/usr/bin/ssh|ExitOnForwardFailure|ServerAlive|ConnectTimeout|BatchMode|LogLevel' Sources Tests`
  matches the exact SSH contract above.
- [ ] `rg -n 'Firefox|SOCKS v5|proxy DNS' README.md Sources/ReluxProxy` retains the
  explicit manual-client contract.
- [ ] Source/manual inspection confirms the complete state, editing,
  failure-message, readiness, stop-escalation, shutdown, accessibility, and Quit
  behavior in sections 2.6–2.7.
- [ ] No generated target, App Group, Keychain store, or migration code reads or
  deletes the legacy defaults without the approved migration decision.

### DMG and bundle layout

- [ ] `VERSION=v0.1.0 BUILD_NUMBER=1 SIGN_IDENTITY=- make dmg` creates
  `dist/ReluxProxy-v0.1.0-universal.dmg`.
- [ ] `hdiutil imageinfo` reports `UDZO` and volume `Relux Proxy`.
- [ ] A read-only mount contains only the expected `ReluxProxy.app` plus
  `/Applications` symlink at the volume root (filesystem metadata aside).
- [ ] Generated-workspace files have not overwritten legacy `Info.plist`, app
  path, icon path, bundle ID, or artifact names.

### CI and release path

- [ ] CI still has a credential-free `swift test` gate and ad-hoc universal
  legacy app build on pushes/PRs.
- [ ] Release still uses the exact Developer ID identity/team, hardened runtime,
  timestamp, DMG signing, notary wait, staple validation, Gatekeeper, checksums,
  provenance, versioned asset, and stable asset.
- [ ] `gh run view 29274001137 --repo relux-works/relux-proxy` shows every v0.1.0
  release step succeeded.
- [ ] `gh release view v0.1.0 --repo relux-works/relux-proxy --json assets` shows
  the three immutable assets and expected sizes/digests.
- [ ] After downloading to a temporary directory, `shasum -a 256` matches the
  published `SHA256SUMS` and the digest recorded in section 2.14.
- [ ] `xcrun stapler validate` and
  `spctl -a -t open --context context:primary-signature -vv` accept the downloaded
  versioned DMG.
- [ ] `gh attestation verify <downloaded-dmg> --repo relux-works/relux-proxy`
  succeeds.
- [ ] Existing tag/release URLs and bytes remain unchanged, and any future stable
  asset routing has an explicit approved owner/rollback decision.

### Documentation and ownership

- [ ] README still labels the current app as manual SOCKS, documents exact
  defaults and stable download, and does not claim the VPN is implemented.
- [ ] SECURITY still distinguishes the shipped app from planned architecture.
- [ ] CONTRIBUTING still includes legacy build/test gates.
- [ ] The architecture ADR and generated target tasks cite this inventory and
  preserve the ownership/destination map in section 3.
- [ ] Any proposed retirement checks off every item in section 4.2 through a
  named decision rather than by file deletion or CI drift.

Cleanup of the disposable clone:

```sh
cd /Users/iv/Developer/relux-tunnel
rm -rf -- "$audit_checkout"
```

### Signing-required release reproduction

The release build cannot be fully reproduced without authorized certificate and
notary secrets. On an authorized release runner, the expected commands are the
steps in `.github/workflows/release.yml`; evidence must include:

```sh
codesign -dv --verbose=4 dist/ReluxProxy.app
codesign --verify --deep --strict --verbose=2 dist/ReluxProxy.app
codesign -d --entitlements - dist/ReluxProxy.app
codesign -dv --verbose=4 dist/ReluxProxy-v<version>-universal.dmg
xcrun stapler validate dist/ReluxProxy-v<version>-universal.dmg
spctl -a -t open --context context:primary-signature -vv \
  dist/ReluxProxy-v<version>-universal.dmg
shasum -a 256 -c dist/SHA256SUMS
```

Expected: app authority is Relux Works Developer ID, team `262RZ595FP`, hardened
runtime present, entitlements empty; DMG Developer ID valid, ticket stapled,
Gatekeeper accepted, checksums match.

## 7. Fact-check results and anomalies

### Verified results

- Temporary detached v0.1.0 clone: `swift test` passed 4/4; `swift build` passed;
  ad-hoc universal app and DMG packaging passed on Xcode 26.5 / Swift 6.3.2.
- Built app: correct plist, arm64+x86_64, valid ad-hoc signature.
- GitHub release run 29274001137: all steps, including notary, provenance, and
  publication, report success.
- Downloaded v0.1.0 release: asset sizes and SHA-256 match GitHub and
  `SHA256SUMS`; DMG Developer ID signature valid; stapler validation and
  Gatekeeper acceptance passed; mounted app is universal, hardened-runtime,
  correctly versioned, and has no entitlements.
- `gh attestation verify` returned success for the downloaded versioned DMG.

### Important anomalies/regression risks

1. `dist/` is ignored by Git and is not authoritative. The current local
   `/Users/iv/Developer/relux-proxy/dist/ReluxProxy-v0.1.0-universal.dmg` is
   1,748,814 bytes with SHA-256
   `97ef23323c7f4d8f11c3e00ee50f69c76f3ccb36e0fa4c48c4495ee059523ae0`.
   It is Developer ID signed but has no stapled ticket and Gatekeeper rejects it
   as “Unnotarized Developer ID.” It differs from the published release asset.
2. `build-app.sh` falls back to ad-hoc signing when the requested identity is
   missing. The app-build step can therefore succeed without release signing;
   the downstream notary/Gatekeeper chain is the actual release fail-closed
   evidence.
3. `create-dmg.sh` always includes `-universal` in the filename even if
   `UNIVERSAL` disables the two-architecture build. Consumers must verify the
   binary slices, not infer them only from the name.
4. `BUILD_NUMBER` differs by path: local default is Git commit count, release is
   GitHub `run_number`. Preserve the release workflow's version evidence rather
   than assuming local reproduction yields the same build number.
5. Current automated tests do not exercise live process/UI/storage/signing
   semantics. The regression checklist retains source, packaging, release, and
   controlled manual checks so generated-workspace success cannot hide legacy
   regressions.

## 8. Recommendation

Treat this document as the binding M0 regression baseline. The generated
workspace should add a parallel target graph while `TASK-260715-14lk3y` keeps the
legacy SwiftPM lane green. The architecture ADR should reference, not reinterpret,
the ownership map. Only `TASK-260715-35nc5m` with accountable product,
architecture, support, and release approval may change the legacy disposition.

## 9. Source references

Repository evidence is from `/Users/iv/Developer/relux-proxy` at signed tag
`v0.1.0` and current HEAD `7e6f25b`:

- `Package.swift:1-24`
- `Sources/ReluxProxy/ReluxProxyApp.swift:1-24`
- `Sources/ReluxProxy/MenuContentView.swift:1-145`
- `Sources/ReluxProxy/TunnelConfiguration.swift:1-42`
- `Sources/ReluxProxy/SSHCommandBuilder.swift:1-35`
- `Sources/ReluxProxy/TunnelController.swift:1-240`
- `Tests/ReluxProxyTests/TunnelConfigurationTests.swift:1-49`
- `Resources/Info.plist:1-34`
- `Makefile:1-19`
- `scripts/build-app.sh:1-41`
- `scripts/create-dmg.sh:1-21`
- `scripts/generate-icon.swift:1-117`
- `.github/workflows/ci.yml:1-21`
- `.github/workflows/release.yml:1-86`
- `README.md:1-60`, `SECURITY.md:1-32`, `CONTRIBUTING.md:1-44`,
  `docs/current-state.md:1-58`
- [GitHub v0.1.0 release](https://github.com/relux-works/relux-proxy/releases/tag/v0.1.0)
- [GitHub release run 29274001137](https://github.com/relux-works/relux-proxy/actions/runs/29274001137)

Destination ownership evidence:

- `.spec/platform-distribution.md:3-22,53-61,90-111`
- `.spec/architecture.md:25-66,105-110`
- `diagrams/TASK-260715-32umrc_target-dependency-plan.dot:11-31`
- `docs/current-state.md:43-58`
- Board tasks `TASK-260715-14lk3y`, `TASK-260715-32umrc`, and
  `TASK-260715-35nc5m`.
