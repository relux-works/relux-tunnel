# TASK-260715-2kchi0 independent review verdict

Date: 2026-07-21
Role: reviewer
Verdict: changes requested
Route: analysis

## Blocking findings

1. The v1 manifest schema does not enforce AC2, AC4, or AC5 and is not a sufficient binding input for TASK-260721-2ohf99. Device, environment, toolchain, revisions, server, algorithms, policy bodies, parameters, traffic, impairment, schedule, counters, and review are generic one-property maps. Metrics permit one arbitrary unavailable metric. DNS parameters are absent from the closed parameters object. Artifact entries cannot record the required capture authorization, custodian, or redacted derivative and accept any nonempty path. There are no conditional invariants connecting pass to all safety gates, production authorization to empty blockers, capture authorization to capture artifacts, or start/end ordering. Executable proof: check-jsonschema 0.37.4 accepted a row with status pass, productionAuthorized true, blockers present, every safety gate false, captureAuthorized false, reversed UTC and monotonic timestamps, absolute /Users/alice paths, and only placeholder nested maps. The metaschema itself passes, so this is a contract weakness rather than invalid JSON Schema syntax.

2. Independent reproduction is under-specified. canonicalRowConfigJSON is not defined as an exact field projection, so runID cannot be independently recomputed. The schema accepts arbitrary seeds, repetition IDs, matrix IDs, and workload IDs. Seeded loss and deterministic uniform jitter do not name a PRNG, stream derivation, packet ordering, or sampling rule. The paired bootstrap names only a seed and resample count, not the PRNG, resampling algorithm, paired-effect estimator, integer-to-index mapping, rounding/non-finite rules, or exact interval inequality for absolute-plus-percent boundaries. Two conforming implementations can therefore produce different impairment traces and classifications.

3. The PlantUML source/render fails the required warning-free visual gate. The SVG visibly embeds three PlantUML 1.2026.6 deprecation warnings because color stereotypes occur after the activity semicolon at source lines 22, 32, 54, 65, 67, and 71. The warning banner occupies the top of the rendered artifact.

4. Downstream traceability has one stale title. The 50-row table resolves every ID, but TASK-260717-l639qp is labeled Ratify M3 policy and resilience contracts while the board title is Ratify the M3 QUIC, route-mode, and reconnect policy contracts.

## Required rework

- Replace generic placeholder maps with explicit closed versioned fields, units, availability forms, required metric/counter sets, DNS parameters, artifact authorization/custodian/redacted-derivative fields, relative-reference constraints, authority/safety/status conditionals, and timestamp/order constraints. Add positive and hostile schema fixtures proving these rules before the validator task consumes v1.
- Normatively define the canonical run configuration projection, identifier relationships, permitted seeds by row family, impairment PRNG and stream/order rules, and the complete deterministic paired-bootstrap/effect/classification algorithm including equality boundaries and multiplicity grouping.
- Fix PlantUML syntax, regenerate the SVG, inspect it, and assert no renderer warning/error text.
- Correct the stale downstream title, update every distributed copy byte-identically, then rerun board, schema, copy, privacy, diff, render, and test checks.

## Passing evidence retained

- swift test passed 332 tests in 29 suites.
- task-board validate, git diff --check, JSON parsing, and Draft 2020-12 metaschema validation passed.
- All 57 unique task references resolve; all protocol/schema/diagram resource copies checked are byte-identical.
- Focused privacy scan found no secrets, absolute local paths, or account identifiers in task artifacts.
- The current harness smoke-only limitation is stated accurately; macOS-first/iPhone-deferred scope, selected-SSH DNS startup/open/reuse/retire rows, no benchmark or winner claim, safety gates, raw retention, and pre-existing external authority gates are otherwise correctly represented.
- The story plan is acyclic with the new validator in phase 2. The broad related-plan cycle is pre-existing and no new reverse edge from this task was found.