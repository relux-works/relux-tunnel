# TASK-260715-1q7u14 test report

Date: 2026-07-20  
Role: tester  
Wire version: relay protocol v1

## Outcome

- Canonical corpus: 89 vectors.
- Corpus SHA-256: `e21e6ff50042bd982e8284b579e89a24e66c3437a9b701687ecf707fc57e6e76`.
- Schema SHA-256: `3dd1bc9d8d0c1f9127cad05913137754da61d2657e8d0b8c0b30108e331e8000`.
- Independent oracle: Python standard library only; no Swift or Go production codec imports/invocations.
- Determinism: two fresh in-memory generations were byte-identical and matched the checked-in corpus.
- Consumers: strict Swift and Go loaders validate exact keys, identifiers, canonical hex, chunk sums, generated limit references, schema digest, provenance, feature names, and coverage tags.
- Failure privacy: negative loader tests prove the exact stable vector identifier is reported without input or payload hex.

## Coverage matrix

- Both fixed hellos, accepted boundaries, malformed magic/version/flags/features/widths, and every schema hello status.
- All six generated message types and every legal direction.
- All ten finite UDP error values plus the unknown raw-value envelope case.
- IPv4, IPv6, and domain records; domain length 0/1/248/249; port 0/1/65535; association ID 0/1/`u32.max`.
- DATA length 0/512/513/1472/1473 and frame body 6/1733/1734 plus effective-frame overflow.
- Reserved flags/types, illegal directions/IDs, fixed-payload under/over widths, truncated prefixes/bodies/addresses/ports, length mismatches, and both association dispositions.
- Fragmented one-byte and cross-boundary plans plus three-frame coalesced input.

## Verification

| Command | Result |
| --- | --- |
| `make relay-protocol-vectors-check` | PASS — 89 vectors, deterministic 2/2, checked-in digest matched |
| `make relay-protocol-check` | PASS — schema negative fixtures, double regeneration, generated drift/digest gates, Go vet/tests, Swift build, 56 Swift protocol tests |
| `swift test --enable-code-coverage --filter RelayProtocol` | PASS — 56 tests in 6 suites |
| Swift relay handwritten source line coverage | 1784 / 1915 = 93.16% |
| Per-file Swift line coverage | ByteCodec 94.58%; DatagramCodec 97.16%; Handshake 96.04%; Session 88.24% |
| `CGO_ENABLED=0 go test -coverprofile=... ./...` | PASS — 85.6% statement coverage |
| `swift format lint --strict --recursive Sources Tests Package.swift` | PASS |
| `gofmt -l relay/internal/protocol` | PASS — no output |
| `go vet ./...` through repository smoke | PASS |
| `python3 -m py_compile scripts/relay-protocol-vectors.py` | PASS |
| `sh -n scripts/tests/test-relay-protocol-go.sh` | PASS |
| `git diff --check` | PASS |
| `task-board validate` | PASS |

## Toolchain note

The workstation has Go 1.25.5. The repository smoke intentionally synthesizes a
temporary Go 1.25 standard-library-only module with `GOTOOLCHAIN=local` until
TASK-260715-27uz4n lands the authoritative relay module pinned to Go 1.26.5.
Release validation still requires Go 1.26.5; this is not treated as evidence for
the release toolchain gate.

## Anomaly

The accepted TASK-260715-18owh7 decision proposed ADR-021, but
`.spec/decisions.md` currently ends at ADR-020. The corpus provenance therefore
cites the accepted task decision and generated schema directly instead of a
nonexistent ADR anchor. This documentation follow-up does not change vector
bytes or block the tester handoff.
