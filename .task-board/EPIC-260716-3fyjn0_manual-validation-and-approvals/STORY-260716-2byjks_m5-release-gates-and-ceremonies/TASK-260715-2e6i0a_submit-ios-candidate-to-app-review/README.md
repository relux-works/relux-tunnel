# Submit the approved iOS candidate to App Review

## Description
Select the go-approved App Store Connect build, apply the audited metadata, privacy, export, storefront, review notes and secure fixture fields, submit for review, and preserve every server state and submission identifier.

## Scope
In scope: go or no-go decision verification, exact build selection lock, version and phased-release choice if approved, metadata and screenshots, privacy and support URLs, App Privacy and export answers, age and content declarations, storefronts, review notes and attachments, secure review credentials, contact, submit action, server validation, submission and review IDs, state polling, notification, evidence, cancellation before review where supported, and credential cleanup. Out of scope: changing the binary, inventing missing legal answers, enabling unapproved regions, putting secrets in ordinary notes, responding to reviewer questions beyond initial submission, and declaring acceptance before Apple review.

## Acceptance Criteria
1. Submission consumes the exact go-approved App Store Connect build ID and package revisions and revalidates that no candidate, metadata, URL, policy, credential, or storefront input changed. 2. All required App Store Connect fields and declarations are populated from audited artifacts and secure review credentials are confined to approved credential fields with current expiry and health. 3. The submit response, submission and review IDs, timestamps, selected build, metadata export, storefronts, package digests, and state transitions are retained and redacted. 4. Server validation error, stale build, broken URL, expired fixture, changed privacy answer, unapproved region, missing agreement, role failure, or new warning prevents or withdraws submission safely. 5. A successful task state means submitted and traceable for review, not approved or released, and the owner receives monitoring and response-handoff instructions.
