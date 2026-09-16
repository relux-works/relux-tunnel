# TASK-260715-1pn983 — cross-layer memory, window, and rekey contract

- Status: binding architecture contract, pending independent review
- Authority: ADR-009, ADR-014, ADR-020, ADR-021, ADR-023, ADR-024
- Active physical target: macOS-first on a named Apple-silicon Mac
- Deferred target: iPhone/iOS under ADR-024; Mac evidence is never substituted
- Numeric rule: accepted inputs are named below; every other ceiling and
  watermark is injected and fail-closed until M3 evidence selects it

## Binding decisions and non-claims

The extension has one byte ledger. Packet, HEV, SSH, DNS, relay, rekey, and
reconnect owners cannot admit work from private budgets that ignore each other.
Every admission reserves its worst permitted bounded storage before work starts.
Release occurs exactly once only after the owning operation, queue, channel,
session, lane, or transport is no longer reachable.

The 25–30 MiB range is an engineering target, not an Apple memory guarantee.
`os_proc_available_memory()` is current advisory evidence only: call it for
each observation, never cache its value as future availability, and never turn
unavailable or failed reads into zero. Jetsam is a failure, never control flow.

An SSH advertised receive window is credit, not proof of eager allocation. The
ledger still reserves the maximum local storage that the credit permits because
the peer may consume it. Wire credit, resident bytes, and ledger reservation
are separate metrics. Final watermarks, BDP caps, lane counts, rekey thresholds,
relay caps, and reconnect overlap remain M3 tuning outputs.

## Ledger model and units

All quantities are unsigned bytes unless named otherwise. Counts/products use
checked arithmetic. Overflow, a missing required ceiling, an unavailable owner
count needed for exact charging, or a sum over its parent ceiling is a typed
configuration/admission refusal; operands are not saturated into plausible
values.

```text
current_i             = exactly observed bytes currently owned, when observable
capacityReservation_i = worst total bytes promised to admitted owner i
peak_i                = maximum current_i in the process generation
charge_i              = max(current_i, capacityReservation_i)

ledgerCurrentBytes   = sum(current_i)
ledgerReservedBytes  = sum(capacityReservation_i)
ledgerCommittedBytes = sum(charge_i)
ledgerHeadroomBytes  = globalLedgerCeilingBytes - ledgerCommittedBytes
```

`capacityReservation_i` always means a total owner envelope, never bytes to add
to `current_i`. A proposed new owner or envelope increase is evaluated without
mutating the ledger:

```text
candidateCharge_i = max(candidateCurrent_i, candidateCapacityReservation_i)
candidateChargeDelta_i = candidateCharge_i - existingCharge_i
candidateLedgerCommittedBytes =
  ledgerCommittedBytes + candidateChargeDelta_i
```

For a new owner, `existingCharge_i=0`. For an increase, subtraction uses
checked arithmetic and the existing row remains charged until the atomic
replacement succeeds. A decrease is applied only after the owner proves the
old capacity unreachable; admission never spends an anticipated release.

If exact current bytes are unavailable, the metric is
`unavailable(reason, owner)` and charging uses the conservative live
reservation, never zero. `physicalFootprintBytes` and its peak are independent
process cross-checks, not added to the logical ledger; this avoids double
counting and still catches native/allocator memory outside declared consumers.

Every reservation records `reservationID`, consumer, owner, bytes, generation,
admission monotonic time, lifetime, release event, and eventual release time and
reason. IDs are opaque and bounded-cardinality. Missing is distinct from failed
read; a failed reservation read is `unknown` and refuses admission.

```text
B_global = configured globalLedgerCeilingBytes
B_base   = sum(non-overlap consumer charges)
B_rekey  = sum(per-lane KEX emergency reservations)
B_rc     = reconnect overlap reservation

B_base + B_rekey + B_rc <= B_global
```

`B_untracked` is a permanent ledger consumer row inside `B_base`, charged at
its configured `capacityReservation` from provider bootstrap through final
process teardown. It explicitly covers code, allocator fragmentation, and
native allocations not yet attributable; it is neither an implicit remainder
nor separately added after admission. Thus every headroom, channel, lane,
reconnect, and pressure calculation already subtracts it exactly once.
Production authorization requires physical rows selecting this reservation and
proving the complete process footprint.

### Current evidence and residual DNS assignment

