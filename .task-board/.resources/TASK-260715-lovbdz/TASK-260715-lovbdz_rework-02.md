# TASK-260715-lovbdz reviewer verdict — rework 01

Date: 2026-07-21
Role: reviewer
Verdict: CHANGES REQUESTED -> to-dev

## Rework verification

The three findings from TASK-260715-lovbdz_rework-01.md are closed: RuntimeStartRequest validates the nested TunnelConfigurationReference schema; unknown RuntimeLifecycleSnapshot routeState now forces all capability facts false; and absent diagnostic aggregate collections decode to empty while explicit null remains corrupt. Focused runtime codec validation passed 15 tests in 2 suites. make validate-core passed boundary and native-package checks, 183 tests in 21 suites, and swift build. Repository-wide swift-format lint, git diff --check, and task-board validate passed.

## Acceptance-blocking finding

The encoded-oversize test is a false positive and does not exercise the encoder size bound. Tests/ReluxTunnelCoreTests/RuntimeMessageCodecTests.swift constructs one diagnostics counter name with RuntimeMessageSizeLimit.diagnosticsSnapshot bytes and only asserts that some RuntimeMessageCodecError is thrown. RuntimeDiagnosticsSnapshot.encode first calls validateMetricNames, whose 64-byte name limit rejects that key with unsupportedValue before RuntimeJSONCodec.encode can create data or compare it with the 64 KiB message limit. Thus AC4 and the task DoD requirement for deterministic codec size-bound tests are not yet proven on the encode path even though the implementation visibly contains the bound.

Required rework: create an oversize but otherwise valid encodable model, for example many unique valid metric names or repeated protocol-kind capability entries, and assert the exact payloadTooLarge error including maximumBytes and actualBytes. A boundary-success assertion is recommended so the test proves the intended bound rather than another validation guard. Re-run the focused codec suite, make validate-core, format lint, diff check, and board validation, then return for a new reviewer cycle.

No stop-the-line boundary exists; this is ordinary implementation/test rework.