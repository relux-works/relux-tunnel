# Add connection presentation and control-model tests

## Description
Build exhaustive deterministic tests for the presentation truth table, shared model, command races, profile/configuration safeguards, provider-version handling, and privacy-safe errors. Test the product state model independently of SwiftUI.

## Scope
In scope: every NETunnelProviderSession state, current/stale/missing/mismatched snapshots, full/degraded/reasserting/failed predicates, reasons, connect/disconnect/retry, permission/configuration errors, duplicate commands, out-of-order callbacks, app recreation, profile switch/edit/delete, policy changes, version skew, cancellation, observer/resource cleanup, and property/table tests. Out of scope: UI pixels, packet forwarding correctness already owned by M1-M3, physical system indicator, and release signing.

## Acceptance Criteria
1. Table tests cover every contract input row and assert presentation state, label/value, capability, reason, primary/secondary actions, and accessibility announcement. 2. Full is impossible without all required current-generation capabilities; degraded requires TCP plus safe DNS; stale/missing data never synthesizes connected capability. 3. Command/race tests cover double tap, stop during start, start during stop, permission denial, late success, timeout, app recreation, profile switch rollback, and policy edit conflicts. 4. Repeated observer/snapshot/command/model recreation cycles return tasks, notifications, timers, managers, and retained closures to baseline. 5. Tests use controllable clocks/events with no sleeps and publish exact commands and redacted result evidence.
