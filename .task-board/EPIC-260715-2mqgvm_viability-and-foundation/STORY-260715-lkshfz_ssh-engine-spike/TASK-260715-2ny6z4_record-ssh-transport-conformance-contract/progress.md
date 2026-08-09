## Status
done

## Assigned To
[reviewer] reviewer (claude)

## Created
2026-07-15T01:03:14Z

## Last Update
2026-08-09T23:12:31Z

## Blocked By
- TASK-260715-28ok1k

## Blocks
- TASK-260715-nzdzv3
- TASK-260715-1af33i
- TASK-260715-1ozsb6
- TASK-260715-2d3g5e
- TASK-260720-100wu6

## Checklist
- [x] Candidate-neutral channel, lifecycle, error, and metric semantics are exact
- [x] Host verification, windows, rekey, and bounded backpressure are independently testable
- [x] The reviewed conformance contract is attached
- [x] Tasks created with description and AC
- [x] Dependencies linked
- [x] Tasks are atomic — one clear deliverable each
- [x] Completeness verified — nothing forgotten
- [x] Gaps closed with blocking tasks
- [x] Diagrams or planning artifacts linked as new task-scoped outcome resources
- [x] Important findings, decisions, anomalies, or regressions recorded in logbook when relevant
- [x] Implementation matches AC
- [x] Solution fits project architecture
- [x] Tests green
- [ ] If review does not accept the work — verdict evidence added and status routed by the explicit verdict branches

## Notes
spawn queued: [analyst] solution-architect (codex) (run=RUN-260720-f8cc43, max_parallel=1)
spawn run started: [analyst] solution-architect (codex) (run=RUN-260720-f8cc43)
Recorded the candidate-neutral SSH transport contract with exact connection/channel lifecycle, mandatory pre-auth host evidence, auth outcomes, bounded partial writes, EOF/half-close/reset/cancel/close, per-channel capped receive credit and WINDOW_ADJUST, byte/time/explicit/server rekey, keepalive, cancellation/timeout scopes, stable errors, schema-v1 metrics/events, lane identity, dependency injection, and privacy rules. Defined one unchanged E-ALGO/E-HOSTAUTH/E-CHANNELS/E-BACKPRESSURE/E-WINDOW/E-REKEY/E-KEEPALIVE/E-CANCEL/E-SCALE/E-ERRORS/E-METRICS-PRIVACY/E-INJECTION suite for both candidates. Created atomic TASK-260720-100wu6 Implement the candidate-neutral SSH transport contract and linked it between this contract and both adapters plus the common suite. Attached the contract, three PlantUML sources, three visually inspected SVGs, and downstream precondition copies. Board validation, contract coverage/hash check, PlantUML syntax, SVG XML/error scan, and git diff check pass; ADR-014 remains open.
agent completed: [analyst] solution-architect (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-f8cc43, pid=35551, exit=0)
spawn queued: [reviewer] reviewer (claude) (run=RUN-260720-fe3f47, max_parallel=1)
spawn run started: [reviewer] reviewer (claude) (run=RUN-260720-fe3f47)
REVIEW ACCEPTED. Verified against .spec/ssh-transport.md, .spec/security-privacy.md, ADR-005/006/014, and the accepted TASK-260715-28ok1k audit. AC1: sections 5/8/11/12/13 define every operation, state transition, cancellation point, timeout, ownership boundary, stable error, schema-v1 metric/event, and privacy rule; section 14 maps them to E-ALGO..E-INJECTION rows covering the full M0 gate matrix. AC2: section 6 mandates raw wire-format key bytes + exact algorithm + SHA256 fingerprint to injected policy before any credential lookup, with first-use (explicit-record only), match, and changed-key stop exactly per security-privacy.md; diagram asserts credentials untouched on rejection. AC3: sections 7/8 give direct-tcpip and exec explicit open, bounded partial writeSome with FIFO prefix-retry semantics, read, EOF, independent half-close, reset (honestly noting no TCP-RST guarantee), cancel, idempotent close. AC4: section 9 requires settable initial window, immutable cap, delivered-bytes-earn-credit adjustment invariant, typed windowAdjusted events, and explicitly overrides libssh2 2MiB helper default and NIOSSH 16MiB target; section 10 covers byte/time/explicit-production-path/server rekey with generation counter and keepalive — all independently observable via events/snapshot. AC5: type-erased factory, common enums, capability report as data, adapterFailure mapping — no candidate type crosses the boundary; audit gaps (NIOSSH no public window/rekey -> fork hooks in nzdzv3; libssh2 manual rekey scheduling + generic open) are all representable. Cross-checks: contract matches audit facts verbatim; all 6 precondition copies hash-identical to the reviewed contract; 3 PlantUML sources render to valid SVGs consistent with contract text; TASK-260720-100wu6 created atomically with description/scope/AC and correctly linked (blocked by 2ny6z4, blocks 1af33i/1ozsb6/2d3g5e); no product code touched (doc-only as required); board validates clean; logbook entry recorded. Tests-green interpreted as doc-task analog: board validation + PlantUML syntax + hash checks pass. No gaps found; ADR-014 remains open as required.
agent completed: [reviewer] reviewer (claude) (exit=0)
spawn run completed: claude (run=RUN-260720-fe3f47, pid=46095, exit=0)

## Precondition Resources
- [TASK-260715-2ny6z4_inputs.md](file://TASK-260715-2ny6z4/TASK-260715-2ny6z4_inputs.md) — SSH conformance contract inputs

## Outcome Resources
- [TASK-260715-2ny6z4_spawn-log_-analyst--solution-architect--codex-.log](file://TASK-260715-2ny6z4/TASK-260715-2ny6z4_spawn-log_-analyst--solution-architect--codex-.log) — System spawn log captured by task-board
- [TASK-260715-2ny6z4_ssh-transport-conformance-contract.md](file://TASK-260715-2ny6z4/TASK-260715-2ny6z4_ssh-transport-conformance-contract.md) — Canonical SSH transport conformance contract revised to approved M0 viability scope
- [TASK-260715-2ny6z4_connection-lifecycle.puml](file://TASK-260715-2ny6z4/TASK-260715-2ny6z4_connection-lifecycle.puml) — PlantUML source for connection lifecycle and ownership
- [TASK-260715-2ny6z4_connection-lifecycle.svg](file://TASK-260715-2ny6z4/TASK-260715-2ny6z4_connection-lifecycle.svg) — Rendered connection lifecycle diagram
- [TASK-260715-2ny6z4_host-verification-sequence.puml](file://TASK-260715-2ny6z4/TASK-260715-2ny6z4_host-verification-sequence.puml) — PlantUML source for mandatory pre-auth host verification
- [TASK-260715-2ny6z4_host-verification-sequence.svg](file://TASK-260715-2ny6z4/TASK-260715-2ny6z4_host-verification-sequence.svg) — Rendered pre-auth host verification sequence
- [TASK-260715-2ny6z4_channel-window-rekey-sequence.puml](file://TASK-260715-2ny6z4/TASK-260715-2ny6z4_channel-window-rekey-sequence.puml) — PlantUML source for bounded channel credit and rekey
- [TASK-260715-2ny6z4_channel-window-rekey-sequence.svg](file://TASK-260715-2ny6z4/TASK-260715-2ny6z4_channel-window-rekey-sequence.svg) — Rendered bounded channel window and rekey sequence
- [TASK-260715-2ny6z4_spawn-log_-reviewer--reviewer--claude-.log](file://TASK-260715-2ny6z4/TASK-260715-2ny6z4_spawn-log_-reviewer--reviewer--claude-.log) — System spawn log captured by task-board
