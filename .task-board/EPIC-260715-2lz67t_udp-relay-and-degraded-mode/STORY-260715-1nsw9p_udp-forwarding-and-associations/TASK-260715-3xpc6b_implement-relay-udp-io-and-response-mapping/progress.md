## Status
done

## Assigned To
[reviewer] reviewer (codex)

## Created
2026-07-15T01:44:42Z

## Last Update
2026-07-21T13:46:26Z

## Blocked By
- TASK-260715-xw5dxc
- TASK-260715-516lhy

## Blocks
- TASK-260715-28jdml
- TASK-260715-z37ay7
- TASK-260715-1ut6ot

## Checklist
- [x] Send and receive byte-exact IPv4 IPv6 and bounded-domain datagrams
- [x] Map oversize resolution socket pressure and cancellation outcomes deterministically
- [x] Prove fair event-loop budgets source-endpoint preservation and log privacy
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
TASK-260715-18owh7 decision ready for review: §4.4 numbered order is the normative pre-socket sequence — prefix/frameLength -> type/direction -> association admission (0x0004) -> HEV structural -> MSGLEN 1472/local cap (0x0005 violation-vs-policy) -> resolver-form rules -> queue credit (0x0006) -> only then socket/resolver. Decision resource TASK-260715-18owh7_decision.md.
spawn queued: [implementer] developer (codex) (run=RUN-260721-ce2e82, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260721-ce2e82)
Implemented bounded registry-owned UDP send/receive, strict cancellable domain resolution, finite error/drop mapping, fair turn budgets, readiness-only retry, source preservation, and stale-generation cleanup. Pinned Go repeated/race/full/vet/build/coverage/cross-compile gates, relay protocol check, 318 Swift tests, Swift build, formatting, privacy/prohibition scans, and board validation pass. Evidence: TASK-260715-3xpc6b_results.md; LOGBOOK 1630.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-ce2e82, pid=72659, exit=0)
spawn queued: [reviewer] reviewer (codex) (run=RUN-260721-538343, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260721-538343)
Independent review requests changes. Blocking evidence is attached in TASK-260715-3xpc6b_review.md. Main defect: domain resolution starts before registry admission/incarnation ownership, so a paused lookup can outlive close and recreate or send through a newer same-generation association. Resolution is also synchronous on the event-loop caller, truncation is mapped after sockaddr conversion, and mapped-IPv6 rejection occurs after socket admission. Fresh repeat/race/full Go, coverage/cross-compile, protocol, Swift, formatting, privacy, and board gates are green, but the missing lifecycle tests leave the AC unmet.
Review findings also recorded in LOGBOOK 1645 for cross-task handoff.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-538343, pid=93795, exit=0)
spawn queued: [implementer] developer (codex) (run=RUN-260721-d58728, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260721-d58728)
Rework 01 closes all four independent-review findings: incarnation-first socketless reservation, fixed bounded asynchronous resolver workers/jobs/completions, truncation-before-sockaddr conversion, and mapped-IPv6 preflight. Barrier tests cover close, expiry, cancellation, replacement, shutdown, parent cancellation, queued cancellation, and same-ID reuse with zero stale send/reopen and exact resource baselines. Pinned Go 1.26.5 repeat/race/full/vet/build/coverage/cross-build, relay protocol, 318 Swift tests/build, formatting, privacy/prohibition scans, and board validation pass. Updated TASK-260715-3xpc6b_results.md and LOGBOOK 1705; raw spawn log removed.
agent completed: [implementer] developer (codex) (exit=0)
spawn completion blocked: no new task-scoped outcome artifact was attached. Add an outcome resource named like TASK-260715-3xpc6b_results.md and then set status back to to-review.
spawn run completed: codex (run=RUN-260721-d58728, pid=4720, exit=0)
spawn queued: [reviewer] reviewer (codex) (run=RUN-260721-9cedfd, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260721-9cedfd)
Independent rework review 02 requests changes. The incarnation-first async resolver, exact-token cancellation races, truncation precedence, mapped-IPv6 preflight, fairness, source fidelity, and resource baselines are verified. Remaining defects: Registry Reserve/Ensure/EnsureTokenFamilies touch existing associations before sendto, so outbound EAGAIN, ENOBUFS, resolver/error paths can refresh idle activity; resolver result filtering also accepts zoned IPv6 and system SendTo drops the zone when constructing SockaddrInet6. Current tests do not cover either path. Actionable evidence and fresh green gate results: TASK-260715-3xpc6b_review-02.md. Findings recorded in LOGBOOK 1707. Route: to-dev.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-9cedfd, pid=24604, exit=0)
spawn queued: [implementer] developer (codex) (run=RUN-260721-590b94, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260721-590b94)
Rework 02 closes both review findings: existing Reserve/Ensure/token-family admission no longer rearms idle activity; injected-clock tests prove only successful numeric/resolved sends refresh exact deadline/arm epochs, while EAGAIN, ENOBUFS, resolver failure/cancellation, and terminal errors do not. Scoped resolver IPv6 is discarded before byte credit/socket/send with deterministic unzoned fallback. Pinned repeat/race/full/vet/build/coverage/cross-build, protocol, 318 Swift tests/build, formatting, privacy/resource scans, and board validation pass. Evidence: TASK-260715-3xpc6b_rework-02-results.md; LOGBOOK 1719. Raw spawn log removed.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-590b94, pid=32986, exit=0)
spawn queued: [reviewer] reviewer (codex) (run=RUN-260721-28857f, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260721-28857f)
spawn queued: [reviewer] reviewer (codex) (run=RUN-260721-2cf9ee, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260721-2cf9ee)
Final independent recovery review accepted. Source audit verified successful-send-only activity deadlines/epochs, scoped IPv6 filtering before credit/socket/send, incarnation-first bounded async resolver lifecycle, truncation/mapped-address precedence, fairness, source fidelity, privacy, and scope. Fresh Go 1.26.5 count=100/race count=10/full/vet/build/coverage/cross-build, protocol, 318-test Swift, build/format/diff, privacy/resource, and board gates passed. Verdict evidence: TASK-260715-3xpc6b_review-03.md.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-2cf9ee, pid=50226, exit=0)

