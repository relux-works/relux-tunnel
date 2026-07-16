# Validate generated workspace determinism and the preserved SwiftPM product

## Description
Add credential-free CI that regenerates the approved Xcode workspace, detects drift, builds its stable schemes, and preserves the current SwiftPM executable, tests, application packaging boundary, and release history until migration approval.

## Scope
In scope: pinned generator bootstrap, no-diff regeneration, project and scheme inventory, Release and Debug configuration inputs, deployment targets, swift test, legacy universal or supported architecture build, packaging smoke where credential-free, default and version invariants, dependency locks, clean checkout, and diagnostic artifacts. Out of scope: signing, notarization, retiring the legacy product, changing migration behavior, and full Apple UI or physical-device tests.

## Acceptance Criteria
1. A clean runner installs or resolves the pinned generator, regenerates the workspace, and fails on any unexplained tracked diff or missing approved target, scheme, configuration, or deployment target. 2. Credential-free builds cover every approved generated scheme that can build without production identities and clearly mark signing-only checks as not executed. 3. The existing SwiftPM tests and executable build pass and the legacy application or DMG packaging contract remains reproducible at its declared boundary. 4. Logs record source revision, generator, Xcode, Swift, SDK, deployment targets, schemes, dependency locks, and commands without secrets. 5. Controlled target removal, generator drift, identifier drift, legacy regression, and dirty-generation fixtures fail the gate.
