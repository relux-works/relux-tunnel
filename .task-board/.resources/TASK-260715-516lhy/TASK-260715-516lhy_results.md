# TASK-260715-516lhy — HEV UDP payload codec rework evidence

Date: 2026-07-20
Role handoff: developer to review

## Rework outcome

- Swift and Go decode paths now validate HEV structure before applying the
  protocol or lowered-local `MSGLEN` policy.
- ATYP, recomputed HDRLEN, domain/address bounds, truncated or zero port, exact
  DATA availability, checked outer length, and outer payload equality all run
  before the 1472-byte protocol ceiling and local cap.
- Every failure returns before endpoint or DATA slicing/materialization.
- A structurally valid 1473-byte record remains association-fatal with
  `messageLengthExceedsProtocolMaximum`.
- A structurally valid 513-byte record under the 512-byte local cap remains a
  survivable `messageLengthExceedsLocalMaximum` policy rejection.
- Existing byte-exact IPv4, IPv6, opaque-domain, maximum-width, privacy-safe
  diagnostics, and response-source preservation behavior is unchanged.

## Tests added or corrected

- Mirrored Swift/Go table tests apply both 513-byte and 1473-byte declared
  lengths to unknown ATYP, wrong HDRLEN, truncated address, truncated port,
  zero port, and inconsistent outer length records.
- Every structural case proves association-close disposition and zero decoded
  materialization.
- The old truncated 1473-byte fixture now expects structural length failure.
- A separate structurally valid 1473-byte fixture proves the protocol-limit
  consequence; the existing valid 513-byte lowered-cap test is retained.

## Verification

- `swift test --filter RelayProtocolDatagramCodecTests`: pass, 11 tests / 1 suite.
- `./scripts/tests/test-relay-protocol-go.sh`: pass.
- `make relay-protocol-check`: pass; deterministic generation/schema drift
  checks, Go smoke, Swift build, and 40 relay protocol tests / 4 suites.
- `swift test`: pass, 150 tests / 16 suites.
- Go `vet` and `test -cover` in the repository smoke module: pass, 91.3%.
- `FuzzDatagramCodec -fuzztime=3s`: pass, 1,135,854 executions.
- `swift format lint --strict --recursive Sources Tests Package.swift`: pass.
- `gofmt -l relay/internal/protocol`: no output.
- `make check-core-boundaries`: pass.
- `git diff --check`: pass.

## Toolchain note

The repository still has no authoritative `relay/go.mod`; the accepted
network-free smoke script synthesizes `.temp/relay-protocol-go-smoke/go.mod`
with Go 1.25 and uses the installed Go 1.25.5 toolchain. Therefore a pinned Go
1.26.5 module build was not run. The relay module/toolchain scaffold remains
owned by TASK-260715-27uz4n; this codec was validated through the repository's
current `make relay-protocol-check` contract.
