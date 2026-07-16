# Implement private-key generation and explicit export

## Description
Implement generation of the approved SSH key types using platform or accepted library cryptography, store the private material in the vault, and expose only contract-approved, user-confirmed export actions.

## Scope
In scope: approved algorithm and size/curve choices, cryptographically secure randomness, key metadata and fingerprint, optional passphrase protection if supported, Keychain insertion, public-key copy/export, explicit private-key export only if the contract permits it, user confirmation, platform share/save adapters, temporary-file protection and cleanup, cancellation, collision handling, and tests. Out of scope: server-side authorized_keys installation, cloud backup, silent export, agent forwarding, unsupported algorithms, and profile editor layout.

## Acceptance Criteria
1. Generated key pairs use only contract-approved algorithms and secure randomness and produce interoperable public-key encoding plus stable non-secret metadata. 2. Private material enters the approved Keychain vault directly or through a bounded in-memory buffer and is never written to App Group, logs, providerConfiguration, crash annotations, or unprotected temporary storage. 3. Public export is explicit; private export either does not exist or requires the contract-approved warning, confirmation, protected file handling, and cleanup with no background or automatic path. 4. Cancellation, generation failure, vault failure, duplicate identity, export failure, and app suspension leave no orphan profile reference or temporary private-key file. 5. Deterministic interface tests and interoperability fixtures verify storage, fingerprint, public encoding, optional passphrase behavior, export policy, cleanup, and extension authentication use.
