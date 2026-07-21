# TASK-260715-30lv40 — rework-02 outcome

## Outcome

The two bounded review-02 contradictions are closed without changing the 11
external states, 32 transitions, 59 reasons, five retry classes, production
gates, numeric non-decisions, or M1/M2/M3/UI ownership split.

- Startup uses an internal `ValidatedRelayCandidate` distinct from
  `activeSession`, `activeRelayGeneration`, `RelayReady`, and UDP admission.
  T04 remains all-false and cannot expose active identity. T07 atomically binds,
  promotes, opens, rechecks `Full`, and publishes.
- M3 now emits one exact local validation-start event after current `BaseReady`
  per transport attempt. M2 registers a captured `reconnectValidator` tuple
  before callbacks/resources, accepts only finite legal callbacks, and owns no
  reconnect retry. T26 alone promotes candidate success to full; T27 clears the
  validator before degraded publication.
- Public Full/Degraded predicates are target-state truth, not circular source
  guards. Reasserting and all candidate/validator phases publish no usable bits.
- The lifecycle diagram exposes M3 Awaiting Base and Validating Relay phases;
  the ownership diagram remains focused on authority and retry cadence.

## Development handoff

No new task was created. The existing 16 implementation, test, DNS, M3, lane,
route, UI, diagnostics, and documentation consumers remain atomic and now carry
byte-identical rework-02 preconditions. The reviewer packet gives
`TASK-260715-1vg1mb` an exact candidate/validator race matrix and maps the
affected schema, transition, reprobe, and M3 owners.

## Evidence

- PlantUML syntax, deterministic renders, and visual source/render review pass.
- Six main resources and all 16 downstream copies byte-match.
- Privacy, board, and diff checks pass.
- 306 core Swift tests, 57 RelayProtocol Swift tests plus protocol/schema gates,
  all Go relay packages, and 11 release-script tests pass.

Production authorization remains false until accepted M0 composition and a
production-authorized DNS policy exist. No final engine, DNS value, MTU,
lane/window, timing, retry, or overlap value was selected.
