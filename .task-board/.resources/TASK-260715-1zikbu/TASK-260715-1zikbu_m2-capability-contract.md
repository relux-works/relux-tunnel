# TASK-260715-30lv40 — capability state, reason, generation, and ownership contract

Contract identifier: `m2-capability-contract/1`
Contract revision: `rework-03`
Provider-message protocol: `1`
M2 runtime/capability snapshot schema: `2`
Scope owner: the packet-tunnel extension runtime
Status: producer handoff for independent review

## 1. Decision and authority

This contract extends, and does not replace, the accepted M1 runtime contract
from `TASK-260715-30zng6`. The provider-side `TunnelRuntimeCoordinator` remains
the only live-state writer. `NETunnelProviderSession.status` remains the system
session authority. The containing app may combine those two read-only sources
for presentation, but it does not own forwarding truth, retry loops, runtime
generations, or capability transitions.

The binding inputs are:

- accepted M1 ownership, ordering, rollback, message, and future-seam contract
  from `TASK-260715-30zng6`;
- accepted relay binding and identity preflight from `TASK-260715-111tde`;
- accepted protocol v1 state, scope, and privacy rules from
  `TASK-260715-2z9b4a`;
- accepted ADR-021 limit ownership from `TASK-260715-18owh7` and
  `.spec/decisions.md`;
- accepted invariant resolver policy from `TASK-260715-1tnjlu`, including the
  SSH-only M1 DNS path, enumerated M2 UDP-to-TCP handoff, and no physical DNS
  fallback;
- ADR-007 and the product requirement that relay loss alone yields useful TCP
  plus safe DNS, not a false total failure; and
- the M3 reconnect scope already assigned to `TASK-260715-1zikbu`.

When wire facts differ, the accepted relay schema/generated artifacts win. When
M1 lifecycle facts differ, the accepted M1 contract wins. This contract owns
only the added M2 capability semantics and their M1/M3/UI seams.

No state in this contract claims an absolute OS kill switch. Route behavior is
truthful only within the selected Apple route mode and its documented system
exceptions.

## 2. Production gates and non-decisions

The state machine is binding and may be implemented and tested against injected
fakes. Production composition must nevertheless keep both full and degraded
readiness false while either of these accepted gates is false:

1. `TASK-260720-1qhxqa` has not bound accepted M0 packet/HEV/SSH revisions and
   therefore M1 `productionCompositionPermitted` remains false.
2. `TASK-260721-3miqh4` has not published an independently accepted,
   production-authorized `DNSRuntimePolicyV1`; its current numeric candidate is
   explicitly non-authoritative.

This contract does not choose or copy a final SSH engine, MTU, lane count,
channel window, backoff, jitter, health age, timeout, overlap budget, DNS
capacity, association capacity, or queue size. Runtime code receives accepted
numeric policies as immutable injected evidence. Relay protocol v1 constants
and `RelayEffectiveLimits` remain owned by accepted ADR-021; the snapshot may
report the injected effective values but cannot invent or raise them.

## 3. Generation model

Every event and snapshot first matches the M1/M3 owner tuple
`(configurationGeneration, runtimeGeneration, transportGeneration)`. Relay
timers, attempts, sessions, health checks, process watchers, channels, and
association callbacks additionally require an M2 registration. The current
relay registration is either null or the exact local tuple
`(relayWorkGeneration, relayAttemptGeneration?, relayWorkPhase)`.

| Field | Sole allocator | Rule |
| --- | --- | --- |
| `configurationGeneration` | M1 configuration source/app-group publisher | Monotonic profile snapshot generation. A change cancels the active relay attempt and requires a new validated runtime/configuration handoff. |
| `runtimeGeneration` | M1 `TunnelProviderAdapter` | Strictly increases for every accepted provider start. M2 never increments or reuses it. |
| `transportGeneration` | M3 reconnect coordinator | `0` for the initial M1/M2 transport. M2 reads it but never changes it. A current M3 handoff cancels M2 timers/attempts and invalidates relay associations. |
| `relayRecoveryPolicyGeneration` | Accepted local M2-policy evidence source through the M1 configuration seam | Monotonic revision of relay-only eligibility/evidence. It may re-arm M2 only when it changes no profile, host, path, route, transport, DNS, or lane fact; those larger changes remain M1/M3-owned. Remote input can never allocate it. |
| `relayRecoveryCycleGeneration` | M2 relay capability owner | Strictly increases when automatic eligibility or a newly accepted relay-only policy revision starts a bounded recovery series. Attempt counters and exhaustion are scoped to this cycle and never reset in place. |
| `relayWorkGeneration` | M2 relay capability owner | Strictly increases before registering each waiting timer or attempt/session authority. Every M2 callback captures it. Clearing the registration retires that work immediately even before another generation is allocated. |
| `relayAttemptGeneration` | M2 relay capability owner | Starts at `0` before any relay attempt and strictly increases before each bootstrap/reprobe attempt acquires resources. It never wraps or reuses a value. |
| `relayWorkPhase` | M2 relay capability owner | Finite `none`, `startupAttempt`, `activationCandidate`, `activeSession`, `reprobeWaiting`, `reprobeAttempt`, or `reconnectValidator`. A callback kind is accepted only in its declared phase. `none` means no current relay registration. |
| `activeRelayGeneration` | M2 relay capability owner | Nullable. It equals the fully validated current `relayAttemptGeneration` only after an atomic full-mode commit. It remains null for every candidate/validator phase and is cleared atomically before UDP revocation is published. |
| `snapshotSequence` | M1 runtime snapshot store | Starts at zero for each runtime generation and strictly increases for every published runtime/capability snapshot. |

UDP association identity is `(runtimeGeneration, transportGeneration,
activeRelayGeneration, associationID)`. An association ID has no meaning after
any containing generation changes or `activeRelayGeneration` is cleared.

Each registered timer/attempt/session resource captures the M1/M3 owner tuple,
its `relayWorkGeneration`, its nullable `relayAttemptGeneration`, and the
allowed `relayWorkPhase`. A relay event is current only when all captured fields
match a non-null current registration and the callback kind is legal in that
phase. Retirement is one serialized action that first clears the registration
and sets the published phase to `none`, then closes admission/association
authority, before cleanup, retry scheduling, or snapshot mutation. Promotion
changes only the phase of the same registration (`startupAttempt` ->
`activationCandidate` -> `activeSession`, `reprobeAttempt` -> `activeSession`,
or `reconnectValidator` -> `activeSession`). A transition back to waiting retires the attempt registration
and allocates a larger `relayWorkGeneration` for the new timer. Thus a callback
from retired attempt N fails currentness immediately, including while N remains
the numerically latest `relayAttemptGeneration` and before attempt N+1 exists.

A stale, unregistered, or wrong-phase event is discarded before payload
inspection, allocation, state mutation, retry scheduling, route mutation, or
snapshot publication. It may increment only the bounded
`stale_generation_ignored_total` diagnostic counter. The internal registration
identity is never serialized or exposed to the app.

### 3.1 Phase and callback legality

The current registration is the callback capability; numeric equality without
that registration grants no authority. The following finite table is exhaustive.

