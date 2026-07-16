# Triage App Review feedback and govern resubmission

## Description
Operate the review-response loop by preserving Apple messages, classifying requests or rejection reasons, reproducing reviewer conditions, responding with approved evidence, routing product or legal changes to new work, and resubmitting only a fully revalidated package.

## Scope
In scope: review status monitoring, message and attachment retention, redaction, Guideline mapping, fixture health, reproduction on exact build, evidence response, clarification, appeal decision by accountable owners, metadata-only versus binary-changing classification, affected-gate analysis, bug or task creation, new build and version rules, privacy or legal reapproval, package audit, resubmission, approval record, and credential rotation after review. Out of scope: misleading reviewers, ad hoc production changes, reusing stale acceptance for a changed binary, exposing confidential Apple communication broadly, and promising appeal success.

## Acceptance Criteria
1. Every reviewer message, date, review ID, referenced guideline, build, fixture state, response, attachment digest, and status transition is retained in a redacted evidence trail. 2. The team reproduces the condition when possible and separates misunderstanding, fixture or instruction failure, metadata change, legal or storefront issue, and binary behavior defect with an accountable owner. 3. Responses use approved factual evidence and any binary, entitlement, privacy, export, region, policy, screenshot, or instruction change invalidates and reruns all affected gates. 4. Resubmission selects a new or unchanged build only as permitted, receives a new go or no-go decision, and records the exact revised package and review identifiers. 5. Approval, rejection, appeal, withdrawal, and unresolved states have explicit next actions; review credentials are rotated or removed at the defined terminal point.
