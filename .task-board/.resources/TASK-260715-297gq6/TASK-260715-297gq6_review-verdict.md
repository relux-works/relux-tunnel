# TASK-260715-297gq6 review verdict

Date: 2026-07-20
Role: reviewer
Verdict: changes requested → to-dev

## Findings

1. The required hostile-input processing-iteration ceiling is not measured. Both hostile suites report `maximumChunkCount`, but neither decoder metric nor test records internal processing iterations. A regression that repeats bounded-looking work per byte while preserving the same semantic digest, allocation count, and retained-byte values would pass. This leaves the task checklist item Measure allocation iteration cleanup and diagnostic bounds and AC2 busy-loop protection unproven. Evidence: `RelayProtocolHostileInputTests.swift` summary and assertions report chunks/body allocations only; `hostile_test.go` does the same; `RelayEnvelopeCodecMetrics` and Go `CodecMetrics` expose no iteration/work counter.

2. The successful CI record does not contain the exact seed values and does not measure actual peak allocated body bytes or explicitly report retained buffers after terminal/reset. The emitted summaries contain only `seeds=4`, `maximumBodyAllocations=2`, and `peakRetainedBytes=20`. `maximumBodyAllocations` is a count, while `peakRetainedBytes` tracks bytes filled, not the full body capacity allocated immediately after an accepted prefix. Therefore AC4 fields seed, peak allocation, and retained buffers are not all present in the CI evidence. The checked JSON has seed values, but the successful Swift/Go output does not record them.

## Required rework

- Add matched Swift/Go work-iteration accounting or an equivalent deterministic test hook, assert a ceiling tied to consumed bytes plus fixed frame overhead, and publish the maximum in the hostile summary.
- Track or deterministically derive peak allocated body bytes separately from retained bytes; assert it never exceeds effective `maxFrame`. Include accepted-at-ceiling and just-over-ceiling declared-length cases in shared deterministic evidence.
- Emit privacy-safe per-seed records in both languages with seed ID/value and semantic digest, and include terminal/reset retained-buffer or outstanding-buffer zero in the aggregate summary. Never emit input/payload bytes.
- Keep the shared semantic digests and exact reproduction commands deterministic, then rerun the full conformance, sanitizer, fuzz, coverage, and lint gates.

## Independent verification

- `make relay-protocol-conformance-check`: PASS, 89 vectors and 57 Swift tests.
- `make relay-protocol-check`: PASS, including schema/generated drift and Swift build.
- `make relay-protocol-hostile-diagnostics`: PASS, Go checkptr and Swift ASan.
- `./scripts/tests/test-relay-protocol-go.sh -fuzz FuzzHostileInputDecoder -fuzztime 5s`: PASS, 2,508,760 executions in the fresh reviewer run.
- Swift relay line coverage: ByteCodec 94.58%, DatagramCodec 97.16%, Handshake 96.22%, Session 88.24%.
- Go protocol statement coverage: 85.6%.
- Swift format, gofmt, shell syntax, JSON validation, `git diff --check`, and `task-board validate`: PASS.

Architecture fit is otherwise sound: the change remains test-only plus Make/script wiring, shares one checked corpus, and does not add runtime dependencies. Go 1.26.5 release-toolchain validation remains owned by TASK-260715-27uz4n.