| Phase | Legal callbacks/events | Success action | Failure/cancel action |
| --- | --- | --- | --- |
| `none` | None | None | Every relay callback is stale. |
| `startupAttempt` | Locally typed bootstrap, process, identity, hello, feature, limit, framing, and initial-health results for the captured tuple | T04 records a validated candidate by promoting the same registration to `activationCandidate`; no UDP or active generation is exposed | T05/T06 clear registration before cleanup or publication |
| `activationCandidate` | M1 activation-complete, current relay health/process/channel loss, stop, or M3 cancellation for the captured tuple | T07 consumes candidate proof in one atomic full commit | T09 clears registration before rollback |
| `activeSession` | Current session/framing/health/process/channel and association events | Maintain full while `RelayReady(g)` remains true | T10/T12/T13 clear registration and UDP/association authority first |
| `reprobeWaiting` | Its one timer, policy cancellation, M3 handoff, base loss, or stop | T19 consumes and clears the timer registration before allocating an attempt | T20/T24/T25 clear registration first |
| `reprobeAttempt` | The same typed validation chain as startup, plus M3/base/stop cancellation | A complete candidate-success event feeds T21 in the same coordinator turn | T22–T25 clear registration before cleanup/reschedule |
| `reconnectValidator` | Only typed relay-validation success/failure, current M3 cancellation, mandatory base loss, or stop for the captured reconnect tuple | A complete candidate-success event feeds T26 in the same coordinator turn | A finite candidate-failure feeds T27; every exit clears or promotes the registration before publication |

M3 starts `reconnectValidator` only by the local event
`m3BaseReadyForRelayValidation(configurationGeneration, runtimeGeneration,
transportGeneration, baseProofToken)`. The coordinator accepts the event only
in `reassertingAwaitingBase`, after `BaseReady(g)` is true for that exact current
transport, with no M2 registration and no stop or newer M3 event. The opaque
`baseProofToken` is local, single-use, and non-serializable. M2 then allocates
larger relay-work and relay-attempt generations and registers the exact captured
tuple `(configurationGeneration, runtimeGeneration, transportGeneration,
relayWorkGeneration, relayAttemptGeneration, reconnectValidator)` before any
validator resource or callback exists. M3 owns whether a later transport
attempt repeats this event; M2 owns no reconnect backoff or retry loop.

### 3.2 Candidate proof is not an active relay

`ValidatedRelayCandidate(g, registration)` is an internal, non-serializable
predicate. It is true only when all of the following hold at one serialized
decision point:

1. `BaseReady(g)` and the M1/M3 owner tuple are current;
2. the exact non-null registration and attempt generation are current in
   `activationCandidate`, `reprobeAttempt`, or `reconnectValidator`;
3. locally trusted platform/asset, install/checksum/identity, live process and
   channel, protocol hello, features, effective limits, framing, and injected
   health validation all succeeded for that same attempt;
4. the success callback is legal for the current phase and has not been
   retired, cancelled, or superseded; and
5. `activeRelayGeneration == null`, UDP admission is closed, and no application
   association has been admitted for the candidate.

`activationCandidate` may retain that proof while M1 commits settings and packet
reads. Reprobe and reconnect validator success is consumed in the same
coordinator turn by T21 or T26. The proof is never `RelayReady(g)`, never appears
in a provider snapshot, and is destroyed when its registration is cleared.

### 3.3 Binding race examples

- Startup validation completes in attempt N: T04 promotes only to
  `activationCandidate`; snapshots still show null active relay and `(0,0,0)`.
  If stop wins before activation, T09 clears the registration. A late health
  callback from N is stale even though N is still the latest numeric attempt.
- Startup activation succeeds: T07 consumes the retained candidate in one
  serialized transaction. No observer can see UDP open without the matching
  active generation, `activeSession`, full lifecycle, and successful `Full(g)`
  recheck.
- M3 restores base for transport K: its local validation-start event registers
  validator V before callbacks exist. A callback for transport K-1, a cleared V,
  or any non-`reconnectValidator` phase is stale. Success takes T26; finite
  failure takes T27. M2 never creates V+1 unless M3 begins a later transport
  attempt and emits a new accepted event.
- T14/T15 enters Waiting only after exactly one state-matched timer
  registration exists; the resulting snapshot remains degraded `(1,1,0)`.
  T19 consumes that registration and establishes exactly one state-matched
  attempt registration before Running can publish the same degraded service.
  If either snapshot observes null, duplicate, wrong-phase, or wrong-tuple work,
  `DegradedRegistrationProof` is false and the provider publishes no usable
  service rather than guessing.

## 4. Binding readiness predicates

For the current generation `g`, define:

`PolicyAuthorized(g)` means the M1 production-composition manifest and the
accepted injected DNS runtime policy are valid for this composition. Test roots
may substitute an explicitly marked test policy; they must never serialize it
as production authorization.

`BaseReady(g)` is true if and only if all of these current-generation facts are
true at one serialized coordinator decision point:

1. configuration/profile generation is valid and policy-authorized;
2. host identity was verified and SSH authentication succeeded;
3. the mandatory SSH session/control path is live;
4. the M1 packet/HEV path is supervised, packet reads are registered, and the
   packet dispatcher is current;
5. TCP admission and its mandatory `direct-tcpip` path are healthy;
6. the approved safe-DNS transport is ready, accepts tunnel-owned UDP and TCP
   DNS, and has no physical fallback edge;
7. network settings are committed for the same generation, route state is
   `installed`, and no settings request is uncertain; and
8. the generation is not cancelled, stopping, or failed. Provider reasserting
   does not erase these resource facts, but section 10 forbids usable projection
   until M3 clears reasserting atomically with T26 or T27.

`RelayReady(g)` is true if and only if all of these facts bind to the same
current owner tuple and non-null
`(relayWorkGeneration, relayAttemptGeneration, activeSession)` registration:

1. the platform/asset is supported and the locally trusted manifest entry is
   present;
2. upload/install verification, remote checksum, and identity preflight match
   the local manifest;
3. the long-lived process and exec byte channel are live;
4. protocol v1 hello is accepted with no duplicate/extra pre-hello bytes;
5. returned features are a valid requested subset and all locally mandatory
   features are present;
6. peer/local values produce a validated immutable `RelayEffectiveLimits`;
7. framing/session state and current health predicate are ready under injected
   policy; and
8. the registration is current in `activeSession` phase; and
9. UDP admission is open on the current association registry.

The public predicates are state-truth predicates, not source guards for
promotion into those states. `DegradedRegistrationProof(g, state)` is the
finite state-dependent proof below; a prospective reprobe registration is not
an active relay and does not revoke otherwise-current degraded service:

```text
Full(g) = Current(g)
       && state == full
       && providerReasserting == false
       && BaseReady(g)
       && RelayReady(g)

DegradedRegistrationProof(g, state) =
    (state == degraded
        && currentRelayRegistration == null
        && relayWorkPhase == none)
 || (state == relayReprobeWaiting
        && exactlyOneCurrentRelayRegistration(g, reprobeWaiting)
        && currentRelayRegistration.relayAttemptGeneration == null)
 || (state == relayReprobeRunning
        && exactlyOneCurrentRelayRegistration(g, reprobeAttempt)
        && currentRelayRegistration.relayAttemptGeneration != null)

Degraded(g) = Current(g)
           && state in {degraded, relayReprobeWaiting, relayReprobeRunning}
           && providerReasserting == false
           && BaseReady(g)
           && !RelayReady(g)
           && DegradedRegistrationProof(g, state)
           && activeRelayGeneration == null
           && udpAdmission == closed
           && associationsForRetiredRelay == invalidated

Failed(g) = Current(g)
         && lifecycle == failed
         && tcp == false
         && safeDNS == false
         && udp == false
```

