# Verify migration isolation from the legacy SwiftPM SOCKS product

## Description
Prove that adding and integrating the generated M1 tunnel runtime does not silently replace, mutate, link into, or break the existing ReluxProxy SwiftPM application and its current release path. Record the explicit boundary and any future migration decision still owned by M4 or M5.

## Scope
In scope: target and product inventory diff, package dependency graph, bundle and executable identities, build products, release scripts, user defaults and Keychain namespaces, launch behavior, and clean builds of both legacy and generated products. Out of scope: migrating users, deleting legacy code, changing release scripts, reconciling UI, shipping two products, or deciding final retirement timing.

## Acceptance Criteria
1. A task-scoped comparison identifies every legacy file, target, artifact, identifier, storage namespace, and release entry point that must remain unchanged. 2. Clean legacy build and existing verification commands pass after M1 integration without importing ReluxTunnelCore or native tunnel dependencies unless explicitly approved by M0 architecture. 3. Generated host and provider builds use distinct products and do not overwrite legacy artifacts, defaults, Keychain items, launch agents, or packaging paths. 4. Automated checks fail on accidental cross-linking, identifier collision, or release-script substitution. 5. Any required future user or data migration is named as M4 or M5 work rather than implemented here.
