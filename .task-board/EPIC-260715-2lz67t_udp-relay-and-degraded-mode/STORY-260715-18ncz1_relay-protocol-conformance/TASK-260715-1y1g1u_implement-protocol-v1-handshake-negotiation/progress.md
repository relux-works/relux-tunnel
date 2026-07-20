## Status
done

## Assigned To
[reviewer] reviewer (codex)

## Created
2026-07-15T01:43:57Z

## Last Update
2026-07-20T14:30:05Z

## Blocked By
- TASK-260715-2azda7

## Blocks
- TASK-260715-1jvgcn
- TASK-260715-1q7u14
- TASK-260715-297gq6
- TASK-260715-2ywde4
- TASK-260715-159pcp

## Checklist
- [x] Implement and test the hello state machine in both peers
- [x] Prove every version status limit timeout and cancellation failure mapping
- [x] Record negotiated feature and frame summaries without remote-controlled text
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
TASK-260715-18owh7 decision ready for review: maxFrame accept range [2048,65536], default advertise 4096, effective=min(client,server,local hard cap) clamped before any body-sized allocation; out-of-range -> server status 0x0002, client unreasonableMaxFrame close, no downgrade guess. Build RelayEffectiveLimits snapshot (fields in decision §4.6) at handshake completion. Floor rationale: max legal v1 frame body = 6+255+1472 = 1733 <= 2048, so every accepted hello carries every legal frame.
spawn queued: [implementer] developer (claude) (run=RUN-260720-a4db0b, max_parallel=1)
spawn run started: [implementer] developer (claude) (run=RUN-260720-a4db0b)
agent completed: [implementer] developer (claude) (exit=1)
spawn run completed: claude (run=RUN-260720-a4db0b, pid=35066, exit=1)
spawn queued: [implementer] developer (codex) (run=RUN-260720-6e2140, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260720-6e2140)
Implemented Swift client and Go relay protocol-v1 handshake state machines with exact generated layouts, bounded incremental parsing, coalesced-byte handoff, feature intersection, maxFrame negotiation, RelayEffectiveLimits, timeout/cancellation/EOF/stale handling, deterministic close semantics, and privacy-safe typed failures. Validation: swift test 128/128; swift build; make relay-protocol-check with 18 RelayProtocol tests; Go gofmt/vet/test CGO_ENABLED=0 and 92.1% coverage; strict swift-format; core boundary check; board validate. Outcome: TASK-260715-1y1g1u_results.md. Known inherited constraint: relay/go.mod/pinned Go 1.26.5 validation remains owned by TASK-260715-27uz4n; accepted smoke ran local Go 1.25.5.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-6e2140, pid=83638, exit=0)
spawn queued: [reviewer] reviewer (codex) (run=RUN-260720-6dcd9e, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260720-6dcd9e)
REVIEW VERDICT 2026-07-20: changes requested. Architecture placement and all current validation gates pass, but AC is not met: (1) Swift and Go RelayEffectiveLimits copy injected local-only limits directly instead of min(respective schema default-or-constant, injected config) required by accepted TASK-260715-18owh7 section 4.6; current tests incorrectly bless above-default effective values. (2) validHello + duplicateHello in one read completes and forwards the duplicate as frame remainder because duplicate detection only runs on a later callback; stable duplicateHello must be independent of chunking. (3) reachable Swift transportFailure and perform-level EOF cleanup paths lack AC5 coverage. Full evidence and exact rework: TASK-260715-1y1g1u_review.md. Independent checks passed: make relay-protocol-check; swift test 128/128; strict swift-format; gofmt; core boundaries; board validate. Routed to to-dev, not blocked.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-6dcd9e, pid=97808, exit=0)
spawn queued: [implementer] developer (codex) (run=RUN-260720-86274c, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260720-86274c)
Rework round 1 addressed: local-only effective limits are bounded by generated client/relay defaults, duplicate RLXR remainders fail before completion at every split, and Swift perform-level invalid/throwing write, throwing read, and EOF paths prove stable failures plus cancel/reset/close cleanup. Validation: make relay-protocol-check (19 protocol tests), swift test (129/129), Go CGO-disabled vet/test with 92.6% coverage, strict swift-format, gofmt, core boundaries, git diff check, and board validate.
agent completed: [implementer] developer (codex) (exit=0)
spawn completion blocked: no new task-scoped outcome artifact was attached. Add an outcome resource named like TASK-260715-1y1g1u_results.md and then set status back to to-review.
spawn run completed: codex (run=RUN-260720-86274c, pid=4597, exit=0)
spawn queued: [reviewer] reviewer (codex) (run=RUN-260720-916375, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260720-916375)
REVIEW VERDICT 2026-07-20 round 2: changes requested -> analysis. Rework items for effective-limit bounding and Swift perform-level transport/EOF cleanup are correct and all gates pass. Remaining contract issue: at exact hello boundary Swift publishes completed/perform returns and Go emits accepted completion before a duplicate RLXR arriving in the next read is inspected; the new every-split tests mask this by invoking the completed state machine again. SSH byte streams have no message boundary, so choose ownership: recommended coalesced-only handshake detection plus stable post-handshake envelope/session classification, or define a bounded pre-completion lookahead/barrier contract. Full evidence, alternatives, recommendation, and exact decision: TASK-260715-1y1g1u_review-02.md.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-916375, pid=12678, exit=0)
spawn queued: [implementer] developer (codex) (run=RUN-260720-bf0b59, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260720-bf0b59)
Decision-02 rework: Swift and Go every-split tests now publish success at the exact 16/12-byte boundary without a second handshake callback, while coalesced full/partial RLXR remainders still fail duplicateHello. Updated .spec/relay-protocol.md, LOGBOOK.md, Swift remainder docs, the main results resource, and added TASK-260715-1y1g1u_decision-02-results.md. Gates: make relay-protocol-check; swift test 129/129; swift build; Go CGO-disabled vet/test and 92.6% coverage; strict swift-format; gofmt; core boundaries; git diff check; board validate.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-bf0b59, pid=18033, exit=0)
spawn queued: [reviewer] reviewer (codex) (run=RUN-260720-f96832, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260720-f96832)
REVIEW ACCEPTED 2026-07-20 round 3. Decision-02 rework correctly encodes immediate exact-boundary completion and same-callback duplicate RLXR rejection; both peers meet wire, negotiation, limit, failure, cleanup, privacy, and architecture AC. Independent gates passed: make relay-protocol-check; swift test 129/129; Go CGO-disabled test with 92.6% coverage; strict swift-format; gofmt; core boundaries; git diff check; board validate. Evidence: TASK-260715-1y1g1u_review-03.md. Local Go 1.25.5 versus pinned 1.26.5 remains accepted TASK-260715-27uz4n ownership, not a blocker.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-f96832, pid=26963, exit=0)

