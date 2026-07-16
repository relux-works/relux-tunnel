# M4 solution-architecture decomposition

## Outcome

EPIC-260715-21g2pi is decomposed into five detailed stories and 50 atomic backlog tasks. Every task has a title, description, explicit in-scope/out-of-scope boundary, five verifiable acceptance criteria, three unchecked delivery checklist items, and dependency links. All five stories are at to-dev; every task remains backlog and unassigned. No implementation, source, specification, release, commit, push, or pull-request work was performed.

## Canonical plan

The internal story plan has four phases:

1. STORY-260715-tx1tbz — profile and key foundation.
2. STORY-260715-14qi1v — host trust/auth and STORY-260715-309t4z — connection/status may proceed in parallel after their concrete inputs.
3. STORY-260715-3tds7d — diagnostics/privacy/support.
4. STORY-260715-n5dt84 — onboarding/accessibility/localization/migration and physical M4 acceptance.

Cross-story critical path: STORY-260715-tx1tbz -> STORY-260715-309t4z -> STORY-260715-3tds7d -> STORY-260715-n5dt84.

The story statuses are to-dev, but computed dependency blocking is expected until their linked M0-M3 tasks are accepted. The graph is acyclic.

## Task inventory

### STORY-260715-tx1tbz — Cross-platform profile and private-key management

- TASK-260715-2hhh7x — Record the profile, key, and ownership contract.
- TASK-260715-1idq8c — Establish shared Apple UI-test and screenshot infrastructure.
- TASK-260715-28bwf4 — Implement the versioned profile repository and App Group publisher.
- TASK-260715-379cpk — Implement the shared Data Protection Keychain credential vault.
- TASK-260715-6ig5xj — Implement private-key import and validation.
- TASK-260715-a37ydn — Implement private-key generation and explicit export.
- TASK-260715-1y5r8p — Implement the shared profile-editor presentation model.
- TASK-260715-n8i3tv — Build the iOS profile and key management UI.
- TASK-260715-2lakiq — Build the macOS profile and key management UI.
- TASK-260715-1yxpqv — Add profile, key-storage, and trust-boundary tests.
- TASK-260715-1kfqgp — Add cross-platform profile and key UI tests.

### STORY-260715-14qi1v — Mandatory host trust and authentication recovery experience

- TASK-260715-31zqvw — Record the host-trust and authentication UX contract.
- TASK-260715-3gp5wd — Implement the approved host-identity write repository.
- TASK-260715-bf3a2d — Implement the host-trust request presentation coordinator.
- TASK-260715-2y9i1d — Build the first-use host-trust confirmation surface.
- TASK-260715-1ex8i3 — Build the changed-host-key blocking recovery flow.
- TASK-260715-1fx855 — Build authentication and passphrase recovery UI.
- TASK-260715-3pxgxx — Add host-trust and authentication security tests.
- TASK-260715-3b6krz — Add cross-platform host-trust and authentication UI tests.

### STORY-260715-309t4z — Truthful VPN connection controls, capability status, and policy settings

- TASK-260715-2a1cp7 — Record the connection presentation-state and command contract.
- TASK-260715-3btpxm — Implement the shared connection presentation model.
- TASK-260715-3ix830 — Build the iOS VPN connection dashboard.
- TASK-260715-17kzx9 — Build the macOS VPN connection dashboard.
- TASK-260715-kq7vqf — Build capability, failure, and recovery detail presentation.
- TASK-260715-wz0mvf — Build QUIC and route-policy settings UI.
- TASK-260715-34pn13 — Implement connected-profile switching and configuration safeguards.
- TASK-260715-39lo79 — Add connection presentation and control-model tests.
- TASK-260715-312zg8 — Add cross-platform connection UI and accessibility tests.
- TASK-260715-132kb2 — Verify physical system VPN status and containing-app lifecycle.

### STORY-260715-3tds7d — Privacy-safe diagnostics, disclosure, and support export

- TASK-260715-2bgp7x — Record the diagnostics, redaction, and export contract.
- TASK-260715-2gwfaw — Approve VPN privacy, retention, and support copy.
- TASK-260715-1m2xet — Implement the bounded privacy-safe diagnostic event store.
- TASK-260715-2o2oq0 — Implement the versioned diagnostic snapshot and event client.
- TASK-260715-2f44rv — Implement the support-export redaction and manifest pipeline.
- TASK-260715-3h64k1 — Build the cross-platform diagnostic summary UI.
- TASK-260715-3c7g17 — Build support-export preview, share, and save UI.
- TASK-260715-6qqmsz — Build VPN privacy disclosure and zero-telemetry UI.
- TASK-260715-o07tjd — Add diagnostics redaction, export, bounds, and zero-telemetry security tests.
- TASK-260715-3nzx7s — Add diagnostics, privacy, and support acceptance tests.

