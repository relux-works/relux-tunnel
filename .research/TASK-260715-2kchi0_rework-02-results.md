# TASK-260715-2kchi0 rework-02 results

Date: 2026-07-22
Role: solution architect
Status: ready for independent review

## Scope

This bounded rework addresses only
`TASK-260715-2kchi0_re-review-01-verdict-20260722.md`. It changes the binding
protocol, manifest schema, fixtures, focused activity diagram, and downstream
validator inputs. It does not run a benchmark, choose a tuning winner, modify a
dependency edge, authorize DNS policy, or change implementation code.

## Blocking findings closed

1. The protocol defines one stable `comparisonGroupID` over a closed
   protocol/device/workload/impairment/parameter-family/candidate-set projection.
   Per-run baseline IDs, repetition, seed, metric, timestamps, review state, and
   results are excluded. Candidate IDs hash the exact schema-listed parameter or
   policy projection.
2. Schema v1 adds a closed versioned comparison result with paired baseline and
   candidate run/sample IDs; exact candidate/multiplicity inputs; signed integer
   point effects and absolute/PPM bootstrap bounds; all sixteen fixed-unit metric
   families; classifications; safety status; and explicit unavailable forms.
3. Coverage is exact rational numerator/denominator plus deterministic integer
   interval ranks. The positive m=3 fixture records `59/60`, lower index 83, and
   upper index 9916 for 10,000 bootstrap samples without PPM rounding.
4. `productionAuthorized=true` requires non-provisional authority, empty
   blockers, concrete authorization task, pass status, production DNS permission,
   accepted independent reviewer/time, available classification/group/count/
   coverage, nonempty accepted-update lineage, a complete available comparison,
   and all prior safety/privacy gates.
5. Status conditionals bind every primary status to its legal reason and
   exclusion form. TTFB, DNS, RTT, outage, and failure latency now record
   simultaneous integer median/p95/p99 values or one explicit unavailable
   triplet.

## Fixtures

Schema-positive:

- valid pass and selected-SSH equality-boundary rows;
- three paired repetitions with one stable group and every comparison metric;
- m=3 exact coverage/ranks;
- production-authorized m=3 row with concrete review and lineage.

Schema-negative:

- selected-SSH aggregate one-over;
- retained original hostile claimed-pass row;
- production authority with unavailable review/statistics and empty lineage;
- `unavailable + measured-pass`;
- valid environmental exclusion with
  `invalid-environment + measured-pass`.

## Downstream handoff

`TASK-260721-2ohf99` — Implement the M3 evidence bundle validator and
statistical reporter retains its existing dependency position and now has:

- the updated protocol/schema/diagram and eleven fixture inputs;
- three additional checklist gates for stable comparison identity, exact m
  arithmetic, latency triplets, all metric results, authority, and status;
- `TASK-260721-2ohf99_rework-02-semantic-rules.md`, which assigns exact
  cross-row hash, ordering, pair ownership, arithmetic, artifact/filesystem,
  time, exclusion, and lineage checks that JSON Schema 2020-12 cannot express.

No objectively separate missing deliverable was found, so no new board task or
dependency edge was created.

## Artifact hashes

Rework-03 correction: independent re-review found that the original hash
commands used `jq -cS`, whose trailing LF is not part of RFC 8785 JCS. The
corrected values below supersede only the rework-02 fixture/hash claims; the
review verdict and all other rework-02 evidence remain preserved.

- protocol: `d2e6fec9f6f2715669df41f929bb3f2cc64ae391136b748f5ae387c4b373eb32`
- schema: `e0813d9936ec6acc4bf13acd3c4b8104209ce19401e36a4d3001ce72f74c8fcc`
- valid fixture: recomputed after the four identity/hash field corrections in
  rework-03 (recorded in `TASK-260715-2kchi0_rework-03-results.md`)
- PlantUML: `30e6a166da3532eaf9b0c61861e7f91313d4591ac39230d15885bc9574b9f89e`
- rendered SVG: `85467a1c431e6c5782bc52e0fa6cd72fff2c72222bf361dd8b62d359cb991308`
- validator semantic rules:
  recomputed after the explicit no-trailing-byte rule in rework-03

The valid fixture recomputes:

- canonical row config SHA-256:
  `1872767d6f1a5d920db6f7357b43133114a24c2043011131fba44e4bb96b9abb`
- immutable manifest SHA-256:
  `221c543f6dd3cf4a006889afd00ce1a66ea409d1f075dd1c9321852752478fb2`

## Verification

- `check-jsonschema --check-metaschema`: pass.
- Five positive schema compositions: pass.
- Five negative schema compositions: reject as expected.
- m=3 inspection: stable group, 3 paired records, m=3, `59/60`, `83/9916`.
- Rework-02's protocol/schema hashes were equal. Its run/immutable hash check
  included a trailing LF and was rejected by re-review-02; rework-03 replaces
  that check with the task-scoped executable no-trailing-byte regression.
- Resource propagation: 19 protocol, 6 schema, 3 PlantUML, and 1 SVG board
  copies are byte-identical; every fixture has both protocol-task outcome and
  validator-task precondition copies.
- PlantUML check, SVG XML parse, warning/error scan, and original-resolution
  visual inspection: pass; no warning banner or clipped content.
- All 57 concrete task references resolve; the corrected
  `TASK-260717-l639qp` title remains exact.
- `task-board validate`, `git diff --check`, and focused privacy/secret scan:
  pass. The known broad related-plan cycle remains pre-existing; no dependency
  edge was touched.
- `swift test`: 332 tests in 29 suites pass. The previously recorded linker
  alignment warning remains unchanged.

Production DNS authorization remains false in the binding protocol until the
accepted selected-SSH, residual-budget, physical-provider, and independent
review gates exist. The production-positive JSON is a schema contract fixture,
not evidence or permission to deploy values.
