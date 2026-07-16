# Implement the host-trust request presentation coordinator

## Description
Implement the app-side generation-safe coordinator that receives trust/auth outcomes, validates their version and profile context, chooses one presentation, publishes explicit user decisions through the repository, and drives retry or cancellation without holding live tunnel resources.

## Scope
In scope: trust-required and changed-key evidence, auth and Keychain failure projection, current profile/generation validation, foreground presentation queue, one-modal-at-a-time policy, duplicate/coalesced events, app relaunch, expired/stale requests, approve/replace/cancel/retry actions, command gating, metrics without fingerprints or secrets, and injectable services. Out of scope: provider host-key comparison, UI layout, key import, automatic reconnection, and background prompts.

## Acceptance Criteria
1. Only evidence matching the current profile, canonical host, schema, generation, and supported algorithm can become a user-visible request; stale or malformed evidence is rejected safely. 2. Duplicate provider callbacks or relaunch recovery yield at most one current presentation and one repository mutation per explicit user action. 3. Approve and replace actions call distinct repository APIs, never store a passphrase/fingerprint in observable logs, and expose retry only after the new generation is durably published. 4. App backgrounding, termination, cancellation, profile edit/delete, concurrent connect, and provider timeout release presentation ownership and cannot leave an SSH session waiting for UI. 5. Swift tests cover every legal and illegal transition with controllable clocks/events and no fixed delays.
