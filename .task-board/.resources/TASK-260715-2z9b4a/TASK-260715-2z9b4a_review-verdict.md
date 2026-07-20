# TASK-260715-2z9b4a review verdict

Date: 2026-07-20
Role: reviewer
Verdict: accepted

## Acceptance evidence

- AC1: The task-scoped developer contract matches `Protocol/Relay/relay-v1.schema.json`, the generated Swift and Go bindings, accepted ADR-021, and the 89-vector corpus for byte order, hello/envelope/HEV widths and offsets, message/status/error values, directions, association IDs, payload lengths, and close/error scope.
- AC2: The limit tables distinguish the negotiated `maxFrame`, fixed `maxUDPPayload`, local caps, defaults/floors/hard ceilings, effective values, policy-versus-protocol breaches, saturation behavior, and association/session close scope.
- AC3: The normative decision rules and task-scoped PlantUML activity diagram state safe optional-feature allocation, deterministic old-peer rejection, unnegotiated-message rejection, and the field/length/value/sequence changes that require a new version with parallel schema, bindings, and vectors. The SVG is valid XML, matches the attached outcome, and was visually reviewed.
- AC4: Every documented command was reproduced from the repository root. Generation and vector generation produced no source/corpus diff. `make relay-protocol-vectors-check`, `make relay-protocol-conformance-check`, `make relay-protocol-hostile-diagnostics`, the 30-second Go fuzz command, `make relay-protocol-check`, and `task-board validate` all passed. The full gate confirmed 12 rejected negative fixtures, deterministic double generation, checked-in output parity, embedded digest checks, stale/manual-edit self-test, Go tests/vet, 57 Swift protocol tests, and Swift build. Reviewer fuzz execution completed 12,606,085 cases with no failure.
- AC5: A literal scan of the contract found no IPv4 destination, hostname, credential assignment, private-key marker, payload sample, or command-stdin example. Public examples remain bounded placeholders. All 35 downstream build/bootstrap/UDP/capability/CI/release consumers have nonempty descriptions and AC, task-scoped precondition links, and resolvable resource payloads.

## Non-blocking handoff constraints

- Local Go is 1.25.5; this is conformance evidence, not Go 1.26.5 release proof. `TASK-260715-27uz4n` owns the pinned release toolchain.
- GitHub Actions/release integration of `make relay-protocol-check` remains owned by `TASK-260715-1m3edc` and `TASK-260715-36gq4m`.

No code changes were made by the reviewer. The implementation fits the frozen protocol architecture and is accepted.