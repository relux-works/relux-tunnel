# TASK-260715-89h7cw reviewer verdict

Date: 2026-07-20
Verdict: changes requested; route to to-dev.

## Required finding

R1 — The frozen relay binding names make relay-protocol-check as the CI gate that compiles and tests both bindings, and its consumer map requires the Swift split, coalescing, and allocation-bound codec cases. The current Makefile runs swift test --filter RelayProtocol, but the new Swift suite type is RelayByteCodecTests. Independent execution proved the mismatch: make relay-protocol-check passed while reporting 19 tests in only the generated-constants and handshake suites; the envelope codec suite was absent. Running swift test --filter RelayByteCodecTests separately passed 10 tests. Therefore the mandated gate can remain green if the Swift codec tests regress.

Required rework: make the gate select the codec suite as well, either by naming the test type under the RelayProtocol prefix or by broadening the Makefile selector. Re-run make relay-protocol-check and show the envelope codec suite in that command output. Keep the mirrored Go package test in the same gate.

## Independent verification

- make relay-protocol-check: PASS, but omitted the Swift envelope codec suite as described above.
- swift test --filter RelayByteCodecTests: PASS, 10 tests in 1 suite.
- swift test: PASS, 139 tests in 15 suites.
- uncached CGO_ENABLED=0 go vet and go test -count=1 in the accepted temporary relay module: PASS.
- swift-format lint --strict on both new Swift files: PASS.
- make check-core-boundaries: PASS.
- git diff --check: PASS.

## Static review summary

The encoder and decoder logic otherwise matches the wire contract: exact big-endian prefix and fields, checked encoder length arithmetic, cap validation before body allocation, fixed prefix state, incremental and coalesced decoding, generated metadata checks, stable terminal EOF/cancel/reset behavior, privacy-safe errors, and reconciled aggregate metrics. The inherited temporary Go 1.25.5 smoke-module deviation remains the already accepted TASK-260715-2azda7 boundary pending TASK-260715-27uz4n. No code was modified during review.