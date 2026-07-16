# Record the macOS release identity, entitlement, and migration contract

## Description
Create the binding macOS distribution contract for ReluxProxyMac, ReluxProxyMacTunnel, Developer ID identities and profiles, minimum entitlements, hardened runtime, bundled resources, versioning, legacy coexistence or migration, artifact names, and channel behavior.

## Scope
In scope: Gate A0 and P0 constraints, host and extension bundle identifiers, embedding, Team ID, App Group and Keychain groups, packet-tunnel entitlement, provisioning profile classes, hardened-runtime options, nested signing order, version and build propagation, relay and notice resources, legacy bundle and defaults decision, clean install, upgrade, coexistence, retirement, uninstall, stable and versioned DMG names, and rollback identity. Out of scope: issuing certificates, changing upstream Gate or migration decisions, implementing signing, iOS distribution, product UX, and adding entitlements to work around an invalid architecture.

## Acceptance Criteria
1. A TASK-ID-scoped matrix lists every signed path, identifier, containing relationship, profile, entitlement, capability, hardened-runtime option, resource, version field, and verification command. 2. Host and extension receive only approved packet-tunnel, App Group, Keychain, and runtime rights and every difference has rationale traced to Gate P0 and the target ADR. 3. The approved legacy coexistence, replacement, or retirement decision defines bundle identity, defaults and stored data, release history, upgrade path, user messaging, uninstall, and rollback. 4. Stable ReluxProxy.dmg and immutable versioned asset semantics, private-repository authentication, checksums, provenance, retention, and withdrawal are explicit. 5. Platform, security, release, and product owners approve the contract or any unresolved identity, entitlement, or migration choice remains a concrete blocker.
