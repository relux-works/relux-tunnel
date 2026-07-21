# TASK-260715-30lv40 — reviewer packet

## Review target

Review `TASK-260715-30lv40_capability-contract.md` revision `rework-03` as the
binding M2 extension to accepted `TASK-260715-30zng6`. The Markdown tables are
normative. The lifecycle diagram explains transitions and registration phases;
the ownership diagram explains authority boundaries only.

The external lifecycle remains 11 states and 32 legal transitions. Rework-03
adds no transition, state, phase, or reason. It makes the degraded predicate
state-dependent so the already-required Waiting/Running prospective
registrations coexist truthfully with public degraded `(1,1,0)` service.

## Rework-03 closure map

| Review-03 finding | Binding closure |
| --- | --- |
| `Degraded(g)` required a null registration in every degraded substate | Section 4 defines `DegradedRegistrationProof`: plain degraded has null registration/phase `none`; Waiting has exactly one current `reprobeWaiting` registration with no attempt generation; Running has exactly one current `reprobeAttempt` registration with a current non-null attempt generation. |
| Waiting/Running promised degraded service while owning prospective work | Sections 5, 6, 9, and 10.3 require the state-matched registration, current `BaseReady`, null active relay, closed UDP, and invalidated retired associations before either state publishes `(1,1,0)`. Missing, duplicate, wrong-phase, or wrong-tuple work projects no usable service. |
| Race-test handoff did not prove prospective-registration projection | The handoff below now requires positive Waiting/Running `(1,1,0)` cases and negative null/duplicate/wrong-phase/wrong-tuple cases. |
| Validation recorded the wrong ownership PNG hash | Rework-03 rerenders both diagrams and records the verified ownership PNG SHA-256 `928d103099635e71534adf5b70b2b8187d2bd78006b4dd08c4e73ce61ca03c35`. |

## Preserved rework-02 closure map

| Review-02 finding | Binding closure |
| --- | --- |
| T07 required `Full(g)` before active relay/UDP existed | Sections 3.2 and 4 separate internal `ValidatedRelayCandidate` from `RelayReady` and public `Full`. T07 now guards on current `BaseReady` plus candidate proof, then atomically binds the generation, promotes `activeSession`, opens UDP, proves `Full`, and publishes. |
| T04 ambiguously exposed an active relay | T04 and the `connectingActivation` row require `activeRelayGeneration=null`, UDP closed, no application association, all bits false, and published local `activation_ready`. |
| T26 required `RelayReady` before validator promotion | Section 3.1 defines the exact local M3 validation-start event, captured tuple, finite `reconnectValidator` phase, allowed callbacks, and single-attempt ownership. T26 consumes candidate success and alone performs the active/full commit. |
| T27 had no legal validator failure phase | The reasserting row permits one validator only after current `BaseReady`; phase legality routes finite failure to T27, which clears registration before cleanup and degraded publication. M2 schedules no M3 retry. |

The four rework-01 findings remain closed: clear-before-cleanup retirement,
bounded local-policy re-arm T15, finite `activation_ready`, and distinct
registered reprobe Waiting/Running phases.

## Post-acceptance commit-hygiene closure

The binding contract and all 16 byte-identical downstream copies no longer use
Markdown hard-break trailing spaces on header metadata lines 3, 5, 6, and 7.
This is a byte-level whitespace correction only: the `rework-03` state,
transition, reason, generation, snapshot, retry, privacy, and ownership semantics
remain unchanged. The corrected contract SHA-256 is
`5b57540c86a0b48595863174e416229babee72cdb2705dd4bbb81bbefdc9ab69`.

Verification covers `git diff --check`, the HEAD-inclusive diff, and
`git diff --cached --check` over an isolated complete index containing staged,
unstaged, and untracked artifacts. The isolated index preserves the user's real
staging area while proving the eventual commit set is whitespace-clean.

## Acceptance-criterion map

