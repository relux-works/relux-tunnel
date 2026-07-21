# TASK-260715-1rsqrh — reviewer verdict

## Verdict

Changes requested. Route to `to-dev` for bounded implementation and test rework.

## Blocking finding

The production iOS and macOS host-session adapters do not translate synchronous `NETunnelProviderSession.startTunnel(options:)` errors into the stable error model required by the accepted lifecycle contract.

- `Sources/ReluxTunnelIOSAdapter/IOSVPNManagerPreferences.swift:155-157` and `Sources/ReluxTunnelMacOSAdapter/MacOSVPNManagerPreferences.swift:156-158` forward the public NetworkExtension throw unchanged.
- Both files already contain an `NSError` -> `VPNPreferencePlatformError` translator at lines 371-389 / 372-390, but the start path does not use it.
- `Sources/ReluxTunnelCore/VPNSessionController.swift:724-737` maps only `VPNPreferencePlatformError` and `VPNPlatformError`. Any raw `NSError` falls into the final catch, which discards the Apple domain/code and returns `platformRejected(domain: reflected Swift error type, code: 0)`.
- The accepted lifecycle contract, section 7 line 385, requires synchronous start rejection to map known `NEVPNError` results and otherwise preserve `platformRejected(domain, code)`.
- `Tests/ReluxTunnelCoreTests/VPNSessionControllerTests.swift:81-113` injects a pre-normalized `VPNPreferencePlatformError`, so it proves only the core mapper and cannot detect the broken production boundary.

This affects both platform adapters and violates the synchronous-error portion of AC 1 / the authoritative accepted input. It is ordinary rework, not a stop-the-line blocker.

## Required rework

1. Normalize thrown NetworkExtension start errors at both thin adapter boundaries, or through one shared injectable translator, before they reach `VPNSessionController`.
2. Preserve the real domain/code for unknown synchronous errors; do not collapse them to reflected type plus code 0.
3. Add adapter-boundary tests for `NEVPNError.configurationInvalid`, `.configurationDisabled`, `.connectionFailed`, and an unknown-domain/code error on both platforms. Also cover the real disabled-manager start path so callers receive the intended stable result rather than an unnormalized repository/controller split.
4. Rerun focused normal and TSan suites, full core validation, strict formatting and diff checks, board validation, and sequential iOS/macOS adapter builds, then hand off for a new reviewer cycle.

## Independent verification

- Focused controller/repository: 57 tests in 2 suites passed.
- Focused Thread Sanitizer: 23 tests in 1 suite passed, with no race report.
- Full `make validate-core`: 275 tests in 25 suites passed; core build passed.
- `swift format lint --strict --recursive Sources Tests`: passed.
- `git diff --check`: passed.
- `task-board validate`: passed. The installed CLI has no `--strict` flag; an attempted `task-board validate --strict` failed at argument parsing only and was replaced with the supported command.
- macOS adapter build: succeeded.
- iOS Simulator adapter build: succeeded when rerun sequentially. The first concurrent iOS/macOS reviewer attempt hit SwiftPM's shared `build.db` lock; this was a recoverable validation-run collision, not a product failure.

Reviewer logs are under `.temp/TASK-260715-1rsqrh-review/`.
