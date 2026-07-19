# Legacy ReluxProxy preservation contract

This contract freezes the shipped ReluxProxy v0.1.0 SwiftPM application as an
independent macOS 14 compatibility lane. The generated Tuist workspace in this
repository must coexist with it; it does not absorb, rename, migrate, or retire
it.

The only authority to change this boundary is a separately approved legacy
coexistence, replacement, or retirement decision. At the time this contract was
recorded, that decision belonged to `TASK-260715-35nc5m`. Updating the guard or
its baseline without such a record is a stop-the-line violation.

## Identity invariants

| Surface | Preserved value |
| --- | --- |
| Source lineage | Signed annotated tag `v0.1.0`, commit `2557aba1c030d0643d76e0bc3b185f6d5fd172e1` |
| SwiftPM package/product | `ReluxProxy` executable and `ReluxProxyTests` test target |
| Deployment target | macOS 14.0; Swift tools 5.10 and Swift language mode 5 |
| Bundle | `dist/ReluxProxy.app`; identifier `works.relux.proxy`; executable `ReluxProxy`; menu-bar-only `LSUIElement=true` |
| Persisted defaults | `sshHost=relux`, `sshAccount=administrator`, `localPort=1080` in the bundle's standard defaults domain |
| SSH behavior | `/usr/bin/ssh` and the exact command-construction assertion in `testSSHArgumentsMatchHardenedTunnelSetup` |
| Universal build | arm64 and x86_64 by default through `scripts/build-app.sh` |
| Signing identity | `Developer ID Application: Relux Works, LLC (262RZ595FP)` |
| Packaging | `make app`, `make dmg`, versioned `ReluxProxy-v<version>-universal.dmg` |
| Stable release artifact | `ReluxProxy.dmg` plus checksums and the v0.1.0 release lineage |

The byte manifest at `config/legacy-v0.1.0.sha256` pins every product-bearing
source, test, manifest, bundle, script, and workflow file at the shipped tag.
This is deliberately stricter than checking names alone: it turns any source or
release-path drift into a visible review decision.

## Ownership boundary

The legacy source remains in the separate `relux-works/relux-proxy` repository.
This repository reserves the following exact paths for that legacy lane and
must not recreate them when the Tuist workspace is generated:

- `Sources/ReluxProxy`
- `Tests/ReluxProxyTests`
- `Resources/Info.plist`
- `scripts/build-app.sh`
- `scripts/create-dmg.sh`

New targets use their approved `ReluxProxyMac`, `ReluxProxyMacTunnel`,
`ReluxProxyIOS`, and `ReluxProxyIOSTunnel` identities and target-owned plist and
release paths. Sharing the stable public artifact name later does not authorize
overwriting the legacy source, bundle identifier, defaults domain, or v0.1.0
release history.

## Runnable regression check

From this repository, with a local read-only legacy checkout or detached clone:

```sh
make check-legacy LEGACY_ROOT=/path/to/relux-proxy
make test-legacy-guard LEGACY_ROOT=/path/to/relux-proxy
```

The first command validates the signed tag lineage, all pinned files, semantic
identity values, existing SwiftPM/Makefile/packaging entry points, and collisions
with future generated-workspace paths. The second creates disposable copies and
proves the check rejects product-file removal, bundle/default/SSH/test/artifact
migration, and a generated-workspace path collision. Neither command modifies
the supplied legacy checkout.

## Before-state evidence (2026-07-20)

The baseline was read from the local legacy repository and independently
verified from a detached local clone of `v0.1.0`; the original legacy checkout
was not modified.

| Check | Observed before state |
| --- | --- |
| Tag | Annotated, SSH-signed `v0.1.0` resolves to `2557aba1c030d0643d76e0bc3b185f6d5fd172e1` |
| Product files | All entries match `config/legacy-v0.1.0.sha256` |
| Tests | `swift test`: four XCTest cases, zero failures |
| Debug build | `swift build`: succeeds |
| App packaging | `SIGN_IDENTITY=- make app`: succeeds with an ad-hoc signature and a universal arm64/x86_64 executable |
| DMG packaging | `VERSION=v0.1.0 make dmg`: succeeds and creates `dist/ReluxProxy-v0.1.0-universal.dmg` |
| Bundle identity | `works.relux.proxy`, `ReluxProxy`, version `0.1.0`, minimum macOS `14.0`, `LSUIElement=true` |
| Stable published artifact | `ReluxProxy.dmg`; v0.1.0 published digest `5159c07c25f9c46df33462d256cab8a10eb79d677ad2e9b182e9e4188363c20d` |

Credentialed signing, notarization, stapling, and publication are not re-run by
this credential-free guard. Their workflow definitions and Developer ID
identity are pinned, while the published v0.1.0 artifact remains the
authoritative signed/notarized binary evidence.
