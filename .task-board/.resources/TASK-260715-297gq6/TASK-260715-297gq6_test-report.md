# TASK-260715-297gq6 test report — review rework

Date: 2026-07-20  
Role: tester  
Wire version: relay protocol v1

## Outcome

The Swift and Go hostile suites now expose matched decoder work and body-allocation metrics, enforce a deterministic processing ceiling, and publish privacy-safe per-seed and cleanup evidence.

- Shared corpus algorithm: `lcg64-v1`.
- Cases: 2,096 per implementation.
- Consumed input bytes: 28,577 per implementation.
- Peak retained bytes: 20.
- Peak allocated body bytes: 4,096, equal to the effective `maxFrame` used by the gate.
- Maximum body allocations per case: 2.
- Maximum processing iterations: 42.
- Maximum processing-iteration ceiling: 43, derived per case as `inputBytes + 3 × bodyAllocations + 1`.
- Maximum chunk count: 5.
- Maximum diagnostic bytes: 96.
- Terminal retained bytes / outstanding body bytes: 0 / 0.
- Reset retained bytes / outstanding body bytes: 0 / 0.
- Materialized datagram bytes after rejection: 0.

The checked corpus includes prefix-only declared lengths of 4,096 and 4,097 bytes. Both directions prove that the accepted ceiling records one 4,096-byte body allocation and EOF cleanup, while the just-over-ceiling case fails before any body allocation.

## Stable semantic records

Both successful Swift and Go output streams record the exact same privacy-safe records:

| Seed ID | Value | Semantic digest |
| --- | --- | --- |
| `zero-state` | `0x0000000000000000` | `00a2ef92f18dcee7` |
| `ascending-bits` | `0x0123456789abcdef` | `79cdb508a6fbb5f1` |
| `alternating-bits` | `0xaaaaaaaa55555555` | `8a739291891be7cb` |
| `task-regression` | `0x2607152976c0ffee` | `930395cb54e2a3ed` |

Digests use only stable frame ordering and code/phase/scope/disposition values. Output includes no input, payload, destination, or remote-controlled diagnostic text.

## Verification

| Command | Result |
| --- | --- |
| `make relay-protocol-conformance-check` | PASS — 89 canonical vectors, verbose Go protocol gate, 57 Swift protocol tests, matched seed records and bounds |
| `make relay-protocol-check` | PASS — conformance plus schema negative fixtures, double generation, generated drift/digest checks, Swift build |
| `make relay-protocol-hostile-diagnostics` | PASS — Go `checkptr=2`; Swift AddressSanitizer |
| `./scripts/tests/test-relay-protocol-go.sh -fuzz FuzzHostileInputDecoder -fuzztime 5s` | PASS — 1,453,381 executions; 19 new coverage-interesting inputs; no failure |
| `swift test --enable-code-coverage --filter RelayProtocol` | PASS — 57 tests; 1,797 / 1,928 handwritten relay lines = 93.21% |
| `./scripts/tests/test-relay-protocol-go.sh -coverprofile=...` | PASS — 85.7% statements; raw profile attached |
| `swift format lint --strict --recursive Sources Tests Package.swift` | PASS |
| `gofmt -l relay/internal/protocol` | PASS — no output |
| Go vet through repository smoke | PASS |
| `sh -n scripts/tests/test-relay-protocol-go.sh` | PASS |
| `python3 -m json.tool Protocol/Relay/Fuzz/v1/regression-seeds.json` | PASS |
| `git diff --check` | PASS |
| `task-board validate` | PASS |

Swift handwritten relay per-file line coverage: ByteCodec 94.51%, DatagramCodec 97.16%, Handshake 96.22%, Session 88.24%.

## Reproduction and CI commands

```sh
make relay-protocol-conformance-check
make relay-protocol-hostile-diagnostics
swift test --filter RelayProtocolHostileInputTests
./scripts/tests/test-relay-protocol-go.sh -run TestHostileInputCorpus -count=1 -v
./scripts/tests/test-relay-protocol-go.sh -fuzz FuzzHostileInputDecoder -fuzztime 30s
```

## Toolchain note

The workstation provides Go 1.25.5. The repository smoke remains a temporary, network-free, standard-library-only module with `CGO_ENABLED=0` until TASK-260715-27uz4n lands the authoritative relay module pinned to Go 1.26.5. Release validation still requires Go 1.26.5; this local result does not replace that gate.