`exactlyOneCurrentRelayRegistration(g, phase)` means one and only one non-null
registration matches the full current M1/M3 owner tuple, current
`relayWorkGeneration`, and the named phase under section 3; for
`reprobeAttempt` it also matches the current non-null attempt generation. It
does not permit an `activeSession`, startup/candidate, validator, second timer,
or second attempt. In all three degraded states the active relay is null, UDP
is closed, and every association from the retired relay is invalidated.

These predicates are necessary and sufficient. In particular, authenticated
SSH alone is never full or degraded; a prospective reprobe registration is
never `RelayReady`; relay presence alone is never full; and a system VPN
`connected` status never implies any provider capability. T07, T08, T21, T26,
and T27 use the internal pre-publication guards in section 6, perform their
target-state mutation atomically, then require the corresponding public
predicate before emitting the snapshot.

## 5. State and traffic contract

“Control only” means bounded SSH/bootstrap/settings/cleanup traffic owned by the
extension, not ordinary application or DNS forwarding.

| State | Entry predicate | Legal exit | Owned resources/generation | Allowed traffic | Bits `(tcp,safeDNS,udp)` | Safe-DNS predicate | Published reason | Cleanup and retry disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `idle` | No active runtime; retained immutable terminal snapshot is allowed | Accepted start -> `connectingBase` | Provider instance only | None | `(0,0,0)` | False | `none` or retained terminal reason | Stop is idempotent no-op; new start allocates a larger runtime generation. |
| `connectingBase` | Accepted current start; M1 load/auth/prepare in progress | Base prepared -> `connectingRelay`; failure/stop -> `stopping` | M1 runtime generation and acquisition stack | Pre-route SSH bootstrap control only; no ordinary traffic | `(0,0,0)` | Prepared is not published ready | Current finite M1/start reason | M1 rollback order; no M2 retry. |
| `connectingRelay` | M1 mandatory components are prepared before settings; relay outcome not yet classified | Relay ready or finite unavailable result -> `connectingActivation`; base failure/stop -> `stopping` | M1 resources plus one registered `startupAttempt` at most | Authenticated relay bootstrap/identity/stdio control only | `(0,0,0)` | Prepared, not published ready | `relay_bootstrap_pending` or finite relay result | Failure clears the relay registration before cleanup/activation; retry eligibility is recorded but no second startup loop runs here. |
| `connectingActivation` | Relay outcome is fixed for this start; M1 applies settings, starts reads, and rechecks current health | Base plus validated candidate -> `full`; base plus finite relay-unavailable result -> `degraded`; mandatory failure/stop -> `stopping` | M1 current generation; successful relay path retains one `activationCandidate` registration, with `activeRelayGeneration=null`, UDP closed, and no application associations | Control only until final atomic publication | `(0,0,0)` | Must become true before exit | Published `activation_ready` on successful relay validation; otherwise the finite relay/base result | M1 route/read rollback on failure; candidate registration is promoted only with the atomic full publication. |
| `full` | `Full(g)` | Relay-only loss -> `degraded`; M3 event -> `reassertingAwaitingBase`; mandatory loss/stop -> `stopping` | M1 base plus one registered `activeSession` and association generation | TCP through M1; tunnel-owned DNS through approved M2/M1 paths; general UDP through relay only | `(1,1,1)` | True for current generation | `none` | Relay loss clears the registration, closes UDP admission, and retires associations atomically before publishing degraded. |
| `degraded` | `Degraded(g)` with the plain-state branch of `DegradedRegistrationProof`: registration null and phase `none` | Automatic eligibility or a current accepted relay-only policy revision -> `relayReprobeWaiting`; M3 event -> `reassertingAwaitingBase`; mandatory loss/stop -> `stopping` | M1 base only; no active relay or relay-work registration | TCP through M1; tunnel-owned safe DNS through approved tunneled fallback; general UDP explicitly rejected | `(1,1,0)` | True for current generation | Causal finite relay reason | Automatic reprobe only for catalogued eligible reasons. A higher accepted relay-only policy generation may re-arm one fresh bounded cycle; otherwise remain usable degraded. |
| `relayReprobeWaiting` | `Degraded(g)` with exactly one current state-matched `reprobeWaiting` registration; automatic eligibility or T15 re-arm created the fresh bounded recovery cycle | Timer/trigger -> `relayReprobeRunning`; ineligible/exhausted -> `degraded`; M3/base loss/stop -> handoff or `stopping` | M1 base plus exactly one registered `reprobeWaiting` timer; no relay session, active relay, or live association | Same as degraded | `(1,1,0)` | True for current generation | Original causal relay reason, including retained `relay_reprobe_exhausted` after a local re-arm until a new attempt result | One timer maximum; clear its registration on consumption/cancel, then cancel on stop, profile/transport change, M3 handoff, or base loss. |
| `relayReprobeRunning` | `Degraded(g)` with exactly one current state-matched `reprobeAttempt` registration after the waiting registration was consumed and base/overlap rechecked | Candidate success -> `full`; finite attempt failure -> waiting/degraded; M3/base loss/stop -> handoff or `stopping` | M1 base plus one registered prospective relay attempt within injected overlap budget; active relay remains null and UDP remains closed until T21; retired associations remain invalidated | Same user traffic as degraded; prospective relay is control-only and receives no application UDP | `(1,1,0)` | True for current generation | Original causal reason, or the new finite attempt result | Clear the attempt registration before cleanup or a new waiting registration. T21 alone promotes it to `activeSession`, binds the active generation, and opens UDP. |
| `reassertingAwaitingBase` | M3-owned current path/host/route/lane/sleep/NAT64/captive event; provider reasserting set by M3 | M3 proves current base, starts one validator, then candidate success -> `full` or finite candidate failure -> `degraded`; exhaustion/failure/stop -> `stopping` | M3 transport generation; initially M2 registration is null and relay associations are invalidated; after the accepted validation-start event, exactly one current `reconnectValidator` registration is allowed with active relay null and UDP closed | No new ordinary admission. Validator traffic is bounded control-only. M3 may later specify safe draining, but cannot set capability bits until current readiness is proven. | `(0,0,0)` | Resource readiness may become true, but published safe DNS remains false while reasserting | M3-owned finite reason | M3 exclusively owns reconnect/backoff/settings replacement. M2 owns one validation attempt only after the explicit current-base event; every exit promotes or clears it before publication. |
| `stopping` | User/system stop, cancellation, mandatory failure, or M3 exhaustion | Confirmed ordinary stop cleanup -> `idle`; failure cleanup -> `failed` | One shielded M1 cleanup task; M2 registration is null and retired resources are being joined | Cleanup control only; no new TCP, DNS, or UDP admission | `(0,0,0)` | False | Initiating finite reason; optional finite safety reason | M1 cleanup order is binding. Repeated stop joins the same task. No retry/timer survives. |
| `failed` | Failure cleanup ended, or settings clear is failed/uncertain | Explicit new provider start with larger runtime generation; stop is no-op | Immutable terminal snapshot only; route state may truthfully remain `clearFailed` | None | `(0,0,0)` | False | Primary finite failure; optional `network_settings_clear_failed` safety reason | Terminal for the runtime generation. M2 never self-reconnects from failed. |

## 6. Legal transition table

Any transition not listed is an invariant violation. A stale event never enters
this table; it follows the discard rule in section 3.

