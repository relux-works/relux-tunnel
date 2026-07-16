# Add credential-free iOS and macOS host-extension build matrix

## Description
Build the generated iOS and macOS containing apps and packet-tunnel extensions without production credentials, inspect static target relationships and entitlement templates, and keep signing-required assertions separate.

## Scope
In scope: approved schemes and configurations, iOS simulator or generic device compilation as supported, macOS compilation, host-to-extension embedding, Info.plist and build-setting inspection, entitlement source files, App Group and Keychain identifiers, dependency linkage, architecture slices, bundle version propagation, warnings policy, and result bundles. Out of scope: claiming valid distribution profiles, code-signature verification, notarization, TestFlight, App Store validation, and physical-device entitlement proof.

## Acceptance Criteria
1. The matrix builds every approved iOS and macOS host and extension scheme from a clean generated workspace using only credential-free settings. 2. Static checks verify one embedded provider per host, approved bundle relationships, deployment targets, architecture policy, version propagation, extension-safe linkage, and expected entitlement templates. 3. Jobs explicitly separate compile and static checks from distribution signing and never report missing production-credential checks as passed. 4. Build logs and artifacts contain no profiles, certificates, private keys, issuer data, user home paths, or other secret material. 5. Controlled identifier, embedding, entitlement-template, architecture, linkage, or version drift fails with an actionable target-specific diagnostic.
