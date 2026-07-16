# Implement the shared Data Protection Keychain credential vault

## Description
Implement app-side private-key and optional passphrase storage that is readable only by the minimum containing-app and packet-tunnel access group. Return opaque stable references to profile storage and bound secret material to the shortest practical lifetime.

## Scope
In scope: Keychain add/read metadata/update/delete, approved accessibility class, access-group selection from Gate P0, stable opaque IDs, key and optional passphrase separation, duplicate handling, reference counting, secret zeroization where supported, user-presence or availability errors, extension-read integration, privacy-safe diagnostics, and test adapters. Out of scope: raw secrets in App Group or providerConfiguration, iCloud Keychain synchronization unless explicitly approved, Secure Enclave claims unsupported by the selected SSH format, UI, host trust, and agent forwarding.

## Acceptance Criteria
1. Imported or generated key material and passphrases are stored only under the approved Data Protection Keychain class and exact shared access group; synchronization is disabled unless the contract explicitly requires it. 2. Profiles receive opaque references that disclose no secret content and remain stable through app relaunch and extension lookup. 3. Reads, updates, duplicates, inaccessible-device state, missing items, malformed items, and deletion return typed errors without secret-bearing descriptions. 4. Deletion refuses or safely coordinates removal while retained profiles reference an item, and successful deletion makes both app and extension lookups fail. 5. Unit and host/extension integration tests plus entitlement inspection prove allowed access, rejected wrong-group access, bounded secret lifetime, and zero secret serialization or logging.
