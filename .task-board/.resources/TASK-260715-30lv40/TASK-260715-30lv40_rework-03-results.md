# TASK-260715-30lv40 — rework-03 architecture handoff

## Outcome

The bounded review-03 contradiction is resolved without adding a state,
transition, reason, retry owner, or dependency.

- Plain `degraded` requires no M2 registration and phase `none`.
- `relayReprobeWaiting` requires exactly one current state-matched
  `reprobeWaiting` registration with no attempt generation.
- `relayReprobeRunning` requires exactly one current state-matched
  `reprobeAttempt` registration with a current non-null attempt generation.
- All three branches require current `BaseReady`, null active relay, closed UDP,
  and invalidated retired associations before publishing degraded `(1,1,0)`.
- Missing, duplicate, wrong-phase, wrong-tuple, or accidentally active relay work
  makes the predicate false and projects no usable service.

Sections 4, 5, 6, 9, 10.3, the lifecycle note, reviewer packet, review checklist,
binding race examples, and downstream race-test handoff now use the same
state-dependent rule. T14, T15, T19, and T22 establish the target lifecycle and
exact registration before re-evaluating `Degraded(g)`.

## Preserved architecture

The accepted candidate/validator seams remain unchanged: T04 cannot expose an
active relay, T07/T21/T26 alone promote validated candidates, and T27 retires
the M3-started validator before degraded publication. The external lifecycle
remains 11 states and 32 transitions, with 59 finite reasons and five retry
classes. M2 owns only relay-only reprobe on a healthy current base; M3 owns
path, host, route, lane-pool, sleep/wake, NAT64, and captive reconnect. The UI
remains a read-only consumer of provider truth plus system session status.

Production full/degraded remains gated by accepted M0 composition and a
production-authorized DNS policy. No SSH engine, MTU, lane/window, timing,
retry, overlap, or DNS numeric value is selected, and no absolute OS
kill-switch claim is made.

## Diagram and evidence checks

PlantUML 1.2026.6 passed syntax checking and deterministic rendering for both
task-scoped sources. Original-resolution visual inspection confirmed source and
render parity, readable Waiting/Running registrations in the lifecycle view,
and unchanged single-purpose ownership boundaries. The ownership PNG hash is
`928d103099635e71534adf5b70b2b8187d2bd78006b4dd08c4e73ce61ca03c35`.

## Regression gates

- `make core-test`: 306 tests in 27 suites passed.
- `make relay-protocol-check`: 57 Swift tests in seven suites, 89 deterministic
  vectors, Go protocol tests, schema regeneration/parity, negative fixtures,
  and Swift build passed.
- `make relay-shell-test`: all Go relay packages and 11 release tests passed.
- PlantUML syntax, deterministic render, privacy, table counts, downstream
  byte-copy, board validation, and diff checks are recorded in
  `TASK-260715-30lv40_validation.md`.

The existing 16 consumers remain atomic and sufficiently scoped; no duplicate
task or dependency edge was created. The corrected binding contract is copied
to each consumer as a task-scoped precondition.
