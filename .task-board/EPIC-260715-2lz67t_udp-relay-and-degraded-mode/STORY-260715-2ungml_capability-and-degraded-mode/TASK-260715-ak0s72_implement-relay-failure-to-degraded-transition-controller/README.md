# Implement relay failure-to-degraded transition control

## Description
Integrate relay startup and runtime failure events into the provider coordinator so UDP associations are invalidated promptly and the tunnel enters degraded only when the existing TCP and selected safe-DNS paths remain usable.

## Scope
In scope: unsupported platform or asset; bootstrap, upload, verification, install, launch, handshake, feature, and limit failure; relay framing, health, process, or lane loss; association admission stop; client and relay state invalidation; queue and timer cleanup; safe-DNS readiness check; TCP preservation; snapshot transition; terminal failure when base path is unsafe; stop cancellation; generation safety; diagnostics. Out of scope: repairing SSH path loss, selecting a new network path, opening lane pools, M3 reasserting implementation, implementing DNS transport, QUIC policy detail, and physical route mutation beyond existing M1 safety.

## Acceptance Criteria
1. Each declared pre-start relay failure reaches degraded without delaying usable TCP only after safe DNS is confirmed, or reaches failed when any mandatory base capability is absent. 2. Runtime relay, framing, process, or relay-lane failure atomically stops new UDP admission, invalidates all association IDs, cancels pumps, closes queues and timers, and publishes the new mode for one generation. 3. Existing and new TCP flows follow the existing M1 transport policy while degraded and no UDP datagram is rerouted to a physical or unrelated local socket. 4. Duplicate failures, simultaneous safe-DNS loss, provider stop, late relay callbacks, and replacement generation events produce one ordered cleanup and no transient false-full snapshot. 5. Fault-injection tests cover every reason, failure at every bootstrap and runtime boundary, cleanup counters, TCP preservation, safe-DNS gate, stop races, and bounded transition latency.
