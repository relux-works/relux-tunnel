# TASK-260715-30lv40 — independent review 04 verdict

Verdict: accepted; route to `done`.

## Rework-03 closure

- `DegradedRegistrationProof` is satisfiable and state-dependent. Plain
  `degraded` requires no M2 registration and phase `none`;
  `relayReprobeWaiting` requires exactly one current `reprobeWaiting`
  registration with no attempt generation; `relayReprobeRunning` requires
  exactly one current `reprobeAttempt` registration with a current non-null
  attempt generation.
- All three degraded branches retain current `BaseReady`, null
  `activeRelayGeneration`, closed UDP admission, and invalidated retired
  associations. Waiting and Running therefore truthfully publish `(1,1,0)`
  while prospective work exists. Null, duplicate, wrong-phase, wrong-tuple, or
  accidentally active relay work makes the predicate false and projects no
  usable service.
- T14, T15, T19, and T22 establish the target lifecycle and exact registration
  in one serialized action before re-evaluating `Degraded(g)` and publishing.
  The state table, readiness predicate, snapshot rules, lifecycle note, and
  race-test handoff agree.

## Regression and ownership audit

- T04 still exposes neither UDP nor active relay identity. T07 consumes a
  distinct validated candidate and atomically binds, promotes, opens, rechecks
  `Full(g)`, and publishes.
- The M3 validation-start event registers one exact `reconnectValidator` tuple
  after current `BaseReady`; T26/T27 consume one finite result without granting
  M2 reconnect cadence or a usable reasserting projection.
- M1 remains the provider live-state writer, M2 owns relay-only reprobe, M3 owns
  path/host/route/lane/sleep/NAT64/captive reconnect, and UI/M4 remains a
  read-only presenter. The M3 implementation contract remains a downstream
  task consuming this binding contract; no accepted contract contradicts the
  boundary.
- Production full/degraded remains false until the accepted M0 composition and
  production-authorized DNS policy gates are satisfied. No engine, MTU,
  lane/window, timing, retry, overlap, or DNS numeric value is selected, and no
  absolute OS kill-switch claim is made.

## Independent evidence

- Recount: 11 states, 32 legal transitions, 59 unique finite reason rows, and
  five retry classes. Every required reason family and privacy-safe disposition
  is present.
- All 16 downstream task-scoped contract copies are byte-identical, and all 16
  consumers have concrete descriptions and acceptance criteria.
- PlantUML 1.2026.6 syntax checking passes. Fresh renders byte-match the stored
  PNGs. Original-resolution inspection confirms readable Waiting/Running and
  reconnect-validator lifecycle phases plus a single-purpose ownership view.
  The ownership PNG SHA-256 is
  `928d103099635e71534adf5b70b2b8187d2bd78006b4dd08c4e73ce61ca03c35`.
- `make core-test`: 306 tests in 27 suites passed.
- `make relay-protocol-check`: 57 Swift tests in seven suites, 89 deterministic
  vectors, Go protocol tests, schema regeneration/parity, negative fixtures,
  and Swift build passed.
- `make relay-shell-test`: all Go relay packages and 11 release tests passed.
- `task-board validate` and `git diff --check` pass. No dependency-edge diff was
  introduced. The broad `plan(..., mode=related)` cycle remains the previously
  logged board-query anomaly.
- Task-scoped text contains no private-key block, URL, workstation path,
  literal IP address, or secret assignment. The automatic zero-byte raw
  reviewer spawn-log outcome was removed before handoff.

The contract is internally consistent, matches the acceptance criteria, and is
implementable without compensating state or retry loops.
