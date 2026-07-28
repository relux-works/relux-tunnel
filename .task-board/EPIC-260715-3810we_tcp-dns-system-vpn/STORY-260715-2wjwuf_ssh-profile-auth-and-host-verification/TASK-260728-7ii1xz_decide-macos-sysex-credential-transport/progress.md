## Status
done

## Review
required

## Task Class
research

## Estimate
estimated(fibonacci(3))

## Blocked By
- (none)

## Blocks
- TASK-260715-379cpk
- TASK-260715-1o9wjz
- TASK-260715-29ws8l
- TASK-260715-3f4lxy
- TASK-260715-ypo7yo
- TASK-260715-2hhh7x

## Checklist
- [x] Compare at least three transports against every AC dimension with evidence
- [x] Select one transport or persist a complete stop-the-line decision packet
- [x] State exact ypo7yo App Group and Keychain entitlement amendments
- [x] Record privacy-safe physical evidence where documentation is insufficient
- [x] Map every affected downstream task to its revised assumption
- [x] Attach a TASK-ID-scoped outcome and hand off for independent review
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
GAP JUSTIFICATION (created 2026-07-28 by TASK-260715-ypo7yo, solution-architect).

Spec requirement it serves: .spec/security-privacy.md Client credentials — "Private keys and passphrases live in the Data Protection Keychain and are shared only through the minimum keychain access group required by the app and its packet tunnel extension" — plus .spec/threat-model.md DF-02 and M-02, which assume the extension resolves opaque references from that shared group.

The gap: while producing the Apple identifier and entitlement matrix, Apple documentation and DTS guidance established two facts that make that requirement unsatisfiable on macOS as written. (1) A macOS Network Extension packaged as a system extension — mandatory for Developer ID direct distribution per TN3134 and .spec/platform-distribution.md — runs as root, outside a user context. (2) The Data Protection Keychain is available only to code running in a user context, and keychain access groups share items between programs running as the same user. The macOS host runs as the logged-in user. Therefore the host and the macOS provider cannot share a Data Protection Keychain access group. iOS is unaffected: its appex runs as the same user as its host. The same root/user split also means the App Group container is not a shared filesystem channel on macOS.

Out-of-scope check before creation: read TASK-260715-29ws8l (SSH profile, trust and credential boundary contract), TASK-260715-2hhh7x (profile, key and ownership contract), TASK-260715-379cpk (Keychain credential vault), TASK-260715-1o9wjz (packet-extension Keychain resolver), TASK-260715-3f4lxy (profile snapshot loader), TASK-260715-1tzaed (macOS release identity contract) and TASK-260715-35nc5m (legacy SOCKS disposition). All five credential tasks ASSUME the shared-access-group model and none owns the question of whether it holds on macOS; 1tzaed is M5 release identity and 35nc5m is the legacy product decision. No existing element owns this. No duplicate created.

Why it is not folded into 29ws8l: 29ws8l is the M1 boundary contract and its own scope already presupposes an in-extension Keychain query contract. Resolving the premise inside the task that depends on it would let three implementation tasks (379cpk, 1o9wjz, 3f4lxy) start on a design that cannot work on the only platform this goal ships.

Why it is not a stop-the-line: the candidate transports are technical and evidence-resolvable by an agent architect. No owner product decision is required unless the comparison itself surfaces one, in which case AC3 routes it to a blocker with a recommendation.

Matrix effect already applied by TASK-260715-ypo7yo: keychain-access-groups on works.relux.tunnel.mac.tunnel is recorded as prohibited-pending-decision with this task as resolutionOwner, so no non-functional privilege is provisioned at Ceremony C1 and no downstream target silently inherits a broken credential path.
2026-07-28 sequencing correction after ypo7yo review verdict 03: this decision now runs against the draft r3 matrix before ypo7yo acceptance. ypo7yo applies the selected transport verdict and is blocked by this task; only then may Ceremony C1 start. This removes the future-only App Group pre-grant while preserving one C1 sitting.
spawn agent resolution: Agent selection: claude via explicit_override (preferred_agentic_system: mixed[claude,codex], config: spawn.preferred_agentic_system)
spawn launch composition: degraded_contract_unavailable; contract=agents-infra.child-launch-composition; provider=claude; schema=1; diagnostic=composition_contract_unavailable; bare child launch retained
spawn queued: [analyst] solution-architect (claude) (run=RUN-260728-96ac9a, max_parallel=1)
spawn run started: [analyst] solution-architect (claude) (run=RUN-260728-96ac9a)
agent completed: [analyst] solution-architect (claude) (exit=0)
spawn run completed: claude (run=RUN-260728-96ac9a, pid=65392, exit=0)
spawn agent resolution: Agent selection: codex via explicit_override (preferred_agentic_system: mixed[claude,codex], config: spawn.preferred_agentic_system)
spawn launch composition: degraded_contract_unavailable; contract=agents-infra.child-launch-composition; provider=codex; schema=1; diagnostic=composition_contract_unavailable; bare child launch retained
spawn queued: [reviewer] reviewer (codex) (run=RUN-260728-102df0, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260728-102df0)
Reviewer verdict 01 (2026-07-28): changes requested. Apple documents that sendProviderMessage launches a non-running provider, contradicting the claimed provider-stopped asynchronous-only revocation path and affecting 379cpk, 29ws8l, and 2hhh7x. Also replace the hard-coded System.keychain path with system-domain resolution and make the ypo7yo row amendment remove/replace stale resolutionOwner and amendmentRule fields. Evidence: TASK-260728-7ii1xz_reviewer-verdict-01.md. Gates: swift test 335/335 exit 0; probe compile exit 0; physical collector exit 0.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260728-102df0, pid=75426, exit=0)
spawn agent resolution: Agent selection: claude via explicit_override (preferred_agentic_system: mixed[claude,codex], config: spawn.preferred_agentic_system)
spawn launch composition: degraded_contract_unavailable; contract=agents-infra.child-launch-composition; provider=claude; schema=1; diagnostic=composition_contract_unavailable; bare child launch retained
spawn queued: [analyst] solution-architect (claude) (run=RUN-260728-ebb281, max_parallel=1)
spawn run started: [analyst] solution-architect (claude) (run=RUN-260728-ebb281)
agent completed: [analyst] solution-architect (claude) (exit=0)
spawn run completed: claude (run=RUN-260728-ebb281, pid=81685, exit=0)
spawn agent resolution: Agent selection: codex via explicit_override (preferred_agentic_system: mixed[claude,codex], config: spawn.preferred_agentic_system)
spawn launch composition: degraded_contract_unavailable; contract=agents-infra.child-launch-composition; provider=codex; schema=1; diagnostic=composition_contract_unavailable; bare child launch retained
spawn queued: [reviewer] reviewer (codex) (run=RUN-260728-005a80, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260728-005a80)
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260728-005a80, pid=84979, exit=0)