Accepted M0 evidence measured an incremental HEV/bridge peak of `9,715,712 B`
at 500 sessions. Against the lower 25 MiB engineering envelope:

```text
25 MiB                    = 26,214,400 B
HEV/bridge observed peak  =  9,715,712 B
residual after HEV/bridge = 16,498,688 B
DNS hard candidate        =  8,388,608 B
residual after DNS        =  8,110,080 B
```

This assigns the complete DNS hard candidate within the lower envelope without
overlap with the accepted HEV/bridge observation. It does not prove that SSH,
client relay, metrics, rekey, reconnect, and untracked overhead fit the remaining
`8,110,080 B`; DNS values therefore remain candidate and whole-extension
production authorization remains false pending physical composition.

## Consumer ledger

“Configured” below is a required hard field, not a numeric default. Inputs are
sampled at 1 Hz and at admission, release, pressure, rekey, reconnect, and stop.

| Consumer / owner | Unit and hard ceiling | Current and peak input | Reservation lifetime / release | Safe observability | Delivery owner |
| --- | --- | --- | --- | --- | --- |
| Packet socket buffers / packet bridge | bytes; configured total effective ceiling; read back all four Darwin send/receive values, refuse start if their sum is over | four effective values; immutable peak per bridge generation | bridge start through both descriptor closes | requested/effective, clamp, descriptors; no packet bytes | pressure integration; fault task |
| Packet batches/frames / pump | bytes/count; queue byte/count and max-datagram ceilings | exact queued bytes plus fixed entry charge; high-water | reserve-before-enqueue through write/drop/fatal teardown | queue count/bytes/high-water and typed drops | packet owner; `TASK-260715-200jez` |
| HEV task stacks / HEV lease | bytes/count; effective stack × max tasks; accepted stack `24,576 B` | live tasks × stack; otherwise full reservation with unavailable metric | task create through joined exit | live/peak tasks, configured/effective stack | `TASK-260715-318m1v`, tuning task |
| HEV sessions / HEV integration | count plus component reservation; accepted initial ceiling 500 | admitted/live/peak sessions | admission through terminal cleanup | admitted/live/peak/refused | same |
| HEV TCP buffers / session | bytes; effective buffer × max owners; accepted size `4,096 B` | exact owners or conservative session reservation | allocation through session teardown | size, owners/report state | same |
| HEV UDP copy buffers / session | bytes; `1,500 × effectiveCopyCount × maxOwners`; accepted count 2 | exact owners or conservative reservation | owner open through teardown | copy count, owners/report state | same |
| HEV caches/internal queues/manager | bytes/count; mandatory cache and queue ceilings | exact public gauges; otherwise full reservation plus unavailable current | HEV generation through shrink acknowledgement/finalization | caps, current/report state, high-water, shrink ack | same |
| SSH lane socket/session/crypto/timers/callbacks / serialized lane owner | bytes/count; configured per-lane base and max lane count (2…4 only after evidence); lane A mandatory | owned allocations/buffered bytes plus typed native/untracked state | before connect through socket/session/timer/callback cleanup | lane role/generation/state, owned bytes, tasks/descriptors | lane and pressure owners |
| SSH receive-window reservation / channel | bytes; immutable channel cap plus per-channel/lane/global window ceilings | reservation; advertised/outstanding credit separately reported/notReported/unsupported | before open through open failure, close/reset/cancel/lane teardown | class, cap, reserved, credit/report state, adjustments | `TASK-260715-3kimon`, M3 `TASK-260728-3cveay` |
| SSH intake/read buffers / channel | bytes; callback intake and read-buffer ceilings | exact buffered bytes or conservative reservation | open through callback retirement and close | aggregate current/peak/report state | window/adapter owners |
| SSH pending writes/operations / lane+channel | bytes/count; per-channel/lane queue, write-call, pending-operation caps; M0 evidence used 32 KiB, 8 KiB, 64 | exact queue bytes/ops and peaks | reserve-before-enqueue through completion/cancel/failure | bytes/ops/high-water/refusal | selected adapter; fault task |
| Rekey overlap / lane coordinator | bytes/count; per-lane emergency reservation and global concurrent-KEX cap; one in flight/lane | old/new keys, scratch, control queue; exact or conservative | pre-reserved with lane; active until new install and old/scratch release | trigger, generation, reservation/current/report state, duration/result | rekey tasks, M3 deep semantics |
| DNS runtime aggregate / manager generation | bytes; hard candidate `8,388,608 B`, not production-authorized | owners, wire queue, buffers, manager/diagnostics, cache; current/peak when available | reserve complete envelope before capability through full retirement | endpoints/owners/queue/cache/attempts/report states; no names | DNS and pressure owners |
| DNS cache / manager generation | bytes/count/TTL; inside DNS aggregate and separately capped | exact encoded bytes or conservative cap | insert through TTL/generation/pressure/stop | aggregate entries/bytes/evictions | DNS owner |
| Client relay framing/byte pumps / lane-A relay session | bytes/count; negotiated `maxFrame <= 65,536`, bounded stdin/stdout/read/write, relay window | decoder, remainder, queues, pending writes | handshake/session through channel/callback cleanup | effective frame, buffered/queued/high-water/report state | relay and pressure owners |
| Client relay associations/queues / relay client | bytes/count; `maxUDPPayload=1,472`; local hard ceilings 1,024 associations, 256 KiB/association/direction, 4 MiB aggregate/direction, 256 KiB control | charge `max(4 + frameLength, 64)`; current/peak associations/queues | reserve-before-enqueue through send/drop/close/idle/session teardown | aggregates/high-water/reason counters; no destination/payload | relay owners; pressure owner |
| Remote relay process buffers / remote session | bytes/count; remote ceilings 1,024 associations, 256 KiB/association/direction, 16 MiB aggregate/direction, 256 KiB control | remote effective-limit/aggregate diagnostics | remote process generation through exit | aggregate remote snapshot | relay owners; **not** extension charge |
| Reconnect old transport / reconnect generation | bytes; ordinary old lane/channel/DNS/relay charges inside overlap ceiling | exact old-generation charge | failure observation through actual cleanup, not cancel request | generation/state/bytes/cleanup ack | `TASK-260715-318m1v` plus reconnect owners |
| Reconnect replacement / reconnect generation | bytes; configured bootstrap includes lane A, SSH base, KEX, DNS/relay, lifecycle | exact reservation before construction, then current charge | reserve before connect through promotion or failed cleanup | requested/granted/refused/released, current/peak | same |
| Metric event/history store / instrumentation | bytes/count/labels; mandatory history, ring, cardinality ceilings | exact retained bytes/records plus overflow/coalescing | insertion through bounded eviction/generation close | fixed-cardinality aggregate labels | instrumentation and fault owners |
| Untracked process reserve / provider generation | bytes; configured `B_untracked` total-capacity row | current is `unavailable(not-attributable)` by definition; fixed reservation and footprint cross-check | provider bootstrap through final process teardown | reservation, generation, physical footprint/current peak; no fabricated attribution | ledger/controller, tuning, physical owners |

