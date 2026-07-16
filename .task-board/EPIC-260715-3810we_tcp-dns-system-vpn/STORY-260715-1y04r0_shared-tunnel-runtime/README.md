# Shared tunnel runtime and extension-owned orchestration

## Description
Build the production ReluxTunnelCore orchestration layer that composes the M0-selected packet bridge, HEV/lwIP integration, and SSH transport into one extension-owned TCP and DNS runtime. Define versioned app-to-extension contracts, deterministic startup and teardown, capability snapshots, and privacy-safe diagnostics without moving live forwarding state into the containing app.

## Scope
In scope: shared Swift runtime composition, dependency injection, versioned non-secret configuration and control messages, baseline state ownership, deterministic cancellation and cleanup, aggregate metrics, harness integration, migration isolation, and seams reserved for M2 UDP and M3 resilience. Out of scope: re-proving M0 packet or SSH gates, profile editing UI, UDP relay, multi-lane scheduling, path reconnect, fail-closed route mode, release packaging, and changes to the legacy SOCKS product.

## Acceptance Criteria
1. ReluxTunnelCore owns the live M1 packet, SSH, TCP, DNS, routing, lifecycle, and diagnostics objects after provider start. 2. The containing app can supply only a versioned non-secret snapshot and commands, and can obtain a versioned capability and diagnostic snapshot without being required for forwarding. 3. Startup, cancellation, stop, and partial-failure paths release tasks, descriptors, channels, and packet reads deterministically. 4. Automated harness tests cover ordered startup, injected failures at every boundary, repeated start and stop, and UI-process loss. 5. Runtime documentation identifies M0 inputs, M1 ownership, M2 and M3 extension seams, privacy constraints, and legacy migration isolation.
