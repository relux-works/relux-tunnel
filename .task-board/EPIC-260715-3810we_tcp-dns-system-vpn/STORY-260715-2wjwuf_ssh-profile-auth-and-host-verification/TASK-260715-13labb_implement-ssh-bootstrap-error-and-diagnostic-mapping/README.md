# Implement SSH bootstrap errors, retry classes, and diagnostics mapping

## Description
Define and implement the stable privacy-safe error taxonomy and diagnostic projection for profile load, physical-path resolution, endpoint connect, host verification, Keychain access, public-key authentication, negotiation, cancellation, and session close. Mark only safe transient failures retryable for later lifecycle use.

## Scope
In scope: typed internal causes, public provider error domain and codes, user-action category, retryable or terminal classification, underlying-error redaction, algorithm and endpoint-family context, cancellation distinction, OSStatus mapping without secrets, snapshot integration, and golden tests. Out of scope: implementing reconnect, UI wording, analytics, raw server banners, destination logging, stack traces in support export, and weakening authentication failures for availability.

## Acceptance Criteria
1. Every bootstrap stage maps to one documented stable public code while preserving the internal cause for tests without exposing secrets or full addresses. 2. Authentication rejection, host mismatch, unsupported host key, corrupt profile, and inaccessible credentials are terminal until configuration or trust changes. 3. Path unavailable, bounded connect timeout, and selected transient transport failures are distinguishable for M3 without retrying in this M1 task. 4. Cancellation and user stop do not surface as authentication or host-security failure. 5. Golden and redaction tests cover representative selected-engine errors, NW or socket errors, OSStatus values, hostile server text, and prohibited data.