Remote relay memory is evidence but is not summed into Apple extension memory.
Client relay queues and channel buffers are. The owner registry prevents double
charge by declaring when a child is already included in a parent ceiling.

## Window-credit and DNS formulas

Let `KiB=1024 B`, bandwidth be integer bits/s, RTT integer ns:

```text
W32 = 32 × KiB
W64 = 64 × KiB
rawBDPBytes = ceil(bandwidthBitsPerSecond × rttNanoseconds /
                   (8 × 1_000_000_000))
cappedBDP = clamp(rawBDPBytes, bulkWindowMinimumBytes,
                  bulkWindowMaximumBytes)
relayBurstBytes = relayBurstDatagramCount ×
                  max(4 + relayMaximumFrameBodyBytes, 64)
relayCandidate = min(relayWindowMaximumBytes,
                     relayControlWindowBytes + relayBurstBytes)
```

For requested `W`:

```text
channelCapacity = W + readBufferCapacity + writeCapacity + metadataCapacity
channelChargeDelta = candidateCharge(channelCapacity) - existingChannelCharge

admit iff W <= perChannelWindowCeiling
  and laneWindowReserved + W <= perLaneWindowCeiling
  and globalWindowReserved + W <= globalWindowCeiling
  and ledgerCommittedBytes + channelChargeDelta <= globalLedgerCeilingBytes
  and lane is current, healthy, not closing, and not in KEX
  and pressure policy permits the class
```

