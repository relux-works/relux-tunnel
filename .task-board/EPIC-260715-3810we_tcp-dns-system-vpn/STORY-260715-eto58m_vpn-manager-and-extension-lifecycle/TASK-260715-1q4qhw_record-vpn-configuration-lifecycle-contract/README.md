# Record the system VPN configuration and lifecycle contract

## Description
Produce the task-scoped contract for how both containing apps own one NETunnelProviderManager configuration and how both NEPacketTunnelProvider adapters delegate to the shared runtime. Define identity, persistence, permission, command, status, app-message, error, stop, and cleanup behavior before platform implementation.

## Scope
In scope: manager discovery and ownership marker, provider bundle identifiers from M0, protocol configuration fields, save and reload rules, session control, Network Extension status mapping, versioned message exchange, start options, stop reasons, host suspension or termination, provider completion handlers, and public API constraints. Out of scope: profile editor UX, final labels or visuals, M0 entitlement proof, packet and SSH internals, reconnect, release signing, TestFlight, and notarization.

## Acceptance Criteria
1. A TASK-ID-scoped contract defines the exact owned-manager predicate and proves unrelated VPN managers are never edited or removed. 2. Save, reload, enable, permission, start, status observation, message, stop, host termination, and stale configuration flows have explicit outcomes and error mappings. 3. The provider remains the authority for runtime capability while NETunnelProviderSession remains the authority for system session state. 4. Start and stop completion-handler ownership, timeouts, cancellation, and idempotency are specified for both platforms. 5. The contract references the approved M0 identifiers and entitlements and reserves reconnect, fail-closed policy, and final UX for later milestones.
