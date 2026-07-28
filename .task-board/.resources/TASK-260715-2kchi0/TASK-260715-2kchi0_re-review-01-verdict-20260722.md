# TASK-260715-2kchi0 re-review-01 verdict

Date: 2026-07-22
Role: independent reviewer
Verdict: changes requested
Route: analysis

## Verdict

Rework-01 closes every original hostile-schema, generic-map, DNS-boundary,
PlantUML-warning, stale-title, and copy-drift finding, but the binding
statistics/review contract still cannot drive `TASK-260721-2ohf99` without
inventing material semantics. The task is not accepted.

## Blocking findings

### 1. Multiplicity grouping is unstable across the repetitions it must bootstrap

Section 2 defines `runID` from a canonical projection containing
`identity.repetitionIndex`, `identity.seed`, and `identity.baselineRunID`.
It also requires each candidate to carry the baseline run ID for the same seed
and execution block. Section 8.1 then includes that per-repetition
`baselineRunID` in `multiplicityGroupID`.

Therefore the group ID changes for every seed/repetition, splitting a planned
five- or ten-pair comparison into one-pair groups. The required 10,000-resample
paired bootstrap cannot operate over the planned repetition set as specified.
This is a protocol contradiction, not a validator implementation detail.

The same group projection includes `parameterFamily`, but neither protocol v1
nor schema v1 defines a stable value construction for it. Schema inspection
found zero `parameterFamily` properties. Schema v1 also has no comparison or
statistics object and only one row-level `review.classification`; it cannot
record per-metric point estimates, absolute/PPM intervals, multiplicity groups,
or classifications for the sixteen required metric families.

Finally, `coveragePartsPerMillion` is an integer while the protocol defines the
exact rational `1 - 1/(20*m)`. For `m=3` the required value is
`2,950,000/3` PPM and for `m=6` it is `2,975,000/3` PPM. No serialization or
rounding rule exists. The valid fixture proves only `m=1`.

Executable/schema evidence:

```text
hasTopStatistics: false
parameterFamilyPropertyCount: 0
classificationPropertyPaths: ["properties.review"]
m=3 coverage: 2950000/3 (not integer)
m=6 coverage: 2975000/3 (not integer)
```

### 2. Schema v1 permits production authorization without review or statistics

Starting from the valid fixture, the reviewer set production authorization
true, provisional false, blockers empty, a valid authorization task and accepted
update reference, and DNS production permission true. The same row replaced
reviewer, review timestamp, classification, multiplicity group, and candidate
count with valid `available:false` objects. `check-jsonschema 0.37.4` accepted
the result.

This allows a production-authorized accepted row with no independent reviewer,
no review time, no comparison classification, no multiplicity group, and no
candidate count. Those are schema-expressible status/authority invariants and
conflict with AC3/AC5 and the rework instruction to encode status/authority and
timestamp invariants wherever JSON Schema 2020-12 can enforce them.

Schema v1 also accepts:

- `status.primary=unavailable` with `reasonCode=measured-pass`; and
- `status.primary=invalid-environment` with `reasonCode=measured-pass` and an
  otherwise valid exclusion.

Section 10.1 assigns UTC comparison and filesystem/content semantics to the
future validator, but it does not cure these closed-schema availability and
status-reason contradictions.

### 3. Required latency summaries cannot be represented by the row schema

Section 5 requires TTFB, DNS latency, and failure latency to be summarized per
repetition as median, p95, and p99. Each schema metric is one `metricBase` with
one `value` and one `aggregation` enum. The row can record only one of median,
p95, or p99 for each named latency metric, not all three. A raw-samples reference
does not satisfy the protocol's required row summaries or provide the binding
integer inputs consumed by the reporter.

## Required rework

1. Define a stable comparison-group identity that is constant across all paired
   repetitions. Do not include a per-repetition baseline run ID in that group;
   define and schema-bind `parameterFamily` or replace it with an exact derived
   projection.
2. Add a closed comparison-result contract (row extension or separate bundle
   schema) containing every metric's paired sample IDs, point estimates,
   absolute/PPM bootstrap bounds, multiplicity inputs, classification, and
   unavailable forms. Define exact coverage serialization, preferably an exact
   numerator/denominator or interval indices rather than an unrepresentable PPM
   integer.
3. Make production authorization require an available reviewer, review time,
   classification, comparison group/candidate count, and every accepted-update
   field. Add schema conditionals for status/reason/exclusion consistency.
4. Represent all required per-repetition latency summaries, including median,
   p95, and p99 simultaneously, with fixed units and unavailable forms.
5. Add multi-repetition and `m=3` positive fixtures plus hostile fixtures for
   absent accepted-review/statistics fields and contradictory status reason
   codes. Propagate all revised copies byte-identically and rerun the existing
   gates.

## Passing evidence retained

- Draft 2020-12 metaschema passes. Valid and equality fixtures pass; one-over
  rejects exactly at 8,388,609 bytes; the original hostile claimed-pass overlay
  rejects for the intended closed-shape, path, capture, gate, and authority
  reasons.
- Canonical row projection, run ID, and immutable manifest hashes recompute to
  the fixture values. SplitMix64 stream/order, integer effect, bootstrap index,
  multiplicity interval-index, rounding, non-finite, and equality rules are
  otherwise explicit.
- Protocol/schema/fixture/diagram source copies are byte-identical: 19 board
  protocol copies, six board schema copies plus source, three board PlantUML
  copies plus source, one board SVG plus source, and both fixture resource sets.
- PlantUML 1.2026.6 `-checkonly`, regenerated SVG hash, SVG XML parse,
  warning/error scan, and visual inspection pass. The render contains no banner.
- All 57 unique task references resolve; all 50 downstream table titles match,
  including `TASK-260717-l639qp` — Ratify the M3 QUIC, route-mode, and reconnect
  policy contracts.
- `TASK-260721-2ohf99` — Implement the M3 evidence bundle validator and
  statistical reporter is atomic and remains between protocol and harness work
  in story phase 2. `task-board validate` and the story plan pass. The broad
  related-plan cycle is pre-existing and does not include this task.
- Privacy scans found no secret or real local identifier. The only absolute path
  and synthetic account token are intentionally confined to the hostile fixture
  and the prior verdict that documents it.
- `git diff --check` passes. `swift test` passes 332 tests in 29 suites; only the
  previously recorded linker alignment warning remains.
- macOS-first/iPhone-deferred scope, selected-SSH DNS startup/open/reuse/retire
  rows, injected MTU/HEV/lane/window/rekey/QUIC/reconnect/memory gates,
  red/unavailable preservation, and no-benchmark/no-winner/no-production-DNS
  claims remain correct. The current harness is accurately described as
  smoke-only.

No code was modified during this review.
