## Status
backlog

## Assigned To
(none)

## Created
2026-07-15T02:37:23Z

## Last Update
2026-07-28T04:41:35Z

## Blocked By
- TASK-260715-2hhh7x
- TASK-260715-1o9wjz
- TASK-260715-ypo7yo
- TASK-260728-7ii1xz

## Blocks
- TASK-260715-6ig5xj
- TASK-260715-a37ydn
- TASK-260715-1y5r8p
- TASK-260715-1yxpqv
- TASK-260715-1fx855

## Checklist
- [ ] Deliver the stated scope while preserving every explicit non-scope boundary
- [ ] Verify every acceptance criterion with the specified automated or manual evidence
- [ ] Attach a TASK-260715-379cpk-scoped redacted outcome with commands artifacts and residual risks

## Notes
2026-07-28 TASK-260728-7ii1xz r2 decided the macOS credential transport. REVISE: the shared Data Protection Keychain access group works on iOS only. On macOS the system of record is a provider-owned file-based SYSTEM-DOMAIN keychain item written by the root provider; the app-side vault is a staging store only. AC1 access-group and accessibility-class language is macOS-inapplicable. AC4 IS synchronously satisfiable on macOS in the ordinary case - an app-originated revoke launches a stopped-but-enabled provider (sendProviderMessage is documented to launch a non-running extension) - but NOT in every state: restate AC4 against the five-state table in section 5.2 (synchronous in states 1-2; deferred to the provider start-time sweep in states 3-5 = config disabled, config invalid/unapproved, or no host running). The vault API must surface WHICH outcome happened, never a bare success. AC5 wrong-group test becomes a SecAccess designated-requirement test. Test seam: the macOS SecItem layer is unit-testable today against a throwaway keychain using kSecUseKeychain on add and kSecMatchSearchList on query/delete - see check E10 (negative control included). Supersedes the r1 note that called revocation always-asynchronous. See TASK-260728-7ii1xz_macos-credential-transport-decision.md sections 5.0, 5.1, 5.2, 8.

## Precondition Resources
(none)

## Outcome Resources
(none)
