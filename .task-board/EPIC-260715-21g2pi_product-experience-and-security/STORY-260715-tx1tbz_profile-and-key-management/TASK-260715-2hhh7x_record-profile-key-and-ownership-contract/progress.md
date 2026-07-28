## Status
backlog

## Assigned To
(none)

## Created
2026-07-15T02:37:23Z

## Last Update
2026-07-28T04:42:01Z

## Blocked By
- TASK-260715-29ws8l
- TASK-260715-1gjxer
- TASK-260715-32umrc
- TASK-260715-1tnjlu
- TASK-260721-3miqh4
- TASK-260728-7ii1xz

## Blocks
- TASK-260715-28bwf4
- TASK-260715-379cpk
- TASK-260715-6ig5xj
- TASK-260715-a37ydn
- TASK-260715-31zqvw
- TASK-260715-2a1cp7

## Checklist
- [ ] Deliver the stated scope while preserving every explicit non-scope boundary
- [ ] Verify every acceptance criterion with the specified automated or manual evidence
- [ ] Attach a TASK-260715-2hhh7x-scoped redacted outcome with commands artifacts and residual risks

## Notes
2026-07-28 TASK-260728-7ii1xz r2 decided the macOS credential transport. REVISE: AC2 requires a matrix proving raw keys and passphrases exist only in the approved Data Protection Keychain access group - that proof is FALSE on macOS. The least-privilege matrix becomes per-platform: iOS = DP keychain + access group; macOS = provider-owned system-domain keychain item + a host staging item with a bounded lifetime. The editor lifecycle gains a state the contract has no concept of today: KEY IMPORTED BUT NOT YET SEEDED, because the system extension may not be approved yet. Deletion and key-replacement transitions must model BOTH revocation outcomes from section 5.2 - COMPLETED (config installed and enabled: an app-originated revoke launches a stopped provider) and PENDING (config disabled, invalid/unapproved, or no host running) - and the UI must show pending as pending, never report a deletion that has not happened. Supersedes the r1 note that told this task to model revocation as always-asynchronous; that would have produced a permanently vague will-be-removed-soon affordance where a definite confirmation is normally available. See TASK-260728-7ii1xz_macos-credential-transport-decision.md sections 5.0, 5.2, 8.

## Precondition Resources
- [TASK-260715-2hhh7x_dns-policy-precondition.md](file://TASK-260715-2hhh7x/TASK-260715-2hhh7x_dns-policy-precondition.md) — Resolver profile fields, no-inference migration, and evidence-gated endpoint validation policy
- [TASK-260715-2hhh7x_dns-runtime-policy-v1.md](file://TASK-260715-2hhh7x/TASK-260715-2hhh7x_dns-runtime-policy-v1.md) — Non-authoritative DNS policy handoff; production remains gated

## Outcome Resources
- [TASK-260715-2hhh7x_credential-boundaries.puml](file://TASK-260715-2hhh7x/TASK-260715-2hhh7x_credential-boundaries.puml) — Solution-architecture component view of App Group, Keychain, manager, provider, and SSH trust boundaries
