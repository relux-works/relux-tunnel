# TASK-260715-1y1g1u review

Date: 2026-07-20
Verdict: changes requested -> to-dev

## Findings

### 1. RelayEffectiveLimits can exceed the accepted schema baseline

The accepted TASK-260715-18owh7 decision section 4.6 requires every local-only field to be computed as min(schema default-or-constant, injected config), with negotiated maxFrame handled separately.

Swift RelayClientHandshakeConfiguration.effectiveLimits currently copies maximumUDPPayloadBytes, maximumAssociations, queue limits, control reserve, DNS weight, and idle timeout directly into the snapshot (RelayHandshake.swift lines 186-196). Go ServerHandshake.Consume does the same from ServerHandshakeConfig (handshake.go lines 286-294). The Swift boundaryLimits test and Go limit snapshot test explicitly expect above-default hard-ceiling values to become effective.

This permits an injected value above the accepted client or relay baseline to raise the effective limit, contrary to the binding decision, and makes the negotiated summary inaccurate.

Required rework:
- In each peer, derive every local-only effective field as min(the respective generated client or relay default/fixed constant, injected config).
- Preserve effectiveMaxFrame as the negotiated minimum required by the hello contract.
- Replace the above-default expectations with tests proving lower injected caps take effect and above-default injected values cannot raise the effective snapshot.
- Record the corrected effective-limit behavior in the task outcome and logbook.

### 2. A duplicate hello coalesced in one read is not rejected as duplicateHello

While awaiting the hello, Swift lines 475-493 and Go lines 256-306 consume exactly the hello prefix and return all remaining bytes as frame input. The duplicate check only runs if another receive/Consume call happens after completion (Swift lines 464-470; Go lines 242-250).

Therefore one read containing validHello + duplicateHello publishes a completed handshake and hands the second hello to the envelope decoder instead of closing with the stable duplicateHello reason required by the task and binding contract. A legal v1 frame prefix cannot equal RLXR because the accepted frame limit is at most 65536, so the duplicate prefix is distinguishable without parsing envelopes.

Required rework:
- Reject a remainder beginning with the generated RLXR magic as duplicateHello before publishing the completed result.
- Add Swift and Go coverage for coalesced validHello + duplicateHello, including split-boundary variants so behavior does not depend on stream chunking.
- Keep valid hello-plus-frame coalescing unchanged.

### 3. Reachable Swift failure/cleanup paths are not fully proved

AC5 requires tests for all declared failure reasons. RelayHandshakeFailureCode.transportFailure is reachable from invalid partial-write acceptance and channel read/write errors, but asyncFailureCleanup covers malformed input, timeout, and cancellation only. EOF is tested at the state-machine level, but not through RelayClientHandshake.perform, so deterministic cancel/reset/close on channel EOF is not independently proved.

Required rework:
- Add async channel tests for transportFailure from invalid or throwing write/read behavior.
- Add async EOF coverage through perform.
- Assert the stable reason and deterministic generation cleanup for these paths.

## Independent validation

- make relay-protocol-check: passed; schema drift, negative fixtures, generated bindings, Go smoke/vet/test, Swift build, and 18 RelayProtocol tests passed.
- swift test: 128 tests in 14 suites passed.
- swift-format lint --strict on changed Swift files: passed.
- gofmt on changed Go files: clean.
- scripts/check-core-boundaries.sh: passed.
- task-board validate: passed.

The missing relay/go.mod and pinned Go 1.26.5 execution remain an inherited scaffold limitation owned by TASK-260715-27uz4n; the accepted network-free Go 1.25 smoke path passed and is not the reason for this verdict.

Architecture placement and dependency boundaries are correct. Rework is required for contract semantics and coverage, so this is not a stop-the-line blocker.