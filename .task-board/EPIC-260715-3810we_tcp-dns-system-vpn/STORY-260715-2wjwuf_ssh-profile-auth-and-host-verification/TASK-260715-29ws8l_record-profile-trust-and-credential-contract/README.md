# Record the SSH profile, trust, and credential boundary contract

## Description
Produce the task-scoped production contract that carries one configured SSH profile from the containing app to the provider without secrets, resolves opaque Keychain references inside the extension, evaluates approved host identity before authentication, and returns stable bootstrap evidence and errors.

## Scope
In scope: profile schema and version, canonical hostname or address, display name, port, account, credential reference, approved host algorithms and SHA-256 fingerprints, provenance and timestamps, App Group snapshot ownership, atomic update and generation rules, Keychain query contract, trust-required and changed-key outcomes, and diagnostic redaction. Out of scope: profile editor UI, key import or generation, trust confirmation UI, password auth, engine selection, routing, multi-lane identity checks, ProxyJump, and arbitrary shell access.

## Acceptance Criteria
1. A TASK-ID-scoped contract defines every field, validation rule, owner, storage location, generation rule, and secret or non-secret classification. 2. App Group and providerConfiguration data contain only non-secret profile data and opaque Keychain references. 3. Host policy receives algorithm and raw key evidence before authentication and has explicit first-use, approved, changed, unsupported, and revoked outcomes. 4. Credential lifetime, Keychain accessibility, access group, passphrase handling, cancellation, and best-effort memory clearing are specified without claiming impossible guarantees. 5. The contract names the M0 selected-engine evidence it consumes and the M4 UI operations that will create or replace approved trust.
