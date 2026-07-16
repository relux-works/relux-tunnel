# Implement the versioned profile repository and App Group publisher

## Description
Implement the containing-app repository that owns non-secret profile CRUD and atomically publishes immutable generations for the packet-tunnel providers. Preserve the M1 loader contract and make selected-profile changes explicit and recoverable across both apps.

## Scope
In scope: stable profile IDs, schema and generation metadata, profile list and selected ID, canonicalized fields, opaque key and passphrase references, atomic App Group writes, read-modify-write serialization, corruption recovery, compatible schema reads, conflict detection, deletion, active-generation retention, app relaunch, and test seams. Out of scope: Keychain secret bytes, trust approval UI, direct provider writes, providerConfiguration secrets, OpenSSH import, legacy preference migration, and UI layout.

## Acceptance Criteria
1. Create, read, update, select, and delete operations produce immutable monotonically versioned snapshots compatible with the M1 loader. 2. Publication uses atomic replacement and serialization so readers observe either the prior complete generation or the next complete generation, never partial data. 3. Stored and logged values contain no raw key, passphrase, packet, DNS, or destination data; providerConfiguration receives only version and opaque profile identity. 4. Invalid, unsupported, corrupt, stale, duplicate, and concurrent updates return typed recoverable errors and preserve the last valid generation. 5. Tests cover empty store, relaunch, concurrent edits, selection deletion, active-generation retention, schema upgrade, corruption, and both platform App Group containers.
