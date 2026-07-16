# Define the Apple identifier and entitlement matrix

## Description
Decide the stable naming and least-privilege capability contract for the iOS and macOS containing apps and packet-tunnel extensions. Produce the exact matrix that portal provisioning, generated targets, archives, and automated entitlement checks will consume.

## Scope
In scope: four bundle identifiers; host-to-extension embedding; Network Extension packet-tunnel provider entitlement; App Group identifiers; Keychain access groups; development and distribution profile classes; team-prefix handling; environment naming; ownership and migration rules. Out of scope: creating portal records, issuing certificates, adding unrelated capabilities, production secret handling, and profile UX.

## Acceptance Criteria
1. A TASK-ID-scoped decision artifact lists exact iOS host, iOS tunnel, macOS host, and macOS tunnel bundle identifiers and their containment relationships. 2. The matrix assigns only the required Network Extension, App Group, and Keychain entitlements to each target and explains every difference between host and provider. 3. Team-prefix, debug versus release, profile type, and cross-platform sharing rules are explicit and machine-checkable. 4. Naming does not collide with the existing shipped macOS bundle or silently repurpose its identity; any migration is called out. 5. The responsible Apple account and architecture owners acknowledge the matrix before portal mutation begins.
