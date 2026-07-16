# Add the macOS host and packet-tunnel targets

## Description
Add ReluxProxyMac and ReluxProxyMacTunnel to the generated workspace with the approved Gate P0 identifiers, embedding, Info.plist ownership, entitlement seams, and minimal compile-only lifecycle entry points.

## Scope
In scope: macOS containing-app target; embedded NEPacketTunnelProvider target; bundle identifiers; App Group and Keychain entitlement configuration; minimum platform; host-provider version compatibility constant; empty provider start, app-message, and stop stubs needed for build verification; target-specific resources and tests. Out of scope: migrating the legacy UI, packet reads, routes, DNS, HEV, SSH, relay, production state machines, Developer ID signing, and notarization.

## Acceptance Criteria
1. Generated ReluxProxyMac embeds exactly one ReluxProxyMacTunnel with bundle identifiers and entitlements derived from the approved matrix. 2. The provider target imports NetworkExtension, exposes only minimal lifecycle and version-message entry points, and contains no live packet or transport implementation. 3. Host and provider build credential-free and with Gate P0 development settings without editing generated Xcode state. 4. Automated target tests verify bundle relationships, version compatibility, Info.plist values, and entitlement-file contents. 5. The existing ReluxProxy SwiftPM executable remains a separate product.
