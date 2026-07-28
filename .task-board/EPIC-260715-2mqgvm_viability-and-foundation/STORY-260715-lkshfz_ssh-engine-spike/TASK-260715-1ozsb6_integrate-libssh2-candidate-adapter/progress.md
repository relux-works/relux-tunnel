## Status
to-dev

## Assigned To
[implementer] developer (codex)

## Created
2026-07-15T01:03:15Z

## Last Update
2026-07-28T00:48:48Z

## Blocked By
- TASK-260715-28ok1k
- TASK-260715-2ny6z4
- TASK-260715-2nfz7w
- TASK-260715-1g9cyt
- TASK-260715-pmww4f
- TASK-260720-100wu6
- TASK-260720-3vwls7
- TASK-260720-2sltje
- TASK-260728-yx2fca

## Blocks
- TASK-260715-2d3g5e
- TASK-260715-1u2vpc

## Checklist
- [ ] Extension-safe libssh2 adapter and nonblocking integration build reproducibly
- [x] Unsupported window or rekey behavior is recorded red rather than bypassed
- [ ] Harness and Apple-target conformance evidence is attached
- [ ] Code written per task description and AC
- [ ] Relevant tests written for new or changed behavior and passing
- [ ] Lint clean
- [ ] Relevant build/validation commands run after changes and build not broken
- [x] New outcome artifact attached on the board with a task-scoped name when the work produces notes, logs, screenshots, or other deliverables
- [x] Important findings, decisions, anomalies, or regressions recorded in logbook when relevant

## Notes
spawn queued: [implementer] developer (codex) (run=RUN-260720-2f7acd, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260720-2f7acd)
STOP-LINE: exact pinned libssh2 source confirms no public client-rekey API. Mandatory byte/time/explicit rekey cannot conform without a forbidden private-symbol call or separately authorized fork. Evidence, rejected workarounds, options, recommendation, and exact resume decision are attached in TASK-260715-1ozsb6_libssh2-rekey-blocker.md. No product code or partial packaging was started; tests/builds were not run because the architecture/API blocker occurs before a valid implementation exists.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-2f7acd, pid=59170, exit=0)
spawn queued: [implementer] developer (codex) (run=RUN-260720-8e319e, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260720-8e319e)
STOP-LINE after accepted client-rekey fork: pinned public libssh2 still exposes neither server-initiated KEX lifecycle/generation nor reply-correlated keepalive/global-request results. Without those seams the adapter cannot truthfully emit server rekey state/events or keepalive RTT/timeout/miss metrics. Exact source/symbol evidence, rejected forced fits, viable options, recommendation, and resume input are attached in TASK-260715-1ozsb6_server-rekey-keepalive-blocker.md; LOGBOOK.md updated. No product code or mock-only conformance tests were added.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-8e319e, pid=20956, exit=0)
spawn queued: [implementer] developer (codex) (run=RUN-260720-7d2228, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260720-7d2228)
STOP-LINE round 3: the accepted public fork still cannot enforce consumer-driven receive credit/cap because channel_read auto-adjusts before delivery; it collapses RFC channel-open reason codes; and it cannot distinguish exit status 0 from absent metadata or expose exit-signal coreDumped. Exact source/header hashes, rejected forced fits, consolidated fork vs fail-red vs M0-to-M3 options, recommendation, and required decision are attached in TASK-260715-1ozsb6_third-public-api-blocker.md. LOGBOOK.md updated. No adapter/package code was started; adapter tests and Apple builds were not run because the current public surface cannot satisfy the mandatory contract.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-7d2228, pid=32102, exit=0)
ESCALATION TO HUMAN — M0-vs-M3 SSH-CONTRACT-SCOPE DECISION (orchestrator, 2026-07-20). Round 3 of libssh2 adapter (and NIOSSH also blocked) proves a definitive pattern: the reviewed candidate-neutral contract (2ny6z4/100wu6) requires precise semantics that NO public SSH library exposes, so EVERY engine needs repeated fork surgery. Remaining libssh2 gaps: (1) consumer-driven receive-window credit with immutable cap — libssh2 ssh2_channel_read auto-adjusts credit on read ENTRY before consumer delivery (SAME class as NIOSSH frame-delivery credit); (2) candidate-neutral channel-open rejection reason categories (libssh2 collapses RFC codes); (3) exact exec-exit metadata (status(0) vs notReported + coreDumped). NIOSSH remains worse (contract-seam mismatch + consumer-credit + growing fork). DECISION NEEDED (one of): [A recommended] RE-SCOPE the M0 adapter contract to VIABILITY-level — control surfaces + host-key verify + direct-tcpip/exec/upload + client-rekey trigger + basic lifecycle + cheaply-available observability; DEFER precise consumer-driven-credit, channel-open reason categories, exact exec-exit metadata, and deep rekey/keepalive observability to M3 (they map to M3 stories 19ii11 instrumentation / 1zzt0c+s3at1l rekey+memory). Unblocks BOTH adapters with current forks. Needs security sign-off (touches accepted security/liveness evidence). [B] Keep forking the chosen engine(s) until the full contract is met — unbounded maintenance, likely recurs. [C] Select libssh2 NOW (far cleaner fit) + one focused fork for the 3 gaps + drop NIOSSH — makes the 1gjxer selection early, before P0 physical evidence, but the architecture evidence is strong. RECOMMENDATION: A (align M0 to viability), or C if you prefer not to revise the contract. Meanwhile continuing all SSH-independent M0/M1/M2 work autonomously. See TASK-260715-1ozsb6_third-public-api-blocker.md + STORY-260715-lkshfz notes.
2026-07-28 human decision recorded: approve M0 viability scope and make libssh2 the primary candidate. Contract/task/consumer mapping must be revised before restarting this task; deferred M3 semantics remain explicitly evidence-gated.

