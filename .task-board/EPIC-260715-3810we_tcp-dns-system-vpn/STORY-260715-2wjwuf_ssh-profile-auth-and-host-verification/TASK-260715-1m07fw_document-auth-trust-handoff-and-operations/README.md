# Document SSH profile, trust, credential, and operator handoffs

## Description
Document the implemented M1 profile snapshot, Keychain, host-verification, authentication, endpoint evidence, errors, tests, and operational troubleshooting. Define the exact M4 handoff for profile editing, key management, first-use confirmation, and explicit host-key replacement.

## Scope
In scope: schema and storage diagram, sequence from profile reference to authenticated session, secret boundary, trust outcomes, supported key types from M0, error and retry table, provider-context diagnostics, test commands, credential rotation and cleanup responsibilities, and M4 integration interface. Out of scope: final UI copy, key import implementation, privacy policy, password auth, ProxyJump, production support export, and implementation changes.

## Acceptance Criteria
1. Documentation identifies every secret and non-secret field, its owner, storage, access group, lifetime, and prohibited destinations. 2. A sequence diagram proves host evidence is evaluated before credential retrieval and authentication. 3. First-use, approved, changed, revoked, inaccessible credential, auth rejection, cancellation, and endpoint evidence behaviors match implementation and tests. 4. M4 handoff lists exact operations and inputs for create or edit profile, import or generate key, approve first use, and explicitly replace changed trust. 5. Reproduction commands cover unit, integration, and physical provider tests without embedding credentials or private fixture data.
