# TASK-260715-89h7cw implementation and rework results

Implemented the mirrored bounded incremental relay envelope codec in Swift and Go.

Code:
- Sources/ReluxTunnelCore/RelayProtocol/RelayByteCodec.swift
- relay/internal/protocol/codec.go

Tests:
- Tests/ReluxTunnelCoreTests/RelayProtocol/RelayByteCodecTests.swift
- relay/internal/protocol/codec_test.go

Behavior covered: exact big-endian encoder and separate write slices; all legal payload sizes through maxFrame floor; every prefix/body split of a maximum frame; one-byte and coalesced reads; both directions; early cap validation before body allocation; unknown types, flags, association IDs, fixed payload widths, EOF, cancel, terminal state, reset; bounded metadata hook; reconciled aggregate metrics; privacy-safe errors.

Reviewer R1 rework:
- Renamed the Swift suite type to RelayProtocolByteCodecTests so the frozen swift test --filter RelayProtocol command selects the codec suite.
- Kept the existing mirrored Go package step in relay-protocol-check unchanged.
- make relay-protocol-check visibly ran Suite RelayProtocol v1 envelope codec and passed 29 tests in 3 Swift suites after the Go smoke passed.

Verification passed on 2026-07-20:
- swift test --filter RelayProtocolByteCodecTests: 10 tests in 1 suite
- make relay-protocol-check: schema and codegen drift gates, mirrored Go smoke, swift build, 29 Swift protocol tests in 3 suites
- swift test: 139 tests in 15 suites
- swift-format lint --strict on both codec Swift files
- GOTOOLCHAIN=local GOFLAGS=-mod=mod CGO_ENABLED=0 go vet ./... in the accepted temporary relay module
- GOTOOLCHAIN=local GOFLAGS=-mod=mod CGO_ENABLED=0 go test -count=1 ./... in the accepted temporary relay module
- make check-core-boundaries
- git diff --check

Toolchain note: the accepted temporary relay smoke uses workstation Go 1.25.5 pending TASK-260715-27uz4n, as already recorded by the frozen binding review.