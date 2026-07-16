# Configure Developer ID, notarization, and the protected macOS release environment

## Description
Provision and validate the least-privilege CI inputs and ownership needed to sign the macOS host and extension, submit notarization, publish GitHub assets, rotate credentials, and recover from compromise.

## Scope
In scope: Developer ID Application certificate and private key import path, compatible Developer ID provisioning profiles, notarization App Store Connect API or approved credential, GitHub Environment secrets and reviewers, publication token scope, temporary keychain, certificate chain, secret masking, expiry monitoring, rotation, revocation, dry-run validation, and named owners. Out of scope: storing secrets in source, board resources, artifacts, or fork jobs; iOS credentials; building archives; notarization submission logic; and granting account-wide administrator access without need.

## Acceptance Criteria
1. Each credential has a named owner, minimum role and scope, protected-environment binding, creation and expiry date, rotation and revocation procedure, and no plaintext copy in the repository or board. 2. A trusted release job imports signing material into an ephemeral keychain, validates certificate chain, Team ID, key match, profile identity and expiry, then removes the keychain on success, failure, or cancellation. 3. The notary credential can submit and read only the required team workflow and the GitHub token can update only the intended private release assets. 4. Forks, pull requests, unapproved branches, ordinary runners, logs, caches, and retained artifacts cannot access or reconstruct any credential. 5. Safe dry runs cover valid, missing, expired, revoked, wrong-team, wrong-profile, masked-log, cancellation, rotation, and emergency-revocation cases.
