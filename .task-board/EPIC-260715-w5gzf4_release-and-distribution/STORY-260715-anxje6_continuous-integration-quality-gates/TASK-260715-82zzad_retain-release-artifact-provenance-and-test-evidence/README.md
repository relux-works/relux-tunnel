# Retain release artifact provenance and test evidence

## Description
Define and implement the evidence bundle and retention policy that binds every build, test, signing, distribution, and review artifact to the exact release candidate without retaining private credential material.

## Scope
In scope: source commit, dirty-state assertion, dependency lockfiles, generator and toolchain versions, SDK and runner identity, relay manifest and protocol version, bundle versions, artifact hashes, signing certificate public metadata, profiles identifiers and expiry without secrets, test results, notarization and App Store Connect IDs, SBOMs, notices, attestations, approvals, retention classes, access control, and deletion. Out of scope: storing private keys, certificate passwords, issuer private keys, session cookies, production profiles when prohibited, user traffic, and indefinite retention without policy.

## Acceptance Criteria
1. One versioned evidence schema identifies required fields and files for credential-free CI, relay, macOS, iOS, and App Review stages. 2. Every release artifact and test result is addressable by cryptographic digest and exact candidate commit, lockfiles, toolchains, relay manifest, protocol, marketing version, and build version. 3. Signing and distribution metadata records public identity, team, profile identifiers, expiry, notarization request, and App Store Connect build IDs without secret key material. 4. Retention, access, legal hold where applicable, expiration, and deletion are explicit by evidence class and enforced or auditable. 5. Completeness, schema, digest, redaction, tamper, missing-file, and expiration fixtures fail the evidence gate.
