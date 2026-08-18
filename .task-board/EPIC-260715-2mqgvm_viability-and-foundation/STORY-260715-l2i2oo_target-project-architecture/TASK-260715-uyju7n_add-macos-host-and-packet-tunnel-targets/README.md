# Add the macOS host and packet-tunnel targets

## Description
Add ReluxProxyMac and ReluxProxyMacTunnel to the generated workspace with the approved macOS identifiers, embedding, Info.plist ownership, entitlement seams, and minimal compile-only lifecycle entry points. Credential-free construction is accepted here; interactive Apple Development signing is tracked separately as the explicit Gate P0 edge.

## Scope
In scope: macOS containing-app target; embedded NEPacketTunnelProvider target; bundle identifiers; target-owned plist and entitlement configuration; minimum platform; host-provider version compatibility constant; empty provider start, app-message, and stop stubs; credential-free builds; target-specific resources and tests; generation of uncompromised Gate P0 signing settings. Out of scope: live packet reads, routes, DNS, HEV, SSH, relay, production state machines, Developer ID signing, notarization, actual interactive Apple Development signing, and iOS.

## Acceptance Criteria
1. Generated ReluxProxyMac embeds exactly one ReluxProxyMacTunnel with bundle identifiers and entitlement files derived from the approved matrix. 2. The provider imports NetworkExtension, exposes only minimal lifecycle and version-message entry points, and contains no live packet or transport implementation. 3. Host and provider build credential-free in Debug and Release; generated Gate P0 development settings are target-specific and preserve all required entitlements without editing generated Xcode state. Actual signed-build execution is tracked by TASK-260819-2lu7p6. 4. Automated target tests verify bundle relationships, version compatibility, plist values, entitlement contents, and absence of App Groups and Keychain Sharing. 5. The existing ReluxProxy SwiftPM executable remains a separate product.
