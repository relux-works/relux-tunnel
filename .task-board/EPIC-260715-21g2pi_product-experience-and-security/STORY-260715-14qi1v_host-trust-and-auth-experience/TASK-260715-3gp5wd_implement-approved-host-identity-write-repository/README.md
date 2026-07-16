# Implement the approved host-identity write repository

## Description
Implement containing-app operations that create, update last-seen metadata, revoke, and explicitly replace approved host identities inside versioned non-secret profile storage. The provider remains read-only and evaluates exactly one immutable identity generation.

## Scope
In scope: canonical host binding, one or more approved algorithms/fingerprints, provenance, first/last-seen timestamps, profile and trust generations, first-use insertion, last-seen update, revocation, explicit changed-key replacement, audit metadata, optimistic conflict detection, active-session retention, atomic publication, typed errors, and tests. Out of scope: SSH verification itself, Keychain secrets, auto-accept, UI, remote known_hosts import, and deleting unrelated profile data.

## Acceptance Criteria
1. First approval writes the exact reviewed algorithm and full SHA-256 fingerprint with provenance, first-seen, last-seen, profile ID, and a new immutable generation. 2. Ordinary verified reuse may update last-seen without changing approved identity; changed-key replacement requires an explicit expected-old plus reviewed-new compare-and-swap operation. 3. Revocation and replacement publish atomically, preserve active readers on their prior generation, and ensure every new lane/bootstrap reads one consistent generation. 4. Stale evidence, wrong profile/host, duplicate approval, concurrent edits, clock anomalies, corrupt records, and unsupported algorithms return typed errors and never broaden trust. 5. Tests prove no raw credentials enter the record, logs, errors, or diagnostic artifacts and provider loader/policy compatibility remains intact.