| ID | Source + event/guard | Target | Atomic actions before target publication | Owner / retry |
| --- | --- | --- | --- | --- |
| T01 | `idle` + accepted start | `connectingBase` | Allocate runtime generation/root task; publish all bits false | M1; none |
| T02 | `connectingBase` + current M1 base prepared, no settings yet | `connectingRelay` | Retain M1 stack; allocate larger relay-work and relay-attempt generations; register `startupAttempt` before bootstrap resources/callbacks exist | M1 -> M2 seam |
| T03 | `connectingBase` + mandatory failure/cancel/stop | `stopping` | Close admission, cancel root, retain primary reason | M1 |
| T04 | `connectingRelay` + full relay validation succeeds | `connectingActivation` | Promote the current registration to `activationCandidate`; retain internal candidate proof and publish reason `activation_ready`; keep `activeRelayGeneration=null`, UDP closed, association admission absent, and all bits false | M2 -> M1 seam |
| T05 | `connectingRelay` + finite relay-unavailable result while mandatory base remains prepared | `connectingActivation` | Clear the attempt registration first; retire prospective relay/associations; clear active relay; retain degraded reason/retry class | M2 |
| T06 | `connectingRelay` + mandatory base failure/cancel/stop | `stopping` | Clear the attempt registration first, then retire resources and enter M1 cleanup | M1/M2 |
| T07 | `connectingActivation` + current `BaseReady(g)` and `ValidatedRelayCandidate(g, activationCandidate)` | `full` | In one serialized transaction create a fresh closed association registry, bind `activeRelayGeneration` to the candidate attempt, promote the registration to `activeSession`, set lifecycle `full`, open UDP admission, re-evaluate `Full(g)`, and only then publish reason `none` with `(1,1,1)`; any failed recheck rolls back without usable publication | M1 capability writer consuming M2 proof |
| T08 | `connectingActivation` + current `BaseReady(g)`, a finite relay-unavailable result, null registration/active relay, closed UDP, and invalidated prospective associations | `degraded` | Set lifecycle `degraded`, re-evaluate `Degraded(g)`, then publish one current sequence with `(1,1,0)` | M1 capability writer |
| T09 | `connectingActivation` + any mandatory failure/cancel/stop | `stopping` | Clear candidate registration before resource cleanup; keep active relay null and UDP closed; execute M1 route/read rollback | M1 |
| T10 | `full` + current registered relay-only session/framing/health/process/channel loss and `BaseReady(g)` | `degraded` | Clear the `activeSession` registration first; close UDP admission; clear active relay; invalidate associations; publish `(1,1,0)`; join retired resources | M2; retry class from reason catalog |
| T11 | `full` + mandatory base/safe-DNS/settings loss | `stopping` | Close all admission and publish bits false before M1 cleanup | M1; M2 retry forbidden |
| T12 | `full` + current M3-owned recovery event | `reassertingAwaitingBase` | M3 sets reasserting and stops unsafe admissions; M2 clears its registration, cancels work, and invalidates relay generation | M3 |
| T13 | `full` + user/system stop | `stopping` | Clear relay registration; publish bits false; retire relay/associations; start one M1 cleanup task | M1 |
| T14 | `degraded` + catalogued automatic relay reason and injected policy admission | `relayReprobeWaiting` | Allocate a larger recovery-cycle and relay-work generation; register exactly one `reprobeWaiting` timer; set the waiting lifecycle; re-evaluate the waiting branch of `Degraded(g)` before retaining `(1,1,0)` | M2 |
| T15 | `degraded` + higher accepted `relayRecoveryPolicyGeneration` makes the retained causal reason eligible, including after `relay_reprobe_exhausted`; `BaseReady(g)` current; no M3/stop/timer/attempt | `relayReprobeWaiting` | Accept only relay-only local evidence; allocate a fresh bounded recovery cycle and exactly one registered waiting timer; reset attempt eligibility only for the new cycle; set the waiting lifecycle and re-evaluate `Degraded(g)` before retaining the causal reason and `(1,1,0)` | M2; never M3/UI |
| T16 | `degraded` + mandatory base/safe-DNS/settings loss | `stopping` | Publish bits false; no degraded fallback remains | M1 |
| T17 | `degraded` + current M3 event | `reassertingAwaitingBase` | Clear any M2 registration, cancel recovery, and publish bits false under M3 reasserting | M3 |
| T18 | `degraded` + stop | `stopping` | Publish bits false; begin one cleanup | M1 |
| T19 | `relayReprobeWaiting` + current registered timer/trigger and base/overlap recheck | `relayReprobeRunning` | Clear/consume the waiting registration; allocate larger relay-work and relay-attempt generations; register exactly one `reprobeAttempt`; set the running lifecycle and re-evaluate the running branch of `Degraded(g)` before retaining `(1,1,0)` | M2 |
| T20 | `relayReprobeWaiting` + policy exhaustion/ineligibility | `degraded` | Clear the waiting registration; remove timer; set reason `relay_reprobe_exhausted` only when the injected cycle bound is exhausted | M2 |
| T21 | `relayReprobeRunning` + current `BaseReady(g)` and a fresh `ValidatedRelayCandidate(g, reprobeAttempt)` success event | `full` | In one serialized transaction create a fresh closed registry, bind active relay, promote registration to `activeSession`, set lifecycle `full`, open UDP, re-evaluate `Full(g)`, and publish reason `none` with `(1,1,1)` only after health | M2 |
| T22 | `relayReprobeRunning` + eligible finite attempt failure | `relayReprobeWaiting` | Clear/retire attempt registration first; allocate a larger relay-work generation for exactly one new waiting timer; set the waiting lifecycle and re-evaluate the waiting branch of `Degraded(g)` before retaining `(1,1,0)` | M2 |
| T23 | `relayReprobeRunning` + noneligible failure or exhaustion | `degraded` | Clear attempt registration first; retire prospective resources; no automatic loop | M2 |
| T24 | Either relay-reprobe state + base loss/stop | `stopping` | Clear timer/attempt registration, cancel work, and join it before M1 cleanup completes | M1/M2 |
| T25 | Either relay-reprobe state + current M3 event | `reassertingAwaitingBase` | Clear timer/attempt registration, cancel work, invalidate relay/associations, and yield all reconnect ownership | M3 |
| T26 | `reassertingAwaitingBase` + accepted M3 validation-start event established a current `reconnectValidator`; current `BaseReady(g)` and its `ValidatedRelayCandidate` success event hold | `full` | In one serialized transaction create a fresh closed registry, bind `activeRelayGeneration` to the validator attempt, promote registration to `activeSession`, set lifecycle `full`, clear provider reasserting, open UDP, re-evaluate `Full(g)`, and only then publish reason `none` with `(1,1,1)`; a failed recheck clears registration/admission and cannot publish full | M3 owns reconnect; M2 supplies one candidate proof |
| T27 | `reassertingAwaitingBase` + accepted M3 validation-start event established a current `reconnectValidator`; current `BaseReady(g)` and its finite candidate-failure event hold | `degraded` | Clear the validator registration first, keep active relay null and UDP closed, retire validator resources/prospective associations, set lifecycle `degraded`, clear provider reasserting, re-evaluate `Degraded(g)`, and publish the finite reason with `(1,1,0)` | M3 owns reconnect; M2 supplies one finite validator result and schedules no retry |
| T28 | `reassertingAwaitingBase` + M3 terminal exhaustion/mandatory failure/stop | `stopping` | Publish all bits false; M3 hands current resources to M1 cleanup | M3 -> M1 seam |
| T29 | `stopping` + user/system stop cleanup confirmed, routes clear/not committed | `idle` | Publish disconnected terminal snapshot and release runtime | M1 |
| T30 | `stopping` + causal failure cleanup confirmed | `failed` | Publish failed with all bits false and route truth | M1 |
| T31 | `stopping` + required clear failed/uncertain | `failed` | Keep `routesInstalled=true`, `routeState=clearFailed`, and finite safety reason; never claim safe cleanup | M1 |
| T32 | `failed` + explicit accepted start | `connectingBase` | Allocate a strictly larger runtime generation; never reuse terminal objects | M1 / explicit new start |

