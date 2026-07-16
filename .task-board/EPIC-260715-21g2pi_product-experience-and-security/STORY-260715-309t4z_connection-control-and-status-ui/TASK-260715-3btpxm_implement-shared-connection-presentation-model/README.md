# Implement the shared connection presentation model

## Description
Implement the platform-neutral observable state and command layer consumed by iOS and macOS dashboards. Combine current manager/session facts and fresh provider snapshots, expose truthful presentation state, gate actions, and survive app relaunch without owning live forwarding.

## Scope
In scope: manager/session observation, initial refresh, provider snapshot requests/timeouts, generation and protocol compatibility, state reduction, selected/active profile metadata, command execution, duplicate/race suppression, disconnect observation, last safe failure, retry actions, profile/policy edit signals, accessibility-ready summaries, injectable services/clocks, and cancellation. Out of scope: view layout, manager repository implementation, provider runtime logic, automatic reconnect policy, and diagnostics export.

## Acceptance Criteria
1. Given any contract input sequence, the reducer emits exactly the specified presentation state and never full/degraded from stale, absent, unsupported, or wrong-generation capability data. 2. Connect/disconnect/retry commands are single-flight, return typed outcomes, tolerate duplicate taps and late callbacks, and reconcile from system session state after app recreation. 3. Selected versus active profile and policy generations remain distinct; edits never silently alter the running provider generation. 4. Observer, snapshot, timeout, cancellation, and deinitialization paths release resources and cannot continue mutating a retired model generation. 5. Swift tests cover the complete truth table, out-of-order events, timeouts, relaunch, start/stop races, invalid manager, permission denial, profile changes, and protocol-version skew with controllable time.
