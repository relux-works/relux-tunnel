## Status
done

## Assigned To
[reviewer] reviewer (codex)

## Created
2026-07-15T01:43:57Z

## Last Update
2026-07-20T15:42:29Z

## Blocked By
- TASK-260715-2azda7

## Blocks
- TASK-260715-1jvgcn
- TASK-260715-1q7u14
- TASK-260715-297gq6
- TASK-260715-1loqwb
- TASK-260715-3xpc6b

## Checklist
- [x] Verify byte-exact IPv4 IPv6 and domain vectors against HEV framing
- [x] Test inconsistent inner and outer lengths before allocation or slicing
- [x] Preserve response source endpoints and privacy-safe diagnostics
- [x] Code written per task description and AC
- [x] Relevant tests written for new or changed behavior and passing
- [x] Lint clean
- [x] Relevant build/validation commands run after changes and build not broken
- [x] New outcome artifact attached on the board with a task-scoped name when the work produces notes, logs, screenshots, or other deliverables
- [x] Important findings, decisions, anomalies, or regressions recorded in logbook when relevant
- [x] Implementation matches AC
- [x] Solution fits project architecture
- [x] Tests green
- [x] If review does not accept the work — verdict evidence added and status routed by the explicit verdict branches

## Notes
TASK-260715-18owh7 decision ready for review: MSGLEN ceiling = fixed v1 constant 1472 (HEV UDP_BUF_SIZE 1500 reply bound: addrlen+datlen<=1500 is HEV-stream-fatal on overflow; worst IPv6 19+1472=1491). Violation (MSGLEN>1472) is association-fatal; policy (localCap<MSGLEN<=1472) is a drop. Swift adapter discards oversized HEV-ingress records with bounded skip + hevOversizedInbound counter, never frames them. Decision §4.2/§4.4.
spawn queued: [implementer] developer (codex) (run=RUN-260720-d7f313, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260720-d7f313)
Implemented exact HEV UDP payload codecs in Swift and Go with opaque domain bytes, source-endpoint preservation, pre-materialization inner/outer length validation, protocol-vs-local limit dispositions, and finite privacy-safe errors. Verification evidence is attached as TASK-260715-516lhy_results.md; LOGBOOK entry 1920 records the non-obvious domain and error-boundary decisions.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-d7f313, pid=65951, exit=0)
spawn queued: [reviewer] reviewer (codex) (run=RUN-260720-cd3039, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260720-cd3039)
REVIEW CHANGES REQUESTED (2026-07-20): both Swift and Go decode paths apply MSGLEN protocol/local caps before HEV structural validation, contrary to accepted TASK-260715-18owh7 section 4.4 step 4 then step 5. With local cap 512, truncated record 02 01 0A 01 C0 00 02 01 00 35 incorrectly returns survivable local-cap reject instead of association-fatal structural failure. Reorder validation and add mirrored malformed-plus-limit precedence tests plus a structurally valid 1473-byte violation vector. Full existing tests and validation are green but miss/codify this case. Evidence: TASK-260715-516lhy_review.md.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-cd3039, pid=75406, exit=0)
spawn queued: [implementer] developer (codex) (run=RUN-260720-4ef717, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260720-4ef717)
REWORK ROUND 1 (2026-07-20): Swift and Go now validate complete HEV structure before protocol/local MSGLEN consequences. Mirrored 513/1473 malformed tables prove association-close and zero materialization; structurally valid 1473 remains protocol-fatal and valid 513 remains local-policy reject. Gates pass: relay-protocol-check, Swift 150/150, Go vet/test 91.3%, fuzz 1,135,854 executions, strict format/gofmt, core boundaries, diff check. Evidence: TASK-260715-516lhy_rework-01-results.md. Toolchain note: repository smoke uses installed Go 1.25.5; pinned 1.26.5 relay module remains TASK-260715-27uz4n ownership.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-4ef717, pid=80791, exit=0)
spawn queued: [reviewer] reviewer (codex) (run=RUN-260720-7b7e08, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260720-7b7e08)
REVIEW ACCEPTED round 2 (2026-07-20): structural validation now precedes protocol/local MSGLEN policy in Swift and Go; mirrored 513/1473 malformed precedence tests prove association-close with zero decoded materialization, while valid 1473 and valid 513 preserve protocol-close versus local-reject outcomes. Full independent gates pass. Evidence: TASK-260715-516lhy_review-02.md.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-7b7e08, pid=86768, exit=0)

## Precondition Resources
- [TASK-260715-516lhy_relay-binding-input.md](file://TASK-260715-516lhy/TASK-260715-516lhy_relay-binding-input.md) — Frozen TASK-260715-111tde relay binding decision; consume the task-specific artifact and validation map
- [TASK-260715-516lhy_rework-01.md](file://TASK-260715-516lhy/TASK-260715-516lhy_rework-01.md) — Review rework: structural validation must precede MSGLEN protocol/local limit policy

## Outcome Resources
- [TASK-260715-516lhy_spawn-log_-implementer--developer--codex-.log](file://TASK-260715-516lhy/TASK-260715-516lhy_spawn-log_-implementer--developer--codex-.log) — System spawn log captured by task-board
- [TASK-260715-516lhy_results.md](file://TASK-260715-516lhy/TASK-260715-516lhy_results.md) — Rework implementation and verification evidence for structural-before-limit HEV validation
- [TASK-260715-516lhy_spawn-log_-reviewer--reviewer--codex-.log](file://TASK-260715-516lhy/TASK-260715-516lhy_spawn-log_-reviewer--reviewer--codex-.log) — System spawn log captured by task-board
- [TASK-260715-516lhy_review.md](file://TASK-260715-516lhy/TASK-260715-516lhy_review.md) — Reviewer verdict and rework evidence for structural-before-limit validation
- [TASK-260715-516lhy_rework-01-results.md](file://TASK-260715-516lhy/TASK-260715-516lhy_rework-01-results.md) — Structural-before-limit rework round and validation evidence
- [TASK-260715-516lhy_review-02.md](file://TASK-260715-516lhy/TASK-260715-516lhy_review-02.md) — Accepted second-review verdict and independent validation evidence