The M3 validation-start event in section 3.1 is an internal registration action
inside `reassertingAwaitingBase`, not a service-lifecycle transition. Therefore
the externally observable lifecycle remains exactly T01–T32. The action may
publish a newer all-false reasserting snapshot with phase
`reconnectValidator`, but cannot change service mode or capability bits.

Global event priority in one coordinator turn is: current user/system stop;
current mandatory safety loss; current M3 ownership event; current relay loss;
current relay recovery success/failure; timer. This prevents a relay success from
winning over simultaneous stop, safe-DNS loss, base loss, or M3 handoff.

## 7. Finite reason and disposition catalog

The wire tokens below form `M2CapabilityReasonV1`. No adapter may synthesize a
new token or embed remote text. `reason` is the first causal code. Cleanup may
add one finite `safetyReason` without replacing the first cause.

Retry classes are finite: `none`, `m2_relay_reprobe`,
`local_change_required`, `m3_reconnect`, and `explicit_new_start`.

### 7.1 Lifecycle and mandatory-base reasons

| Stable code | Event | State/capability disposition | Cleanup | Retry owner |
| --- | --- | --- | --- | --- |
| `none` | No fault in full/idle | No change | None | `none` |
| `start_requested` | Accepted provider start | Connecting, all bits false | Normal acquisition stack | `none` |
| `activation_ready` | Current startup relay validation succeeded and M1 activation is applying settings/reads | `connectingActivation`, all bits false; changes to `none` only with atomic full publication | Retain the registered activation candidate; M1 rollback on later failure | `none`; published local outcome token, never derived from remote text |
| `stop_user` | User-initiated stop | Stopping -> disconnected when cleanup is confirmed | Full M1 stop; M2 timer/session/associations retired | `none` |
| `stop_system` | System/provider stop | Same as user stop | Same | `none` |
| `start_cancelled` | Stop/cancel wins during start | Stopping; never publishes usable | Roll back every acquired resource | `explicit_new_start` |
| `configuration_invalid` | Invalid/unsupported profile or policy input | Failed, no usable traffic | M1 rollback | `explicit_new_start` after remediation |
| `production_policy_unauthorized` | Required accepted M0/DNS policy gate absent | Failed in production; test root must identify itself | No routes may apply | `local_change_required` |
| `ssh_trust_rejected` | Host identity rejection/change | Failed | M1 rollback/teardown | `local_change_required`; never M2 |
| `ssh_credentials_rejected` | Authentication/credential failure | Failed | M1 rollback/teardown | `local_change_required`; never M2 |
| `ssh_transport_unavailable` | Mandatory authenticated SSH/control path unavailable | Failed, or M3 reasserting when M3 owns an established-session recovery | Retire relay, then M1/M3 cleanup | `m3_reconnect` only after M3 contract; otherwise `explicit_new_start` |
| `packet_path_unavailable` | Mandatory packet/HEV path not ready/lost | Failed | M1 cleanup | `explicit_new_start` or M3 as later contract permits |
| `tcp_path_unavailable` | Mandatory TCP admission/path not ready/lost | Failed | M1 cleanup | `explicit_new_start` or M3 as later contract permits |
| `safe_dns_not_ready` | Safe DNS fails startup readiness | Failed; degraded is forbidden | M1 cleanup before usable publication | `explicit_new_start` |
| `safe_dns_lost` | Current safe DNS becomes unhealthy/exhausted | Stopping -> failed; all bits false | Stop admission, bounded SERVFAIL when safe, clear settings, invalidate cache/transport generation | `explicit_new_start` or M3 if caused by its transport event |
| `network_settings_apply_failed` | Settings did not commit or commit is uncertain | Failed; all bits false | Clear if uncertain, then rollback | `explicit_new_start` / M3 later |
| `network_settings_clear_failed` | Required clear failed or remained uncertain | Failed; all bits false; routes truthfully remain installed/uncertain | Retain terminal snapshot and safety annotation | `local_change_required` |
| `runtime_invariant` | Illegal current transition/generation exhaustion | Failed | Full cleanup | `local_change_required` |

### 7.2 Relay bootstrap/session reasons

All rows below produce degraded, not failed, only when `BaseReady(g)` is true.
If the base predicate is false, its mandatory-base reason wins.

| Stable code | Event | Relay disposition and cleanup | Automatic retry |
| --- | --- | --- | --- |
| `relay_bootstrap_pending` | Current first bootstrap is in progress | Connecting only; no usable bits | No |
| `relay_platform_unsupported` | No supported normalized OS/architecture asset | Retire attempt; degraded | No; `local_change_required` |
| `relay_asset_missing` | Trusted manifest has no required asset | Retire attempt; degraded | No; `local_change_required` |
| `relay_asset_manifest_invalid` | Local manifest/path/size/digest metadata invalid | Security failure; never upload/launch; degraded | No; `local_change_required` |
| `relay_bootstrap_upload_failed` | Authenticated bounded upload transport failed | Close upload channel and partial install state; degraded | Yes, `m2_relay_reprobe` while base remains current |
| `relay_bootstrap_install_failed` | Private install/rename/permission operation failed | Close bootstrap channels and partial state; degraded | No; `local_change_required` |
| `relay_checksum_mismatch` | Remote checksum/self-hash differs from trusted manifest | Never execute; retire asset/session; degraded | No; `local_change_required` |
| `relay_identity_mismatch` | Canonical identity preflight differs from trusted local manifest or is malformed/extra | Never start stdio session; degraded | No; `local_change_required` |
| `relay_launch_failed` | Verified stdio process could not start or exited before hello | Close channel/process state; degraded | Yes, bounded `m2_relay_reprobe` |
| `relay_version_unsupported` | Identity/protocol version unsupported or hello status says unsupported | Close session; no downgrade guess; degraded | No; `local_change_required` |
| `relay_handshake_rejected` | Invalid/duplicate/extended hello, unknown nonzero status, timeout, EOF, or extra pre-hello output | Session-fatal; invalidate prospective generation; degraded | No; `local_change_required` |
| `relay_feature_unsupported` | Reserved/impossible/unrequested features or mandatory feature absent | Session-fatal; degraded | No; `local_change_required` |
| `relay_limit_policy_rejected` | Local limit config invalid, peer frame limit unreasonable, or resource policy rejected | Fail before unsafe allocation/admission; degraded | No; `local_change_required` |
| `relay_framing_invalid` | Session-fatal envelope direction/flag/type/length/EOF/decoder error | Close session and every association once; degraded | No; `local_change_required` |
| `relay_health_lost` | Current injected relay health predicate becomes false/stale | Close UDP admission, retire associations/session; degraded | Yes, `m2_relay_reprobe` |
| `relay_process_exited` | Current relay process exits unexpectedly | Same atomic invalidation; degraded | Yes, `m2_relay_reprobe` |
| `relay_channel_lost` | Relay exec byte channel alone fails while mandatory SSH/TCP/DNS remain healthy | Same atomic invalidation; degraded | Yes, `m2_relay_reprobe` |
| `relay_session_closed` | Unexpected peer/session close/reset | Same atomic invalidation; degraded | Yes, `m2_relay_reprobe` |
| `relay_reprobe_exhausted` | Injected bounded M2 recovery cycle has no further attempt | Clear the waiting/attempt registration; remain degraded with no timer/attempt | No until T15 accepts a higher local relay-only policy generation and allocates a fresh bounded cycle |
| `relay_unknown_failure` | Unrecognized remote numeric/status/adapter error after finite local classification | Close at known session scope; raw value/text discarded; degraded | No; `local_change_required` |

