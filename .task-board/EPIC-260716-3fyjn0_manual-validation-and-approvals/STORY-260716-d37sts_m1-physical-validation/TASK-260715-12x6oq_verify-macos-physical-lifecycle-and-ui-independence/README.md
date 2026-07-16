# Verify Mac VPN lifecycle and UI-process independence

## Description
Run the M1 lifecycle matrix on a named physical Apple-silicon Mac using the generated host and embedded packet-tunnel provider. Capture system approval, manager persistence, connect, truthful status, host quit or termination, relaunch, disconnect, repeated cycles, nested-code context, and cleanup evidence.

## Scope
In scope: supported physical Apple-silicon Mac and macOS version, development-signed M1 build, one test profile, system VPN state, normal quit and forced host termination, provider snapshots after relaunch, stop reason, ten or more lifecycle cycles, redacted unified logs, and resource observations. Out of scope: virtual-machine-only evidence, legacy app behavior, Developer ID release, notarization, path switching, routing leak matrix owned by the routing story, and unrelated system logs.

## Acceptance Criteria
1. Evidence records Mac class, exact macOS and Xcode, source and dependency revisions, profile fixture identifier, bundle versions, nested signing metadata by non-secret identifier, and timestamp. 2. The host installs and reloads one owned manager, required system approval succeeds, and the provider state matches the system session plus capability snapshot. 3. TCP and safe DNS forwarding continue after normal host quit and forced termination, and the relaunched host reconstructs current state without restarting the tunnel. 4. At least ten connect, host-exit, relaunch, and disconnect cycles show no duplicate manager, provider crash, orphaned session, stale state, or resource growth. 5. A TASK-ID-scoped runbook and redacted evidence bundle allows another authorized operator to repeat the matrix.
