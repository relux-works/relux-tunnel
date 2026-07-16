# Exercise TestFlight withdrawal, supersession, and credential revocation

## Description
Rehearse stopping distribution of a bad iOS beta, selecting and verifying a replacement build, preserving version history and evidence, communicating tester impact, and rotating or revoking compromised distribution credentials.

## Scope
In scope: stop testing or remove group access, build expiry and availability behavior, bad-build declaration, immutable build IDs, replacement candidate and new build number, tester notes, prior-build fallback limits, App Store Connect role and issuer compromise, distribution certificate and profile revocation, environment freeze, evidence preservation, communication, and timing. Out of scope: deleting App Store Connect history, reusing build numbers, changing an uploaded binary, production App Store rollback, and destructive credential tests against active production without approval.

## Acceptance Criteria
1. A safe rehearsal identifies an exact bad TestFlight build, stops or limits its distribution according to App Store Connect capabilities, and records what already-installed testers can still do. 2. A replacement uses a new monotonic build number, reruns every signing and TestFlight gate, and cannot inherit acceptance evidence from the withdrawn binary. 3. Build history, beta notes, tester groups, evidence, and reason remain traceable and no workflow claims that an uploaded binary was replaced in place. 4. Compromised certificate, profile, issuer key, or account role scenarios define containment, revocation or rotation, environment freeze, rebuild and resign requirements, and notification. 5. The rehearsal records actors, commands or APIs, build IDs, timestamps, group state, device observations, recovery time, gaps, and corrections without exposing credentials.
