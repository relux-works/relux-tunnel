## Status
blocked

## Review
required

## Task Class
code

## Estimate
estimated(fibonacci(8))

## Blocked By
- BUG-260811-3qdo3e

## Blocks
- TASK-260715-1u2vpc

## Checklist
- [x] Replace peer-event snapshot races with a deterministic teardown-completion seam; no sleeps, retries, or wall-clock polling
- [x] Audit every sibling adapter-internal assertion in HEVUDPDatagramAdapterTests and fix the same race shape
- [ ] Pass both named tests in at least twenty consecutive full swift test runs
- [x] Attach task-scoped before/after reproduction evidence and record any anomaly
- [ ] Code written per task description and AC
- [x] Relevant tests written for new or changed behavior and passing
- [x] Lint clean
- [x] Relevant build/validation commands run after changes and build not broken
- [x] New outcome artifact attached on the board with a task-scoped name when the work produces notes, logs, screenshots, or other deliverables
- [x] Important findings, decisions, anomalies, or regressions recorded in logbook when relevant

## Notes
2026-08-11 reproduction from TASK-260715-1u2vpc: full swift test exited 1 with five issues across HEVUDPDatagramAdapterTests boundedBackpressure and replyValidationConsequences (active/closing association and oversized/drop counter snapshots). Both exact tests passed alone (exit 0), confirming aggregate-order sensitivity. Raw logs are attached in TASK-260715-1u2vpc_evidence.zip; full log SHA-256 69b4756b1c0dd2095498eb44ac1f66cc2e92dd233e10d75fdf72496b8702b043.
spawn agent resolution: Agent selection: codex via explicit_override (preferred_agentic_system: mixed[claude,codex], config: spawn.preferred_agentic_system)
spawn launch composition: empty; contract=agents-infra.child-launch-composition; provider=codex; schema=1; producer=dev; diagnostic=launch_composition_empty; no project MCP servers enabled
spawn queued: [implementer] developer (codex) (run=RUN-260811-3d504f, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260811-3d504f)
STOP-THE-LINE: The in-scope teardown seam, suite audit, targeted 20-run gate, format lint, and build pass. The required 20 consecutive unfiltered swift test runs cannot complete because the unrelated LibSSH integration test "caller cancellation is scoped and idle reads have no implicit timeout" hung in three independent gate attempts after the HEV UDP suite had passed. Maximum final clean streak: 12 full runs (426 tests each); run 13 hung after HEVUDPDatagramAdapterTests passed in 1.735s. Failed assumptions/attempts: repeated fresh full-suite streaks, adapter-suite serialization to remove its own blocking-worker/idle anomaly, and cleanup of only task-created leaked sshd fixtures. Changing or stashing the user-owned modified LibSSH test is out of scope. Options: (1) stabilize that LibSSH hang, preferred; (2) provide an isolated full-suite environment where it does not reproduce; (3) explicitly broaden scope to diagnose it. Exact input needed: one of those environment/scope resolutions, then rerun 20 consecutive unfiltered swift test runs. Full evidence: BUG-260728-2j25tu_results.md. Items 3 and 5 remain unchecked; developer handoff was not run.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260811-3d504f, pid=65617, exit=0)

## Precondition Resources
(none)

## Outcome Resources
- [BUG-260728-2j25tu_spawn-log_-implementer--developer--codex-_RUN-260811-3d504f.log](file://BUG-260728-2j25tu/BUG-260728-2j25tu_spawn-log_-implementer--developer--codex-_RUN-260811-3d504f.log) — System spawn log captured by task-board
- [BUG-260728-2j25tu_results.md](file://BUG-260728-2j25tu/BUG-260728-2j25tu_results.md) — Handoff evidence

## Created
2026-07-28T10:10:48Z

## Last Update
2026-08-11T16:53:17Z

## Assigned To
[implementer] developer (codex)
