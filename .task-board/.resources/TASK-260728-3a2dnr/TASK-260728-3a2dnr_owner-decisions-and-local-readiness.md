# Owner decisions and local readiness — 2026-07-28

## Binding decisions
- SSH contract: Option A for M0 viability; exact deep observability stays M3 evidence work.
- Primary SSH candidate: libssh2. Retain NIOSSH evidence, but it must not block the working macOS client path.
- A0/App Review opinion is not a gate for the protocol prototype. Do not run Apple-policy research on the prototype critical path.
- iOS is deferred. Physical P0 for this goal is macOS-only.
- Linux CI/runner is not required for the early working-client path.
- Sparkle EdDSA generation may be performed locally when the updater integration reaches its ceremony.

## Privacy-safe local preflight
- Host: arm64 Mac, macOS 26.5, Xcode 26.5.
- Keychain exposes valid Relux Works Apple Development and Developer ID Application identities. Developer ID expires in 2031.
- Existing Relux Works provisioning profiles do not include Network Extension entitlements; tunnel-specific identifiers/profiles still need creation.
- The owner-supplied notarization note references an existing App Store Connect API private-key file with mode 0600. No notarytool Keychain profile was detected. Do not copy its path or values to board, repo, shell logs, or providerConfiguration.
- The approved Git signing key is already loaded in ssh-agent.

## Required human interaction
Plan a single early ceremony on this Mac: user unlocks Keychain and approves private-key access, authenticates Xcode/Apple Developer portal if required, authorizes creation/download of macOS packet-tunnel App IDs/profiles, and permits notarytool to store a named credential profile in Keychain. Never request or echo secret values.