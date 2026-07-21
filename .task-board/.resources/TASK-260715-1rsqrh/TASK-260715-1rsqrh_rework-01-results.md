# TASK-260715-1rsqrh — rework 01 verification

## Production-boundary correction

- `IOSVPNHostSession` and `MacOSVPNHostSession` now invoke the real
  `NETunnelProviderSession.startTunnel(options:)` call through platform-local,
  injectable normalization boundaries.
- Both boundaries translate public NetworkExtension errors through the existing
  `VPNPreferencePlatformError` model before they reach the platform-neutral
  controller.
- `NEVPNError.configurationInvalid`, `.configurationDisabled`, and
  `.connectionFailed` therefore retain the accepted stable controller results.
- An unknown or non-NEVPN `NSError` retains its original domain and integer code,
  so the controller returns `platformRejected(domain, code)` without reflection
  or code-zero substitution.
- A disabled freshly loaded exact-owned manager is normalized to
  `VPNSessionControllerError.configurationDisabled`; the test proves that the
  system start API is not called and the manager is not mutated.

The controller remains free of `NetworkExtension` imports and does not duplicate
manager ownership or persistence logic. Session status and provider capability
authority, deadlines, generation retirement, cancellation, and race behavior are
unchanged.

## Added deterministic coverage

- iOS adapter: the three known public `NEVPNError` start failures and one unknown
  exact `NSError` domain/code.
- macOS adapter: the same four boundary cases independently.
- Real `OwnedVPNManagerRepository` to `VPNSessionController` disabled-manager
  preflight with zero session starts and zero preference mutations.

## Verification

| Gate | Result |
| --- | --- |
| `swift test --filter 'VPNSessionControllerTests|OwnedVPNManagerRepositoryTests'` | 58 tests in 2 suites passed |
| Same focused suites with `--sanitize=thread` | 58 tests in 2 suites passed; no TSan report |
| `make validate-core` | 276 tests in 25 suites passed; post-test build passed |
| `swift format lint --strict --recursive Sources Tests Package.swift` | Passed |
| `git diff --check` | Passed |
| `task-board validate` | Passed |
| iOS Simulator `ReluxTunnelIOSAdapter` Xcode build | `BUILD SUCCEEDED` |
| Universal macOS `ReluxTunnelMacOSAdapter` Xcode build | `BUILD SUCCEEDED` |

The platform builds were run sequentially to avoid SwiftPM's shared build-database
lock.
