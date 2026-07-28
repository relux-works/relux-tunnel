# TASK-260715-2kchi0 rework-01 results

Date: 2026-07-22
Role: solution-architect
Route: ready for independent review

## Scope preserved

This bounded rework addresses only the blocking findings in
`TASK-260715-2kchi0_review-verdict-20260721.md`. It does not run benchmarks,
select tuning winners, authorize production DNS values, weaken red-row or
safety gates, or alter the dependency graph. The original changes-requested
verdict remains attached.

## Rework outcomes

1. Protocol v1 now defines the exact RFC 8785 canonical row projection,
   identifier and seed relationships, SplitMix64-v1 state transition and stream
   derivation, packet ordering, loss/jitter sampling, integer effect estimator,
   rounding, median/quantile rules, 10,000-resample paired bootstrap,
   integer-to-index mapping, multiplicity group/coverage, non-finite rejection,
   and inclusive equality/strict regression-boundary classification.
2. Manifest schema v1 replaces generic maps with closed, versioned structures
   and fixed units for device, environment, toolchain, revisions, server,
   algorithms, policy, parameters, traffic, impairment, schedule, all required
   metrics/counters, gates, artifacts, privacy, authority, and review. It adds
   selected-SSH DNS parameters and hard-envelope maxima.
3. Schema conditionals connect pass to every safety gate plus isolation,
   impairment restoration, and privacy scan; production authorization to pass,
   accepted review, non-provisional state, empty blockers, explicit authority,
   accepted update reference, and DNS production permission; capture artifacts
   to authorization, restricted privacy/retention, custodian, and a redacted
   derivative. Non-pass rows cannot be production-authorized.
4. Bundle-relative references reject absolute/traversing forms. The protocol
   assigns non-expressible hash/ID, UTC/event ordering, cross-field schedule and
   ledger, artifact filesystem/hash, gate/counter, deterministic replay,
   preservation, and immutable update-lineage rules explicitly to
   `TASK-260721-2ohf99` — Implement the M3 evidence bundle validator and
   statistical reporter.
5. New task-scoped schema fixtures cover valid pass, DNS hard-envelope equality,
   one byte over the aggregate DNS envelope, and the reviewer-hostile claimed
   pass/authorization/capture/clock shape. They are attached to this task as
   outcomes and to `TASK-260721-2ohf99` as preconditions.
6. The stale `TASK-260717-l639qp` title is corrected to “Ratify the M3 QUIC,
   route-mode, and reconnect policy contracts.” PlantUML inline colors that
   emitted deprecation banners were removed; source and SVG are warning-free.

## Content hashes

| Artifact | SHA-256 |
| --- | --- |
| Protocol | `16b9fea5c1c713337de639bf6419d6600d6f7bc6fcee2c6eba03adde0b1a7994` |
| Schema | `81a0d85dfafc60932ba012d4ee8acb59a9f1f8db95ddb7aa01311e4950f368cb` |
| Valid fixture | `936cfb7789ac8392333f6be49fcb7ddc3efb173f025831a00f1df49cdb726570` |
| Equality overlay | `f9fbb8707d0c5045c78031f2bacad79c63aebae6b68fb0c5e6898ae4d650218b` |
| One-over overlay | `0259ccb7acf770e4dc0a4c62a2f13582dec567835bc45656b7940219e191b4fd` |
| Hostile overlay | `c00f067dc504fe00cade8aeaf232e4536277f314295e4ca2b81289d8f207d117` |
| PlantUML source | `8bba30d7a0ff8d37422e064a1cbf7f9741a4ddb38cc7c5558401b5db6b402662` |
| Rendered SVG | `090c2173f71136e2429bf60afb3cb8f2c4da97121b7b24aa09cb3582478efa22` |

## Verification evidence

- `check-jsonschema 0.37.4 --check-metaschema`: pass.
- Valid fixture: accepted.
- Equality-boundary DNS overlay: accepted.
- One-over DNS overlay: rejected at 8,388,609 bytes versus 8,388,608 maximum.
- Reviewer-hostile overlay: rejected for closed shape, monotonic clock shape,
  absolute reference, artifact authorization/privacy/redaction/retention,
  failed pass gates, and contradictory production authority. UTC ordering is an
  explicit semantic-validator rejection because JSON Schema cannot compare two
  independent date-time fields.
- Valid fixture protocol/schema hashes, canonical projection hash/run ID, and
  immutable-manifest hash recompute exactly.
- `task-board validate`: pass.
- Story child plan: acyclic; validator remains in phase 2 between protocol and
  harness consumers. The known broad related-plan cycle remains pre-existing;
  this rework changed no dependency edges.
- All 57 task references in the protocol resolve.
- Nineteen board protocol copies, six schema copies, three PlantUML copies, one
  SVG copy, and both fixture resource sets are byte-identical to their sources.
- PlantUML check, SVG XML parse, warning/error-text scan, and visual inspection:
  pass.
- Focused actual-identifier/secret scan and `git diff --check`: pass. The hostile
  fixture uses only the explicit synthetic account token needed to prove
  absolute-path rejection.
- `swift test`: 332 tests in 29 suites passed. The linker emitted the existing
  alignment-reduction warning; no test failed.

## Remaining authority gates

Production authorization is still false. Selected-SSH `direct-tcpip` timing,
footprint, and cleanup evidence (`TASK-260715-1gjxer`), the accepted ADR-009
residual DNS budget (`TASK-260715-1pn983`), physical-provider startup/footprint
evidence, and independent review remain mandatory. No candidate value is stored
in a user profile.
