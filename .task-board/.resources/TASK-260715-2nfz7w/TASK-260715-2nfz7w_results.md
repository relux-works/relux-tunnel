# TASK-260715-2nfz7w implementation evidence

Date: 2026-07-20

## Delivered boundary

- Added a SwiftPM package with `ReluxTunnelCore`,
  `ReluxTunnelIOSAdapter`, and `ReluxTunnelMacOSAdapter` library products at the
  accepted iOS 18.0 / macOS 15.0 deployment floors.
- Added platform-neutral endpoint, opaque configuration reference, packet flow,
  packet bridge, SSH transport/channel/upload, internal SOCKS, lifecycle,
  version message, metrics, clock, privacy-labelled logging, cancellation, and
  memory-pressure contracts.
- Kept numeric packet, channel, upload, and SOCKS limits caller-supplied. No MTU,
  lane, window, session-count, engine, route, DNS, relay, or UI policy was chosen.
- Added shared generation-safe provider lifecycle/version routing and two thin
  composition roots. Only the named adapter modules import NetworkExtension.
- Added public `NEPacketTunnelFlow` adapters plus protocol-based root
  initializers so the same contracts run under SwiftPM without a generated
  workspace or provider subclass.
- Added DocC/module boundary mapping and `docs/core-adapter-boundaries.md` with
  explicit specification/ADR ownership and deferred semantics.
- Added `scripts/check-core-boundaries.sh` and Makefile entry points to enforce
  the import/dependency direction.

## Verification

| Command | Result |
| --- | --- |
| `make validate-core` | Passed: boundary guard, SwiftPM build, and 4 Swift Testing adapter contract tests |
| `swift build --target ReluxTunnelCore` | Passed independently |
| `swift format lint --recursive Sources Tests Package.swift` | Passed with no diagnostics |
| `shellcheck scripts/check-core-boundaries.sh` | Passed with no diagnostics |
| `xcodebuild -scheme ReluxTunnelIOSAdapter -destination 'generic/platform=iOS' -derivedDataPath .temp/TASK-260715-2nfz7w/ios-derived-data CODE_SIGNING_ALLOWED=NO build` | `BUILD SUCCEEDED` with Xcode 26.5, targeting arm64 iOS 18.0 |
| `git diff --check` | Passed |

The Swift Testing suite proves both composition roots inject the same packet
flow/configuration into the shared runtime, transition through the same
start/stop phases, preserve the platform stop reason, return byte-identical
version responses, and reject unsupported protocol versions identically.

## Evidence files

- `.temp/TASK-260715-2nfz7w/core-validation-01.log`
- `.temp/TASK-260715-2nfz7w/core-only-build-02.log`
- `.temp/TASK-260715-2nfz7w/swift-format-lint-01.log`
- `.temp/TASK-260715-2nfz7w/ios-adapter-build-01.log`

No generated Xcode workspace, signed extension, concrete
`NEPacketTunnelProvider` subclass, or physical-device test was run. Those are
explicitly gated/later tasks and are not required for this SwiftPM boundary.
