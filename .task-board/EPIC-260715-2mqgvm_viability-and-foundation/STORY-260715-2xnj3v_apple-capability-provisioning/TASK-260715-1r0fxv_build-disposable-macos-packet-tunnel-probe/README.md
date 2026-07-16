# Build the disposable macOS packet-tunnel entitlement probe

## Description
Create a minimal, explicitly disposable macOS containing app and NEPacketTunnelProvider target that exercise only configuration, provider launch, versioned app-message response, and clean stop on Apple silicon. Keep it separate from the current shipped menu-bar SOCKS app and the later generated production workspace.

## Scope
In scope: approved Gate P0 identifiers and profiles; embedded packet-tunnel extension; NETunnelProviderManager save, load, enable, start, status, app-message, and stop paths; one versioned provider response; privacy-safe logs; deterministic build and archive inspection. Out of scope: modifying the current ReluxProxy executable, packet forwarding, HEV, SSH, relay, Developer ID distribution, notarization, full sandbox design, or production UX.

## Acceptance Criteria
1. The macOS probe is a separate host/provider pair and leaves the existing SwiftPM application and release scripts unchanged. 2. Both targets sign with approved development identities and entitlements, and the host embeds exactly the expected provider. 3. The provider returns a versioned probe payload, reports lifecycle transitions, and stops without leaked work or packet forwarding. 4. Clean build and install instructions record Xcode, SDK, source revision, signing inputs by non-secret identifier, and expected outputs. 5. Scripted signature, embedded-profile, nested-code, and entitlement inspection fails on identifier or capability drift.
