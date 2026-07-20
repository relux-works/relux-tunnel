# TASK-260715-1jvgcn review verdict — round 2

Date: 2026-07-20
Verdict: changes requested; route to `to-dev`.

## Rework verification

The four items from `TASK-260715-1jvgcn_rework-01.md` are implemented symmetrically:

- Swift and Go retain a bounded partial post-handshake magic prefix and test all eight segmentations of `RLXR` for the same `postHandshakeHello` reason with cleanup once.
- Both public outbound `UDP_DATAGRAM` paths now decode through the bounded HEV codec before activation or emission and reject malformed, protocol-oversized, and lowered-local-cap payloads.
- Generic association failure APIs reject `0x0006` and `0x0009`; dedicated APIs implement the saturation episode edge and idle error-retire-close ordering.
- Paired live-association EOF, cancellation, and transport-failure tests exercise duplicate, stale, and late callbacks and reconcile cleanup and counters.

## Required change

Association admission remains ordered incorrectly and is not bounded.

Swift `handleDatagram` calls `activateAssociation` at lines 553-564 before HEV decoding at lines 565-590. Go does the same at lines 605-613. In both implementations, `activateAssociation` creates a missing entry unconditionally (Swift 667-669; Go 699-702). Consequences:

1. A client accepts and delivers a valid relay datagram for an association ID the client never allocated.
2. A relay policy-dropped first datagram still creates generation-owned association state; malformed first datagrams briefly create state and invoke owned cleanup.
3. Relay outbound `send` can create a missing association instead of requiring an already active client-created association.
4. Neither session implementation consumes `RelayEffectiveLimits.maxAssociations` / `EffectiveLimits.MaxAssociations`. Because the session inserts into its own association map before returning an event to downstream registry code, downstream admission cannot prevent this lifecycle-state growth.

This violates the frozen binding requirement that the client allocates IDs, an association opens only on the first fully validated client datagram, and relay state is admitted only after validation and limit credit. It also leaves a bounded-memory gap under a stream of unique, otherwise trustworthy association IDs.

Independent built-module probes reproduced identical behavior:

```text
Swift:
clientUnallocatedID events=1 accepted=1 cleanup=1
relayFirstPolicyDrop outbound=[17] rejected=1 cleanup=1

Go:
clientUnallocatedID events=1 accepted=1 cleanup=1
relayFirstPolicyDrop outbound=1 rejected=1 cleanup=1
```

Required rework:

- Decode/validate inbound HEV records before creating association lifecycle state.
- Require client inbound replies and relay outbound replies to reference an existing active client-owned association; an unknown/closed ID must follow a bounded finite reject/close policy without payload delivery or state creation.
- Enforce injected association credit before the session map admits a fresh relay-side ID, or introduce an explicit admission token/callback boundary that makes it impossible for downstream registry rejection to occur after session-state insertion.
- Add paired Swift/Go tests for unsolicited relay datagrams, malformed/protocol/local-cap first datagrams, the `maxAssociations` boundary and unique-ID flood, plus cleanup/counter reconciliation and valid ordered reuse.

## Independent validation

- `make relay-protocol-check` — passed; 51 RelayProtocol tests in 5 suites.
- `swift test` — passed; 161 tests in 17 suites.
- `GO111MODULE=off go test ./relay/...` — passed.
- `GO111MODULE=off go vet ./relay/...` — passed.
- `swift format lint --recursive Sources Tests Package.swift` — passed.
- `gofmt -d relay/internal/protocol/*.go` — clean.
- `git diff --check` — passed.

The installed Go toolchain remains 1.25.5; the repository already records the missing 1.26.5 module/toolchain gate as downstream ownership of TASK-260715-27uz4n, so this is not the reason for the verdict.