The pre-admission `ledgerCommittedBytes` includes the permanent `B_untracked`
row and every existing owner, including every admitted lane's permanent KEX
reservation; it excludes only this proposed `channelChargeDelta`. Successful
admission atomically installs the channel capacity row and window aggregates
before open construction. Failed construction releases that row exactly once
after callbacks/tasks cannot reach it. Refusal is typed and creates no queue.

Initial credit is at most the reserved immutable cap. `WINDOW_ADJUST(delta)`
requires an atomic reservation while the generation is current and state is
Normal or Soft. Pressure, Critical, KEX, closing, failed, stale, or insufficient
budget withholds it. Previously advertised credit is never revoked/reclaimed.
No failed adjustment is queued on the side.

```text
delta = min(channelCap - outstandingAdvertisedCredit,
            laneWindowHeadroom, globalWindowHeadroom,
            ledgerHeadroomAfterOtherReservations)
```

`delta=0` is withholding. Until M3 delivers consumer-earned immutable credit,
libssh2 wire metrics stay `unsupported/notReported`; bounded adapter intake and
the conservative reservation remain mandatory.

### Lane admission

Lane admission is one serialized transaction. Lane base excludes channel,
DNS, relay, and KEX child rows so the following bootstrap charge owns each byte
once:

```text
laneBootstrapCapacity =
  laneBaseCapacity + perLaneKEXEmergencyBytes + mandatoryControlCapacity +
  (isLaneA ? mandatoryLaneAWindowCapacity + mandatoryDNSBootstrap +
             mandatoryRelayBootstrap : 0)

laneChargeDelta = laneBootstrapCapacity  // new lane; existing charge is zero

admit iff liveLaneCount + 1 <= configuredLaneCountCeiling
  and configuredLaneCountCeiling <= evidencedLaneCountHardMaximum
  and laneBaseCapacity <= configuredPerLaneBaseCeiling
  and perLaneKEXEmergencyBytes >= configuredMinimumKEXEmergencyBytes
  and mandatoryControlCapacity >= configuredMinimumControlCapacity
  and (lane A already remains current, or isLaneA)
  and all mandatory lane-A slices are configured and fit their component caps
  and ledgerCommittedBytes + laneChargeDelta <= globalLedgerCeilingBytes
  and provider generation is current and not stopping
  and lane pool is healthy, not closing, and has no construction in flight
  and pressure state permits the requested role
```

Because `ledgerCommittedBytes` already charges `B_untracked`, the final global
predicate is also the untracked-headroom predicate. Normal permits lane A and
evidence-authorized optional roles; Soft/Pressure fast-refuse optional lanes;
Critical admits no lane until the old generation is actually released and the
critical bootstrap path below succeeds. Any failed predicate returns
`laneAdmissionRefused(reason)` synchronously. Admission installs one bootstrap
row before construction; construction may atomically transfer its DNS, relay,
window, and KEX slices to child rows without changing total committed bytes.
Failed construction cancels reachability and releases all transferred or
untransferred slices exactly once. There is no waiting or retry side queue.

For endpoints `E`, owners `O`, maximum DNS message `M`, queued wire `Q`:

```text
framedMessage = M + 2
perOwner = 3 × framedMessage + 1,024
fixed = 2 × framedMessage + 65,536 manager + 65,536 diagnostics + 64 × E + Q
dnsLocalLedger = O × perOwner + fixed
dnsSlack = dnsAggregateBytes - dnsLocalLedger
```

```text
default: E=4, O=16, M=65,535, Q=262,144
         3,686,706 <= 4,194,304; slack 507,598
hard:    E=8, O=32, M=65,535, Q=1,048,576
         7,635,554 <= 8,388,608; slack 753,054
```

Equality is accepted; one byte over any component/aggregate is typed refusal.
The manager reserves the complete component before capability publication.
Unused DNS slack stays DNS-owned until an atomic transfer, preventing two owners
from spending the same residual byte.

## Pressure states and hysteresis

Configuration supplies three entry headroom floors and three higher exit floors
for ledger, physical-footprint, and advisory signals:

```text
criticalEnter < pressureEnter < softEnter
criticalExit > criticalEnter
pressureExit > pressureEnter
softExit > softEnter
```

Each observation records generation/time, footprint/peak, ledger
current/reserved/committed/peak, one new advisory-call result, warning input,
and owner report states. Severity is the maximum entry predicate across ledger
headroom, configured footprint headroom, fresh advisory bytes, and explicit
memory warning (at least Pressure). Entry may jump severity.

