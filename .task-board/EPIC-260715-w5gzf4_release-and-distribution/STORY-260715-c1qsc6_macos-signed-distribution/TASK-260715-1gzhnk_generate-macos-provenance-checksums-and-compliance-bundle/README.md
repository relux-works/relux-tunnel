# Generate macOS checksums, provenance, and compliance evidence

## Description
Assemble a macOS distribution evidence bundle that binds the archive, signed application, DMGs, entitlements, profiles, certificate metadata, notarization, Gatekeeper results, relay provenance, SBOMs, notices, versions, and tests.

## Scope
In scope: artifact and nested-code hashes, source and dependency materials, build and signing invocations, generator and Xcode versions, release versions, public signing identity and profile metadata, entitlement reports, notarization request and ticket, Gatekeeper output, relay staging attestations, SBOM and notice references, install tests, approvals, retention, attestation, and evidence index. Out of scope: private keys, passwords, issuer secrets, unredacted notarization logs, user data, iOS evidence, and replacing independent verification.

## Acceptance Criteria
1. The evidence index identifies every macOS artifact by digest and traces it to source commit, locks, toolchains, unsigned input, signed output, relay staging bundle, versions, and release invocation. 2. Public certificate, Team ID, profile identifiers and expiry, exact signed entitlements, designated requirements, notarization request and ticket, Gatekeeper result, and test environment are present without secret material. 3. Checksums cover versioned and stable DMGs, application and extension, relay assets, manifests, SBOMs, notices, and evidence archive itself. 4. Provenance and approval signatures use the approved trust mechanism and verification succeeds independently of the build runner. 5. Missing, inconsistent, unredacted, tampered, expired, wrong-candidate, or unverified evidence fails the publication gate.