## Precondition Resources
- [TASK-260715-3xpc6b_protocol-v1-developer-contract.md](file://TASK-260715-3xpc6b/TASK-260715-3xpc6b_protocol-v1-developer-contract.md) — Accepted relay protocol v1 developer contract and compatibility gates from TASK-260715-2z9b4a
- [TASK-260715-3xpc6b_execution-brief.md](file://TASK-260715-3xpc6b/TASK-260715-3xpc6b_execution-brief.md) — Bounded relay UDP I/O, resolver, fairness, cancellation and privacy implementation constraints
- [TASK-260715-3xpc6b_reviewer-focus.md](file://TASK-260715-3xpc6b/TASK-260715-3xpc6b_reviewer-focus.md) — Independent UDP I/O, resolver bounds, fairness, error mapping and privacy review
- [TASK-260715-3xpc6b_rework-01.md](file://TASK-260715-3xpc6b/TASK-260715-3xpc6b_rework-01.md) — Incarnation-first async resolver lifecycle, truncation precedence and mapped-IPv6 preflight
- [TASK-260715-3xpc6b_reviewer-focus-02.md](file://TASK-260715-3xpc6b/TASK-260715-3xpc6b_reviewer-focus-02.md) — Fresh verification of incarnation-first bounded async resolver rework and precedence fixes
- [TASK-260715-3xpc6b_rework-02.md](file://TASK-260715-3xpc6b/TASK-260715-3xpc6b_rework-02.md) — Successful-send-only activity refresh and scoped resolver IPv6 rejection
- [TASK-260715-3xpc6b_reviewer-focus-03.md](file://TASK-260715-3xpc6b/TASK-260715-3xpc6b_reviewer-focus-03.md) — Final independent review of successful-send-only activity and scoped-result filtering
- [TASK-260715-3xpc6b_reviewer-focus-04.md](file://TASK-260715-3xpc6b/TASK-260715-3xpc6b_reviewer-focus-04.md) — Recovery fresh reviewer after ENOSPC killed the prior verdict handoff

## Outcome Resources
- [TASK-260715-3xpc6b_results.md](file://TASK-260715-3xpc6b/TASK-260715-3xpc6b_results.md) — Rework implementation, lifecycle tests, activity semantics, scoped-result filtering, and verification evidence
- [TASK-260715-3xpc6b_review.md](file://TASK-260715-3xpc6b/TASK-260715-3xpc6b_review.md) — Independent UDP I/O review verdict and rework evidence
- [TASK-260715-3xpc6b_review-02.md](file://TASK-260715-3xpc6b/TASK-260715-3xpc6b_review-02.md) — Independent rework review verdict and send-activity/address evidence
- [TASK-260715-3xpc6b_rework-02-results.md](file://TASK-260715-3xpc6b/TASK-260715-3xpc6b_rework-02-results.md) — Successful-send activity and scoped IPv6 resolver rework evidence
- [TASK-260715-3xpc6b_review-03.md](file://TASK-260715-3xpc6b/TASK-260715-3xpc6b_review-03.md) — Final independent recovery review accepted verdict