Exit moves at most one state/evaluation and requires every available signal
above the exit floor, required actions acknowledged, no unresolved owner-read
failure, and a configured recovery dwell. This is hysteresis, not averaging.
An advisory value is fresh only in the observation that called the API.
Unavailable, failed, malformed, or late results are typed; they cannot cause
recovery, become zero, or conceal escalation from other evidence. In Normal
they do not alone stop the provider; hard ledger fit still governs admission.

## One ordered action table

The serialized executor applies rows cumulatively and keys each action by
`(policyGeneration, ordinal, owner)`.

| # | State | Action | Completion/failure semantics |
| ---: | --- | --- | --- |
| 1 | Soft | Suppress optional-lane admission | Lane A remains; optional request fast-refuses `memoryPressure` |
| 2 | Soft | Close contract-defined idle channels/associations | No live-stream migration or arbitrary kill; timeout blocks recovery |
| 3 | Soft | Cap new channel windows at configured soft value | Existing advertised credit unchanged |
| 4 | Soft | Shrink semantics-safe DNS/relay/packet/other caches and queues | Ack released bytes; no unsafe eviction |
| 5 | Pressure | Withhold all new `WINDOW_ADJUST` | No pending-adjust side queue |
| 6 | Pressure | Reduce HEV session admission and reversible HEV/cache limits | Existing sessions remain accounted; refusal is bounded/typed |
| 7 | Pressure | Fast-refuse new nonessential TCP/UDP/bulk/optional control work | Mandatory safe DNS/control uses its reserved slice; no physical fallback |
| 8 | Critical | Freeze/cancel a replacement not yet started | Bytes stay reserved until actual cleanup ack |
| 9 | Critical | Release old transport, channels, DNS/relay generation, timers, callbacks | Must observe release before replacement construction; no replay/migration |
| 10 | Critical | If continuity is requested, reserve critical bootstrap then start replacement | New lane A includes KEX/DNS/relay mandatory slices |
| 11 | Critical | If release/replacement cannot fit or finish by deadline, stop explicitly | `memoryRecoveryImpossible`; cancel retries, withdraw capability/settings, await bounded cleanup; never jetsam |

Acknowledgements record requested/released/remaining bytes, owner generation,
deadline outcome, and failure. Duplicate/stale acknowledgements are counted and
ignored. Soft/Pressure failure holds state and refuses dependent admission.
Critical failure proceeds to explicit stop. Recovery reverses only admission
and cache targets; it never recreates closed owners or returns prior credit.

## Rekey, reconnect, cancellation, and stop

Each lane permanently reserves `perLaneKEXEmergencyBytes`, allowing inbound
server KEX or a due client security threshold under pressure. Before KEX, the
lane becomes unavailable for new channels. Existing channels remain pinned and
inside existing reservations. One KEX runs/lane; simultaneous triggers coalesce
into it with at most one bounded later-due reason bitset.

Pressure uses the emergency slice for protocol-required server or due client
KEX while withholding new channels/credit; manual/test triggers defer in the
bounded bitset. Critical lets an active KEX finish only for the retained lane
inside reservation, otherwise closes it during old release/stop. Success
releases old keys/scratch and resumes admission only when current state permits.
Failure is lane-fatal first, closes its channels once, updates lane-A relay/DNS
capability before publication, and requests only an admitted replacement. No
bytes are replayed or migrated.

```text
replacementBootstrapReservation =
  newTransportBase + mandatoryLaneA + laneAKEXEmergency +
  mandatoryDNSBootstrap + mandatoryRelayBootstrap + lifecycleOverhead

admit iff oldTransportCharge + replacementBootstrapReservation
           <= reconnectOverlapBytesCeiling
       and ledgerCommittedBytes + replacementBootstrapReservation
           <= globalLedgerCeilingBytes
```

Before this predicate, `ledgerCommittedBytes` already includes `B_untracked`,
the complete old transport charge, and every admitted old lane's permanent KEX
row; it excludes the proposed replacement. The overlap predicate's
`oldTransportCharge` is a scoped subset check, not another addition to the
global ledger. Successful admission installs the replacement total-capacity
row once, then transfers slices to its constructed children without changing
the total. At Critical, actual old cleanup first removes its rows from both the
ledger and overlap account; only then is the same replacement predicate run
with `oldTransportCharge=0`.

