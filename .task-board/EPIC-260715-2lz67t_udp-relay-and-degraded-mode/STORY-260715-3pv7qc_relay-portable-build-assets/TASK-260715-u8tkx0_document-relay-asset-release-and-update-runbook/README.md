# Document the relay asset release, update, and rollback runbook

## Description
Publish the developer and release-engineering procedure for pinning, building, verifying, bundling, updating, auditing, and rolling back the four relay assets while preserving manifest, notice, provenance, and later signing boundaries.

## Scope
In scope: prerequisites; clean build commands; target matrix; version and protocol changes; artifact naming; manifest and notice generation; reproducibility and smoke gates; bundle integration check; source pin update; dependency review; checksum rotation; rollback; incident response for mismatches; ownership; M2 versus M5 gates. Out of scope: end-user remote bootstrap troubleshooting, app store submission steps, organization-wide incident policy, implementing automation, publishing standalone relay downloads, and claiming assets are signed when only the containing app protects them.

## Acceptance Criteria
1. Another authorized developer can rebuild all four assets and their manifest from pinned inputs using only documented commands and obtains the expected verification outputs. 2. The update procedure orders source and dependency review, protocol compatibility, build, notices, provenance, reproducibility, smoke, manifest, bundle validation, and downstream bootstrap testing with no bypass. 3. Rollback preserves a known manifest and exact bytes, explains remote version coexistence or replacement, and never directs operators to execute an unverified remote file. 4. A responsibility table clearly separates relay source integrity and bundle hashing from application signing, notarization, attestation, release approval, and notices owned elsewhere. 5. Troubleshooting covers hash drift, missing target, unsupported runtime, notice failure, compromised asset response, and credential-safe evidence collection and links each relevant board task.
