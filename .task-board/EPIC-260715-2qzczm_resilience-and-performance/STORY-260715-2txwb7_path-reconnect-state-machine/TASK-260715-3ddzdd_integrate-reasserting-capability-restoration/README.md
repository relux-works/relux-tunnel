# Integrate reasserting and leak-safe capability restoration

## Description
Integrate the reconnect coordinator with provider reasserting and the M2 capability authority so mandatory control, packet, TCP, safe-DNS, relay, and optional-lane resources restore in order and only truthful full or degraded service clears reasserting.

## Scope
In scope: provider reasserting flag; generation-safe capability inputs; lane A; packet plane; TCP adapter; tunnel-owned DNS and safe upstream; route settings readiness; relay bootstrap and current identity; optional lanes; full, degraded, failed, stopping snapshots; traffic admission; error reasons; app-message projection; cancellation; metrics. Out of scope: implementing components, final UI, relay-only reprobe, preserving UDP associations, physical path selection, or absolute kill-switch claims.

## Acceptance Criteria
1. A current reconnect trigger sets reasserting before new ordinary flow admission can use a failed generation and invalidates old relay associations and unsafe capabilities. 2. Restore order is authenticated lane A, safe DNS and packet or TCP prerequisites, current settings, packet reads, relay capability, then optional lanes, with each readiness input generation-checked. 3. Reasserting becomes false only when the published current mode is usable full or degraded, and safe-DNS or mandatory-base loss publishes failed even if the system VPN session remains connected. 4. No UDP, ordinary DNS, or failed new TCP flow opens a physical fallback during connecting, reasserting, degraded, failed, stopping, or stale callbacks. 5. Integration tests cover full restoration, degraded restoration, relay failure, DNS failure, settings failure, simultaneous events, stop, stale generations, app snapshots, route sentinels, and resource cleanup.
