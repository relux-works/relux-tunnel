# TASK-260715-30lv40 — rework-01 outcome

## Outcome

The four bounded review findings are resolved without changing the accepted
M1/M2/M3 ownership split, production gates, or numeric non-decisions.

- Relay work now has an explicit current registration: monotonic work
  generation, nullable attempt generation, and finite phase. Retirement clears
  registration before cleanup, publication, or rescheduling, making every late
  callback from attempt N stale before N+1 exists.
- T15 now provides the sole legal same-runtime path from exhausted or
  local-change-required degraded into a fresh bounded relay-only recovery cycle.
  The trigger is a higher locally authorized relay-only policy generation; it
  cannot be remote/UI-owned and cannot overlap M3 reconnect.
- `activation_ready` is the stable published local success reason during
  all-false `connectingActivation`; atomic full publication changes it to
  `none`.
- The lifecycle diagram shows registered Waiting and Running reprobe phases and
  their timer, failure, exhaustion, local re-arm, M3-yield, and stop edges.

## Development handoff

No duplicate task was created. Existing atomic consumers remain the correct
owners, with the revised contract attached as a task-scoped precondition:

- `TASK-260715-3edgwz`: schema-2 registration/cycle fields and activation reason;
- `TASK-260715-ak0s72`: clear-before-cleanup failure retirement;
- `TASK-260715-kxxujt`: bounded cycle, T15 re-arm, and phase transitions;
- `TASK-260715-1vg1mb`: retirement, stale-callback, re-arm, state, transition,
  reason, and snapshot matrix;
- the other 12 M2/M3/DNS/lane/route/UI/diagnostic/test/doc consumers retain
  their established atomic scope and received byte-identical preconditions.

## Evidence

- Contract: 11 states, 32 legal transitions, 59 finite reason rows, five retry
  classes.
- Six main resources and 16 downstream copies byte-match validated sources.
- Both PlantUML sources pass syntax, deterministic rerender, and visual review.
- Privacy scan, board validation, and diff whitespace checks pass.
- 306 core Swift tests, 57 RelayProtocol Swift tests plus protocol/schema gates,
  all Go relay packages, and 11 release-script tests pass.

Production full/degraded remains false until accepted M0 composition and
production-authorized DNS policy exist. No engine, MTU, lane/window, timing,
retry, overlap, or DNS numeric value was selected.
