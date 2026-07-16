# Implement protected and serialized release orchestration

## Description
Build the release-only workflow layer that consumes already-verified inputs, enters protected environments, serializes production publication, and delegates macOS, iOS, relay, and evidence jobs without exposing credentials to untrusted code.

## Scope
In scope: trusted tag or approved dispatch entry, immutable source checkout, candidate manifest input, environment approvals, reusable workflow interfaces, least-privilege tokens, macOS and iOS credential separation, concurrency groups, staged dependencies, dry run, idempotent retries, cancellation, partial-failure state, and promotion outputs. Out of scope: signing job internals, notarization commands, TestFlight implementation, legal approval, and bypassing failed prerequisite checks.

## Acceptance Criteria
1. Only an approved immutable commit and validated version manifest can enter protected release environments; pull-request and arbitrary-branch code cannot invoke production credentials. 2. macOS, iOS, relay, GitHub publication, and App Store Connect permissions are separately scoped and supplied only to the job that needs them. 3. A single production release is active at a time and retries are idempotent, reuse the same candidate inputs, and cannot duplicate versions or publish a mixed release. 4. Cancellation or any stage failure records state, revokes temporary material, withholds dependent publication, and emits an actionable resumable or rollback disposition. 5. Dry-run and controlled-failure tests prove approvals, job ordering, environment isolation, serialization, secret masking, and no partial promotion.
