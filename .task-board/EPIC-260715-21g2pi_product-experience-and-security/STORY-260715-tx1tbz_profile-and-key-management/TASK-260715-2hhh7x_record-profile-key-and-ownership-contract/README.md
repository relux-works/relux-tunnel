# Record the profile, key, and ownership contract

## Description
Produce the binding M4 contract for profile fields, normalization, credential formats, storage ownership, publication, lifecycle, deletion, error handling, and iOS/macOS behavior. This contract reconciles the user-facing editor with the existing M1 provider snapshot and Keychain resolver contracts before production writes begin.

## Scope
In scope: schema versioning, stable profile and key IDs, generations, display name, canonical host or literal address, port, account, opaque key/passphrase references, selected profile, validation/defaults, approved key formats and generation algorithms, import/export policy, App Group and Keychain access matrix, atomic publication, concurrent edits, active-session restrictions, deletion/reference rules, error taxonomy, migration seams, accessibility and test hooks. Out of scope: implementation, host-trust decisions, password-only auth, OpenSSH config import, ProxyJump, arbitrary shell access, and the legacy SOCKS product decision.

## Acceptance Criteria
1. A TASK-ID-scoped contract defines every persisted and presented field, type, default, normalization rule, validation error, schema version, and compatibility rule. 2. A least-privilege matrix proves raw keys and passphrases exist only in the approved Data Protection Keychain access group while App Group and providerConfiguration values remain non-secret and opaque. 3. The selected import formats, generated algorithms, public/private export policy, secret lifetime, and unsupported-key behavior are explicit and compatible with the accepted M0/M1 SSH engine. 4. Create, edit, select, publish, delete, key replacement, active-session conflict, relaunch, corruption, and concurrent-write state transitions have deterministic outcomes. 5. The contract identifies exact downstream tasks and test vectors and contains no credentials or secret samples.