### 7.3 Association-local and saturation reasons

These are operation outcomes, not capability-mode reasons, unless their owning
session also fails through a separate row above.

| Stable code | Protocol/event mapping | Disposition | Mode/retry |
| --- | --- | --- | --- |
| `relay_invalid_datagram` | UDP error `0x0001` / validated malformed HEV payload | Reject/close association as accepted protocol context permits | Stay full; no retry loop |
| `relay_unsupported_address` | `0x0002` | Close association | Stay full |
| `relay_unknown_association` | `0x0003` | Reject/close ID without admitting state | Stay full |
| `relay_association_limit` | `0x0004` or local admission cap | Reject opening datagram; no state/socket | Stay full |
| `relay_datagram_too_large` | `0x0005` | Protocol violation closes association; lower local policy drops only as ADR-021 defines | Stay full unless separate session fault |
| `relay_queue_saturated` | `0x0006` | Drop newest; edge-triggered signal; association survives | Stay full |
| `relay_resolution_failure` | `0x0007` | Association-local terminal close when safe | Stay full |
| `relay_socket_failure` | `0x0008` | Association-local terminal close when safe | Stay full |
| `relay_idle_expired` | `0x0009` | Retire and close association | Stay full |
| `relay_resource_limit` | `0x000A` | Declared association-scope reject/close | Stay full |
| `relay_unknown_association_error` | Unknown future numeric association error | One local association failure; raw value discarded | Stay full |
| `relay_associations_invalidated` | Capability transition retires current relay generation | Close admission, associations, queues, timers, pumps, process/channel exactly once | Diagnostic event only; causal mode reason remains unchanged |

### 7.4 Stale and M3-owned reasons

| Stable code | Event | Disposition | Owner |
| --- | --- | --- | --- |
| `stale_generation_ignored` | Any callback/timer/health/process/association result with a noncurrent owner tuple, no current relay registration, mismatched relay-work/attempt generation, or illegal relay-work phase | Discard before state, retry, cleanup authority, or snapshot mutation; bounded aggregate counter only | Generation owner that receives it |
| `path_changed` | Physical interface/path/viability event | Cancel M2 reprobe, invalidate relay associations, enter reasserting-compatible handoff | M3 |
| `host_transport_lost` | Mandatory authenticated transport/host reachability lost | Same; no M2 SSH reconnect loop | M3 |
| `route_invalid` | Endpoint exclusion/settings generation no longer current | Same; M3 replaces settings atomically | M3 |
| `lane_pool_unavailable` | Mandatory lane or lane-pool ownership loss, not relay exec-channel-only loss | Same; no M2 lane repair | M3 |
| `sleep_wake` | Sleep/wake lifecycle recovery | Same | M3 |
| `nat64_changed` | NAT64/synthesized endpoint context changed | Same | M3 |
| `captive_network` | Captive-network recovery required | Same | M3 |
| `profile_changed` | Profile/configuration generation changed | Cancel M2; old generation cannot continue or retry | M1 new-start/config owner, then M3 if live replacement is approved |

Remote stderr, remote JSON values before local-manifest equality, OS strings,
resolver text, errno text, and unknown raw protocol numbers never become a
reason, diagnostic label, UI string, or retry input.

## 8. Relay loss and association invalidation ordering

For every current relay-session-fatal event, one coordinator turn performs:

1. clear the exact current relay-work registration and publish phase `none`;
2. mark UDP admission closed;
3. clear `activeRelayGeneration`;
4. retire the association registry so all association IDs become invalid;
5. mark `RelayReady(g)=false`;
6. re-evaluate `BaseReady(g)` using current facts;
7. publish degraded `(1,1,0)` or stopping/failed `(0,0,0)` with the causal
   finite reason; and
8. asynchronously join/cancel the retired pumps, queues, timers, process,
   channel, and association resources exactly once.

Steps 1–5 precede the snapshot. The cleared registration makes every later
callback from that attempt stale immediately, even before another attempt is
allocated. Physical cleanup may finish after publication because retired work
has no admission, retry, snapshot, or routing authority. A simultaneous
safe-DNS/base loss wins over degraded, and a simultaneous stop wins over every
recovery action.

## 9. M2 relay-only reprobe contract

M2 may schedule relay-only reprobe automatically only when all are true:

- the current state is degraded;
- `BaseReady(g)` remains true on the same authenticated transport generation;
- the reason catalog marks `m2_relay_reprobe`;
- the injected retry, jitter, stable-reset, memory-overlap, and health policies
  are present and authorized;
- no timer, attempt, M3 recovery, stop, or profile change is active.

After exhaustion or a local-change-required relay reason, the only same-runtime
re-entry is the finite local event
`relayRecoveryPolicyChanged(newRelayRecoveryPolicyGeneration)`. The serialized
coordinator accepts it only when the generation is strictly higher than the
last evaluated policy, the changed evidence is relay-only, the retained causal
reason is eligible under that new evidence, `BaseReady(g)` remains current, and
no registration, stop, or M3 recovery exists. It does not accept remote input,
an app retry command, or a profile/host/path/route/transport/DNS/lane change.
T15 then allocates a larger `relayRecoveryCycleGeneration`, resets attempt
eligibility only inside that new bounded cycle, and registers exactly one
waiting timer with a larger `relayWorkGeneration`. The snapshot retains the
causal reason until the new attempt yields a finite result. A larger-scope
configuration change follows the M1/M3 path instead and cannot take T15.

Only one current registration, timer, and prospective attempt may exist. A
failed attempt registration is cleared before a new waiting registration is
allocated; its physical resources may only overlap under the injected budget.
A plain `degraded` state therefore has registration null/phase `none`; Waiting
has exactly one current `reprobeWaiting` registration; Running has exactly one
current `reprobeAttempt` registration. Those prospective registrations are
required by `DegradedRegistrationProof`, while all three states retain current
`BaseReady`, null active relay, closed UDP, and invalidated retired
associations. Any missing, duplicate, wrong-phase, or wrong-tuple registration
makes `Degraded(g)` false and forces a non-usable projection until the
coordinator resolves the invariant.
A successful attempt publishes full only after asset, checksum, identity,
process, hello, feature, limit, framing, and health validation is current. The
candidate keeps UDP closed and active relay null; T21 alone binds a fresh
association registry and opens admission atomically. It always uses a larger
attempt generation.

M2 never resolves or reconnects the SSH host, changes physical interfaces,
rebuilds endpoint exclusions/routes, repairs the mandatory lane/lane pool,
handles sleep/wake/NAT64/captive recovery, or sets provider reasserting. A
current M3 event cancels M2 work and owns the only reconnect loop.

### 9.1 M3-owned reconnect validation seam

