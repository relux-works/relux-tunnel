# TASK-260715-1r0fxv results

Status: ready for review.

## Delivered

Created an explicitly disposable macOS 14 arm64 XcodeGen project under `Probes/macOSPacketTunnelProbe`. It is separate from the shipped SwiftPM products and contains host `works.relux.tunnel.probe.mac` plus exactly one embedded packet-tunnel provider `works.relux.tunnel.probe.mac.tunnel`.

The host implements `NETunnelProviderManager` load, save, reload, enable, start, status polling, versioned provider messaging, and stop. The provider exposes a strict v1 JSON response, logs privacy-safe lifecycle transitions, installs no network settings, never accesses `packetFlow`, forwards no packets, and owns no worker task that could leak at stop. Four Swift Testing cases cover the exact v1 request/response, no-forwarding response, protocol-version drift rejection, and bounded-message rejection.

Clean build, install, exercise, cleanup, expected-output, and signing-input instructions are in `Probes/macOSPacketTunnelProbe/README.md`. They record Xcode 26.5 build 17F42, macOS SDK 26.5, XcodeGen 2.44.1, source revision/state, team and profile UUIDs, bundle identifiers, capability, architecture, and artifact paths without secret material.

## Signed build and inspection evidence

The approved Aqua Terminal execution seam ran `Probes/macOSPacketTunnelProbe/Scripts/build-and-inspect.sh` end to end after the final logging change. Exit code: 0.

- Profile-scoped signing preflight passed for both approved development profiles.
- Xcode test and archive both succeeded.
- Host and provider signatures verify and use Apple Development under team `262RZ595FP`.
- Signed application identifiers are exactly `262RZ595FP.works.relux.tunnel.probe.mac` and `262RZ595FP.works.relux.tunnel.probe.mac.tunnel`.
- Embedded profile UUIDs are exactly `c0a3cd4e-77c8-475e-98e0-6deec8269810` and `ef64bcae-00ac-458f-94dc-45834429fe80`.
- Both signed targets contain exactly the unsuffixed `packet-tunnel-provider` capability, with no extra Network Extension capability, App Groups, or Keychain Sharing entitlement.
- Host and provider are arm64; the host embeds exactly one expected provider and no unexpected nested code.
- Negative mutations for identifier, capability, profile, nesting, and signature drift were all rejected.

Full privacy-filtered command evidence is attached as `TASK-260715-1r0fxv_build-and-inspect.log`. The log-redaction regression test covers Xcode's `--sign`, `-signing-cert`, and Signing Identity output. The retained log was scanned after the final run and contains no unredacted 40-character certificate fingerprint.

## Additional validation

- Deterministic XcodeGen regeneration: exit 0; generated `project.pbxproj` SHA-256 unchanged.
- Plist lint, shell syntax, strict Swift format, and `git diff --check`: exit 0.
- Probe Xcode test target: exit 0; 4 tests passed.
- Fresh unsigned arm64 host/provider build: exit 0.
- Signed archive inspection: exit 0.
- Five inspector drift tests: exit 0.
- Log-redaction regression test and retained-log privacy scan: exit 0.
- Existing repository `swift test`: exit 0; 378 tests in 31 suites passed.
- `Package.swift`, `Sources/`, existing `Tests/`, root `scripts/`, `Makefile`, and release workflows have no task changes.

## Scope note

This handoff does not claim a user-approved installed VPN run or mutate System Settings. The signed product is ready for the documented install/exercise flow. The implementation and contract tests establish the versioned response and no-forwarding behavior; provider stop has no asynchronous work to drain.
