# Disposable macOS Packet-Tunnel Probe

This project is an explicitly disposable Gate P0 development probe. It is
separate from the repository's SwiftPM products and from the future generated
production workspace. The provider never reads `packetFlow`, installs network
settings, adds routes, forwards packets, or starts background work.

## Approved signing inputs

| Input | Approved value |
| --- | --- |
| Development team | `262RZ595FP` |
| Host identifier | `works.relux.tunnel.probe.mac` |
| Host profile UUID | `c0a3cd4e-77c8-475e-98e0-6deec8269810` |
| Provider identifier | `works.relux.tunnel.probe.mac.tunnel` |
| Provider profile UUID | `ef64bcae-00ac-458f-94dc-45834429fe80` |
| Target entitlement | `packet-tunnel-provider` |
| Architecture | `arm64` |

The checked-in configuration requests the generic `Apple Development`
identity class. Xcode selects a locally available certificate authorized by the
two named device-bound development profiles. No certificate fingerprint,
private key, account value, or device identifier is recorded.

## Clean build and inspection

The recorded baseline is Xcode 26.5 (`17F42`), macOS SDK 26.5, and XcodeGen
2.44.1. From the repository root:

```bash
Probes/macOSPacketTunnelProbe/Scripts/build-and-inspect.sh
```

The script regenerates `ReluxPacketTunnelProbe.xcodeproj`, lints plists, shell,
and Swift, runs the standalone Swift Testing bundle, verifies that an installed
Apple Development private key is accessible, archives the signed arm64
host/provider pair, verifies signatures and nested code, decodes both embedded
profiles, checks exact target entitlements, and runs negative drift tests. It
records Xcode, SDK, Git revision/state, non-secret signing inputs, expected
paths, and real command output under:

```text
.temp/TASK-260715-1r0fxv/build-metadata.txt
.temp/TASK-260715-1r0fxv/build-and-inspect.log
.temp/TASK-260715-1r0fxv/ReluxPacketTunnelProbe.xcarchive
```

## Install and exercise

Quit and remove any older copy, then install the inspected archive product:

```bash
sudo ditto \
  .temp/TASK-260715-1r0fxv/ReluxPacketTunnelProbe.xcarchive/Products/Applications/ReluxPacketTunnelProbe.app \
  /Applications/ReluxPacketTunnelProbe.app
open /Applications/ReluxPacketTunnelProbe.app
```

Select **Run Probe** and approve the development VPN configuration if macOS
asks. The expected lifecycle is configuration reload, `connecting`,
`connected`, validated response `v1, running, packetForwarding=false`,
`disconnecting`, and `disconnected`. **Stop** cancels an in-flight host task and
requests provider stop. Launching with `--args --run-probe` starts the same path
automatically.

If the signing preflight reports that installed identities cannot sign, unlock
the login Keychain or grant `codesign` access to the Apple Development private
key in Keychain Access, then rerun the same build command. Do not export or
attach the private key, certificate fingerprint, Keychain password, or raw
profile.

After the experiment, stop the tunnel, quit the app, delete the probe VPN
configuration in System Settings, and remove
`/Applications/ReluxPacketTunnelProbe.app`. This project is not configured for
Developer ID distribution or notarization.
