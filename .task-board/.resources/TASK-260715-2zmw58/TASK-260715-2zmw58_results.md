# TASK-260715-2zmw58 — solution-architect handoff evidence

## Outcome

The degraded safe-DNS decision is recorded in
`TASK-260715-2zmw58_degraded-safe-dns-contract.md`. It consumes the accepted M1
resolver policy unchanged: required ordered canonical numeric `dns53`
endpoints, port default 53, and DNS-over-TCP through authenticated SSH
`direct-tcpip`. DoH, discovery, vendor/system/physical resolver fallback, and a
second resolver schema are not selected.

The contract explicitly preserves the existing numeric evidence boundary.
`TASK-260721-3miqh4` has not yet produced an accepted production-authorized
`DNSRuntimePolicyV1`; therefore there are no legitimate embedded numeric
defaults, and production composition must fail before routes with
`production_policy_unauthorized`. This is an evidence-backed existing gate, not
an inferred absence and not a new research task.

## Acceptance and completeness mapping

1. Exact fields, port default, endpoint identity/order/family rules, injected
   deadline/capacity fields, structural retries, pooling, cache invalidation,
   migration, and production-absence behavior are specified in sections 2–5.
2. The only degraded upstream is M1 SSH DNS-over-TCP. The accepted M1 policy
   deferred DoH and provides no trust inputs, so no DoH branch exists.
3. Section 6 binds preparation and public `BaseReady(g)` to the production
   `TunnelRuntimeCoordinator` entry points and makes mandatory loss all-false,
   teardown-only, and physical-fallback-free.
4. Sections 4–8 cover UDP/TCP clients, TC/oversize, DNSSEC transparency,
   cancellation, profile change, relay restoration, diagnostics, zero query
   logging, and required negative gate evidence.
5. Section 9 lists concrete integration, state, leak, documentation, profile,
   and UI IDs and audits the existing nonredundant dependency path.

No new Story, Task, Bug, research item, planning snapshot, or diagram was
created. The existing board is the smallest complete decomposition: every
literal requirement maps to an existing atomic owner; the only beyond-current-
production evidence gap is already owned by `TASK-260721-3miqh4`, whose exact
question is whether measured DNS numeric candidates can be production-authorized
against accepted SSH and runtime-memory evidence. Out-of-scope public resolver,
DoH, discovery, physical DNS, fake DNS, transport implementation, and final UI
work were checked and not added.

## Validation record

- Tool readiness: `.temp/TASK-260715-2zmw58/tool-readiness-01.log`, exit 0.
- M1 outcome/reviewer resources materialized successfully; SHA-256 values are
  recorded in the decision.
- Binding M2 capability input byte count `64673` and SHA-256
  `5b57540c86a0b48595863174e416229babee72cdb2705dd4bbb81bbefdc9ab69`
  match the assignment exactly.
- `task-board validate` returned process exit `0` but reported one semantic
  board issue: `PARENT_STATUS_MISMATCH` for out-of-scope
  `STORY-260715-1y04r0` (`backlog` versus child aggregate `development`, with
  `TASK-260720-1qhxqa` currently in `development`). This task did not touch that
  Story or its children. The board-wide gate is recorded as failing despite the
  zero process exit; task-scoped resources, dependencies, and handoff evidence
  have no reported issue.
- A scoped batch that combined `get(STORY-260715-1y04r0)` with an activity read
  returned exit `1` because that Story has no activity resource. A separate
  scoped child-status query returned exit `0`; absence of activity was not used
  to infer history or provenance.
- The first multi-statement checklist mutation returned exit `1` with
  `one activity event cannot represent multiple checklist changes`; a scoped
  read proved all items remained unchecked. Twelve individual `check_item`
  mutations then each succeeded and the checklist is complete.
- Scoped task and dependency projections were read for every downstream ID.
- Byte-identical decision preconditions were attached to direct integration,
  state-test, leak-test, documentation, presentation, and profile-UI consumers:
  `TASK-260715-3260rm`, `TASK-260715-1vg1mb`, `TASK-260715-2y78ah`,
  `TASK-260715-3kga9i`, `TASK-260715-2a1cp7`, and `TASK-260721-2raag7`.
- No implementation, DNS request, socket, VPN, route, interface, credential,
  signing, installation, application/provider launch, or remote execution was
  performed.

## Independent review

CR revision 1 was accepted after independent resolver-policy, capability,
dependency, privacy, production-call-site, exact-patch, static-gate, Swift-test,
and build review. The detailed verdict is attached separately as
`TASK-260715-2zmw58_review-verdict.md`; it records all command exit codes and
retains the two `task-board validate` semantic issues as known non-candidate
board anomalies rather than calling that board gate green.
