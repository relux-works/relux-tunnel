# TASK-260715-1jvgcn review verdict

Date: 2026-07-20
Verdict: changes requested; route to `to-dev`.

## Independent validation

- `make relay-protocol-check` passed, including Go smoke, Swift build, and 48 RelayProtocol tests in 5 suites.
- `swift test` passed: 158 tests in 17 suites.
- `swift format lint --recursive Sources Tests Package.swift` passed.
- `git diff --check` passed.

The green gates do not cover the protocol defects below.

## Required changes

1. Post-handshake RLXR classification is not invariant to stream splitting. Swift `RelaySession.receive` (lines 249-253) and Go `Session.Consume` (lines 321-322) recognize RLXR only when all four bytes occur in one call while the decoder is still at a frame boundary. If RLXR is split, the first chunk is retained as a normal frame prefix and the final chunk closes with `frameLengthExceedsMaximum`, not the required stable `postHandshakeHello` reason. The paired tests only pass unsplit `RLXR` (Swift lines 304-318; Go lines 255-269). Preserve the no-lookahead/no-barrier contract while classifying every split of the four-byte prefix identically in both peers, and add paired every-split tests with once-per-generation cleanup assertions.

2. The public outbound UDP_DATAGRAM path bypasses HEV validation and payload ceilings in both peers. Swift `send` activates and emits directly at lines 314-320, while `validate` explicitly skips UDP_DATAGRAM payload bounds at lines 532-537. Go has the same behavior at lines 375-380 and 570-573. A locally constructed empty, structurally malformed, protocol-oversized, or local-cap-oversized payload can therefore be put on the wire. Route outbound datagrams through the bounded datagram codec or expose a typed datagram send API that cannot emit invalid records. Add symmetric client/relay tests for malformed structure, protocol ceiling, and lowered local-cap behavior.

3. The accepted TASK-260715-18owh7 contract assigned this session task the edge-triggered 0x0006 saturation rule and the 0x0009 error-then-retire-then-close sequence. The current generic `reportAssociationFailure(code, closeAssociation)` API permits unlimited repeated queue-saturation errors and permits idle-expiry without close. Encode the required dispositions/episode boundary in this layer, or constrain the API so the owning bounded scheduler cannot violate them, with paired tests and reconciled counters.

4. Abrupt cleanup is not tested with live associations. The Swift abrupt case at lines 245-255 and Go case at lines 220-227 terminate empty sessions and assert only generation cleanup. Add active-association EOF, cancellation, and transport-failure cases, then duplicate/stale/late callbacks, proving association cleanup and generation cleanup each run once and all close/error/late counters reconcile in both peers.

These are ordinary implementation and coverage rework, not an external blocker.