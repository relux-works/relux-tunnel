## Status
done

## Assigned To
[reviewer] reviewer (codex)

## Created
2026-07-15T01:16:47Z

## Last Update
2026-07-21T02:42:14Z

## Blocked By
- TASK-260715-30zng6

## Blocks
- TASK-260715-b6uruh
- TASK-260715-2yz8du
- TASK-260715-sdnk2k
- TASK-260715-zfg9ap

## Checklist
- [x] Deliver a byte-level ownership streaming and resource contract
- [x] Prove the chosen internal endpoint rejects non-owned local clients on both platforms
- [x] Attach task-scoped contract and M0 capability references
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
- [x] If review does not accept the work — verdict evidence added and status routed by the explicit verdict branches
- [x] Resolve reviewer rework for source-accurate authentication deadlines downstream adversarial coverage and legible diagrams
- [x] Resolve rework 02 pending-capacity and stopped rejection ordering with verified render and evidence

## Notes
spawn queued: [analyst] solution-architect (codex) (run=RUN-260721-b6754a, max_parallel=1)
spawn run started: [analyst] solution-architect (codex) (run=RUN-260721-b6754a)
Architecture handoff prepared: attached task-scoped contract, accepted M0 capability trace, state and ownership diagrams with rendered SVGs, and validation/hashes. Existing story decomposition already provides atomic implementation, fuzz, conformance, integration, matrix, and documentation tasks with dependency edges; no duplicate task was created. Refined TASK-260715-b6uruh parser AC for bounded coalesced early payload, TASK-260715-1n9v9o lifecycle scope for explicit no-default-idle policy, and TASK-260715-1mr9j2 fuzz AC; linked every consumer by notes to the contract. Recorded the nonexistent TASK-260715-100wu6 input typo and correct accepted TASK-260720-100wu6 seam in the contract and LOGBOOK. Validation: focused no-auth rejection test passes, PlantUML sources and SVGs validate, task-board validate passes, resource copies are byte-identical, and git diff --check passes.
agent completed: [analyst] solution-architect (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-b6754a, pid=7132, exit=0)
spawn queued: [reviewer] reviewer (codex) (run=RUN-260721-424e9d, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260721-424e9d)
Review changes requested; evidence is in TASK-260715-1juybj_review-verdict.md. Reconcile the claimed absolute authentication deadline with the current SO_RCVTIMEO inactivity timer and add explicit downstream slow-trickle coverage; repair and visually verify the clipped state-diagram SVG. All 276 Swift tests, PlantUML syntax, board validation, hashes, and diff checks passed. Route: analysis because this is architecture/spec artifact rework, not implementation and not a human-only blocker.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-424e9d, pid=24260, exit=0)
spawn queued: [analyst] solution-architect (codex) (run=RUN-260721-1e6310, max_parallel=1)
spawn run started: [analyst] solution-architect (codex) (run=RUN-260721-1e6310)
Rework 01 prepared for handoff. Corrected every source-backed admission claim: current SO_RCVTIMEO is explicitly a restartable per-receive inactivity timeout with no send deadline, while the production monotonic accept-to-auth deadline is an M1 decision owned by TASK-260715-b6uruh. Refined that task description, scope, AC, and checklist for deterministic greeting/auth slow trickle, wrong credential, both reply stalls, cancellation, stale generation, slot recovery, descriptor cleanup, and explicit iOS/macOS rows; existing dependencies remain sufficient. Removed Smetana, restored default Graphviz rendering after installing missing Homebrew libtool 2.6.2, rendered task-scoped diagrams, and inspected 1575x1349 and 1635x1528 opaque PNGs at original resolution with all labels legible/unclipped. Focused no-auth rejection test passed; PlantUML syntax/render, task-board validate, eight resource download/cmp checks, hashes, and git diff --check passed. Updated contract, M0 trace, validation, diagram sources/SVGs, LOGBOOK, and added TASK-260715-1juybj_rework-evidence.md.
agent completed: [analyst] solution-architect (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-1e6310, pid=28723, exit=0)
spawn queued: [reviewer] reviewer (codex) (run=RUN-260721-db828c, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260721-db828c)
Rework 01 review changes requested; evidence is in TASK-260715-1juybj_rework-01-review-verdict.md. Deadline correction, downstream adversarial coverage, hashes, tests, and visual legibility pass. Remaining correction: the normative ownership sequence must move pending-capacity/stopped rejection to immediately after accept and close without negotiation or RFC 1929 reply, matching HEVSOCKSBoundary.swift and contract section 4.1. Route: analysis for specification/diagram rework; no code change and no human-only blocker.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-db828c, pid=40782, exit=0)
spawn queued: [analyst] solution-architect (codex) (run=RUN-260721-2dc04e, max_parallel=1)
spawn run started: [analyst] solution-architect (codex) (run=RUN-260721-2dc04e)
Rework 02 prepared for review. Corrected the normative ownership sequence so stopped/retired/pending-authentication-full rejection occurs immediately after accept/socket setup and before any SOCKS method or RFC 1929 bytes; the descriptor closes immediately with no authentication enqueue or adapter handoff. Wrong/stale capability and monotonic-deadline expiry remain in the authentication branch with conditional safe reply behavior. The contract and production code were not changed. Rendered with PlantUML 1.2026.6/Graphviz 14.0.4, converted to a 1921x1742 opaque RGB PNG, and inspected at original resolution with all corrected branches and labels legible/unclipped. Focused externalIngressRejected passed 1/1; both PlantUML sources passed syntax/render; task-board validate, nine resource download/cmp checks, hashes, directive checkpoint, and git diff --check passed. Updated sequence source/SVG, validation, cumulative rework evidence, LOGBOOK, and attached new TASK-260715-1juybj_rework-02-evidence.md.
agent completed: [analyst] solution-architect (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-2dc04e, pid=44223, exit=0)
spawn queued: [reviewer] reviewer (codex) (run=RUN-260721-690b82, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260721-690b82)
Rework 02 accepted. Corrected pre-negotiation stopped/retired/pending-capacity rejection matches production source and contract section 4.1; wrong/stale/deadline failures remain in authentication. Independent review passed 276 Swift tests, PlantUML syntax and deterministic rendering, opaque original-resolution visual inspection, recorded hashes/resource copies, task-board validation, and git diff check. Verdict resource: TASK-260715-1juybj_rework-02-review-verdict.md.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-690b82, pid=49954, exit=0)

