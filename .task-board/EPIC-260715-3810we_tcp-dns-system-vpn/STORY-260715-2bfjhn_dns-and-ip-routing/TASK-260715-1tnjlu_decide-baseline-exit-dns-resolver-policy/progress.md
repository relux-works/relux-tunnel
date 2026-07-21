## Status
done

## Assigned To
[reviewer] reviewer (codex)

## Created
2026-07-15T01:17:04Z

## Last Update
2026-07-21T04:52:56Z

## Blocked By
- (none)

## Blocks
- TASK-260715-2pml0c
- TASK-260715-5o6jqg
- TASK-260715-1o4h97
- TASK-260715-28jdml
- TASK-260715-3260rm
- TASK-260721-33o8fc
- TASK-260715-2zmw58
- TASK-260715-2hhh7x
- TASK-260721-3miqh4

## Checklist
- [x] Compare all viable resolver policies against privacy bootstrap UX and reliability criteria
- [x] Obtain an accountable decision with exact schema defaults and failure semantics
- [x] Attach task-scoped decision record and downstream impact list
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

## Notes
spawn queued: [analyst] solution-architect (codex) (run=RUN-260721-937b9c, max_parallel=1)
spawn run started: [analyst] solution-architect (codex) (run=RUN-260721-937b9c)
Proposed ADR-022 derives a vendor-neutral policy from accepted invariants: each profile must supply 1-4 ordered canonical numeric IPv4/IPv6 dns53 endpoints; port defaults to 53; M1 uses bounded reusable DNS-over-TCP only through authenticated SSH; M2 reuses the identity for relay UDP plus TCP fallback; no product/system resolver, hostname bootstrap, discovery, DoH, fake DNS, or physical fallback. Runtime/profile snapshot implementation is TASK-260721-33o8fc; M4 profile experience is TASK-260721-2raag7. Exact comparison/schema/limits/retry/failure/migration/privacy/downstream evidence is attached as TASK-260715-1tnjlu_resolver-policy-decision.md with DOT/SVG and validation resources. ADR-022 remains Proposed until the independent Codex architecture reviewer accepts this task; accepted inputs make that reviewer the accountable approval boundary, so no unresolved human vendor/product choice remains.
agent completed: [analyst] solution-architect (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-937b9c, pid=14254, exit=0)
spawn queued: [reviewer] reviewer (codex) (run=RUN-260721-d9cde3, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260721-d9cde3)
Reviewer CHANGES REQUESTED 2026-07-21. The explicit per-profile numeric resolver direction, privacy proof, migration, downstream graph, diagram, and RFC-backed transport choices are sound; no human vendor/product choice remains. Rework is required because the proposed 5/5/15/10-second, 32/128 in-flight, and 1–4 endpoint limits lack the evidence/derivation required by the review input; shared reusable-connection failure does not define coordinated handling of other in-flight queries or endpoint promotion; and the one-transmission rule conflicts with M2 UDP-to-TCP fallback. Independent checks pass: task-board validate, git diff --check, DOT/XML/hash/resource comparison, visual render inspection, and make validate-core (306 Swift tests/27 suites plus build). Full evidence and exact changes: TASK-260715-1tnjlu_review.md. Routed to analysis for architecture-decision rework and another reviewer cycle.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-d9cde3, pid=31270, exit=0)
spawn queued: [analyst] solution-architect (codex) (run=RUN-260721-e0843c, max_parallel=1)
spawn run started: [analyst] solution-architect (codex) (run=RUN-260721-e0843c)
Rework 01 closes every independent reviewer finding without changing the vendor-neutral explicit-numeric-endpoint direction. Removed all unevidenced endpoint/timing/capacity defaults and hard caps; created TASK-260721-3miqh4 as the blocking evidence gate for accepted DNSRuntimePolicyV1 values. Froze generation-global active endpoint and connection-epoch ownership, atomic classification of all in-flight queries, one coordinated retry batch/promotion, tombstones, late-epoch rejection, cache invalidation, cancellation/deadline semantics, and mandatory exhaustion teardown. Reconciled M2 as one relay UDP attempt plus enumerated same-endpoint TCP handoff, with M1 owning later serial TCP endpoint promotion and one visible result. Refined TASK-260721-33o8fc, TASK-260721-2raag7, TASK-260715-5o6jqg, TASK-260715-28jdml, and TASK-260715-336ljl; linked dependencies and task-scoped preconditions. Updated ADR-022, architecture/routing/validation specs, research/decision, DOT/SVG, LOGBOOK, rework outcome, and validation resource. Checks pass: board, related plan, spec links, stale-policy scans, diff, DOT/XML, byte/hash comparisons, visual render, and make validate-core with 306 tests in 27 suites plus build. No human vendor/product choice remains; independent architecture review is the approval boundary.
agent completed: [analyst] solution-architect (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-e0843c, pid=37456, exit=0)
spawn queued: [reviewer] reviewer (codex) (run=RUN-260721-abab5f, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260721-abab5f)
Reviewer ACCEPTED after rework 01 on 2026-07-21. ADR-022 invariant policy is accountably approved: explicit ordered canonical numeric per-profile dns53 endpoints; SSH-only M1 TCP; enumerated M2 UDP-to-TCP handoff; no product, discovered, DoH, or physical fallback. Prior numeric, shared-connection, and M2 findings are closed. Exact DNSRuntimePolicyV1 values remain the separately reviewed evidence gate TASK-260721-3miqh4 and correctly block numeric consumers. Independent board, links, diff, RFC, DOT/XML/visual, hash, and make validate-core gates pass; 306 tests in 27 suites plus build. Verdict evidence: TASK-260715-1tnjlu_review-rework-01.md.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-abab5f, pid=51530, exit=0)

