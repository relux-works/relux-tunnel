# Exercise macOS rollback, release withdrawal, and credential revocation

## Description
Rehearse recovery from a bad macOS release by withdrawing affected assets, restoring an approved prior stable candidate, preserving versioned evidence, handling data compatibility, and rotating or revoking compromised signing, notarization, or publication credentials.

## Scope
In scope: bad-candidate declaration, freeze and owner approval, stable asset rollback, immutable versioned asset treatment, GitHub release warning or withdrawal, prior checksum and provenance verification, application and extension downgrade compatibility, profile and data rollback limits, certificate and notary or GitHub credential compromise, revocation and rotation, user and support communication, audit trail, and timing. Out of scope: deleting evidence, reusing compromised credentials, changing product data formats ad hoc, App Store rollback, and pretending already-downloaded artifacts can be remotely removed.

## Acceptance Criteria
1. A safe rehearsal starts from a published test candidate, identifies an exact bad digest, blocks further promotion, and restores the stable name to a previously approved version without changing its immutable evidence. 2. The prior candidate is independently verified, installs and runs under documented data and extension compatibility rules, and any downgrade limitation has explicit user and support guidance. 3. Affected versioned assets remain traceable and are marked or withdrawn according to policy; stable and checksum assets never point to different versions. 4. Compromised certificate, notary credential, or GitHub token scenarios define immediate containment, revocation or rotation, audit, rebuild and resign requirements, and communication. 5. The rehearsal records commands, actors, timestamps, remote asset digests, install results, gaps, recovery time, and corrections without using production secrets destructively.
