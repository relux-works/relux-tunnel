# Verify iPhone VPN lifecycle and UI-process independence

## Description
Run the M1 lifecycle matrix on a named physical iPhone using the generated host and packet-tunnel provider. Capture system VPN permission, configuration persistence, connect, truthful status, host suspension and termination, host relaunch, disconnect, repeated cycles, and cleanup evidence.

## Scope
In scope: supported physical iPhone and iOS version, development-signed M1 build, one test profile, system VPN indicator, app backgrounding and force termination, provider snapshots after relaunch, stop reason, ten or more lifecycle cycles, relevant redacted device logs, and resource observations. Out of scope: simulator evidence, final UI polish, TestFlight, App Review, path switching, DNS leak and external-IP matrix owned by the routing story, and unrelated personal device logs.

## Acceptance Criteria
1. Evidence records device class, exact iOS and Xcode, source and dependency revisions, profile fixture identifier, bundle versions, signing metadata by non-secret identifier, and timestamp. 2. The system installs one owned VPN configuration, grants permission, starts the provider, and shows a session state consistent with the provider snapshot. 3. TCP and safe DNS forwarding continue while the containing app is suspended and after it is force-terminated, then the relaunched app reconstructs current state. 4. At least ten connect, app-termination, relaunch, and disconnect cycles show no duplicate manager, crash, orphaned session, stale status, or unexplained cleanup failure. 5. A TASK-ID-scoped runbook and redacted evidence bundle allows another authorized operator to repeat the matrix.
