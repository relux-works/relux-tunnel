# Implement the shared profile-editor presentation model

## Description
Implement a platform-neutral observable model for profile list, editor, validation, key selection, dirty state, asynchronous repository operations, and safe conflict handling. Views receive presentation-ready state and typed actions without accessing Keychain or App Group directly.

## Scope
In scope: list loading, draft creation, field validation, normalized previews, selected-key metadata, save eligibility, duplicate profiles, dirty-discard confirmation, optimistic-operation gating, repository and Keychain errors, selected/active profile constraints, deletion confirmation, relaunch restore, accessibility-ready labels/errors, and injectable clocks/services. Out of scope: SwiftUI layout, host trust, connection controls, file parsing, key generation implementation, and legacy migration.

## Acceptance Criteria
1. The model exposes deterministic states and actions for empty, loading, loaded, editing, saving, deleting, conflict, and recoverable failure without leaking repository or Keychain implementation types. 2. Host/address, port, account, display name, and key selection validation matches the storage contract and produces field-specific accessible messages. 3. Save, discard, delete, selected-profile change, active-profile conflict, concurrent repository generation, and retry actions are idempotent or explicitly guarded. 4. Secret bytes and passphrase values are never retained in observable state; only opaque references and approved metadata are exposed. 5. Swift tests cover every validation boundary, transition, injected failure, duplicate action, relaunch, and conflict without wall-clock sleeps.