At Critical the old charge must reach zero before the replacement constructor.
Stop/cancel invalidates generations, cancels admissions/retries, and waits for
actual cleanup before release. Late callbacks cannot allocate, publish
capability, adjust credit, restart timers, or release current-generation bytes.

Normative views:
[`memory pressure`](../diagrams/TASK-260715-1pn983_memory-pressure-state.puml)
and [`reconnect/rekey`](../diagrams/TASK-260715-1pn983_reconnect-rekey-state.puml).

## Metrics, evidence, and privacy

Every metric has a fixed unit, bounded labels, owner, availability state,
monotonic time, generation, and current/peak meaning. Required families cover:

- footprint/peak and fresh advisory bytes;
- ledger current/reserved/committed/headroom/peak by fixed consumer;
- packet buffers/queues/drops and HEV tasks/sessions/buffers/caches/queues;
- lanes/channels/window cap/reservation/wire-credit report, adjustments,
  read buffers, pending writes/operations;
- DNS owners/buffers/cache/queue/aggregate/slack/refusals;
- client relay associations/frame/queue/control reservations and drops;
- KEX reservation/triggers/active generation/duration/result;
- reconnect old/new reservation, overlap peak, release order, denial/stop;
- action request/ack/timeout/failure/released bytes and transitions;
- tasks/timers/sockets/descriptors and cleanup reconciliation.

Labels are fixed enums: consumer, lane role, channel class, pressure state,
action ordinal, availability, typed reason. Never capture payload, DNS name,
destination, full address, username, host, fingerprint, credential reference,
command/stdin, path, or stable device ID. Restricted packet/Instruments evidence
follows the M3 custody protocol and is never a board attachment. Unavailable is
never pass.

## Required invariant and negative tests

Tests drive production entry points, not helpers preloaded with valid inputs.
Each gate is proved by narrowing a bound or bypassing one lifecycle branch.

| Invariant | Negative proof | Production boundary / owner |
| --- | --- | --- |
| Global reservation | One-byte-smaller global/component ceiling under concurrent admission refuses exactly one owner | ledger entry used by channel/DNS/relay/lane/reconnect; pressure/fault tasks |
| Untracked reservation cannot be spent | With existing owner charges plus `B_untracked` at the ceiling, narrow remaining headroom by one; channel, lane, reconnect, and pressure paths all refuse/escalate through their production entry points | ledger bootstrap and each real admission/controller entry; pressure/fault tasks |
| Total-capacity vs incremental reservation | Hold nonzero current bytes, then propose a larger total envelope and separately an incremental owner; candidate delta charges the former once and the latter in full, with one-byte narrowing refusal | atomic ledger replace/new-owner entries; pressure/fault tasks |
| DNS equality/one-over | `7,635,554` fits `8,388,608`; add one to any term or shrink aggregate by one and publication fails | DNS composition; DNS/fault owners |
| Credit not allocation/reclaim | Stall consumer and spend prior credit; no eager-allocation claim, false reclaim, or Pressure adjustment passes | real adapter open/read path; window/M3 owners |
| No side queue | Narrow queue bytes/count under flood; bounded refusal/drop and no second queue | actual channel/packet/relay enqueue; fault owner |
| State/hysteresis | Equality and one-under/over for every edge; stale/unavailable cannot recover | provider observation; sampler owner |
| Fresh advisory call | Second read fails after high first value; production observation reports failure, not reuse | platform sampler; sampler owner |
| Ordered actions | Fail/timeout each ordinal; later success cannot launder missing release | pressure executor; pressure owner |
| Reconnect overlap | Narrow replacement by one on normal/retry/resume/recovery/critical paths; all refuse or release old first | replacement constructor; pressure owner |
| Lane admission | Independently narrow lane count, base, KEX, mandatory lane-A slice, and global headroom by one; stale/closing/Soft optional construction also fast-refuses and failed construction returns the ledger to baseline | serialized lane-pool admission entry; lane/pressure/fault owners |
| KEX serialization | Race all triggers/channel open/Pressure/close/stop; one current KEX, no new channel | per-lane trigger/event entry; coordinator |
| Rekey isolation | Inject each adapter failure; affected lane first, close once, no replay/migration | lane KEX completion; isolation owner |
| Forged/stale evidence | Correctly shaped stale reservation/action/KEX/reconnect ack cannot release/publish current state | serialized owners; fault task |
| Cancel/stop cleanup | Cancel every seam and deliver late callbacks; all ownership returns baseline | provider stop/component teardown; fault task |
| Privacy | Prohibited sentinels at every source appear nowhere in composed export | diagnostics export, not formatter helper; instrumentation |

