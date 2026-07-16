# Build the changed-host-key blocking recovery flow

## Description
Build a separate high-severity iOS/macOS flow for a server presenting a key that differs from approved trust. Keep connection stopped, explain plausible benign and hostile causes, show old and new evidence, and require inspected explicit replacement or cancellation.

## Scope
In scope: blocking error entry, approved and presented algorithms/fingerprints, canonical host, last-seen/provenance context, risk copy, verification guidance, copy actions, explicit replace trust confirmation, cancel, profile navigation, stale/conflict handling, retry only after atomic replacement, accessibility, identifiers, and screenshots. Out of scope: first-use accept reuse, automatic replacement, DNS or network debugging, bypass for one connection, password auth, and provider implementation.

## Acceptance Criteria
1. The flow is visually and semantically distinct from first use, labels the connection unsafe/stopped, and shows complete approved and presented SHA-256 fingerprints plus algorithms. 2. No connect/retry path can proceed while the mismatch remains; replace requires a second explicit confirmation referencing the reviewed new fingerprint. 3. Cancel, dismissal, app backgrounding, stale generation, concurrent profile edit, replacement failure, and another changed key leave prior trust intact and no active SSH authentication. 4. Successful replacement atomically revokes the prior current identity, retains auditable non-secret metadata per policy, and enables a fresh explicit retry only. 5. iOS/macOS UI and security tests cover mismatch, alternate algorithm, reversion, stale evidence, replace/cancel, VoiceOver/keyboard, text scaling, and screenshot review.
