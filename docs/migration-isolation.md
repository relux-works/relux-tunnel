# Legacy-to-generated migration isolation

This repository integrates the generated M1 tunnel runtime without replacing
or migrating the legacy `relux-works/relux-proxy` SwiftPM application. The
accepted M0 preservation baseline is `TASK-260715-14lk3y`; its frozen source is
the signed `v0.1.0` tag at
`2557aba1c030d0643d76e0bc3b185f6d5fd172e1`.

## Product boundary

| Surface | Legacy lane — unchanged | Generated M1 lane | Isolation rule |
| --- | --- | --- | --- |
| Repository | `relux-works/relux-proxy` | `relux-works/relux-tunnel` | Separate Git roots; the generated repository does not recreate legacy-owned paths. |
| Package/product | SwiftPM `ReluxProxy` executable | SwiftPM `ReluxTunnel` libraries and `ReluxTunnelHarness`; Tuist `ReluxProxyMac` host | The legacy package imports no `ReluxTunnelCore`, adapter, HEV, or native product. The generated package defines no exact `ReluxProxy` product or target. |
| Tests | `ReluxProxyTests` | Generated host/provider and package test targets | No shared target or test product identity. |
| Application | `dist/ReluxProxy.app` | `ReluxProxyMac.app` | Build roots and executable names are distinct. |
| Provider | None | `works.relux.tunnel.mac.tunnel.systemextension` | The provider exists only in the generated application bundle. |
| Bundle identifiers | `works.relux.proxy` | Host `works.relux.tunnel.mac`; provider `works.relux.tunnel.mac.tunnel` | Exact identifiers must remain unequal. |
| Launch behavior | SwiftUI `MenuBarExtra`, macOS 14 | Accessory `NSApplication` host plus NetworkExtension system-extension mode, macOS 15 | Generated launch code neither opens the legacy bundle nor installs a legacy LaunchAgent. The generated host's installer-launcher service remains under its distinct bundle identity. |
| Defaults | Standard bundle domain `works.relux.proxy`; `sshHost=relux`, `sshAccount=administrator`, `localPort=1080` | Standard bundle domain `works.relux.tunnel.mac`; no reuse of the three legacy keys | No implicit defaults import or write-through. |
| Keychain | No v0.1.0 product Keychain namespace | Read-only system-domain service `works.relux.tunnel.credential.v1`; deferred iOS group `$(AppIdentifierPrefix)works.relux.tunnel.shared` | No generated lookup uses the legacy defaults domain or a legacy-owned service. |
| Launch agents | None in the v0.1.0 product/release baseline | None owned by M1 | Runner or updater operations may not substitute a legacy label or path. |
| Release entry points | `make app`, `make dmg`, `scripts/build-app.sh`, `scripts/create-dmg.sh`, legacy release workflow | Credential-free generated build/validation only; no application release path is claimed by M1 | Generated scripts and workflows must not create `ReluxProxy.dmg`, `ReluxProxy-v*`, or `dist/ReluxProxy.app`. |
| Stable artifacts | `ReluxProxy-v<version>-universal.dmg`, `ReluxProxy.dmg` | No generated stable application artifact in M1 | The legacy names remain exclusively owned by the legacy release lane. |

The complete legacy product-bearing byte inventory remains pinned by
`config/legacy-v0.1.0.sha256` and is verified by
`scripts/check-legacy-preservation.sh`. The complementary
`scripts/check-migration-isolation.py` command verifies the cross-repository
dependency, identity, storage, launch, release, generated-project, and optional
built-product boundary.

## Automated gates

Run the source and release boundary plus its adversarial checks against a
detached v0.1.0 checkout:

```sh
make check-migration-isolation LEGACY_ROOT=/path/to/legacy-v0.1.0
make test-migration-isolation LEGACY_ROOT=/path/to/legacy-v0.1.0
```

`scripts/validate-credential-free.sh` is the production integration call site.
It runs the accepted legacy preservation guard, the migration-isolation CLI,
and the negative suite after generated host/provider validation. The negative
suite drives that same CLI and narrows the boundary with generated and legacy
cross-links, bundle/defaults/Keychain collisions, built-product collisions,
and release-script substitution. Each mutation must be refused for its named
reason.

When `--generated-project` and `--products-root` are supplied, the gate also
checks the generated PBX target/product inventory and both Debug and Release
host/provider bundles. An exact legacy target, app, executable, or DMG name in
those products is a failure.

## Deferred ownership

This task does not migrate users or data, delete legacy code, change either
release path, reconcile UI, ship both products, or decide retirement timing.

- M4 `TASK-260715-35nc5m` owns the coexistence, replacement, or retirement
  decision and any user-facing/import behavior.
- M5 `TASK-260715-1tzaed` owns the macOS release identity, entitlement, and data
  migration contract after the M4 decision.

Until both decisions are accepted, the only valid behavior is independent
coexistence with zero implicit migration.
