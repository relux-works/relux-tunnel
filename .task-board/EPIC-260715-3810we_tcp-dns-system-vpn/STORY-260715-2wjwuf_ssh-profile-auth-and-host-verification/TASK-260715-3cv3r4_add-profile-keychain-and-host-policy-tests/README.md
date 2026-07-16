# Add profile, Keychain, host-policy, and redaction unit tests

## Description
Build deterministic shared test suites for profile snapshot loading, canonicalization, Keychain reference isolation, scoped secret handling, host-key policy ordering, fingerprint decisions, bootstrap error mapping, and logging redaction using fakes rather than production credentials.

## Scope
In scope: valid and malformed profiles, schema versions, atomic generations, host forms, exact Keychain queries, inaccessible and malformed items, passphrase cases, first use, approved match, rotation, change, revocation, unsupported algorithms, pre-auth ordering, cancellation, and prohibited-data scans. Out of scope: real SSH network integration, physical devices, UI acceptance, performance, route settings, password auth, and storing any real private key or passphrase.

## Acceptance Criteria
1. Table-driven profile tests cover every validation rule and prove an invalid snapshot cannot trigger Keychain or network access. 2. Keychain fakes assert exact access group and reference queries, bounded lifetime, cancellation cleanup, and no enumeration or fallback. 3. Host policy tests assert the callback precedes credential and auth calls and cover first-use, match, change, rotation, revocation, and malformed evidence. 4. Error and log golden tests scan messages, snapshots, and captured logging for fixture secrets, hostnames, full addresses, and raw key material. 5. Repeated test execution shows no retained secret container, task, connection, or observer count growth.
