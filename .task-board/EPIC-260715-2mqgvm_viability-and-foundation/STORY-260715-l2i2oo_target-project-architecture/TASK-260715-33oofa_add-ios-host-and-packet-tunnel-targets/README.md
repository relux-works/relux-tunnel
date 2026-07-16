# Add the iOS host and packet-tunnel targets

## Description
Add ReluxProxyIOS and ReluxProxyIOSTunnel to the generated workspace with the approved Gate P0 identifiers, embedding, Info.plist ownership, entitlement seams, and minimal compile-only lifecycle entry points.

## Scope
In scope: iOS containing-app target; embedded NEPacketTunnelProvider target; bundle identifiers; App Group and Keychain entitlement configuration; minimum platform; host-provider version compatibility constant; empty provider start, app-message, and stop stubs needed for build verification; target-specific resources and tests. Out of scope: product UI, packet reads, routes, DNS, HEV, SSH, relay, production lifecycle state machines, TestFlight, and App Store submission.

## Acceptance Criteria
1. Generated ReluxProxyIOS embeds exactly one ReluxProxyIOSTunnel with identifiers and entitlements derived from the approved matrix. 2. The provider imports NetworkExtension, exposes only minimal lifecycle and version-message entry points, and contains no live packet or transport implementation. 3. Host and provider build for the selected simulator and device SDK configurations without manual Xcode edits; physical signing consumes Gate P0 inputs. 4. Automated target tests verify bundle relationships, version compatibility, Info.plist values, and entitlement-file contents. 5. No iOS target depends on the legacy macOS executable sources.
