# Add credential-free macOS target build matrix

## Description
Build the active generated macOS containing app and packet-tunnel system extension without production credentials, inspect static target relationships and entitlement templates, and keep signing-required and deferred-iOS assertions separate.

## Scope
In scope: approved active macOS schemes and Debug/Release configurations, credential-free macOS compilation, host-to-extension embedding, Info.plist and build-setting inspection, entitlement source files, prohibited macOS App Group/Keychain identifiers, dependency linkage, architecture slices, bundle version propagation, warnings policy, and result bundles. Deferred boundary: iOS target definitions remain preserved but are not generated or built under ADR-024/027; their future compile/signing workflows belong to the deferred iOS owners. Out of scope: claiming valid distribution profiles, code-signature verification, notarization, TestFlight, App Store validation, physical-device entitlement proof, and activating iOS work.

## Acceptance Criteria
1. The matrix builds every approved active macOS host and extension scheme from a clean generated workspace using only credential-free settings; deferred iOS schemes are absent and reported deferred. 2. Static checks verify one embedded provider, approved bundle relationships, deployment targets, architecture policy, version propagation, extension-safe linkage, expected entitlement templates, and the prohibited macOS App Group/Keychain values. 3. Jobs explicitly separate compile and static checks from distribution signing and never report missing production-credential or deferred-iOS checks as passed. 4. Build logs and artifacts contain no profiles, certificates, private keys, issuer data, user home paths, or other secret material. 5. Controlled identifier, embedding, entitlement-template, architecture, linkage, version, or unexpected-iOS-scheme drift fails with an actionable target-specific diagnostic.
