# Build the disposable iOS packet-tunnel entitlement probe

## Description
Create a minimal, explicitly disposable iOS containing app and NEPacketTunnelProvider target that exercise only configuration, provider launch, versioned app-message response, and clean stop. The probe exists to test signing and entitlement viability before the production generated workspace.

## Scope
In scope: approved Gate P0 identifiers and profiles; NETunnelProviderManager save, load, enable, start, status, app-message, and stop paths; one provider protocol and version response; privacy-safe logging; deterministic build and archive instructions; public Apple APIs. Out of scope: packet reads or writes, routes or DNS beyond the minimum harmless launch configuration, HEV, SSH, relay, profile editing UX, reusable production architecture, TestFlight, and private APIs.

## Acceptance Criteria
1. The iOS host embeds exactly one packet-tunnel extension and both targets sign with the approved development identities and entitlements. 2. The host can create or update only its own NETunnelProviderManager configuration using the extension bundle identifier. 3. Provider launch returns a versioned probe payload through app messaging and stop cancels all work without packet forwarding. 4. Clean build and install instructions record Xcode, SDK, source revision, signing inputs by non-secret identifier, and expected outputs. 5. Automated or scripted archive inspection fails on entitlement drift, mismatched application identifier, or a missing embedded extension.
