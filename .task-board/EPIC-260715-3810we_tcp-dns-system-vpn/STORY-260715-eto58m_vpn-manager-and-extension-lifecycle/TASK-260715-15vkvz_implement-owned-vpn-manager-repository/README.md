# Implement the owned NETunnelProviderManager repository

## Description
Implement a shared host-side repository that loads Network Extension preferences, identifies only the Relux custom VPN configuration, creates or updates it idempotently, persists non-secret provider references, reloads the saved object, enables it, and removes it only on an explicit owned request.

## Scope
In scope: asynchronous load and save wrappers, owned-manager predicate, single-manager deduplication policy for Relux-owned duplicates, localized description, provider and server identifiers, providerConfiguration with version and opaque profile reference only, preference conflicts, save then reload, enable and disable, and stable errors. Out of scope: storing secrets, choosing a profile, connect UI, deleting unrelated configurations, account migration, final uninstall policy, and provider runtime behavior.

## Acceptance Criteria
1. Repeated ensure operations converge to one Relux-owned manager with the approved provider bundle identifier and current schema version. 2. The repository never mutates or removes a manager that does not satisfy the exact owned predicate, with tests containing multiple unrelated VPN types. 3. providerConfiguration contains no private key, passphrase, host fingerprint payload, packet data, or raw profile JSON beyond approved non-secret references. 4. Save conflicts, permission denial, stale objects, corrupt owned configuration, and reload failure return stable recoverable errors. 5. iOS and macOS host targets compile against the same repository contract and platform-adapter tests verify persistence calls and outcomes.
