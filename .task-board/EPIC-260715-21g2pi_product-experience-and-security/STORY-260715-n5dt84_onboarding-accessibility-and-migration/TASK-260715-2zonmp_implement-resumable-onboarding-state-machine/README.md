# Implement the resumable onboarding state machine

## Description
Implement a platform-neutral versioned model for first-run and resumable onboarding. Coordinate education and handoffs to profile, trust, approved privacy disclosure, system VPN permission, first connection, capability explanation, help, and completion without duplicating those feature state machines.

## Scope
In scope: onboarding version, not-started/in-progress/completed state, step prerequisites, optional/back navigation, profile/trust/privacy/permission/connection handoff results, app relaunch, disclosure version changes, migration branch, deep links/settings re-entry, skip policy, help, error recovery, test injection, minimal non-secret persistence, and analytics-free progress. Out of scope: screen layout, VPN runtime ownership, storing credentials, auto-trust, bypassing privacy acknowledgement, release review, and arbitrary tutorials.

## Acceptance Criteria
1. A deterministic state graph defines each step, prerequisite, entry/exit, resume point, skip/back rule, completion rule, and migration/disclosure version transition. 2. Relaunch, app background/termination, permission denial, profile deletion, trust/auth failure, connection failure, disclosure update, and migration interruption resume at the earliest valid actionable step without losing user data. 3. Completion requires an eligible profile, required trust/auth outcome for the attempted host, current disclosure acknowledgement, permission outcome handling, and an observed authoritative session/capability result or explicit supported deferral. 4. Persisted progress contains only version, step/status, opaque IDs, and timestamps; no credentials, fingerprint copy, traffic, or diagnostics payload. 5. Swift tests cover every transition, invalid/stale event, duplicate action, relaunch, backward navigation, migration branch, and reset using controllable services/clocks.