After M3 restores the current authenticated transport, settings, packet/TCP,
and safe-DNS base, it may emit the single-use validation-start event defined in
section 3.1. M2 registers exactly one `reconnectValidator` attempt for that M3
transport attempt. Candidate callbacks must match the full captured tuple and
the phase table; no startup, reprobe, or prior-transport callback is accepted.

On candidate success, T26 consumes the proof atomically. No intermediate
snapshot may expose an active relay generation, UDP, associations, full service,
or safe DNS while provider reasserting remains true. On finite candidate
failure, T27 first clears the registration, then retires resources and publishes
degraded only after M3 clears reasserting and `Degraded(g)` is true. On stop,
mandatory loss, or a newer M3 transport attempt, registration is cleared before
cancel/join and the event is routed to T28 or remains in M3 recovery. M2 never
schedules another reconnect validator; only M3 may begin a later transport
attempt and issue a new validation-start event.

## 10. Versioned provider snapshot contract

### 10.1 Version negotiation

`getProtocolCapabilities` remains schema 1 and advertises per-kind ranges. The
provider must support runtime/capability snapshot schemas `1...2`; unrelated
message kinds retain their accepted ranges. `getRuntimeSnapshot` and
`getCapabilities` request `schemaVersion` selects the matching response schema.
An unsupported requested version returns a bounded `protocolError`; the provider
does not guess or downgrade.

Schema 1 remains the accepted M1 projection for older consumers. It must still
publish truthful existing lifecycle and capability bits. Schema 2 is required
for M2 consumers and adds the finite reason/retry/generation/evidence fields.
The current implementation's single global schema-version equality check must
be replaced by kind-specific supported ranges in `TASK-260715-3edgwz`; changing
unrelated configuration or diagnostics schemas is not implied.

### 10.2 Required schema-2 fields

Both runtime and capability snapshots retain the accepted envelope, size bound,
sorted deterministic JSON, existing capability bits, route fields, and
`RuntimeSnapshotPosition`. Schema 2 additionally requires:

| Field | Type / rule |
| --- | --- |
| `configurationGeneration` | Current unsigned generation. |
| `transportGeneration` | Current M3-owned unsigned generation; initial value is zero. |
| `relayRecoveryPolicyGeneration` | Current accepted local relay-only policy evidence generation; remote input cannot set it. |
| `relayRecoveryCycleGeneration` | Current M2 bounded-cycle generation; zero before recovery is ever armed. |
| `relayWorkGeneration` | Latest allocated M2 registration generation. It remains monotonic evidence after retirement but grants no authority by itself. |
| `relayAttemptGeneration` | Current M2 monotonic attempt value; zero before any attempt. |
| `relayWorkPhase` | Finite `none`, `startupAttempt`, `activationCandidate`, `activeSession`, `reprobeWaiting`, `reprobeAttempt`, or `reconnectValidator`; `none` iff no current registration exists. |
| `activeRelayGeneration` | Nullable; non-null only when `udp=true` and phase is `activeSession`, and equal to the current validated attempt. It is always null in every candidate/validator phase. |
| `serviceMode` | Finite `none`, `full`, `degraded`, `unknown`. Unknown projects all bits false. |
| `recoveryKind` | Finite `none`, `relayReprobe`, `transportReconnect`, `unknown`. M2 never emits `transportReconnect` as an owner; it only projects M3 input. |
| `reason` | One `M2CapabilityReasonV1` token; `activation_ready` is the published local startup-success outcome while activation still has all bits false; `none` is used only in fault-free full/idle. |
| `safetyReason` | Nullable finite token, currently used for settings-clear safety evidence without replacing the first cause. |
| `retryClass` | Finite class from section 7. |
| `relayEvidence` | Nullable typed object described below. |

`relayEvidence` contains only locally validated facts:

- normalized platform enums (`linux|darwin`, `amd64|arm64`, or `unknown`);
- locally trusted manifest/build identifier or digest after exact equality, never
  the raw remote identity string;
- relay protocol/schema version and a finite verification state;
- negotiated feature bitset masked to known bits;
- current injected `RelayEffectiveLimits` numeric fields;
- finite health state/age bucket and aggregate counters.

A mismatch publishes only its finite reason and verification state. It never
publishes the observed remote value. No destination, DNS query, payload,
credential, profile/host identifier, local address, command/path, remote stderr,
raw OS error, raw unknown numeric value, or raw spawn log is representable.

### 10.3 Projection invariants

- `serviceMode=full` if and only if lifecycle is `connectedFull` and `Full(g)`.
- `serviceMode=degraded` if and only if lifecycle is `connectedDegraded` and
  `Degraded(g)`. Plain degraded requires no registration; Waiting requires one
  current `reprobeWaiting` registration; Running requires one current
  `reprobeAttempt` registration. The two prospective registrations keep
  `(1,1,0)` truthful because they confer no active-relay or UDP authority.
- Connecting, reasserting, disconnecting/stopping, failed, disconnected with no
  active service, unknown lifecycle, unknown route state/mode, stale/mismatched
  generation, or corrupt required fields project `(0,0,0)` and `healthy=false`.
- `activationCandidate`, `reprobeAttempt`, and `reconnectValidator` never imply
  `activeRelayGeneration` or UDP. While reasserting, even a current
  `reconnectValidator` registration and true `BaseReady(g)` project all bits
  false until T26 or T27 atomically clears reasserting and proves the target
  predicate.
- `healthy=true` means the requirements of the published service mode are
  currently ready; it is not a generic process-alive bit.
- `udp=true` requires non-null current `activeRelayGeneration` and safe DNS.
- `tcp=true` requires `safeDNS=true`, installed/current routes, and mandatory
  packet/TCP readiness. There is no TCP-only public degraded mode.
- Snapshot consumers accept only a higher runtime generation or a strictly
  higher sequence in the same generation. A lower generation or non-increasing
  sequence cannot replace cached authority.
- `relayWorkGeneration` and `relayAttemptGeneration` are evidence, not
  callback authority. A non-`none` phase reflects the current registration at
  the snapshot decision point; a cleared registration projects `none`, and no
  consumer can infer currentness from the numerically latest generation alone.
- Internal `baseProofToken` and `ValidatedRelayCandidate` proof are never
  serialized. Consumers cannot promote a candidate or initiate validation.

### 10.4 App-message and UI projection

The provider answers read-only app messages from its immutable snapshot store.
The containing app:

1. reads system session status from `NETunnelProviderSession`;
2. requests the newest supported provider snapshot schema;
3. accepts only a current generation/sequence and otherwise projects provider
   capability as unknown with all bits false;
4. maps finite reasons to local bundled copy/remediation; it never displays
   remote text or uses a reason string supplied by the exit;
5. does not infer full from system connected, degraded from missing UDP alone,
   TCP from relay presence, or success from a cached app model; and
6. issues connect/disconnect through the system VPN APIs. It never starts an M2
   or M3 retry loop by app message.

Final copy, accessibility, and action availability remain owned by
`TASK-260715-2a1cp7`. The runtime truth and finite reasons are not UI-owned.

## 11. Ownership matrix

