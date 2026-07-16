# Write the cross-platform release operations runbook

## Description
Create an executable operator runbook for promoting a verified relay bundle, macOS candidate, iOS TestFlight and App Store candidate, compliance evidence, metadata, review package, and communications through protected channels.

## Scope
In scope: prerequisites, roles, environment checks, candidate manifest, version and tag validation, relay staging, CI verdicts, macOS signing and publication, iOS archive and TestFlight, physical acceptance, privacy and legal approvals, review package, go or no-go, App Review submission, release notes, support readiness, evidence retention, abort, retry, status communication, and post-action verification. Out of scope: implementation internals duplicated from platform runbooks, embedding secrets, skipping human approval boundaries, making legal decisions, and assuming commands succeeded without verification.

## Acceptance Criteria
1. The runbook gives ordered commands or workflow links, required roles and approvals, expected inputs and outputs, evidence checks, timing, and abort criteria from clean candidate through submission. 2. Relay, macOS, iOS, privacy, legal, support, and review versions cannot diverge and every transition verifies immutable digests or App Store Connect build IDs. 3. Credential setup and cleanup, environment protection, concurrency, retries, partial failures, service outages, release notes, communications, and support handoff are explicit. 4. A dry run or staging rehearsal by an operator other than the author completes without hidden knowledge and records duration, ambiguities, failures, and corrections. 5. The final runbook is versioned, accessible to on-call owners, references all rollback and incident paths, and contains no credentials or production personal data.
