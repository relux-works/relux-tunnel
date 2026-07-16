# Document M1 runtime ownership, operation, and extension seams

## Description
Write the developer and operator documentation for the implemented M1 runtime. Explain component ownership, startup and shutdown, message versions, diagnostics, failure mapping, test entry points, and the stable seams where M2 UDP and M3 resilience can extend behavior without moving authority to the app.

## Scope
In scope: architecture overview, focused startup and teardown sequence, dependency table, message compatibility, state and capability semantics, diagnostics privacy, troubleshooting, harness commands, migration boundary, and M2 or M3 extension guidance. Out of scope: end-user onboarding copy, release notes, privacy policy, App Review notes, implementation changes, and undocumented promises about future modes.

## Acceptance Criteria
1. Documentation matches the implemented modules and names their public and internal ownership boundaries. 2. A sequence diagram covers successful start, partial failure rollback, app termination, and stop. 3. Capability and error tables state exactly what M1 reports and do not label TCP plus safe DNS as full UDP capability. 4. Reproduction commands cover unit tests, harness scenarios, both provider builds, and diagnostics redaction checks. 5. Links point to the M0 decisions consumed and the concrete M2, M3, M4, and M5 handoff boundaries.
