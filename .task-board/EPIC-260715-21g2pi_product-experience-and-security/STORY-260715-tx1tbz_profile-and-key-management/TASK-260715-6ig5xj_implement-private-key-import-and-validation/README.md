# Implement private-key import and validation

## Description
Implement an explicit document-import path that validates supported SSH private-key formats before securely ingesting them into the credential vault. Keep file access and parsed secret buffers short-lived and make encrypted-key handling consistent with the approved passphrase policy.

## Scope
In scope: iOS document picker and macOS open-panel adapters behind a shared importer, security-scoped URL lifetime, size limits, approved OpenSSH/PEM or engine-specific formats, encrypted-key detection, passphrase validation without retention unless chosen, algorithm and public fingerprint extraction, duplicate identification, metadata naming, cancellation, malformed and permission errors, temporary cleanup, and deterministic fixtures. Out of scope: OpenSSH config import, public-key-only authentication entries, filesystem permission changes outside user-selected files, silent export, password auth, and UI layout beyond adapter contracts.

## Acceptance Criteria
1. Only user-selected files within the contract size and supported format/algorithm set can enter the vault; malformed, truncated, oversized, unsupported, and public-key-only inputs are rejected before persistence. 2. Security-scoped access, input handles, parser buffers, and temporary copies close or clear on success, cancellation, parse failure, passphrase failure, and app backgrounding. 3. The importer derives non-secret metadata and fingerprint, identifies duplicates deterministically, and never logs or publishes key bytes, passphrases, or file contents. 4. Encrypted inputs require an explicit passphrase step and follow the approved store-once, prompt-each-time, or reject policy without ambiguity. 5. Tests cover each approved format and algorithm, permissions, cancellation, duplicates, wrong passphrase, corrupt data, size bounds, cleanup, and app-to-extension resolution after import.
