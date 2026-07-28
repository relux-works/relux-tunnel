## Status
backlog

## Assigned To
(none)

## Created
2026-07-15T00:58:02Z

## Last Update
2026-07-28T04:42:12Z

## Blocked By
- TASK-260715-1r0fxv

## Blocks
- TASK-260715-2ayxqn

## Checklist
- [ ] The physical Mac passes signature, configuration, launch, message, and stop checks
- [ ] Lifecycle-loop and reinstall evidence contains no unexplained failure
- [ ] The redacted runbook and result bundle are attached

## Notes
2026-07-28 replan (TASK-260728-3a2dnr): this task belongs to Ceremony C1, the single up-front human permission session on the current arm64 Mac. See the wave plan and ceremony script attached to TASK-260728-3a2dnr. Never request, echo, or persist secret values, key paths, or credential contents in board, repo, or logs.
2026-07-28 TASK-260728-7ii1xz adds three privacy-safe checks to this physical run, because no code could be run as root in that analysis session. V1: from the signed sandboxed approved provider running as root, SecItemAdd plus SecItemCopyMatching of a placeholder generic password in /Library/Keychains/System.keychain with a restrictive SecAccess, with NO keychain-access-groups and NO temporary exception on the provider - pass when both return OSStatus 0, no sandbox denial appears in the unified log, and a read after provider restart still returns 0 with no prompt. V2: in the same root context log the resolved containerURL for the app group, PATH ONLY - pass when it is under /private/var/root and differs from the host path. V3: start the tunnel from System Settings with the containing app not running after V1 seeded the item - pass when the provider reaches connected without the host. Placeholder values, paths and OSStatus only, never a secret. See TASK-260728-7ii1xz_macos-credential-transport-decision.md section 7.
2026-07-28 TASK-260728-7ii1xz r2 adds two verifications to this physical sitting, and amends V1. V1 AMENDED: resolve the keychain with SecKeychainCopyDomainDefault(kSecPreferencesDomainSystem, ...) and log the RESOLVED PATH ONLY, then SecItemAdd with kSecUseKeychain and SecItemCopyMatching with kSecMatchSearchList (not kSecUseKeychain - that key is add-only). V4 NEW: with the provider installed, enabled and NOT running, and the tunnel NOT started, send a bounded no-op app message via NETunnelProviderSession.sendProviderMessage. Record whether the provider process starts, whether handleAppMessage is reached, and the round-trip outcome. PASS = the provider is launched and responds without the tunnel being started. Apple documents this (If the extension is not running, it should be launched to handle the message) but it was NOT executed before Ceremony C1, so this is the settlement. If it FAILS, section 5.1.3 seeding and section 5.2 states 1-2 collapse to eventual consistency and TASK-260715-29ws8l must restate the revocation guarantee - either result is valid, the design must not ship on the assumption. V5 NEW: with the configuration DISABLED, attempt the same send; PASS = it fails with NEVPNErrorConfigurationDisabled, confirming the app can DETECT the deferred-revocation case rather than silently believing it succeeded. Privacy for V4/V5: no-op message carrying no credential; log NEVPNError and OSStatus values and paths only, never a secret. See TASK-260728-7ii1xz_macos-credential-transport-decision.md section 7.

## Precondition Resources
(none)

## Outcome Resources
(none)
