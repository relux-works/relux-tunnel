# Implement the thin macOS packet-tunnel provider adapter

## Description
Implement the macOS NEPacketTunnelProvider target adapter that translates Apple lifecycle calls and packetFlow access into the same shared production factories and TunnelRuntimeCoordinator used on iOS, while preserving the generated product boundary from the legacy app.

## Scope
In scope: startTunnel options decoding, provider configuration reference loading, packetFlow injection, network-settings closure, app-message delegation, stop reason handling, provider error termination, sleep or wake callback safe handling where exposed, privacy-safe logging, and generated macOS target integration from M0. Out of scope: duplicate runtime logic, legacy SwiftPM product changes, system extension redesign, reconnect, UDP relay, Developer ID release, notarization, and app UI.

## Acceptance Criteria
1. The macOS adapter is behaviorally conformant with the iOS adapter through shared tests and contains no duplicate packet, SSH, TCP, DNS, or route policy. 2. Start and stop completion handlers fire once at the same shared-runtime readiness and cleanup boundaries as iOS. 3. Provider messages and stop reasons use the common versioned and privacy-safe contracts. 4. Host-app termination or relaunch does not tear down or recreate the active provider runtime. 5. The generated macOS host and provider build and adapter tests cover duplicate start, stop during start, mapped failure, late callback, and clean deallocation without touching the legacy release target.