## Precondition Resources
(none)

## Outcome Resources
- [TASK-260728-7ii1xz_spawn-log_-analyst--solution-architect--claude-_RUN-260728-96ac9a.log](file://TASK-260728-7ii1xz/TASK-260728-7ii1xz_spawn-log_-analyst--solution-architect--claude-_RUN-260728-96ac9a.log) — System spawn log captured by task-board
- [TASK-260728-7ii1xz_macos-credential-transport-decision.md](file://TASK-260728-7ii1xz/TASK-260728-7ii1xz_macos-credential-transport-decision.md)
- [TASK-260728-7ii1xz_physical-evidence-03.log](file://TASK-260728-7ii1xz/TASK-260728-7ii1xz_physical-evidence-03.log) — Physical evidence log with commands and exit codes, no secret values
- [TASK-260728-7ii1xz_keychain-context-probe-01.log](file://TASK-260728-7ii1xz/TASK-260728-7ii1xz_keychain-context-probe-01.log) — Physical evidence log with commands and exit codes, no secret values
- [TASK-260728-7ii1xz_sandbox-and-systemkeychain-02.log](file://TASK-260728-7ii1xz/TASK-260728-7ii1xz_sandbox-and-systemkeychain-02.log) — Physical evidence log with commands and exit codes, no secret values
- [TASK-260728-7ii1xz_kcprobe.swift](file://TASK-260728-7ii1xz/TASK-260728-7ii1xz_kcprobe.swift) — Reproducible evidence harness
- [TASK-260728-7ii1xz_run-probe.sh](file://TASK-260728-7ii1xz/TASK-260728-7ii1xz_run-probe.sh) — Reproducible evidence harness
- [TASK-260728-7ii1xz_collect-evidence.sh](file://TASK-260728-7ii1xz/TASK-260728-7ii1xz_collect-evidence.sh) — Reproducible evidence harness
- [TASK-260728-7ii1xz_results.md](file://TASK-260728-7ii1xz/TASK-260728-7ii1xz_results.md) — Handoff evidence
- [TASK-260728-7ii1xz_spawn-log_-reviewer--reviewer--codex-_RUN-260728-102df0.log](file://TASK-260728-7ii1xz/TASK-260728-7ii1xz_spawn-log_-reviewer--reviewer--codex-_RUN-260728-102df0.log) — System spawn log captured by task-board
- [TASK-260728-7ii1xz_reviewer-verdict-01.md](file://TASK-260728-7ii1xz/TASK-260728-7ii1xz_reviewer-verdict-01.md) — Independent review verdict 01 — changes requested
- [TASK-260728-7ii1xz_spawn-log_-analyst--solution-architect--claude-_RUN-260728-ebb281.log](file://TASK-260728-7ii1xz/TASK-260728-7ii1xz_spawn-log_-analyst--solution-architect--claude-_RUN-260728-ebb281.log) — System spawn log captured by task-board
- [TASK-260728-7ii1xz_system-domain-and-lifecycle-04.log](file://TASK-260728-7ii1xz/TASK-260728-7ii1xz_system-domain-and-lifecycle-04.log) — r2 physical evidence E8-E10: system-domain keychain resolution, SecItem key split with negative control, plus verbatim sendProviderMessage/handleAppMessage lifecycle text
- [TASK-260728-7ii1xz_kcdomain.swift](file://TASK-260728-7ii1xz/TASK-260728-7ii1xz_kcdomain.swift) — r2 harness: system-domain keychain resolution probe and contract round-trip against a throwaway keychain
- [TASK-260728-7ii1xz_spawn-log_-reviewer--reviewer--codex-_RUN-260728-005a80.log](file://TASK-260728-7ii1xz/TASK-260728-7ii1xz_spawn-log_-reviewer--reviewer--codex-_RUN-260728-005a80.log) — System spawn log captured by task-board
- [TASK-260728-7ii1xz_reviewer-verdict-02.md](file://TASK-260728-7ii1xz/TASK-260728-7ii1xz_reviewer-verdict-02.md) — Independent review verdict 02 — accepted

## Created
2026-07-28T02:55:06Z

## Last Update
2026-07-28T04:51:19Z

## Assigned To
[reviewer] reviewer (codex)
