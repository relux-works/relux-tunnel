# Configure App Store Connect and the protected iOS distribution environment

## Description
Provision and validate least-privilege Apple Distribution, provisioning, App Store Connect API, agreement, and protected CI inputs for archive export, TestFlight upload, validation, build management, rotation, and revocation.

## Scope
In scope: Apple Distribution certificate and private key import path, host and extension distribution profiles, App Store Connect issuer, key ID and private key or approved authentication, minimum roles, app access, agreements and account readiness, GitHub Environment reviewers, temporary keychain, secret masking, expiry monitoring, device-independent validation, rotation, revocation, and named owners. Out of scope: plaintext secrets in repository or board, broad administrator access without need, Developer ID credentials, archive build logic, App Review legal decisions, and production credentials in tests.

## Acceptance Criteria
1. Every certificate, profile, issuer credential, App Store Connect role, agreement, and environment reviewer has an accountable owner, minimum scope, expiry or review date, rotation, and revocation path. 2. Trusted jobs import signing material into an ephemeral keychain, validate key and certificate match, Team ID, profile IDs, bundle coverage, entitlements, expiry, and App Store Connect app access, then clean up on all exits. 3. Upload or build-management credentials cannot manage unrelated apps or access account functions not required by the workflow where App Store Connect permits scoping. 4. Forks, pull requests, unapproved branches, ordinary runners, logs, caches, and retained artifacts cannot access certificate keys, issuer keys, profiles containing sensitive metadata, or sessions. 5. Dry runs cover valid, missing, expired, revoked, wrong-team, wrong-bundle, wrong-role, unsigned-agreement, masked-log, cancellation, rotation, and emergency-revocation cases.
