# Verify physical system VPN status and containing-app lifecycle

## Description
Run the M4 connection-control acceptance matrix on one named physical iPhone and one named Apple-silicon Mac using authorized test profiles. Prove the system VPN indicator follows the Network Extension, the UI reflects full/degraded/reasserting/failure truthfully, and forwarding survives containing-app suspension or termination.

## Scope
In scope: device/OS/Xcode/source revisions, development-signed apps/providers, owned manager and permission, connect/disconnect, external session state, system indicator, full/degraded/reasserting/failed fixtures, app background/suspend/terminate/relaunch, selected/active profile, policy display, stop reason, privacy-safe logs, repeated cycles, screenshots/video where permitted, and cleanup. Out of scope: packet throughput/rekey, full leak matrix already owned by M1-M3, release signing, TestFlight, production credentials, and unsupported devices.

## Acceptance Criteria
1. Both devices show system VPN active only when the provider session is active and the app dashboard converges to the matching authoritative state after launch/relaunch. 2. Full, degraded, reasserting, disconnecting, and mandatory failure rows match current capability snapshots and expected controls; degraded preserves TCP/safe DNS evidence and names missing UDP. 3. Suspending/terminating the containing app does not stop forwarding or alter the system indicator; relaunch reconstructs state from the manager/session plus fresh provider snapshot. 4. Permission denial, trust/auth failure, provider start failure, user disconnect, forced stop, and repeated start/stop leave no stale manager/session/UI state or unintended physical fallback. 5. A TASK-ID-scoped redacted bundle records devices, revisions, profiles by opaque ID, steps, observations, screenshots, system status, counters, cleanup, and pass/fail per row.