### STORY-260715-n5dt84 — Onboarding, accessibility, localization, and legacy migration

- TASK-260715-35nc5m — Decide legacy SOCKS coexistence, replacement, or retirement.
- TASK-260715-1jtyre — Implement the approved legacy SOCKS migration or coexistence adapter.
- TASK-260715-intsjz — Decide launch locales, copy ownership, and fallback policy.
- TASK-260715-2zonmp — Implement the resumable onboarding state machine.
- TASK-260715-2yywzw — Build the iOS onboarding and VPN-permission journey.
- TASK-260715-qdpbd1 — Build the macOS onboarding and system-approval journey.
- TASK-260715-2unyf6 — Implement M4 accessibility semantics, focus, scaling, contrast, and motion.
- TASK-260715-1ets2m — Externalize, localize, and pseudo-localize M4 copy.
- TASK-260715-1fwkrd — Build empty, error, help, and settings recovery surfaces.
- TASK-260715-1fk4ja — Add onboarding, migration, localization, and accessibility UI tests.
- TASK-260715-zwtrhy — Run the physical M4 product, security, privacy, and accessibility matrix.

## External prerequisites and release handoffs

- M0 links cover generated iOS/macOS targets, the least-privilege App Group/Keychain entitlement matrix, SSH-engine selection, legacy inventory, and preservation of the current release path.
- M1 links cover the versioned profile loader, extension Keychain resolver, mandatory host policy, auth/error/bootstrap ordering, manager/session state projection, provider messaging, diagnostics, lifecycle tests, physical auth, and migration isolation.
- M2 links cover capability/full/degraded contracts, safe DNS and UDP behavior, restoration, snapshots, and physical iPhone/Mac evidence.
- M3 links cover reconnect/reasserting and QUIC plus compatible/fail-closed routing contracts, implementation, and physical evidence.
- M5 release privacy/App Review, iOS TestFlight, and macOS distribution stories are linked to the relevant M4 privacy, accessibility/onboarding, connection, and migration outputs.

## Remaining accountable decisions

1. TASK-260715-35nc5m: no approved SOCKS migration mode exists. Planning recommendation is isolated coexistence until evidence and accountable approval select replacement or retirement; the current SwiftPM app, defaults, DMG path, and release history remain untouched meanwhile.
2. TASK-260715-intsjz: launch locales and translation/copy owners are unspecified. All strings must still be externalized and pseudo-localization-ready; the shipping locale set cannot be assumed.
3. TASK-260715-2gwfaw: exact pre-VPN, retention/deletion, support-data, system-exclusion, and zero-telemetry copy needs product/privacy/legal/security approval before disclosure UI acceptance.

These gaps are explicitly modeled as decision tasks. They become executable when their linked evidence prerequisites are accepted and block only the dependent implementation; no M4 task uses explicit blocked status.

## Planning diagrams

- TASK-260715-2hhh7x_credential-boundaries.puml on TASK-260715-2hhh7x: component boundaries for App Group, Keychain, containing apps, manager, provider, runtime, and SSH host.
- TASK-260715-31zqvw_mandatory-host-trust-sequence.puml on TASK-260715-31zqvw: first use, approved identity, changed/revoked/lane mismatch, credential ordering, and fresh retry.
- TASK-260715-2a1cp7_connection-state-contract.puml on TASK-260715-2a1cp7: disconnected, connecting, full, degraded, reasserting, disconnecting, and failed.

## Completeness audit

Coverage is explicit for iOS and macOS UI and physical behavior; App Group versus Data Protection Keychain boundaries; mandatory host trust; full/degraded/reasserting/failure truthfulness; QUIC and route policies; disclosure and zero telemetry; diagnostic bounds, redaction, export preview, retention and deletion; shared identifiers, Page Objects, screenshots and visual review; VoiceOver, macOS keyboard, focus, text scaling, contrast and reduced motion; localization/pseudo-localization; legacy SOCKS decision/migration; and final physical M4 acceptance.