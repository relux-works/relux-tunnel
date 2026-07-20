# TASK-260715-1jvgcn implementation results

## Delivered

- Added generated-backed relay protocol v1 session transition tables in Swift and Go.
- Added paired session machines for direction, association ID, flags, payload policy, PING/PONG, finite UDP errors, association close, session close, and generation-safe cleanup.
- Made exact-boundary post-handshake `RLXR` classification invariant across every split of the four-byte prefix.
- Routed public outbound datagrams and inbound datagrams through bounded HEV validation before lifecycle admission or emission.
- Enforced client-owned association identity: client inbound replies and relay outbound replies require an existing active association.
- Enforced injected `maxAssociations` credit before either peer creates lifecycle state. Fully retired entries become reusable or are pruned only after both close directions are observed, so active and half-closed state remains bounded.
- Rejected malformed, protocol-oversized, local-cap-oversized, unsolicited, closed, and over-limit datagrams without creating cleanup-owned state. Relay failures use finite generated errors and bounded close frames only.
- Preserved edge-triggered queue saturation, idle error-retire-close ordering, duplicate/crossed close idempotence, and once-per-generation abrupt cleanup.
- Added symmetric Swift and Go tests for nominal, hostile, malformed-first, protocol/local-cap-first, unsolicited, closed, maximum-credit, unique-ID flood, abrupt, duplicate, stale, late, and ordered-reuse sequences.

## Verification

- `make relay-protocol-check` — passed: schema negative/drift/digest gates, Go smoke, Swift build, and 53 RelayProtocol tests in 5 suites.
- `swift test` — passed: 163 tests in 17 suites.
- `GO111MODULE=off go test ./relay/...` — passed.
- `GO111MODULE=off go vet ./relay/...` — passed.
- `swift format lint --recursive Sources Tests Package.swift` — passed.
- `gofmt -d relay/internal/protocol/*.go` — clean.
- `git diff --check` — passed.
- `task-board validate` — passed.

## Environment note

The repository's authoritative `relay/go.mod` scaffold remains owned by TASK-260715-27uz4n and is intentionally absent. The repository-owned smoke gate and `GO111MODULE=off` checks used the installed Go 1.25.5 toolchain. The frozen Go 1.26.5 module/toolchain gate remains downstream ownership; this task did not add a competing module or dependency.
