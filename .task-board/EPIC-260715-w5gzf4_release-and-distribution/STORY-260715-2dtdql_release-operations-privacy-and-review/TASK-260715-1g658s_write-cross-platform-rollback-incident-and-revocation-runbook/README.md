# Write the cross-platform rollback, incident, and credential-revocation runbook

## Description
Define coordinated response for a bad relay, macOS or iOS candidate, privacy or legal mismatch, App Review rejection, compromised dependency or builder, leaked review fixture, and compromised signing, notarization, GitHub, or App Store Connect credential.

## Scope
In scope: detection and severity, release freeze, owner and incident roles, evidence preservation, stable macOS rollback and withdrawal, TestFlight stop and supersession, App Review withdrawal or correction, relay manifest rollback, region disablement, privacy or metadata correction boundaries, review-fixture rotation, certificate and API credential revocation, rebuild and resign criteria, user and reviewer communication, support scripts, recovery validation, and tabletop. Out of scope: hiding incidents, deleting audit history, changing uploaded binaries in place, reusing compromised identities, promising remote deletion from user devices, and destructive production exercises without approval.

## Acceptance Criteria
1. Each incident class has trigger, severity, decision authority, containment, evidence, channel actions, credential actions, communication, recovery, and closure criteria. 2. The runbook distinguishes what can be rolled back or withdrawn on GitHub, TestFlight, App Review, and installed devices and never claims unavailable remote control. 3. Relay, application, metadata, privacy, storefront, and review-fixture versions remain traceable through rollback and any replacement reruns all invalidated gates. 4. Certificate, profile, issuer key, GitHub token, builder, dependency, and review credential compromise paths identify revocation, rotation, re-sign or rebuild, and trust-notification requirements. 5. A tabletop exercises one bad-binary and one credential or privacy incident, recording participants, timing, decisions, commands, evidence, gaps, and corrected runbook revision.
