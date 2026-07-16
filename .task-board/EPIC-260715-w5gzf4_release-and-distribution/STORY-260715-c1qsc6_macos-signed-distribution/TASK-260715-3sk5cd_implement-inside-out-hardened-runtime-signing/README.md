# Implement inside-out hardened-runtime signing for the macOS archive

## Description
Sign every nested framework, helper, tunnel extension, and containing application in the approved inside-out order with the intended Developer ID identity, profiles, timestamps, hardened runtime, and explicit entitlements.

## Scope
In scope: ephemeral keychain use, certificate selection by fingerprint, profile placement, nested traversal, framework and executable signatures, extension entitlements, host entitlements, hardened runtime, secure timestamp, designated requirements, no deep-sign shortcut, strict verification, cleanup, idempotent retry from unsigned inputs, and redacted logs. Out of scope: DMG signing if separately required, notarization, changing entitlements to make verification pass, using ad-hoc signatures for release, and preserving imported private keys after the job.

## Acceptance Criteria
1. Signing starts from recorded unsigned archive hashes, signs every approved nested path exactly once in inside-out order, and uses the certificate fingerprint and entitlements selected by the contract. 2. Hardened runtime and secure timestamps are present where required, profiles match signed identifiers, and no deep, force, wildcard, or ad-hoc fallback hides a missing signing rule. 3. Strict codesign verification, designated-requirement checks, bundle traversal, and the independent entitlement verifier pass for the complete application. 4. A retry discards partial output and recreates the same signed topology from immutable unsigned inputs; cancellation removes the temporary keychain and partial candidate. 5. Wrong identity, wrong team, missing nested signature, modified post-sign byte, entitlement drift, expired certificate or profile, timestamp failure, keychain leak, and partial signing fail safely.
