## Status
backlog

## Assigned To
(none)

## Created
2026-07-15T01:16:33Z

## Last Update
2026-07-28T04:41:52Z

## Blocked By
- TASK-260715-29ws8l
- TASK-260728-7ii1xz

## Blocks
- TASK-260715-3t2v9w
- TASK-260715-3cv3r4
- TASK-260715-379cpk
- TASK-260715-1yxpqv

## Checklist
- [ ] Implement exact-reference least-privilege Keychain retrieval
- [ ] Run access-boundary format cancellation lifetime and redaction tests
- [ ] Attach task-scoped non-secret Keychain verification evidence

## Notes
2026-07-28 TASK-260728-7ii1xz r2 decided the macOS credential transport. REVISE: this task is written against the shared Data Protection Keychain access group, which cannot work on macOS (root provider vs user-context host). The resolver targets the file-based SYSTEM-DOMAIN keychain: kSecUseDataProtectionKeychain=false; resolve the keychain with SecKeychainCopyDomainDefault(kSecPreferencesDomainSystem, ...) and NEVER hard-code /Library/Keychains/System.keychain (Apple DTS advises against the literal; verified OSStatus=0 resolving to that path, system-domain search list count=1). SecItem key split matters: kSecUseKeychain is defined for SecItemAdd ONLY; SecItemCopyMatching/Update/Delete take kSecMatchSearchList. No kSecAttrAccessGroup, no kSecAttrAccessible - both are Data Protection Keychain concepts. AC1 becomes: queries only the fixed non-identifying service constant and the exact credentialRef, scoped by an explicit search list to the resolved system-domain keychain, never the ambient search list. startTunnel is READ-ONLY (r2 change): a miss fails fast with credentialNotProvisioned; the r1 awaitingCredential wait inside the 60s budget is removed, because seeding is a separate app-message operation that can launch a stopped provider. AC2 gains credentialNotProvisioned. AC4 zeroization drops to best-effort (no candidate can guarantee it). See TASK-260728-7ii1xz_macos-credential-transport-decision.md sections 5.0, 5.1.2, 5.1.4, 8.

## Precondition Resources
(none)

## Outcome Resources
(none)
