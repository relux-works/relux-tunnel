## Status
backlog

## Assigned To
(none)

## Created
2026-07-15T01:16:33Z

## Last Update
2026-07-28T07:35:37Z

## Blocked By
- TASK-260715-30zng6
- TASK-260728-7ii1xz
- TASK-260715-ypo7yo

## Blocks
- TASK-260715-3f4lxy
- TASK-260715-1o9wjz
- TASK-260715-12zaq5
- TASK-260715-13labb
- TASK-260715-1m07fw
- TASK-260715-2hhh7x
- TASK-260717-1dsqnj

## Checklist
- [ ] Deliver a field-level storage trust and credential boundary contract
- [ ] Trace host verification ordering and secret handling to security requirements
- [ ] Attach task-scoped contract and explicit M4 handoff evidence
- [ ] AUTONOMY: complete this contract autonomously — full draft + agent-reviewer acceptance, then to-review. Do NOT block on human owner sign-off. Human ratification is decoupled and tracked as TASK-260717-1dsqnj; downstream implementation proceeds on the accepted draft.

## Notes
2026-07-28 TASK-260728-7ii1xz r2 decided the macOS credential transport. THIS TASK OWNS the transport contract in section 5.1. REVISE: AC2 App Group language is macOS-false (host and root provider resolve DIFFERENT containers); non-secret snapshot travels in providerConfiguration. AC4 Keychain accessibility + access group is macOS-inapplicable and becomes SecAccess designated-requirement ACL. Must specify: SeedCredential and RevokeCredential message schemas with size bounds; the keychain-resolution rule (SecKeychainCopyDomainDefault(kSecPreferencesDomainSystem) - no path literal - plus kSecUseKeychain on add vs kSecMatchSearchList on query/update/delete); the read-only startTunnel rule; the start-time reconciliation sweep as CRASH-RECOVERY DEFENCE ONLY, not as the deletion path; the non-identifying attribute rule (System keychain attributes are world-readable, 192 items dumped as uid 502). Revocation must be stated as the FIVE-STATE table in section 5.2, not a single yes/no: synchronous when the config is installed and enabled (running or not), unavailable when disabled (NEVPNErrorConfigurationDisabled), invalid/unapproved (NEVPNErrorConfigurationInvalid), or when no host runs. Must also specify the UNINSTALL RESIDUE case: removing the system extension deletes its container but the system-domain keychain item is not in that container and survives. State the one property macOS genuinely cannot offer: login-password protection of the secret at rest. Supersedes the r1 note that called deletion always-asynchronous. See sections 5.0, 5.1, 5.2, 8.

## Precondition Resources
(none)

## Outcome Resources
(none)
