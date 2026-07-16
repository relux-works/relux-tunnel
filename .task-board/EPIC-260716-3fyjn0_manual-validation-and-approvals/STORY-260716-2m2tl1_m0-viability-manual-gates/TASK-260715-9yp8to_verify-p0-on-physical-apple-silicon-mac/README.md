# Verify Gate P0 on a physical Apple-silicon Mac

## Description
Install and exercise the disposable macOS probe on the designated Apple-silicon Mac. Capture a repeatable end-to-end record of nested signing, VPN configuration, provider launch, app messaging, system approval behavior, repeated stop, and clean reinstall.

## Scope
In scope: physical Apple-silicon Mac and current supported macOS; development-signed host and embedded provider; nested signature and entitlement inspection; system VPN approval; manager save and reload; launch, message, stop, host termination, uninstall and reinstall; privacy-safe unified logs. Out of scope: Intel-only evidence, Developer ID release, notarization, DMG publication, packet forwarding, and changing the shipped SwiftPM application.

## Acceptance Criteria
1. Evidence records Mac model, exact macOS and Xcode, source revision, profile metadata, bundle versions, signing identity class, and test timestamp without private credentials. 2. Inside-out nested signature, designated requirement, embedded profile, and entitlement inspections all match the approved matrix. 3. The app saves and reloads one manager, starts the provider, receives the expected versioned message, and stops cleanly after required system approval. 4. At least ten start and stop cycles plus host termination and reinstall show no stale manager duplication, orphaned provider, crash, or unexplained launch failure. 5. A TASK-ID-scoped runbook and redacted result bundle supports repetition by another authorized operator.
