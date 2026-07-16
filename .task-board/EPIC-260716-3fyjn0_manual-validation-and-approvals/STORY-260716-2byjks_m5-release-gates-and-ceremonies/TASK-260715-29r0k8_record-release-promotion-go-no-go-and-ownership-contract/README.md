# Record the release promotion, go or no-go, and ownership contract

## Description
Define the cross-platform release control model that identifies candidate artifacts, required gates, role separation, approvals, promotion order, abort criteria, rollback authority, communications, evidence retention, and handoff to App Review.

## Scope
In scope: source and version manifest, relay staging bundle, macOS and iOS candidate IDs, required CI and acceptance verdicts, product, security, privacy, legal, release and App Review roles, separation of duties, GitHub and App Store channel order, release windows, go or no-go quorum, exception policy, abort and resume, rollback authority, evidence index, retention, and post-release ownership. Out of scope: implementing workflows, making legal decisions, issuing credentials, approving a candidate without evidence, and product feature changes.

## Acceptance Criteria
1. A TASK-ID-scoped contract identifies every candidate input and immutable digest or build ID and maps each promotion gate to evidence, owner, approver, and expiration. 2. No single low-privilege actor can change source, approve all gates, sign, publish, and erase evidence; emergency authority and audit are explicit. 3. Promotion order prevents relay, macOS, iOS, metadata, privacy, and review materials from referring to different candidate versions. 4. Abort, retry, exception, withdrawal, rollback, credential revocation, communication, and post-release monitoring decisions have named authority and deterministic state transitions. 5. Product, engineering, security, privacy or legal, and release owners approve the contract or unresolved ownership and approval choices remain blockers.
