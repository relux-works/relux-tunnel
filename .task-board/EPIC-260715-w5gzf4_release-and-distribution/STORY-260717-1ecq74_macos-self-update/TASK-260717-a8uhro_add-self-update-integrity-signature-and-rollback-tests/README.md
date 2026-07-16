# TASK-260717-a8uhro: add-self-update-integrity-signature-and-rollback-tests

## Description
Automated tests for update safety: reject appcast entries with missing/invalid EdDSA signatures, reject downgrade below installed version unless an explicit rollback channel is used, reject payloads whose Developer ID / team identifier does not match, and verify a failed/interrupted update leaves the installed app intact. AC: a hostile-appcast fixture suite (tampered signature, wrong team id, truncated payload, downgrade) all fail closed; happy-path signed update passes; tests run in CI without network by using local fixtures.

## Scope
(define task scope)

## Acceptance Criteria
(define acceptance criteria)
