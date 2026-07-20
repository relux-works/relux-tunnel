# TASK-260715-1y1g1u implementation and rework results

Implemented the fixed protocol-v1 handshake on the Swift client and Go relay,
including both independent-review rework rounds and the approved exact-boundary
ownership decision.

## Behavior

- Swift emits the generated exact 12-byte client hello and incrementally accepts
  the generated exact 16-byte server hello over `SSHByteChannel`, with partial
  writes, bounded reads, deadline, cancellation, EOF, stale-generation handling,
  and deterministic cancel/reset/close on failure.
- Go incrementally consumes the exact client hello in fixed storage, returns
  exact accepted or rejection server hellos, intersects requested and supported
  features, negotiates `maxFrame`, and exposes explicit fail-closed steps.
- Both peers derive local-only `RelayEffectiveLimits` as the minimum of the
  generated peer default or fixed constant and injected configuration. Lower
  injected caps take effect; above-default values cannot raise the snapshot.
  `effectiveMaxFrame` remains the negotiated peer/local minimum.
- A full or partial `RLXR` prefix already present after the hello in the same
  consume/read callback is rejected as `duplicateHello` before success is
  published. Legal coalesced hello-plus-frame input remains supported.
- At the exact 12-byte client or 16-byte server hello read boundary, success is
  published immediately. No lookahead, delay, or transport barrier is added.
  `RLXR` first observed in a later read is post-handshake session/envelope input
  owned by `TASK-260715-1jvgcn`, which must map it to a stable privacy-safe
  session-close reason.
- Diagnostics remain finite local code/phase/scope/disposition values and never
  reflect remote-controlled bytes or raw unknown statuses.

## Coverage

- Swift and Go exercise every split of hello plus duplicate hello. Splits below
  the exact hello boundary fail when the completing callback contains the
  duplicate; the exact boundary publishes success; splits above the boundary
  reject the coalesced full or partial `RLXR` remainder.
- Existing every-split and coalesced legal frame tests remain green.
- Swift `perform` tests cover invalid write acceptance, throwing write, throwing
  read, EOF, timeout, cancellation, malformed input, stable code/phase mapping,
  and deterministic cancel/reset/close cleanup.
- Limit tests prove lower-cap behavior and cannot-raise behavior for generated
  client and relay baselines.

## Validation

- `make relay-protocol-check`: passed; deterministic schema regeneration/drift
  checks, negative fixtures, Go smoke/vet/test, Swift build, and 19 selected
  `RelayProtocol` tests.
- `swift test`: 129 tests in 14 suites passed.
- Go protocol smoke and coverage: `CGO_ENABLED=0` vet/test passed; statement
  coverage is 92.6%.
- Strict `swift-format` lint: passed on changed Swift files.
- `gofmt`: clean on changed Go files.
- `scripts/check-core-boundaries.sh`: passed.
- `git diff --check`: passed.
- `task-board validate`: passed.

## Toolchain note

The accepted temporary relay smoke remains necessary because `relay/go.mod`
belongs to `TASK-260715-27uz4n` and is not present. Validation ran network-free
with local Go 1.25.5; pinned Go 1.26.5 module validation remains with that
scaffold task.