## Precondition Resources
- [TASK-260715-1juybj_accepted-inputs.md](file://TASK-260715-1juybj/TASK-260715-1juybj_accepted-inputs.md) — Accepted runtime, HEV boundary, SSH byte-seam, security, memory, and review constraints for the internal SOCKS contract
- [TASK-260715-1juybj_rework-01.md](file://TASK-260715-1juybj/TASK-260715-1juybj_rework-01.md) — Reviewer-directed correction for monotonic authentication deadline evidence, downstream slow-trickle coverage, and legible diagram rendering
- [TASK-260715-1juybj_rework-02.md](file://TASK-260715-1juybj/TASK-260715-1juybj_rework-02.md) — Narrow correction for pending-capacity and stopped rejection ordering in the normative ownership sequence

## Outcome Resources
- [TASK-260715-1juybj_spawn-log_-analyst--solution-architect--codex-.log](file://TASK-260715-1juybj/TASK-260715-1juybj_spawn-log_-analyst--solution-architect--codex-.log) — System spawn log captured by task-board
- [TASK-260715-1juybj_contract.md](file://TASK-260715-1juybj/TASK-260715-1juybj_contract.md) — Corrected private endpoint, byte protocol, direct-tcpip, streaming, deadline, resource, metric, and residual-decision contract
- [TASK-260715-1juybj_flow-state.puml](file://TASK-260715-1juybj/TASK-260715-1juybj_flow-state.puml) — PlantUML default-layout state view for one CONNECT flow and once-only cleanup
- [TASK-260715-1juybj_ownership-sequence.puml](file://TASK-260715-1juybj/TASK-260715-1juybj_ownership-sequence.puml) — Corrected PlantUML sequence with pre-negotiation stopped/retired/pending-capacity rejection, authentication failures, channel open, pumps, and cleanup
- [TASK-260715-1juybj_flow-state.svg](file://TASK-260715-1juybj/TASK-260715-1juybj_flow-state.svg) — Rendered and opaque-background-verified state view with legible states and transitions
- [TASK-260715-1juybj_ownership-sequence.svg](file://TASK-260715-1juybj/TASK-260715-1juybj_ownership-sequence.svg) — Rendered ownership sequence with source-accurate pre-negotiation admission rejection and visually verified labels
- [TASK-260715-1juybj_validation.md](file://TASK-260715-1juybj/TASK-260715-1juybj_validation.md) — Rework-02 source audit, focused test, PlantUML/render inspection, board-copy verification, and hashes
- [TASK-260715-1juybj_m0-capability-trace.md](file://TASK-260715-1juybj/TASK-260715-1juybj_m0-capability-trace.md) — Accepted HEV, Apple-boundary, current timeout gap, M0 memory, runtime, and SSH capability source map
- [TASK-260715-1juybj_spawn-log_-reviewer--reviewer--codex-.log](file://TASK-260715-1juybj/TASK-260715-1juybj_spawn-log_-reviewer--reviewer--codex-.log) — System spawn log captured by task-board
- [TASK-260715-1juybj_review-verdict.md](file://TASK-260715-1juybj/TASK-260715-1juybj_review-verdict.md) — Reviewer changes-requested verdict with source, timeout, diagram, and validation evidence
- [TASK-260715-1juybj_rework-evidence.md](file://TASK-260715-1juybj/TASK-260715-1juybj_rework-evidence.md) — Cumulative reviewer-finding closure including deadline evidence, adversarial coverage, diagram legibility, and corrected admission ordering
- [TASK-260715-1juybj_rework-01-review-verdict.md](file://TASK-260715-1juybj/TASK-260715-1juybj_rework-01-review-verdict.md) — Rework 01 reviewer changes-requested verdict for the remaining pending-capacity sequence contradiction
- [TASK-260715-1juybj_rework-02-evidence.md](file://TASK-260715-1juybj/TASK-260715-1juybj_rework-02-evidence.md) — Rework-02 evidence for pre-negotiation pending-capacity/stopped rejection ordering and render verification
- [TASK-260715-1juybj_rework-02-review-verdict.md](file://TASK-260715-1juybj/TASK-260715-1juybj_rework-02-review-verdict.md) — Accepted rework-02 reviewer verdict with source-order, render, test, hash, and board evidence
