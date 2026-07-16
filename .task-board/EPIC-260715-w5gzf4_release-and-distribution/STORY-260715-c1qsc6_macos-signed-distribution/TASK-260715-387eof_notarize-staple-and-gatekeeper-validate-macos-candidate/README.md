# Notarize, staple, and Gatekeeper-validate the macOS candidate

## Description
Submit the exact signed macOS application or DMG as required, preserve notarization evidence, staple tickets, and validate signatures and Gatekeeper behavior on clean supported systems.

## Scope
In scope: notarization submission by artifact digest, request ID, asynchronous polling with timeout and backoff, notarization log retrieval and redaction, accepted or invalid handling, stapling application and DMG as required, ticket validation, strict codesign verification, spctl Gatekeeper assessment, quarantine-based launch or install smoke, offline ticket check where supported, retry and credential cleanup. Out of scope: bypassing Gatekeeper, removing quarantine manually, resubmitting changed bytes under the same evidence, iOS validation, and ignoring warning or invalid responses.

## Acceptance Criteria
1. The submitted digest, notarization request ID, credential identity metadata, timestamps, response, and redacted log are bound to the candidate evidence. 2. Only an accepted response permits stapling; invalid, timeout, service error, changed bytes, missing ticket, or log retrieval failure leaves publication blocked with an explicit retry state. 3. Stapled application and DMG pass ticket validation, strict nested signature checks, and Gatekeeper assessment from a quarantined clean download context on a supported Apple-silicon Mac. 4. The candidate can be validated without relying on the build-machine keychain or clearing quarantine and the stapled artifact digest is recorded. 5. Controlled rejected, delayed, wrong-team, mutated-after-submit, missing-ticket, offline, cancellation, and service-recovery paths are exercised with no secret leakage or false success.
