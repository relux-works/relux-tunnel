# TASK-260715-lovbdz reviewer verdict

Date: 2026-07-20
Role: reviewer
Verdict: CHANGES REQUESTED -> to-dev

## Acceptance-blocking findings

1. Nested configuration schema versions bypass rejection. RuntimeConfigurationCodec.decodeStartRequest validates only the outer RuntimeStartRequest.schemaVersion through decodeVersioned. The synthesized decoder then accepts configurationReference.schemaVersion without validating it. Independent smoke input with outer schemaVersion 1 and nested schemaVersion 2 decoded successfully and printed: accepted outer=1 nested=2. This violates AC1 and AC4 plus the accepted rule that unsupported versions reject before side effects. Add nested version validation and deterministic old/future nested-version tests. Relevant source: RuntimeMessageModels.swift lines 198-213 and 798-803.

2. Unknown route state does not fail safe. RuntimeLifecycleSnapshot decodes a future routeState as unknown, but capability projection considers only routeMode and lifecycleState. Independent smoke input with routeState futureState decoded as routeState=unknown while tcp=true, safeDNS=true, routesInstalled=true, healthy=true. This violates the accepted unknown-output-state rule requiring unknown projection with all capabilities false. Include routeState in projection and add a deterministic regression test. Relevant source: RuntimeMessageModels.swift lines 485-507 and 963-976.

3. Diagnostics required/default documentation and decoder behavior disagree. RuntimeMessages.md says RuntimeDiagnosticsSnapshot requires generation and sequence and defaults aggregate collections to empty, while its decoder requires counters, gauges, histograms, and errors via decode. Either decode absent collections to the documented empty defaults or document all four as required, according to the approved v1 decision; add a missing-fields test. Relevant source: RuntimeMessages.md line 26 and RuntimeMessageModels.swift lines 636-653.

## Verification

Independent make validate-core passed core boundaries, native packaging checks, 182 tests in 21 suites, and swift build. Swift format lint, git diff --check, and task-board validate passed. Current tests are green but omit the two hostile compatibility cases above. No platform-specific or selected-engine imports were found in the new shared model file.

No stop-the-line boundary exists; this is ordinary implementation rework.