## M0–M3 ownership and interface map

| Surface | Required contract | Owner |
| --- | --- | --- |
| M0 packet/HEV | effective socket read-back, accepted 500/24,576/4,096/2 baseline, bounded queues, unavailable internal gauges, cleanup | accepted `TASK-260715-2jatnd`; pressure integration |
| M0 SSH | 32/64 KiB injectable windows, bounded M0 read/write/call/pending operations, client rekey, deferred reports | accepted `TASK-260715-1gjxer`; window/rekey tasks |
| M1 DNS/TCP | complete component reservation, exact formulas, one manager generation, bounded retire, no physical fallback | DNS owner; candidate pending physical composition |
| M2 relay/UDP | client queues in extension ledger; remote observed separately; 1,472-byte bound and typed drops | relay/pressure owners |
| M3 exact SSH | consumer-earned immutable credit and deep KEX/window reports or evidenced red | `TASK-260728-3cveay` |
| M3 controller/faults | fresh sampling, hysteresis, actions, overlap, invariant/negative/allocation tests | `TASK-260715-3kjhkw`, `TASK-260715-318m1v`, `TASK-260715-200jez` |
| M3 tuning/physical | select final numeric values only from valid paired/physical rows; retain rejected candidates/cleanup | tuning, physical soak, final-matrix owners |

## Decomposition, traceability, and gap record

The existing eight-task Story is the smallest complete decomposition. No new
research task is justified: numeric winners already belong to tuning/physical
tasks, while ownership/formulas are settled from accepted evidence.

| Story child | Atomic deliverable | Spec trace / dependency reason |
| --- | --- | --- |
| `TASK-260715-1pn983` | this ledger/policy contract | ADR-009; packet memory; SSH windows/rekey; routing reconnect; validation memory |
| `TASK-260715-3kimon` | pure window/reservation policy | SSH Channel windows; blocked by this contract |
| `TASK-260715-3kjhkw` | fresh sampler/state machine | packet uncached advisory and pressure order; blocked by contract |
| `TASK-260715-s3at1l` | per-lane automatic KEX | SSH Rekey; selected SSH/lane prerequisites |
| `TASK-260715-3j3luy` | lane-local KEX failure/recovery | SSH failure semantics; blocked by coordinator/lane recovery |
| `TASK-260715-318m1v` | actions/reconnect reservation executor | packet Critical plus routing overlap; consumer prerequisites |
| `TASK-260715-200jez` | invariant/negative/race/allocation suite | validation packet/SSH/memory and M3 resource gates; integration prerequisites |
| `TASK-260728-3cveay` | four deferred exact SSH semantics | ADR-023/conformance registry; selected engine/window prerequisite |

Beyond-literal-spec gap record:

| Gap | Added binding | Spec/out-of-scope checks |
| --- | --- | --- |
| No stale/unavailable recovery rule | typed failed/stale advisory, never cache/zero, cannot recover | packet/validation/M3 checked; no Apple guarantee/private API/final threshold |
| Rekey overlap unassigned | per-lane emergency reserve, one KEX, bounded reason bitset | SSH/conformance/engine checked; no algorithm/threshold winner or fork |
| Reconnect budget lacks atomic order | reserve before construction; Critical old-to-zero first; else stop | routing/pressure checked; no migration/replay/route/retry widening |
| Relay attribution implicit | client memory charged locally, remote observed separately | ADR-021 checked; no framing/wire/cap change |
| DNS lacks ADR-009 residual assignment | assign 8 MiB hard candidate but retain provisional authority | equations, SSH evidence, HEV peak, physical gates checked; no production promotion |

## Release and revalidation gates

Production remains refused until complete physical composition, exact or
conservative owner evidence, pressure/one-over/order/cleanup/privacy negative
tests, M3 numeric selection including `B_untracked`, and independent review all
pass. Re-run after any device/OS/toolchain/native pin, allocator, limit, queue,
window, lane, KEX, DNS/relay, reconnect, metrics, or provider lifecycle change.
A red row reopens its owner; it is never averaged away or repaired by weakening
a safety gate.
