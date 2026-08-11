## Status
done

## Assigned To
[reviewer] reviewer (codex)

## Created
2026-07-15T01:16:33Z

## Last Update
2026-08-11T13:16:30Z

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
- [x] Deliver a field-level storage trust and credential boundary contract
- [x] Trace host verification ordering and secret handling to security requirements
- [x] Attach task-scoped contract and explicit M4 handoff evidence
- [x] AUTONOMY: complete this contract autonomously — full draft + agent-reviewer acceptance, then to-review. Do NOT block on human owner sign-off. Human ratification is decoupled and tracked as TASK-260717-1dsqnj; downstream implementation proceeds on the accepted draft.
- [x] Board size is proportional to the spec and is the smallest decomposition that maps every requirement
- [x] Every story and task traces to a concrete spec requirement; justified-gap elements also carry a self-verified gap record
- [x] Beyond-literal-spec elements include a written justification naming the gap and the spec and out-of-scope checks performed before creation
- [x] Research tasks cite an exact question the spec genuinely leaves open
- [x] Dependencies linked
- [x] Tasks are atomic — one clear deliverable each
- [x] Completeness verified — nothing forgotten
- [x] Any planning artifacts actually produced are linked as new task-scoped outcome resources; diagrams are strictly optional, never a standing deliverable
- [x] Important findings, decisions, anomalies, or regressions recorded in logbook when relevant
- [x] Implementation matches AC
- [x] Solution fits project architecture
- [x] Tests green
- [x] If review does not accept the work — verdict evidence added and status routed by the explicit verdict branches

## Notes
2026-07-28 TASK-260728-7ii1xz r2 decided the macOS credential transport. THIS TASK OWNS the transport contract in section 5.1. REVISE: AC2 App Group language is macOS-false (host and root provider resolve DIFFERENT containers); non-secret snapshot travels in providerConfiguration. AC4 Keychain accessibility + access group is macOS-inapplicable and becomes SecAccess designated-requirement ACL. Must specify: SeedCredential and RevokeCredential message schemas with size bounds; the keychain-resolution rule (SecKeychainCopyDomainDefault(kSecPreferencesDomainSystem) - no path literal - plus kSecUseKeychain on add vs kSecMatchSearchList on query/update/delete); the read-only startTunnel rule; the start-time reconciliation sweep as CRASH-RECOVERY DEFENCE ONLY, not as the deletion path; the non-identifying attribute rule (System keychain attributes are world-readable, 192 items dumped as uid 502). Revocation must be stated as the FIVE-STATE table in section 5.2, not a single yes/no: synchronous when the config is installed and enabled (running or not), unavailable when disabled (NEVPNErrorConfigurationDisabled), invalid/unapproved (NEVPNErrorConfigurationInvalid), or when no host runs. Must also specify the UNINSTALL RESIDUE case: removing the system extension deletes its container but the system-domain keychain item is not in that container and survives. State the one property macOS genuinely cannot offer: login-password protection of the secret at rest. Supersedes the r1 note that called deletion always-asynchronous. See sections 5.0, 5.1, 5.2, 8.
spawn agent resolution: Agent selection: codex via explicit_override (preferred_agentic_system: mixed[claude,codex], config: spawn.preferred_agentic_system)
spawn launch composition: empty; contract=agents-infra.child-launch-composition; provider=codex; schema=1; producer=dev; diagnostic=launch_composition_empty; no project MCP servers enabled
spawn queued: [analyst] solution-architect (codex) (run=RUN-260811-879af3, max_parallel=1)
spawn run started: [analyst] solution-architect (codex) (run=RUN-260811-879af3)
2026-08-11 contract finding: accepted macOS transport supersedes shared App Group and Keychain Sharing assumptions. Independent review required failure-atomic copy-on-write credential replacement, exact trust-probe and protected-record codecs, tombstone-aware changed-key handling, and bounded fixed-service crash reconciliation. Final agent-reviewed contract is attached; human ratification remains decoupled under TASK-260717-1dsqnj.
agent completed: [analyst] solution-architect (codex) (exit=0)
spawn run completed: codex (run=RUN-260811-879af3, pid=25218, exit=0)
spawn agent resolution: Agent selection: codex via explicit_override (preferred_agentic_system: mixed[claude,codex], config: spawn.preferred_agentic_system)
spawn launch composition: empty; contract=agents-infra.child-launch-composition; provider=codex; schema=1; producer=dev; diagnostic=launch_composition_empty; no project MCP servers enabled
spawn queued: [reviewer] reviewer (codex) (run=RUN-260811-ecd9fa, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260811-ecd9fa)
2026-08-11 reviewer finding: contract sections 12-13 misidentify TASK-260715-297imp as the host-policy implementation and omit the actual host-policy and error-mapping consumers TASK-260715-12zaq5 and TASK-260715-13labb. Evidence and exact rework are attached in TASK-260715-29ws8l_review-verdict.md. Focused Swift tests passed 13/13 with exit 0; initial board validation exited 0 but reported a parent-status mismatch caused by reviewing under a hard-blocked parent. Routed to analysis for contract trace correction.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260811-ecd9fa, pid=80126, exit=0)
spawn agent resolution: Agent selection: codex via explicit_override (preferred_agentic_system: mixed[claude,codex], config: spawn.preferred_agentic_system)
spawn launch composition: empty; contract=agents-infra.child-launch-composition; provider=codex; schema=1; producer=dev; diagnostic=launch_composition_empty; no project MCP servers enabled
spawn queued: [analyst] solution-architect (codex) (run=RUN-260811-b8331b, max_parallel=1)
spawn run started: [analyst] solution-architect (codex) (run=RUN-260811-b8331b)
2026-08-11 rework 01: applied the accepted traceability-only delta in contract sections 12-13, refreshed digest and evidence, and reran focused gates. Host policy now maps to TASK-260715-12zaq5; stable bootstrap error/retry/redaction maps to TASK-260715-13labb; TASK-260715-297imp remains only the composed integration-matrix consumer. No architecture, schema, security semantic, or board decomposition changed.
agent completed: [analyst] solution-architect (codex) (exit=0)
spawn run completed: codex (run=RUN-260811-b8331b, pid=89108, exit=0)
spawn agent resolution: Agent selection: codex via explicit_override (preferred_agentic_system: mixed[claude,codex], config: spawn.preferred_agentic_system)
spawn launch composition: empty; contract=agents-infra.child-launch-composition; provider=codex; schema=1; producer=dev; diagnostic=launch_composition_empty; no project MCP servers enabled
spawn queued: [reviewer] reviewer (codex) (run=RUN-260811-b670de, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260811-b670de)
2026-08-11 reviewer verdict 02: ACCEPTED. Focused traceability correction is exact: TASK-260715-12zaq5 owns raw-evidence host policy, TASK-260715-13labb owns stable bootstrap error/retry/redaction, and TASK-260715-297imp remains only the integration-matrix consumer. Digest matched; 13/13 focused tests passed; git diff check passed; post-verdict board validation is clean. Acceptance evidence: TASK-260715-29ws8l_review-verdict-02.md.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260811-b670de, pid=92749, exit=0)

