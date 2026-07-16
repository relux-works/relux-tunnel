# Externalize, localize, and pseudo-localize M4 copy

## Description
Move all M4 user-facing text into the approved localization system, implement the launch locale/fallback decision, provide translator context for privacy/security terminology, and make layouts resilient to pseudo-localization and text expansion.

## Scope
In scope: String Catalog or approved equivalent, source keys, plural/format placeholders, dates/numbers, SSH/security terminology comments, approved launch translations, fallback, missing/stale key detection, privacy-copy version parity, pseudo-locale schemes, expansion, right-to-left behavior per decision, snapshot fixtures, accessibility pronunciation/context, and CI validation. Out of scope: inventing unapproved translations, regional licensing/storefront availability, public privacy-policy hosting, and unrelated legacy strings unless migration UI uses them.

## Acceptance Criteria
1. Every M4 visible/accessibility string, error, menu command, notification, privacy/support text, and help label resolves through one reviewed localization resource with stable keys and translator context. 2. Launch locales and fallback exactly match the decision; missing, stale, placeholder-mismatched, or privacy-version-mismatched strings fail validation rather than silently shipping. 3. Variable substitution, plurals, dates/numbers, fingerprints, host/account display, error codes, and technical terms remain safe and correctly ordered across locales. 4. Pseudo-localization, long-text expansion, and required right-to-left rows render all M4 states without truncating critical evidence/actions or breaking focus/accessibility. 5. Swift/CI and snapshot tests record locale matrix, missing-key checks, screenshot diffs, accessibility review, and approved translation provenance.
