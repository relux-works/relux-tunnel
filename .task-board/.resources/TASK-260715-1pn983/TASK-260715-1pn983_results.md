# TASK-260715-1pn983 — solution-architect handoff evidence

## Outcome

The binding cross-layer extension contract is recorded in
`docs/TASK-260715-1pn983_memory-window-rekey-contract.md`. It defines one
checked-byte ledger for packet, HEV, SSH, DNS, client relay, rekey, metrics, and
reconnect owners; exact reservation/release semantics; channel-window and DNS
formulas; deterministic Soft/Pressure/Critical hysteresis; one eleven-step
action order; rekey/reconnect/cancellation interactions; privacy-safe metrics;
negative tests; M0–M3 interfaces; and the complete eight-child Story trace.

The exact DNS ledgers independently recompute to `3,686,706 B` (candidate
default) and `7,635,554 B` (candidate hard). The hard component fits its
`8,388,608 B` budget. Combined with the accepted `9,715,712 B` incremental
HEV/bridge peak, it leaves `8,110,080 B` inside the lower 25 MiB engineering
envelope. This is arithmetic assignment, not whole-extension or Apple memory
proof; production authorization remains false pending physical composition and
M3 numeric selection.

Two focused state diagrams cover memory-pressure recovery and reconnect/rekey
reservation. Sources and rendered SVGs are task-scoped.

Revision 2 closes every revision-1 reviewer counterexample:

- `B_untracked` is a permanent charged ledger row and therefore cannot be spent
  by channel, lane, reconnect, or pressure headroom calculations;
- total-capacity reservations and proposal deltas have distinct, closed
  meanings, including explicit pre-admission KEX/reconnect inclusion rules;
- atomic lane admission covers every count/base/KEX/lane-A/global/state/pressure
  predicate with typed fast refusal, transfer-without-double-charge, and exact
  failed-construction release;
- reconnect ownership and permanent per-lane KEX reservation are orthogonal in
  the normative state model; and
- the packet-plane memory target now says named physical Apple-silicon Mac,
  while iPhone evidence stays explicitly deferred and non-substitutable.

## Repository artifacts

- `docs/TASK-260715-1pn983_memory-window-rekey-contract.md`
- `diagrams/TASK-260715-1pn983_memory-pressure-state.puml`
- `diagrams/TASK-260715-1pn983_reconnect-rekey-state.puml`
- `diagrams/artefacts/TASK-260715-1pn983_memory-pressure-state.svg`
- `diagrams/artefacts/TASK-260715-1pn983_reconnect-rekey-state.svg`
- `.spec/decisions.md`, `.spec/packet-plane.md`, `README.md`, and `LOGBOOK.md`
  link or record the binding contract without promoting provisional numbers.

## Validation

| Gate | Exit | Result |
| --- | ---: | --- |
| Input SHA-256 verification | 0 | Both supplied digests match exactly |
| PlantUML syntax and SVG render | 0 | Two sources valid; two SVGs rendered and visually inspected |
| Contract assertions revision 1 | 1 | Formula passed; a phrase assertion failed because Markdown wrapped the words across lines; retained as red evidence |
| Corrected contract assertions | 0 | DNS/residual arithmetic, all consumer families, 11 actions, 13 negative/invariant rows, eight child traces, non-claims, and `git diff --check` pass |
| `task-board validate` | 0 | Command reported two unrelated parent-status mismatches; neither belongs to this task/Story and no foreign status was changed |
| Checklist batch attempt | 1 | Board refused one activity event for 12 changes; no side effects |
| Twelve atomic checklist mutations | 0 | All task checklist items checked |
| Resource byte-match attempt 1 | 127 | zsh special variable `path` hid `PATH`; no artifact changed |
| Corrected resource byte-match | 0 | Contract, two PUML, two SVG, and results board bytes match local SHA-256 |
| Independent review revision 1 | changes requested | Five blockers reproduced: untracked-reserve spend, reservation ambiguity, missing lane predicate, KEX diagram contradiction, and stale iPhone target |
| Revision-2 first harness run | 0 shell / failing inner gates | Retained red evidence: Markdown-wrap assertion failed and PlantUML rejected the first composite-state shape; the wrapper also exposed that missing `set -e` could return a false shell success |
| Revision-2 strict harness run | 200 | After enabling fail-fast, the same PlantUML syntax failure propagated as a real nonzero exit |
| Revision-2 corrected contract/mutant/render gate | 0 | Reviewer accounting examples, one-byte untracked bound, total-capacity delta, ten independently narrowed lane predicates, PlantUML syntax/SVG render, and `git diff --check` pass |
| Revision-2 PNG visual QA | 0 | Both diagrams rendered from the normative sources and were inspected; pressure transitions and the separate reconnect/permanent-KEX state machines are legible |
| Revision-2 `task-board validate` | 0 | Command reports two unrelated pre-existing parent-status mismatches; this task/Story is not named and no foreign status was changed |

Revision-2 evidence logs are
`.temp/TASK-260715-1pn983/{diagram-tool-readiness-02,rev2-validation-01,rev2-validation-02,rev2-validation-03,png-render-01,diagram-visual-qa-rev2-01,board-validation-rev2-01}.log`.
The first two rev2 validation logs are intentionally retained as negative
evidence; only `rev2-validation-03.log` is the corrected green gate.

No build or runtime test was run because this is a documentation/architecture
delta with no production code change. Validation is scoped to formulas,
traceability, syntax/rendering, repository diff, and board lifecycle.

## Completeness and remaining gates

- Every packet, HEV, SSH, DNS, client relay, lane, rekey, reconnect, metrics,
  and cleanup owner has a unit, hard ceiling field, current/peak input,
  reservation lifetime, release event, observability source, and downstream
  owner.
- Advertised credit is not treated as eager allocation or revocable credit.
- Failed reads remain unknown; absence is not inferred.
- No unbounded write/adjustment/drop/rekey side queue is allowed.
- Final watermarks, BDP/window winners, component limits, `B_untracked`, overlap,
  complete physical footprint, and iPhone rows remain evidence-gated.
- No new research task was created because no new exact question remained after
  the accepted inputs; existing tuning and physical tasks already own numeric
  uncertainty. The eight existing Story children are atomic and sufficient.

Revision 2 is ready for independent architecture re-review; this is a
`to-review` handoff, not accepted completion.
