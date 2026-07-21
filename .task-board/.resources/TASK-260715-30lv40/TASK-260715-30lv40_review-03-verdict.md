# TASK-260715-30lv40 — independent review 03 verdict

Verdict: changes requested; route to `analysis` for bounded architecture-contract rework.

## Rework-02 findings closed

- T04 retains an internal `activationCandidate` with `activeRelayGeneration=null`, UDP closed, no admitted association, and all public bits false. T07 now guards on current `BaseReady` plus `ValidatedRelayCandidate` and atomically binds, promotes, opens UDP, rechecks `Full`, and publishes.
- The M3 validation-start event is explicit, current-transport and single-use. It registers one exact `reconnectValidator` tuple before resources or callbacks. T26 alone promotes success to full; T27 clears registration before degraded publication; M2 owns no reconnect cadence.
- Clear-before-cleanup retirement, T15 bounded policy re-arm, finite `activation_ready`, and distinct reprobe Waiting and Running phases remain intact.

## Blocking contract contradiction

`Degraded(g)` is not satisfiable in either relay-reprobe state. Contract lines 227-235 include `relayReprobeWaiting` and `relayReprobeRunning` in the predicate but also require `currentRelayRegistration == null`. State rows 264-265 require those states to own a live `reprobeWaiting` timer or `reprobeAttempt` registration, and T14, T15, T19, and T22 create those registrations while retaining degraded traffic. The lifecycle diagram likewise says public service remains degraded during reprobe.

This makes the target invariant false immediately after entering Waiting or Running. Section 10.3 then cannot truthfully publish `serviceMode=degraded` and `(1,1,0)` for those states even though the state and transition tables require it. An implementation must either violate the readiness predicate or suppress the promised degraded service.

Bounded rework: replace the unconditional null-registration clause with explicit state-dependent non-active-relay proof. Plain `degraded` must have no M2 registration; `relayReprobeWaiting` must have exactly one current `reprobeWaiting` registration; `relayReprobeRunning` must have exactly one current `reprobeAttempt` registration. All three must keep `activeRelayGeneration=null`, UDP closed, retired associations invalidated, and current `BaseReady`. Reconcile sections 4, 5, 6, 9, 10.3, the lifecycle note, and the race-test handoff; add tests that prove Waiting and Running publish truthful degraded service while a prospective registration exists. Recopy the corrected contract to all 16 consumers.

## Evidence defect

The validation packet records the ownership PNG SHA-256 as `928d103099635e71534aba66e5922b8187d2bd78006b4dd08c4e73ce61ca03c35`. The stored PNG and a fresh PlantUML 1.2026.6 render both hash to `928d103099635e71534adf5b70b2b8187d2bd78006b4dd08c4e73ce61ca03c35`. Correct the validation hash after rerendering both diagrams.

## Independent gates

- Recount: 11 states, 32 transitions, 59 reason rows, five retry classes. Required reason families and privacy-safe finite dispositions are present.
- M1 live-state authority, system-session separation, M2 relay-only reprobe, M3 reconnect ownership, UI read-only projection, production M0/DNS gates, and numeric non-decisions otherwise remain consistent.
- All 16 downstream copies match the binding contract byte-for-byte; all 16 downstream tasks have non-empty descriptions and AC.
- PlantUML syntax passes; both fresh renders byte-match the stored PNGs and are visually readable. The lifecycle diagram shows Waiting/Running and M3 validator phases; the ownership diagram remains single-purpose.
- `task-board validate` and `git diff --check` pass. The broad related-plan cycle reproduces as the pre-existing board-query anomaly; no dependency-link diff was introduced by rework-02.
- `make core-test`: 306 tests in 27 suites passed.
- `make relay-protocol-check`: 57 Swift tests in seven suites, 89 deterministic vectors, Go protocol tests, schema regeneration/parity, negative fixtures, and Swift build passed.
- `make relay-shell-test`: all Go relay packages and 11 release tests passed.
- Task-scoped text privacy scan found no private-key block, URL, workstation path, literal IP address, or secret assignment. The automatic zero-byte raw reviewer spawn-log resource was removed before handoff.
