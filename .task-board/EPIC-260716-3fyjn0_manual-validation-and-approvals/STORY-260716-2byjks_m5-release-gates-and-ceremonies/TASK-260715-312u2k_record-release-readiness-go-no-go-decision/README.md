# Record the release-readiness go or no-go decision

## Description
Convene the accountable release gate over the exact candidate manifest and record an evidence-backed promote, hold, or reject decision for relay staging, macOS publication, iOS App Review submission, and approved storefronts.

## Scope
In scope: immutable candidate manifest, CI verdict, relay audit, macOS acceptance, iOS acceptance, regression matrix, privacy and legal audit, regional decision, public URLs, App Review package, credential readiness, open bugs and severity, exceptions and expiry, support and incident readiness, approvers, decision timestamp, promotion scope, hold conditions, and evidence signature. Out of scope: overriding blocking evidence without approved exception, approving unresolved legal regions, changing artifacts during meeting, implementing fixes, and calling a release successful before channel verification.

## Acceptance Criteria
1. The decision names exact source, relay staging digest, macOS asset digest, iOS App Store Connect build ID, versions, policy and metadata revisions, storefronts, and review-package revision. 2. Every required gate is present, current, passing, and independently verifiable or the decision is hold or reject with exact owner and resume condition. 3. Approved exceptions are scoped, risk accepted by authorized roles, time limited, visible in notes and review materials where relevant, and do not waive Gate A0, P0, signing, privacy, legal, or credential safety. 4. Product, engineering, security, privacy or legal, release, support, and App Review owners record approval according to the contract. 5. The signed decision and evidence index are retained before any production publication or App Review submission and later artifact or metadata change invalidates it.