## Precondition Resources
- [TASK-260715-1y1g1u_relay-binding-input.md](file://TASK-260715-1y1g1u/TASK-260715-1y1g1u_relay-binding-input.md) — Frozen TASK-260715-111tde relay binding decision; consume the task-specific artifact and validation map
- [TASK-260715-1y1g1u_inputs.md](file://TASK-260715-1y1g1u/TASK-260715-1y1g1u_inputs.md) — Protocol v1 handshake requirements
- [TASK-260715-1y1g1u_rework-01.md](file://TASK-260715-1y1g1u/TASK-260715-1y1g1u_rework-01.md) — Independent review rework instructions round 1
- [TASK-260715-1y1g1u_decision-02.md](file://TASK-260715-1y1g1u/TASK-260715-1y1g1u_decision-02.md) — Approved exact-boundary duplicate hello ownership decision

## Outcome Resources
- [TASK-260715-1y1g1u_spawn-log_-implementer--developer--claude-.log](file://TASK-260715-1y1g1u/TASK-260715-1y1g1u_spawn-log_-implementer--developer--claude-.log) — System spawn log captured by task-board
- [TASK-260715-1y1g1u_spawn-log_-implementer--developer--codex-.log](file://TASK-260715-1y1g1u/TASK-260715-1y1g1u_spawn-log_-implementer--developer--codex-.log) — System spawn log captured by task-board
- [TASK-260715-1y1g1u_results.md](file://TASK-260715-1y1g1u/TASK-260715-1y1g1u_results.md) — Implementation, review rework, exact-boundary ownership, and validation evidence
- [TASK-260715-1y1g1u_spawn-log_-reviewer--reviewer--codex-.log](file://TASK-260715-1y1g1u/TASK-260715-1y1g1u_spawn-log_-reviewer--reviewer--codex-.log) — System spawn log captured by task-board
- [TASK-260715-1y1g1u_review.md](file://TASK-260715-1y1g1u/TASK-260715-1y1g1u_review.md) — Reviewer verdict evidence and required rework for protocol v1 handshake
- [TASK-260715-1y1g1u_rework-01-results.md](file://TASK-260715-1y1g1u/TASK-260715-1y1g1u_rework-01-results.md) — Rework round 1 completion evidence
- [TASK-260715-1y1g1u_review-02.md](file://TASK-260715-1y1g1u/TASK-260715-1y1g1u_review-02.md) — Review round 2: exact-boundary duplicate hello ownership decision
- [TASK-260715-1y1g1u_decision-02-results.md](file://TASK-260715-1y1g1u/TASK-260715-1y1g1u_decision-02-results.md) — Approved exact-boundary duplicate-hello ownership rework evidence
- [TASK-260715-1y1g1u_review-03.md](file://TASK-260715-1y1g1u/TASK-260715-1y1g1u_review-03.md) — Independent review round 3 accepted verdict and validation evidence
