## Status
blocked

## Assigned To
[implementer] developer (codex)

## Created
2026-07-15T01:03:15Z

## Last Update
2026-07-28T01:18:28Z

## Blocked By
- TASK-260715-nzdzv3
- TASK-260715-2ny6z4
- TASK-260715-2nfz7w
- TASK-260715-1g9cyt
- TASK-260715-pmww4f
- TASK-260720-100wu6
- TASK-260720-34d4du

## Blocks
- TASK-260715-3ikonq

## Checklist
- [ ] Adapter fully conforms without leaking candidate types
- [ ] Host key, channels, windows, rekey, cancellation, and metrics are wired
- [ ] Apple-target and harness build or smoke evidence is attached
- [ ] Code written per task description and AC
- [ ] Relevant tests written for new or changed behavior and passing
- [ ] Lint clean
- [ ] Relevant build/validation commands run after changes and build not broken
- [x] New outcome artifact attached on the board with a task-scoped name when the work produces notes, logs, screenshots, or other deliverables
- [x] Important findings, decisions, anomalies, or regressions recorded in logbook when relevant

## Notes
spawn queued: [implementer] developer (codex) (run=RUN-260720-bf5c69, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260720-bf5c69)
STOP-THE-LINE 2026-07-20: required development transition rejected because TASK-260720-100wu6 Implement the candidate-neutral SSH transport contract is backlog. Source inspection confirms SSHContracts.swift is still the earlier skeleton, so implementing this adapter now would duplicate or leak the common boundary. Evidence, rejected forced-fit options, recommendation, and exact resume condition are attached in TASK-260715-1af33i_blocker.md. No product code changed; tests and builds were not run because implementation could not validly start.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-bf5c69, pid=86256, exit=0)
spawn queued: [implementer] developer (codex) (run=RUN-260720-18645b, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260720-18645b)
STOP-THE-LINE 2026-07-20: accepted core and fork APIs do not compose for three mandatory clauses: the neutral async signer cannot produce NIOSSHPrivateKey authentication offers; reply-requiring generic keepalive is internal-only; caller KEX/host-key policy and exact negotiated KEX/host-key/cipher/MAC are not public. No product code changed and no tests/builds were run because implementation cannot validly begin. Evidence, rejected forced fits, viable options, recommendation, and exact resume condition are attached in TASK-260715-1af33i_fork-api-blocker.md and recorded in LOGBOOK.md.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-18645b, pid=12698, exit=0)
spawn queued: [implementer] developer (codex) (run=RUN-260720-c15d42, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260720-c15d42)
STOP-THE-LINE 2026-07-20 round 2: accepted core and fork APIs still do not compose for mandatory E-WINDOW/E-INJECTION behavior. The fork returns full-frame receive credit at NIO pipeline delivery before bounded SSHByteChannel.read consumption, and the neutral SSHTCPConnection cannot be hosted by NIOSSH without a transferable socket/engine-bootstrap seam. No product code changed. Focused fork window test passed; adapter/root/Apple builds were not run because no valid adapter can be constructed. Evidence, rejected forced fits, options, recommendation, and exact resume condition are attached in TASK-260715-1af33i_adapter-api-blocker.md and recorded in LOGBOOK.md.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-c15d42, pid=46407, exit=0)
ORCHESTRATOR DEFERRAL (2026-07-20): NIOSSH adapter blocked on round-2 composition gaps (see fork-api-blocker + adapter-api-blocker): (Gap 1) fork returns receive credit at frame-delivery, contract requires consumer-driven credit after read(maximumBytes:) — proper backpressure; (Gap 2) neutral byte-seam SSHTCPConnection (fakeable, E-INJECTION) conflicts with NIOSSH channel-ownership (needs connected-socket/NIO pipeline). Resolving these requires BOTH a neutral-contract seam revision (connected-socket-lease/engine-bootstrap that stays fakeable) AND further fork surgery (consumer-driven credit + intake bound). This is the 3rd round of NIOSSH-specific gaps. DECISION: rather than keep bending contract+fork around NIOSSH, first prove the contract with libssh2 (TASK-260715-1ozsb6, whose callback transport fits the byte-seam) and gather comparative evidence. The accumulating NIOSSH fork/contract cost is recorded viability evidence for the engine selection (TASK-260715-1gjxer, gated on P0). RESUME 1af33i only after: (a) 1ozsb6 validates the contract, and (b) 1gjxer either selects NIOSSH (then invest the seam+fork changes) or selects libssh2 (then close 1af33i). Not escalating to human yet — libssh2 evidence needed first.
2026-07-28 replan (TASK-260728-3a2dnr): human decision makes libssh2 the primary M0 candidate. ReluxNIOSSH stays recorded comparative evidence and receives no further fork work unless new evidence invalidates libssh2. This task is off the macOS prototype critical path; it no longer blocks TASK-260715-2d3g5e. Prior blocker evidence is retained. Reactivate only on an explicit decision.
DEFERRED 2026-07-28 by TASK-260728-3a2dnr under ADR-014 + ADR-027.
Constraint: ADR-014 selected libssh2 as the primary SSH engine and states ReluxNIOSSH receives no further fork work unless new evidence invalidates libssh2. This adapter integration IS further fork work.
Evidence: three rounds of pinned-source analysis recorded on TASK-260715-1ozsb6 and TASK-260715-1gjxer; prior blocker evidence on this task is retained unchanged.
Why blocked and not backlog: with its blockers satisfied this task became schedulable and a previous plan placed it in Wave 1 of the autonomous run, i.e. prohibited work would have re-entered the critical path. blocked status is the only board mechanism that prevents that while preserving all evidence and the downstream 3ikonq -> 2xx2tk comparative chain.
Alternatives considered: (a) leave in backlog and rely on the plan document to exclude it - rejected, the scheduler reads the board, not the document; (b) close it - rejected, deferral is reversible and the comparative evidence has value.
Exact input needed to resume: an owner decision that new evidence invalidates libssh2 as primary engine, which would reopen ADR-014.

## Precondition Resources
- [TASK-260715-1af33i_ssh-transport-conformance-contract.md](file://TASK-260715-1af33i/TASK-260715-1af33i_ssh-transport-conformance-contract.md) — Candidate-neutral SSH transport contract from TASK-260715-2ny6z4; consume after blocker review acceptance
- [TASK-260715-1af33i_inputs.md](file://TASK-260715-1af33i/TASK-260715-1af33i_inputs.md) — ReluxNIOSSH adapter requirements

## Outcome Resources
- [TASK-260715-1af33i_spawn-log_-implementer--developer--codex-.log](file://TASK-260715-1af33i/TASK-260715-1af33i_spawn-log_-implementer--developer--codex-.log) — System spawn log captured by task-board
- [TASK-260715-1af33i_blocker.md](file://TASK-260715-1af33i/TASK-260715-1af33i_blocker.md) — Stop-the-line evidence for missing common SSH contract
- [TASK-260715-1af33i_fork-api-blocker.md](file://TASK-260715-1af33i/TASK-260715-1af33i_fork-api-blocker.md) — Stop-the-line evidence for missing ReluxNIOSSH authentication, keepalive, and algorithm negotiation APIs
- [TASK-260715-1af33i_adapter-api-blocker.md](file://TASK-260715-1af33i/TASK-260715-1af33i_adapter-api-blocker.md) — Stop-the-line evidence for TCP ownership and consumer-driven receive-credit gaps
- [TASK-260715-1af33i_window-gap-test-01.log](file://TASK-260715-1af33i/TASK-260715-1af33i_window-gap-test-01.log) — Focused fork receive-window behavior test evidence