## Precondition Resources
- [TASK-260715-1ozsb6_ssh-transport-conformance-contract.md](file://TASK-260715-1ozsb6/TASK-260715-1ozsb6_ssh-transport-conformance-contract.md) — Candidate-neutral SSH transport contract from TASK-260715-2ny6z4; consume after blocker review acceptance
- [TASK-260715-1ozsb6_inputs.md](file://TASK-260715-1ozsb6/TASK-260715-1ozsb6_inputs.md) — libssh2 adapter requirements + neutral-seam fit
- [TASK-260715-1ozsb6_approved-m0-viability-decision.md](file://TASK-260715-1ozsb6/TASK-260715-1ozsb6_approved-m0-viability-decision.md) — Human-approved SSH scope and candidate decision

## Outcome Resources
- [TASK-260715-1ozsb6_spawn-log_-implementer--developer--codex-.log](file://TASK-260715-1ozsb6/TASK-260715-1ozsb6_spawn-log_-implementer--developer--codex-.log) — System spawn log captured by task-board
- [TASK-260715-1ozsb6_libssh2-rekey-blocker.md](file://TASK-260715-1ozsb6/TASK-260715-1ozsb6_libssh2-rekey-blocker.md) — Pinned-source proof, rejected forced fits, options, recommendation, and exact resume decision
- [TASK-260715-1ozsb6_server-rekey-keepalive-blocker.md](file://TASK-260715-1ozsb6/TASK-260715-1ozsb6_server-rekey-keepalive-blocker.md) — Pinned public-API proof, rejected forced fits, options, recommendation, and exact resume decision for server-rekey and keepalive gaps
- [TASK-260715-1ozsb6_third-public-api-blocker.md](file://TASK-260715-1ozsb6/TASK-260715-1ozsb6_third-public-api-blocker.md) — Third-round pinned-source evidence, rejected forced fits, M0-versus-M3 options, recommendation, and exact resume decision
