# Implement VPN session control and truthful status projection

## Description
Implement the host-side controller that starts and stops the loaded NETunnelProviderSession, observes Network Extension status, requests versioned provider snapshots, and projects a truthful combined state without making the containing app part of the live packet path.

## Scope
In scope: start with opaque profile reference, stop request, status notifications, initial status refresh, app-message request and timeout, version compatibility, session-state plus capability-state projection, stale snapshot handling, disconnect completion observation, and privacy-safe errors. Out of scope: final UI rendering, automatic reconnect, profile switching UX, UDP relay semantics, analytics, and duplicating runtime state in app memory.

## Acceptance Criteria
1. Connect requires a saved enabled manager and emits deterministic configuration, permission, start, and provider-error outcomes. 2. Projected state distinguishes session connecting, connected, disconnecting, disconnected, invalid, and provider capability facts such as TCP, safe DNS, and UDP without claiming full mode when UDP is absent. 3. A missing, suspended, or terminated host app cannot stop the provider or invalidate its runtime state. 4. Snapshot timeouts, old protocol versions, out-of-order status notifications, and stale sessions never synthesize a connected-capable state. 5. Tests cover connect and disconnect races, controller recreation after app relaunch, provider unavailable, and recovery of the current state from the system session plus a fresh snapshot.
