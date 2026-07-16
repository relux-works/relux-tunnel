# Implement the extension-owned M1 TunnelRuntimeCoordinator

## Description
Implement the shared asynchronous coordinator that owns one M1 tunnel generation from validated configuration through authenticated SSH, prepared packet and DNS components, route application, packet reads, usable-state publication, failure rollback, and deterministic stop.

## Scope
In scope: state machine from disconnected through starting, usable TCP and DNS, stopping, and failed, generation tokens, structured cancellation, serialized transitions, dependency health callbacks, ordered rollback, idempotent stop, and future capability hooks. Out of scope: NETunnelProviderManager, profile UI, detailed SSH policy, TCP or DNS internals, UDP, multi-lane scheduling, reasserting reconnect behavior, memory-watermark tuning, and final UI state wording.

## Acceptance Criteria
1. Concurrent start, stop, and callback events are serialized and stale callbacks from an older generation cannot mutate the active generation. 2. The coordinator does not request network settings until profile validation, SSH authentication, packet plane preparation, and safe DNS readiness succeed. 3. It publishes usable capability only after network settings apply and packet reads start, and never publishes TCP or DNS capability after their mandatory component fails. 4. Cancellation or failure at every startup step rolls back exactly the resources already acquired in reverse order and completes once. 5. At stop, all reads, tasks, timers, channels, native runtimes, sockets, and retained configuration references return to the recorded baseline.
