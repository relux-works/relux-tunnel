## Status
backlog

## Assigned To
[tester] tester (codex)

## Created
2026-07-15T01:03:16Z

## Last Update
2026-08-11T16:20:41Z

## Blocked By
- TASK-260715-1ozsb6
- TASK-260715-2d3g5e
- TASK-260715-9yp8to
- BUG-260728-2j25tu

## Blocks
- TASK-260715-2xx2tk
- TASK-260715-1gjxer

## Checklist
- [x] Every libssh2 functional, compatibility, Apple, and rekey row has metadata
- [x] Window and rekey gaps remain explicit red with reproducible evidence
- [x] Safe mixed-traffic and cleanup evidence plus the full matrix are attached
- [ ] Tests written and passing
- [x] Coverage target ~80%+ for affected code
- [x] Lint clean
- [x] New task-scoped outcome artifact attached on the board for reports, logs, screenshots, or other produced evidence
- [x] Important findings, decisions, anomalies, or regressions recorded in logbook when relevant

## Notes
2026-07-28 replan round 3 (TASK-260728-3a2dnr): restored blocker TASK-260715-2ayxqn. Round 2 had removed it, which scheduled this matrix before Gate P0 existed even though its scope still requires the Gate-P0 provider smoke on the physical Apple-silicon Mac. The matrix is not re-scoped and the Apple-target rows are not weakened; it simply runs after the P0 disposition.
spawn agent resolution: Agent selection: codex via explicit_override (preferred_agentic_system: mixed[claude,codex], config: spawn.preferred_agentic_system)
spawn launch composition: empty; contract=agents-infra.child-launch-composition; provider=codex; schema=1; producer=dev; diagnostic=launch_composition_empty; no project MCP servers enabled
spawn queued: [tester] tester (codex) (run=RUN-260811-d6c00d, max_parallel=1)
spawn run started: [tester] tester (codex) (run=RUN-260811-d6c00d)
TESTER EVIDENCE 2026-08-11: focused libssh2 M0 matrix PASS (46 affected tests, four macOS release builds, artifact/source/rekey gates, 80.28% region/90.04% line coverage, strict format). Four M3 semantics remain explicit unsupported/notReported and physical scale/soak remain M3. Not ready for review: TASK-260715-2d3g5e remains backlog and full swift test exits 1 with five aggregate-order HEV UDP issues; both failers pass alone and are routed to BUG-260728-2j25tu. Owner-approved decoupling makes TASK-260715-9yp8to the passing technical P0 prerequisite; TASK-260715-2ayxqn remains release-only. Evidence: TASK-260715-1u2vpc_results.md and evidence.zip.
agent completed: [tester] tester (codex) (exit=0)
spawn run completed: codex (run=RUN-260811-d6c00d, pid=41033, exit=0)

## Precondition Resources
- [TASK-260715-1u2vpc_ssh-transport-conformance-contract.md](file://TASK-260715-1u2vpc/TASK-260715-1u2vpc_ssh-transport-conformance-contract.md) — Revised M0-viability matrix contract and M3 deferred-state mapping
- [active-macos-libssh2-viability-matrix-scope.md](file://TASK-260715-1u2vpc/active-macos-libssh2-viability-matrix-scope.md) — Binding macOS-only selected-libssh2 M0 viability scope
- [owner-approved-m0-vs-release-gate-decoupling.md](file://TASK-260715-1u2vpc/owner-approved-m0-vs-release-gate-decoupling.md) — Owner-approved decoupling of protocol viability from Apple account release readiness

## Outcome Resources
- [TASK-260715-1u2vpc_spawn-log_-tester--tester--codex-_RUN-260811-d6c00d.log](file://TASK-260715-1u2vpc/TASK-260715-1u2vpc_spawn-log_-tester--tester--codex-_RUN-260811-d6c00d.log) — System spawn log captured by task-board
- [TASK-260715-1u2vpc_results.md](file://TASK-260715-1u2vpc/TASK-260715-1u2vpc_results.md) — Handoff evidence: full M0/M3 libssh2 matrix, metadata, red gates, and resume inputs
- [TASK-260715-1u2vpc_evidence.zip](file://TASK-260715-1u2vpc/TASK-260715-1u2vpc_evidence.zip) — Raw task-scoped libssh2, build, coverage, lint, privacy, and aggregate-red logs

## Estimate
estimated(fibonacci(13))
