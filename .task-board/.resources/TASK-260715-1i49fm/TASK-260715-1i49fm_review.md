# TASK-260715-1i49fm reviewer verdict

Date: 2026-07-21
Role: reviewer
Verdict: CHANGES REQUESTED -> to-dev

## Acceptance blockers

1. AC1 non-blocking sink boundary is not met. The accepted runtime contract requires component-to-metrics sink enqueue to avoid blocking the component executor. RuntimeDiagnosticsRecorder calls store methods directly, and all updates synchronously acquire the same NSLock used by snapshot construction. A packet or SSH actor awaiting the sink can therefore block its executor behind snapshot dictionary copies, histogram construction, and error sorting. Evidence: RuntimeDiagnostics.swift lines 163-189, 300-301, 329-359, and 361-401; accepted runtime contract lines 121-122. Rework must use a bounded genuinely non-blocking ingestion boundary, with a deterministic test proving snapshot requests do not stall packet or SSH executor progress.

2. AC4 and AC5 stable-cardinality error codes are not enforced. recordError accepts any RedactedRuntimeErrorCode token and retains it without a finite catalog. The high-cardinality test injects 10,000 distinct error_<n> values and explicitly accepts error_9999 in output. Repeated snapshots can therefore expose an unbounded series of unstable labels even though only one value per domain is retained at a time. This conflicts with stable error codes only and adapters map to finite codes before reporting. Evidence: RuntimeDiagnostics.swift lines 265-267 and 518-522; RuntimeDiagnosticsTests.swift lines 311-335; accepted runtime contract lines 306-320 and 352-353. Rework must constrain diagnostic error codes to a reviewed finite typed catalog or fixed per-domain allowlist, reject/count unknown codes, and add hostile/high-cardinality regression coverage.

3. Generation snapshot sequencing starts at the wrong value. The accepted contract says sequence starts at zero for each runtime generation and increases for every published snapshot. State initializes at zero but snapshot increments before construction, so the first snapshot is one; the generation test asserts that behavior. Evidence: RuntimeDiagnostics.swift lines 280-281 and 333-347; RuntimeDiagnosticsTests.swift lines 228-240; accepted runtime contract lines 355-359. Rework must publish sequence zero first and test reset plus exhaustion semantics.

4. AC5 nested schema/redaction regression is incomplete. The schema test freezes metric names and top-level snapshot fields, while redactionBoundary encodes only an empty-error default snapshot and scans marker strings. A prohibited nested field or unstable identifier added to RedactedRuntimeError or another populated nested diagnostic type is not protected by an exact populated diagnostic golden or recursive key allowlist. Evidence: RuntimeDiagnosticsTests.swift lines 7-220 and 416-435. Add a populated exact golden or recursive schema allowlists plus injected prohibited-value tests that fail on nested additions.

## Independent verification

- swift test --filter RuntimeDiagnosticsTests: 8 tests passed.
- swift test --sanitize=thread --filter RuntimeDiagnosticsTests: 8 tests passed with no Thread Sanitizer report.
- make validate-core: boundary and native dependency checks passed; 191 tests in 22 suites passed; post-test swift build passed.
- swift format lint --strict --recursive Sources Tests Package.swift: passed.
- git diff --check: passed.
- task-board validate: passed.

The implementation is bounded and race-free under its current lock, but green tests do not close the contract and privacy/cardinality gaps above. No external blocker or human-only decision is required; this is ordinary implementation rework.