# Assemble the macOS host-extension release archive

## Description
Build and assemble the exact unsigned or ad-hoc release archive that will be signed, including ReluxProxyMac, its embedded tunnel extension, verified relay staging bytes, compliance resources, versions, and deterministic packaging metadata.

## Scope
In scope: clean generated workspace, approved Release scheme and architecture policy, host application, one embedded system extension or app extension as designed, Info.plists, minimum deployment target, relay manifest and assets, licenses and notices, privacy and support resources where required, marketing and build versions, symbols, timestamps or filesystem normalization before signing, archive inventory, and no-diff input capture. Out of scope: Developer ID signing, notarization, DMG creation, product feature changes, rebuilding relay assets, and altering approved legacy migration behavior.

## Acceptance Criteria
1. A clean protected or credential-free build produces one archive with the approved host, exactly one embedded packet-tunnel provider, required frameworks and resources, relay staging bytes, manifest, notices, and no undeclared executable. 2. Bundle IDs, versions, deployment targets, architecture slices, resource names, extension point, and host-to-extension relationships match the release contract. 3. Relay files and manifest are copied by digest from the approved staging bundle and reverified after archive assembly. 4. The archive inventory, build settings, source commit, dependency locks, generator and Xcode versions, symbols, and pre-sign hashes are recorded without secrets. 5. Missing or duplicate extensions, unexpected executables or dynamic libraries, stale relay bytes, version drift, wrong architecture, dirty generation, or missing compliance resources fail before signing.