## Precondition Resources
- [active-macos-credential-contract-scope.md](file://TASK-260715-29ws8l/active-macos-credential-contract-scope.md) — Binding macOS-only credential transport and libssh2 scope
- [rework-01-traceability.md](file://TASK-260715-29ws8l/rework-01-traceability.md) — Focused reviewer-requested traceability correction

## Outcome Resources
- [TASK-260715-29ws8l_spawn-log_-analyst--solution-architect--codex-_RUN-260811-879af3.log](file://TASK-260715-29ws8l/TASK-260715-29ws8l_spawn-log_-analyst--solution-architect--codex-_RUN-260811-879af3.log) — System spawn log captured by task-board
- [TASK-260715-29ws8l_profile-trust-credential-contract.md](file://TASK-260715-29ws8l/TASK-260715-29ws8l_profile-trust-credential-contract.md) — Agent-reviewed macOS profile trust credential and M4 handoff contract; focused traceability rework ready for review
- [TASK-260715-29ws8l_agent-review.md](file://TASK-260715-29ws8l/TASK-260715-29ws8l_agent-review.md) — Independent agent-review history and focused traceability rework evidence
- [TASK-260715-29ws8l_results.md](file://TASK-260715-29ws8l/TASK-260715-29ws8l_results.md) — Final accepted handoff evidence
- [TASK-260715-29ws8l_spawn-log_-reviewer--reviewer--codex-_RUN-260811-ecd9fa.log](file://TASK-260715-29ws8l/TASK-260715-29ws8l_spawn-log_-reviewer--reviewer--codex-_RUN-260811-ecd9fa.log) — System spawn log captured by task-board
- [TASK-260715-29ws8l_review-verdict.md](file://TASK-260715-29ws8l/TASK-260715-29ws8l_review-verdict.md) — Reviewer changes-requested verdict and independent gate evidence
- [TASK-260715-29ws8l_spawn-log_-analyst--solution-architect--codex-_RUN-260811-b8331b.log](file://TASK-260715-29ws8l/TASK-260715-29ws8l_spawn-log_-analyst--solution-architect--codex-_RUN-260811-b8331b.log) — System spawn log captured by task-board
- [TASK-260715-29ws8l_spawn-log_-reviewer--reviewer--codex-_RUN-260811-b670de.log](file://TASK-260715-29ws8l/TASK-260715-29ws8l_spawn-log_-reviewer--reviewer--codex-_RUN-260811-b670de.log) — System spawn log captured by task-board
- [TASK-260715-29ws8l_review-verdict-02.md](file://TASK-260715-29ws8l/TASK-260715-29ws8l_review-verdict-02.md) — Accepted reviewer verdict and independent focused-gate evidence

## Estimate
estimated(fibonacci(8))
