# Implement the thin iOS packet-tunnel provider adapter

## Description
Implement the iOS NEPacketTunnelProvider target adapter that translates Apple lifecycle calls and packetFlow access into the shared production factories and TunnelRuntimeCoordinator. Keep policy and data-plane state in ReluxTunnelCore and use only public APIs.

## Scope
In scope: startTunnel options decoding, provider configuration reference loading, packetFlow adapter injection, network-settings application closure, app-message delegation, stop reason handling, provider error termination, system sleep callbacks where required for safe no-op behavior, privacy-safe logging, and iOS build settings already established by M0. Out of scope: duplicate packet or SSH state machines, UI code, private utun access, path reconnect, UDP relay, entitlements changes, and TestFlight packaging.

## Acceptance Criteria
1. The adapter contains only platform translation and composition and has no independent packet, SSH, TCP, DNS, or route state machine. 2. startTunnel completes only when the shared runtime reaches its M1 usable point or returns one mapped error exactly once. 3. stopTunnel cancels the active generation, waits for bounded cleanup, records the Apple stop reason, and calls its completion exactly once. 4. App messages are size-bounded and delegated to the shared versioned router even after the containing app has relaunched. 5. The iOS provider builds with approved public APIs and automated adapter tests cover duplicate start, stop during start, mapped failure, late callback, and deallocation.