| Concern/event | M1 owner | M2 owner | M3 owner | App/UI owner |
| --- | --- | --- | --- | --- |
| Provider callbacks, runtime generation, configuration, start/stop, settings, packet/HEV, TCP, base DNS, snapshot store | Sole runtime owner | Consumer only | Consumer during later reconnect | Read-only projection |
| Authenticated initial SSH session and mandatory base readiness | Sole owner | Required predicate; no reconnect | Replaces/recovers after established-session events | No ownership |
| Relay asset/bootstrap/identity/stdio/hello/features/effective limits/health and relay-work registration | Provides injected channel/factory seam | Sole allocator/writer; clears registration before retirement; candidate proof is internal | After current base restoration, emits one local validation-start event per M3 transport attempt and consumes one M2 result | Displays finite result only |
| General UDP admission and relay association generation | No M1 general UDP | Sole owner | Invalidates on transport replacement; does not preserve IDs | Displays capability only |
| Relay-only failure with healthy base | Keeps base alive | Clear registration, degrade, invalidate, and optionally reprobe | Must not start a parallel loop | No retry ownership |
| Physical path/viability, host reconnect, actual endpoint, route replacement | Initial M1 setup only | Cancel/yield | Sole reconnect owner | Display only |
| Mandatory lane/lane pool and optional-lane recovery | Initial single-session seam | Relay exec-channel-only loss is M2; no lane-pool repair | Sole owner | Display only |
| Sleep/wake, NAT64, captive recovery | No M1 retry | Cancel/yield | Sole owner | Display only |
| Provider `reasserting` flag and transport-reconnect loop | Never emitted by M1 | Never set by relay-only reprobe | Sole owner | Present accepted state |
| Full/degraded capability calculation | Supplies `BaseReady` facts and serial writer | Supplies internal candidate proof, `RelayReady`, reason, association, and reprobe facts | Supplies current transport/reasserting facts and atomically clears reasserting at T26/T27 | Never synthesizes |
| System VPN state | No replacement for Apple authority | None | None | Reads `NETunnelProviderSession.status` |
| User-visible labels, copy, accessibility, commands | None | None | None | Sole presentation owner under accepted runtime truth |

There is exactly one retry owner at a time. M2 owns only relay reprobe on a
healthy current base. A current M3 event cancels M2 recovery before M3 schedules
transport work. M3 may invoke exactly one M2 `reconnectValidator` after base
restoration for each M3 transport attempt; M2 returns one finite result and does
not create a second retry policy.

## 12. Stop, failure, and privacy rules

Stop is stop-the-world for capability admission:

1. publish stopping with all bits false and close TCP/DNS/UDP admission;
2. clear the relay-work registration, cancel its timer/attempt, clear active
   relay, invalidate associations, and join relay pumps/process/channel;
3. execute the accepted M1 packet-read, settings-clear, DNS, TCP, SSH, and
   resource-release ordering;
4. publish disconnected only when no clear was required or required clear was
   confirmed; otherwise publish failed with truthful route state; and
5. ignore every late callback by generation.

The first causal finite reason wins. A settings-clear failure is always retained
as `safetyReason`; it becomes the primary reason only when ordinary stop had no
prior failure. Duplicate failures and duplicate stops share the same cleanup
task and cannot double-release resources or publish a newer false-full snapshot.

Diagnostics are bounded and aggregate. Allowed data is limited to finite state,
reason, scope/disposition, locally validated build/protocol evidence, injected
effective limits, generations, health buckets, queue/association high-water
marks, and aggregate counts. Forbidden data includes credentials, private keys,
profile or host identifiers, destinations, full addresses, DNS queries,
payloads, traffic samples, per-app/per-flow IDs, command stdin, paths, remote
stderr/stdout strings, raw OS/resolver errors, unknown peer values, and raw
spawn logs.

## 13. Development task handoff and completeness

The existing decomposition is atomic and sufficient; no duplicate gap task is
created.

| Task | One deliverable from this contract |
| --- | --- |
| `TASK-260715-3edgwz` | Implement kind-versioned schema-1/schema-2 snapshots, including registration/cycle generations, `reconnectValidator`, candidate-vs-active invariants, `activation_ready`, predicates, reasons, evidence, and stale projection. |
| `TASK-260715-ak0s72` | Implement clear-before-cleanup relay-work retirement, association invalidation, degraded/failed decision, and stop races. |
| `TASK-260715-kxxujt` | Implement one bounded relay-only recovery cycle, T15 local-policy re-arm, registration phases, candidate proof, and atomic fresh full restoration. |
| `TASK-260715-uh8kk6` | Enforce full/degraded/failed/stopping traffic policy and physical-socket prohibitions. |
| `TASK-260715-2zmw58` / `TASK-260715-3260rm` | Bind the accepted M1 SSH DNS policy into degraded readiness without inventing resolver values or DoH. |
| `TASK-260715-1vg1mb` | Exhaustively table-test every state, transition, reason, candidate/active distinction, validator registration/retirement race, re-arm, generation, snapshot version, and cleanup invariant. |
| `TASK-260715-2y78ah` | Prove composed traffic/leak behavior, including association invalidation and restoration. |
| `TASK-260715-1zikbu` / `TASK-260715-3ddzdd` | Bind and implement the explicit M3 base-ready validation-start event, single `reconnectValidator`, T26/T27 atomic restoration, and no parallel retry ownership. |
| `TASK-260715-2a1cp7` | Define M4 presentation from system status plus current provider snapshot; no runtime inference. |
| `TASK-260715-2bgp7x` | Define diagnostic export/redaction from the finite schema. |
| `TASK-260715-3f9kv8` / `TASK-260715-1cj49i` | Preserve the lane-pool boundary: mandatory/optional lane recovery remains M3. |

The story plan already sequences contract -> snapshot/DNS policy -> transition
controller/DNS integration -> reprobe/rejection -> state tests -> leak tests ->
documentation. Direct dependency edges from this task to M2, M3, UI, route,
lane, QUIC, and diagnostics consumers are present. The contract is attached as
a task-scoped precondition to the implementation/test/ownership consumers that
need its exact tables.

## 14. Review checklist

- Every required full/degraded/failed predicate is a conjunction over current
  M1/M2 generations; no partial combination can publish usable state.
- T04 cannot expose active relay generation or UDP; T07 uses `BaseReady` plus
  internal candidate proof, then atomically binds/promotes/opens and proves
  `Full(g)` before publication.
- Reasserting permits at most one explicitly M3-started `reconnectValidator`;
  T26/T27 consume its finite result, and M2 cannot schedule a reconnect retry.
- Plain degraded has no M2 registration; reprobe Waiting/Running each have
  exactly one current state-matched prospective registration while truthfully
  publishing degraded `(1,1,0)` with null active relay and closed UDP.
- Every legal transition names its entry guard, atomic action, reason, cleanup,
  traffic result, and retry owner.
- A retired timer/attempt/session callback fails the registration predicate
  immediately, before a later attempt exists; wrong-phase callbacks are stale.
- Exhausted/local-change degraded can re-enter only through T15 with higher
  accepted relay-only policy evidence and a fresh bounded recovery cycle.
- All required unsupported platform/asset/bootstrap/checksum/launch/version/
  feature/limit/framing/health/process/lane/safe-DNS/stop/stale events map to a
  finite code and disposition.
- Association invalidation precedes degraded publication and cannot leak IDs
  across a relay generation.
- M2 relay-only reprobe and M3 reconnect are mutually exclusive owners.
- Schema 2 is backward-compatible through explicit per-kind schema-1 responses,
  not a global schema bump or a guessed downgrade.
- Provider state and system VPN state remain distinct authorities.
- Production gates and all unselected numeric/engine/route decisions remain
  explicit; no state claims absolute kill-switch behavior.
- Artifacts contain no prohibited sensitive or remote-controlled data.