| AC | Primary evidence |
| --- | --- |
| State/transition traffic/capability/reason/cleanup/retry table | Contract sections 5–9.1 and lifecycle diagram |
| Full/degraded/failed proof | Contract sections 3.2, 4, 6, and 10.3 |
| Finite reason coverage | Contract section 7, including every required event family |
| Versioned generation-safe privacy-safe snapshots | Contract sections 3, 10, and 12 |
| M1/M2/M3/UI ownership with no parallel reconnect loops | Contract sections 3.1, 9.1, 11, and ownership diagram |

## Load-bearing proofs to challenge

1. `ValidatedRelayCandidate` requires a current registered attempt and the full
   local validation chain, but it explicitly requires active generation null,
   UDP closed, and no admitted association. It is never serialized.
2. T04 cannot expose active relay identity. T07 is the only startup action that
   binds/promotes/opens, and publication follows a successful `Full(g)` recheck.
3. M3 emits `m3BaseReadyForRelayValidation(...)` only after current
   `BaseReady`, once per M3 transport attempt. Registration precedes resources;
   all callbacks capture the exact six-field tuple.
4. T26 promotes one current validator result atomically. T27 clears the
   registration before cleanup/publication. A later validator requires a later
   M3 transport attempt; M2 owns no reconnect timer or backoff.
5. Candidate/validator phases, reasserting, stopping, failed, unknown, stale,
   and corrupt projections expose no usable bits. Numeric generation equality
   never substitutes for a live registration.
6. Plain degraded has no M2 registration. Waiting and Running each require
   exactly one current state-matched prospective registration, but both keep
   active relay null, UDP closed, retired associations invalidated, and
   `Degraded(g)` true; a prospective registration is never `RelayReady`.
7. Production full/degraded remains false until accepted M0 composition and a
   production-authorized DNS policy exist; no engine, MTU, lane/window, timing,
   retry, overlap, or DNS value is selected here.

## Race-test handoff

`TASK-260715-1vg1mb` must cover at least:

- T04 snapshot has `activationCandidate`, `activation_ready`, null active relay,
  closed UDP, and all bits false;
- late T04 candidate callback after T09 retirement is stale before any later
  attempt exists;
- plain degraded publishes `(1,1,0)` only with registration null and phase
  `none`;
- Waiting publishes `(1,1,0)` with exactly one current `reprobeWaiting`
  registration and no attempt generation; a null, duplicate, wrong-phase, or
  wrong-tuple registration projects `(0,0,0)`;
- Running publishes `(1,1,0)` with exactly one current `reprobeAttempt`
  registration and current non-null attempt generation while active relay is
  null, UDP is closed, and retired associations remain invalidated; a null,
  duplicate, wrong-phase, wrong-tuple, or accidentally active relay projects
  `(0,0,0)`;
- T14/T15/T19/T22 change the lifecycle and register the exact target work in
  one serialized action before re-evaluating `Degraded(g)` and publishing;
- T07 rollback publishes no usable state if any bind/promote/open/full recheck
  fails;
- M3 validation-start is rejected before `BaseReady`, for an old transport,
  while a registration exists, after stop, or after a newer M3 event;
- success/failure/stop/newer-transport callbacks match only
  `reconnectValidator` and the exact captured tuple;
- T26 alone yields active generation plus UDP plus full; T27 clears registration
  before degraded; no intermediate reasserting snapshot exposes usable bits;
- M2 never schedules a second reconnect validator or competes with M3 retry.

## Existing downstream owners

No duplicate task is needed. The 16 established consumers remain atomic. The
most affected are `TASK-260715-3edgwz` (schema/predicate phase),
`TASK-260715-kxxujt` (candidate promotion), `TASK-260715-ak0s72` (retirement),
`TASK-260715-1vg1mb` (race matrix), and `TASK-260715-1zikbu` plus
`TASK-260715-3ddzdd` (M3 validation-start/T26/T27 seam).

## Stop-the-line audit

No accepted-contract contradiction was found. Review must reject any candidate
that becomes active before the atomic commit, any validator without the exact
current registration, any M2-owned reconnect retry, any usable reasserting
projection, any remote-controlled diagnostic text, or any bypass of the M0/DNS
production gates.
