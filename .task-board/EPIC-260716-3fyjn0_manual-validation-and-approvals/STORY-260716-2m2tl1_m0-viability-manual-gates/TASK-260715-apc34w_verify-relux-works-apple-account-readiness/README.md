# Verify Relux Works Apple Developer account readiness

## Description
Audit the external Apple Developer account prerequisites for Gate P0 before creating identifiers or code-signing assets. Runs unattended after Ceremony C1 (TASK-260728-q5kjta) using the authenticated portal session and Keychain access granted there; the human is not present for this task. Record the organization, team, responsible operators, agreements, device registrations, and capability-management access without copying secrets into project artifacts.

## Scope
In scope: organization enrollment required by App Review Guideline 5.4, legal entity and team identifier, current paid-program status, required agreements, least-privilege roles for identifiers and profiles, registered physical Apple-silicon Mac inventory, and named owners for portal and device actions. The physical-iPhone registration is recorded as a named deferred gap under ADR-024, never as a pass and never as a failure. Out of scope: performing the human grants themselves (TASK-260728-q5kjta owns Ceremony C1), changing product architecture, purchasing hardware, storing login sessions, recovery keys, certificates, private keys, or personally identifying account screenshots.

## Acceptance Criteria
1. A TASK-ID-scoped readiness report records organization status, non-secret team identifier, required agreements, role-to-action matrix, registered test-device identifiers in privacy-safe form, and accountable owners. 2. Evidence confirms an authorized operator can view or manage Network Extension capabilities, identifiers, certificates, profiles, and test devices. 3. The report identifies every missing agreement, role, device registration, or external approval as a concrete blocker with owner and resolution action. 4. App Review organization eligibility is assessed separately from technical portal access. 5. No credential, token, certificate private key, recovery code, or full device identifier is stored in the repository or board.
