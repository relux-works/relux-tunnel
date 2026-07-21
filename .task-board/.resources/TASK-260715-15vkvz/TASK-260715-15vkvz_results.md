# TASK-260715-15vkvz implementation evidence

## Implementation

- Added the serialized, injectable `OwnedVPNManagerRepository` and complete `PlatformVPNIdentity` in `ReluxTunnelCore`.
- Added thin public-NetworkExtension preference clients/factories for iOS and macOS.
- Implemented exact ownership partitioning; nil-collection fail-closed behavior; canonical three-key provider configuration; idempotent ensure; explicit enable/disable/remove; inactive current-schema duplicate repair; future/corrupt preservation rules; reload verification; one stale retry; 15-second timeout/cancellation tokens; stable platform error mapping; and late-callback retirement.
- Production identity factories deterministically fail closed pending accepted release bindings.

## Test evidence

- `swift test --filter OwnedVPNManagerRepositoryTests`: 18 tests passed.
- `make validate-core`: 236 tests in 24 suites passed; post-test Swift build passed.
- `swift format lint --recursive Sources Tests Package.swift`: passed with no diagnostics.
- iOS Simulator Xcode build of `ReluxTunnelIOSAdapter`: succeeded for arm64 and x86_64 at the iOS 18 floor.
- macOS Xcode build of `ReluxTunnelMacOSAdapter`: succeeded for arm64 and x86_64 at the macOS 15 floor.

Logs attached separately: `TASK-260715-15vkvz_validate-core.log`, `TASK-260715-15vkvz_ios-build.log`, `TASK-260715-15vkvz_macos-build.log`, and `TASK-260715-15vkvz_swift-format-lint.log`.
