# TASK-260819-2lu7p6: validate-generated-macos-target-development-signing

## Description
Validate the generated ReluxProxyMac host and ReluxProxyMacTunnel system extension with current Relux Works Apple Development signing after the required host System Extension profile and interactive key access are available.

## Scope
In scope: regenerate/install the host macOS Development profile with System Extension capability, restore an authenticated Xcode account session, permit the Apple Development private key for codesign, build the checked-in generated target definitions without weakening entitlements, inspect the embedded signed provider, and preserve privacy-safe evidence. Out of scope: changing product entitlements to fit a stale profile, Developer ID distribution, notarization, runtime forwarding, or iOS.

## Acceptance Criteria
1. The host development profile includes com.apple.developer.system-extension.install and the provider profile includes packet-tunnel-provider. 2. ReluxProxyMac Debug builds with the Relux Works Apple Development identity and embeds exactly one signed ReluxProxyMacTunnel. 3. The built host and provider identifiers, entitlements, team identifier, versions, and designated requirements match the approved matrix. 4. No generated Xcode state, secrets, profile contents, or private-key material are committed or recorded. 5. Evidence records the signed build result and the exact remaining human input if macOS approval is encountered.
