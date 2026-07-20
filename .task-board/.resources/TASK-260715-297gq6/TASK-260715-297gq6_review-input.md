# TASK-260715-297gq6 test report

Date: 2026-07-20
Role: tester
Wire version: relay protocol v1

## Outcome

- Added one checked `lcg64-v1` regression corpus consumed by both Swift and Go.
- Four fixed seeds produced 2,080 deterministic cases per implementation.
- Both languages produced the same semantic digest for every seed:
  - `zero-state`: `7edf451aa3c0989d`
  - `ascending-bits`: `4c52d45967a7c651`
  - `alternating-bits`: `60a8941231c3ca05`
  - `task-regression`: `bcc9f6fa91624bc4`
- The shared digest is derived only from stable message ordering and code/phase/scope/disposition values. Implementation-specific text and input bytes are excluded.

## Hostile-input bounds

| Metric | Swift | Go |
| --- | ---: | ---: |
| Cases | 2,080 | 2,080 |
| Consumed input bytes | 34,492 | 34,492 |
| Peak retained bytes | 20 | 20 |
| Maximum body allocations per case | 2 | 2 |
| Maximum chunk count | 6 | 6 |
| Maximum diagnostic bytes | 96 | 96 |
| Retained bytes after EOF/cancel/failure/reset | 0 | 0 |
| Materialized datagram bytes after rejection | 0 | 0 |
| Deterministic duration | 39–80 ms observed | 3–4 ms observed |

Inputs include legal and mutated frames, arbitrary bytes up to 512 bytes, hostile four-byte length prefixes, RLXR close sequences, truncation, appended/coalesced frames, both envelope directions, inner datagram parsing, EOF, cancellation, and reset. The existing 89-vector corpus remains the authority for exhaustive field mutations, every incremental cut, fixed hello directions, every type/status/error, and all session-versus-association dispositions.

## Verification

| Command | Result |
| --- | --- |
| `make relay-protocol-check` | PASS — 89 canonical vectors, generated/schema drift gates, Go vet/tests/fuzz seeds, 57 Swift protocol tests, Swift build |
| `make relay-protocol-hostile-diagnostics` | PASS — Go `checkptr=2`; Swift AddressSanitizer |
| `./scripts/tests/test-relay-protocol-go.sh -fuzz FuzzHostileInputDecoder -fuzztime 5s` | PASS — 99,854 executions; 27 new coverage-interesting inputs; no failures |
| `swift test --enable-code-coverage --filter RelayProtocol` | PASS — Swift relay source coverage 1,785/1,915 = 93.21% |
| `./scripts/tests/test-relay-protocol-go.sh -coverprofile=...` | PASS — Go protocol coverage 85.6% statements |
| `swift format lint --strict --recursive Sources Tests Package.swift` | PASS |
| `gofmt -l relay/internal/protocol` | PASS — no output |
| `sh -n scripts/tests/test-relay-protocol-go.sh` | PASS |
| `python3 -m json.tool Protocol/Relay/Fuzz/v1/regression-seeds.json` | PASS |
| `git diff --check` | PASS |
| `task-board validate` | PASS |

## Reproduction and CI commands

```sh
make relay-protocol-conformance-check
make relay-protocol-hostile-diagnostics
swift test --filter RelayProtocolHostileInputTests
./scripts/tests/test-relay-protocol-go.sh -run TestHostileInputCorpus -count=1
./scripts/tests/test-relay-protocol-go.sh -fuzz FuzzHostileInputDecoder -fuzztime 30s
```

## Toolchain note

The workstation provides Go 1.25.5. The repository smoke remains a temporary, network-free, standard-library-only module with `CGO_ENABLED=0` until TASK-260715-27uz4n lands the authoritative relay module pinned to Go 1.26.5. Release validation still requires Go 1.26.5; this local result does not replace that gate.
