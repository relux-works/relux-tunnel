# Upload, process, and distribute the TestFlight candidate

## Description
Upload the exact inspected iOS candidate to App Store Connect, wait for processing, capture server validation, attach approved beta information, and distribute the unchanged build to the intended TestFlight group.

## Scope
In scope: artifact digest verification, App Store Connect API authentication, upload transport, progress and timeout, processing polling with bounded backoff, server warning and error handling, build ID, encryption or export answer inputs from approved record, beta release notes and contact where required, internal group assignment, optional external beta review only when approved, notifications, idempotent retry, cancellation, and evidence. Out of scope: rebuilding or resigning after upload, App Review submission, inventing legal answers, using personal production credentials, and automatically accepting server warnings outside policy.

## Acceptance Criteria
1. Upload starts only for the evidence-approved archive or export digest and records marketing version, build number, bundle ID, source commit, upload request, and resulting App Store Connect build ID. 2. The job waits for terminal processing and fails on invalid binary, entitlement, privacy, encryption, symbol, duplicate build, or other blocking server response. 3. The exact processed build is assigned to the approved TestFlight group with reviewed beta notes and no unapproved external testers or public link. 4. Retry and cancellation cannot create mixed candidate identity, duplicate versions, duplicate group assignment, or leaked issuer credentials. 5. Controlled network loss, processing timeout, duplicate upload, invalid binary, warning policy, missing agreement, wrong role, cancellation, and successful distribution paths produce redacted auditable evidence.
