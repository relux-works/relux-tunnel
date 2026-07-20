# TASK-260715-1y1g1u review round 2

Date: 2026-07-20
Verdict: changes requested -> analysis

## Blocking finding

The duplicate-hello rework is not satisfied at the exact hello boundary, and the new tests mask the production transition.

Swift accepts an exact 16-byte server hello with no remainder and publishes completed at RelayHandshake.swift:508-518. RelayClientHandshake.perform immediately returns that result at lines 702-706, so a duplicate hello beginning in the next SSH read is never passed back to the handshake state machine. The split test at RelayHandshakeTests.swift:67-78 nevertheless calls receive again after the first result; for split == 16 the first result is completed, contradicting the required before-publishing-completion behavior.

Go has the same boundary at handshake.go:283-310: an exact 12-byte client hello produces ServerHandshakeCompleted and an accepted reply. Its test at handshake_test.go:46-54 calls Consume again after completion; for split == 12 it therefore proves only that a retained completed object can later fail, not that a production consumer avoided publishing the accepted result.

This contradicts TASK-260715-1y1g1u_rework-01.md requirement 2: reject post-hello RLXR before publishing completion on both peers, including split variants. It also makes the outcome and LOGBOOK claims that every split fails before success inaccurate.

## Why this needs analysis

An SSH/TCP byte stream has no hello message boundary. When the current read ends exactly at byte 16/12, the implementation cannot know whether RLXR will arrive in a future read without delaying a valid standalone handshake indefinitely or adding an explicit lookahead/completion contract. A local beginsWithHelloMagic predicate cannot resolve this ownership boundary.

Viable choices:

1. Recommended: define duplicateHello detection during handshake only for bytes already present in the consume callback. Route an RLXR prefix first seen after exact-boundary completion through the envelope/session decoder as a stable session-close reason. Update the task/rework wording and tests so they do not claim pre-publication equivalence at the exact boundary.
2. Require detection before completion across future reads. Then specify a bounded transport lookahead or a new completion barrier/message-boundary API, including how a valid standalone hello completes without waiting indefinitely. This expands the handshake/session-pump contract and needs architecture approval.
3. Change the v1 wire format to length-delimit the hello. This is incompatible with the frozen v1 layout and is not recommended.

Exact decision needed: choose whether exact-boundary future RLXR belongs to the post-handshake envelope/session state (option 1) or define a concrete pre-completion lookahead contract (option 2).

## Rework items already verified

- Swift and Go local-only RelayEffectiveLimits fields use min(generated peer default/fixed constant, injected config); lower caps and cannot-raise cases are tested.
- Swift perform-level invalid write, throwing write/read, EOF, timeout, cancellation, and malformed-input paths prove stable codes and cancel/reset/close cleanup.
- Wire layout, feature intersection, maximum-frame negotiation, finite diagnostics, architecture placement, and generated-constant use are otherwise sound.

## Independent validation

- make relay-protocol-check: passed (schema drift/negative fixtures, Go smoke/vet/test, Swift build, 19 RelayProtocol tests).
- swift test: 129 tests in 14 suites passed.
- CGO_ENABLED=0 Go test coverage: 92.6%.
- strict swift format lint: passed.
- gofmt diff: clean.
- scripts/check-core-boundaries.sh: passed.
- git diff --check: passed.
- task-board validate: passed.
- Local toolchain remains Go 1.25.5; pinned Go 1.26.5/module validation is the accepted TASK-260715-27uz4n scaffold responsibility and is not this verdict's cause.
