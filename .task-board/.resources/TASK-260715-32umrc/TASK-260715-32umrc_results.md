# TASK-260715-32umrc — Handoff evidence

Date: 2026-08-19 (Asia/Tbilisi)

## Result

Ready for independent review. ADR-029 and the task-scoped architecture ADR now
bind the generated workspace to an acyclic consumer-to-dependency graph for the
macOS-only P0 path. The focused DOT source uses the same direction and marks all
iOS nodes deferred.

The decision covers the required products, generated targets, local Swift
package products/targets, Go relay targets, schemes, Debug/Release and signing
variants, identifier injection, source-control policy, exact dependency pins,
version propagation, test placement, legacy coexistence/retirement boundaries,
and iOS resume points. Gate P0 is incorporated as the accepted macOS PASS
without claiming iPhone, Gate A0, App Review, notarization, release, or packet
forwarding evidence.

## Outcomes

- `TASK-260715-32umrc_generated-project-architecture-adr.md` — binding ADR with
  sections 1–10 and downstream traceability.
- `TASK-260715-32umrc_target-dependency-plan.dot` — focused target/dependency
  diagram. The earlier Core-to-native direction was corrected to the implemented
  native-adapter-to-Core dependency direction.
- `.spec/decisions.md` ADR-029 — accepted decision-log pointer to the full ADR.
- `LOGBOOK.md` entry — decision, scope, and corrected-direction finding.

## Completeness and board shape

No Story, Task, Bug, research task, planning artifact, or additional diagram was
created. The existing decomposition is the smallest board shape that maps the
specification. Sections 9–10 trace all direct downstream consumers and all
target-project-architecture implementation/verification owners. Existing
dependency edges remain linked; the independent board validator reports no
cycle or consistency issue.

No beyond-literal-spec board element was created, so no justified-gap record is
applicable. No exact question remains open in the supplied spec/evidence, so no
research task is warranted.

## Validation and real results

- Initial compact board query: exit 1 because `resources` is not a supported
  projection field. Scoped `schema(operation=get)`: exit 0; corrected compact
  task/parent/evidence queries: exit 0.
- First combined diagram validation attempt: not executed because the command
  runner rejected `rm -f` before process creation. No result was treated as a
  pass. The cleanup-free rerun below is authoritative.
- Graphviz `dot -Tsvg`: exit 0.
- Graphviz `tred`: exit 0.
- Graphviz `acyclic -v -n`: exit 0 and reported the graph acyclic.
- ADR outcome byte comparison against the source-controlled file: exit 0.
- DOT outcome byte comparison against the source-controlled file: exit 0.
- `git diff --check`: exit 0.
- `task-board validate`: exit 0, “Board is valid. No issues found.”
- Product builds/tests: not applicable; this task changes architecture
  documentation, diagram source, the decision log, logbook, and board outcomes,
  not product implementation.

## Acceptance mapping

1. ADR §§2–4 enumerate the P0 and deferred-iOS graph, products, targets,
   packages, schemes, configurations, and focused diagram.
2. ADR §2 fixes live-state/configuration ownership, thin adapters, inward Core
   dependencies, and the no-UI/no-generated-state Core boundary.
3. ADR §§5–7 decide generated versus checked-in files, identifiers, signing with
   and without credentials, pins, version propagation, and tests.
4. ADR §8 preserves the legacy SwiftPM lane and requires a later explicit
   migration/retirement decision before removal or identity/data changes.
5. ADR §9 traces downstream tasks to sections; §§1 and 10 preserve the accepted
   macOS Gate P0 constraints without reinterpretation and retain iOS/A0 deferral.