## Precondition Resources
- [TASK-260715-1tnjlu_accepted-inputs.md](file://TASK-260715-1tnjlu/TASK-260715-1tnjlu_accepted-inputs.md) — Accepted security, DNS, profile, relay, migration, and decision-boundary inputs
- [TASK-260715-1tnjlu_review-focus.md](file://TASK-260715-1tnjlu/TASK-260715-1tnjlu_review-focus.md) — Independent DNS architecture, fail-closed, bootstrap, migration, tuning, and graph review focus
- [TASK-260715-1tnjlu_rework-01.md](file://TASK-260715-1tnjlu/TASK-260715-1tnjlu_rework-01.md) — Reviewer changes requested: numeric evidence gates, shared-connection failure, and M2 UDP-to-TCP semantics

## Outcome Resources
- [TASK-260715-1tnjlu_spawn-log_-analyst--solution-architect--codex-.log](file://TASK-260715-1tnjlu/TASK-260715-1tnjlu_spawn-log_-analyst--solution-architect--codex-.log) — System spawn log captured by task-board
- [TASK-260715-1tnjlu_resolver-policy-decision.md](file://TASK-260715-1tnjlu/TASK-260715-1tnjlu_resolver-policy-decision.md) — Reworked resolver comparison, invariant schema, coordinated TCP failure, M2 fallback, migration, privacy proof, and downstream impacts
- [TASK-260715-1tnjlu_dns-policy-flow.dot](file://TASK-260715-1tnjlu/TASK-260715-1tnjlu_dns-policy-flow.dot) — Graphviz source for pre-route bootstrap, SSH-only ordinary queries, and fail-closed teardown
- [TASK-260715-1tnjlu_dns-policy-flow.svg](file://TASK-260715-1tnjlu/TASK-260715-1tnjlu_dns-policy-flow.svg) — Rendered and visually inspected DNS policy flow after rework 01
- [TASK-260715-1tnjlu_validation.md](file://TASK-260715-1tnjlu/TASK-260715-1tnjlu_validation.md) — Rework 01 board, spec, link, diagram, XML, hash, diff, and full core validation evidence
- [TASK-260715-1tnjlu_spawn-log_-reviewer--reviewer--codex-.log](file://TASK-260715-1tnjlu/TASK-260715-1tnjlu_spawn-log_-reviewer--reviewer--codex-.log) — System spawn log captured by task-board
- [TASK-260715-1tnjlu_review.md](file://TASK-260715-1tnjlu/TASK-260715-1tnjlu_review.md) — Independent changes-requested verdict with AC, numeric-evidence, failover-concurrency, M2 semantics, diagram, RFC, board, and test evidence
- [TASK-260715-1tnjlu_rework-01-outcome.md](file://TASK-260715-1tnjlu/TASK-260715-1tnjlu_rework-01-outcome.md) — Closure of numeric evidence, shared-connection failure, and M2 UDP-to-TCP review findings
- [TASK-260715-1tnjlu_review-rework-01.md](file://TASK-260715-1tnjlu/TASK-260715-1tnjlu_review-rework-01.md) — Independent acceptance of reworked ADR-022 invariants with AC RFC graph artifact and full validation evidence
