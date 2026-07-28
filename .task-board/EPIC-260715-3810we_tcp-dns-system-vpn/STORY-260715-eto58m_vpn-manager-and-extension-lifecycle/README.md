# System VPN manager, provider lifecycle, and physical M1 acceptance

## Description
Implement the macOS host and provider lifecycle — the iOS adapter stays defined but deferred under ADR-024 and re-arms unchanged — needed to install, start, observe, and stop one owned custom VPN configuration while keeping the packet-tunnel extension authoritative. Integrate the completed SSH, TCP, DNS, and routing core in the real providers and own the physical Apple-silicon Mac acceptance evidence, with the physical-iPhone rows deferred with iOS under ADR-024 as named gaps.

## Scope
In scope: idempotent NETunnelProviderManager ownership, save and reload, permission integration, NETunnelProviderSession control, thin iOS and macOS provider adapters, versioned app messaging, truthful status, stop and cleanup, host suspension or termination independence, provider-context SSH authentication, dual-stack TCP and DNS routing, authorized leak evidence, repeated lifecycle tests, and physical-device runbooks. Out of scope: profile editor UX, final visual design, UDP relay, path reconnect, fail-closed routing, TestFlight, notarization, and repeating M0 entitlement or engine gates.

## Acceptance Criteria
1. Each platform creates or updates only the Relux-owned manager configuration and does not duplicate or overwrite unrelated VPN configurations. 2. The thin providers delegate live work to ReluxTunnelCore, report versioned state, and stop promptly with all owned work cancelled. 3. Forwarding and truthful system VPN state continue while the containing app is suspended or terminated. 4. Automated lifecycle tests cover persistence, start cancellation, provider failures, messages, stop reasons, stale configuration, and repeated cycles. 5. Physical Apple-silicon Mac evidence proves, with the iPhone row deferred under ADR-024, approved host verification and auth, dual-stack representative TCP, leak-free DNS, exit-host external IP, no route loop, host-app independence, disconnect, and cleanup.
