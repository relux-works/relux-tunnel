# Compose accepted M0 components behind production runtime factories

## Description
Wire the accepted M0 PacketFlowBridge, unmodified HEV or lwIP integration, selected SSHTransport adapter, clocks, metrics, and platform services behind production dependency factories consumed by ReluxTunnelCore. Preserve test substitution and prevent candidate-specific or provider-specific types from entering the coordinator.

## Scope
In scope: factory protocols, ownership transfer, configuration validation, native library startup and shutdown hooks, selected dependency pins, harness and provider compositions, compile-time seams, and fail-fast handling when an M0 decision is absent or incompatible. Out of scope: changing M0 implementations or pins, choosing an SSH engine, tuning MTU or windows, implementing TCP or DNS behavior, and platform UI.

## Acceptance Criteria
1. One production composition exists for each provider and one deterministic composition exists for the harness, all satisfying the same shared interfaces. 2. Packet, HEV, and SSH objects are created once per runtime generation and are released in reverse ownership order. 3. The build fails or runtime start fails before routes when the accepted M0 dependency revision or required capability is unavailable. 4. No selected-engine, HEV C API, NEPacketTunnelProvider, or host-app type crosses an unintended shared boundary. 5. iOS provider, macOS provider, and harness compile and smoke tests prove the production factories resolve the pinned accepted components.
