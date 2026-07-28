# M3 performance measurement and evidence protocol v1

Status: binding pre-registration for `TASK-260715-2kchi0`; benchmark results and
production tuning selections are not part of this document.

## 1. Authority, scope, and execution eligibility

This protocol is the reproducibility contract for M3 benchmark, failure,
resource, and physical evidence. It consumes `.spec/goal-macos-v1.md`,
`.spec/validation.md`, `.spec/delivery.md`, ADR-003/005/008–012/015/020–022,
the current SPM harness boundary, and accepted packet/HEV/relay/DNS contracts.

The current autonomous target is macOS-first:

- `mac-primary-01` is the mandatory named Apple-silicon baseline slot. A run
  binds the alias to model identifier, chip, installed RAM, OS version/build,
  and provider/harness mode without recording a serial number or hardware UUID.
- `mac-minimum-01` is a second slot when the minimum supported macOS cannot be
  exercised on `mac-primary-01`. If absent, every affected row is `unavailable`,
  never inferred from the primary Mac.
- `iphone-primary-01` and `iphone-constrained-01` are schema-compatible deferred
  physical slots. Their rows remain `unavailable` with reason
  `deferred-iphone-physical` until an authorized physical-provider run is
  scheduled. iPhone execution is not a prerequisite for producing or reviewing
  this protocol.

Every run declares one execution class:

1. `harness-controlled`: SPM harness plus owned local/remote fixtures;
2. `mac-provider-physical`: signed provider on a named physical Mac;
3. `iphone-provider-physical`: deferred signed provider on a named iPhone;
4. `analysis-only`: comparison of already captured valid rows.

Harness results cannot satisfy provider-only route, Network Extension, sleep,
captive, physical footprint, or energy gates. Simulator results cannot satisfy
physical rows. A missing capability is recorded as unavailable with an owner.

### 1.1 Current authority state

- HEV/lwIP pin and unmodified-upstream boundary: accepted
  `TASK-260715-uopycx`; integration and ADR-020 injectable baseline: accepted
  `TASK-260715-1vv52g`.
- Relay v1 layout, compatibility, and local-cap model: accepted
  `TASK-260715-2z9b4a` and ADR-021. `maxUDPPayload=1472` is a fixed v1
  compatibility constant; association/queue/idle values remain injectable M3
  candidates within their accepted floors and ceilings.
- Exit DNS identity/failover semantics: accepted `TASK-260715-1tnjlu`.
  `TASK-260721-3miqh4` values are controlled-measurement candidates only;
  `productionAuthorization.permitted` remains false.
- Production SSH engine and its controlled `direct-tcpip` rows are unavailable
  until `TASK-260715-1gjxer` is accepted.
- The residual cross-layer DNS component budget is unavailable until
  `TASK-260715-1pn983` is accepted.
- ADR-015 MTU, final lane/window/rekey/QUIC/reconnect/memory values, and any HEV
  fork remain evidence gates. This protocol never promotes a candidate.

Rows that depend on unavailable authorities may be captured as explicitly
`provisional` engineering evidence, but cannot be `production-pass`.

## 2. Immutable run identity and payload generation

Every executed row has:

```text
runID = "m3v1-" + lowerHex(SHA256(canonicalRowConfigJSON))[0..<24]
repetitionID = runID + "-r" + twoDigit(repetitionIndex)
```

`canonicalRowConfigJSON` is RFC 8785 JCS UTF-8 serialization of exactly this
projection, with the property names and nested values copied without coercion:

```text
{
  schemaVersion,
  protocol: {taskID, revision, documentSHA256, schemaSHA256},
  identity: {
    rowID, repetitionIndex, seed, matrixID, workloadID, executionClass,
    pairRole, baselineRunID, candidateID
  },
  authority,
  device, environment, toolchain, revisions, server, algorithms, profile,
  policies, parameters, traffic, impairment, schedule
}
```

No other field participates. In particular `runID`,
`canonicalRowConfigSHA256`, `repetitionID`, status, timestamps, metrics,
counters, gates, artifacts, privacy, and review are excluded. Every numeric
configuration token is a plain base-10 schema-v1 integer in its named unit,
matches `0|-?[1-9][0-9]*`, and lies inclusively between
`-9007199254740991` and `9007199254740991`. Floats, decimal or exponent
notation (even when mathematically integral), NaN, infinities, negative zero,
unsafe integers, duplicate object keys, string-to-number coercion, and omitted
required fields are invalid. Lexical/domain validation occurs before hashing;
JSON Schema integer acceptance alone is insufficient. A jq-equivalent
canonicalizer may be used only after this closed domain is proved and its exact
no-trailing-byte output is checked against an independent strict serializer;
otherwise a true RFC 8785 implementation is required.
`canonicalRowConfigSHA256` is the lower-case SHA-256 of the serialized bytes,
and `runID` uses its first 24 lower-case hex digits. A rerun with any projected
field changed receives a new run ID.

`rowID` is `M3V1-<workloadID>-<twoDigitRowOrdinal>`; the ordinal is assigned in
the immutable matrix catalog before execution and is `01` through `99`.
`repetitionID` is the exact `runID`, `-r`, and a zero-padded two-digit
`repetitionIndex` (`100` is written as three digits). A candidate must carry
the baseline run ID for the same device, row catalog entry, seed, impairment,
and execution block. Baselines have unavailable `baselineRunID` and
`candidateID`; unpaired failure/lifecycle rows declare `pairRole=unpaired`.

The fixed repetition seeds are decimal:

```text
104729, 130363, 155921, 196613, 262147,
327673, 393241, 524309, 786433, 1048583
```

Long physical energy/idle rows use the first five seeds; all other performance
rows use all ten. Fault/lifecycle rows use all ten unless the catalog specifies
100 cycles. Candidate and baseline use the same seeds and are executed as
paired blocks. Odd repetition indexes run baseline/candidate and even indexes
run candidate/baseline. No seed is replaced after results are known.

Payload bytes are generated without user traffic:

```text
block(j) = SHA256(
  UTF8("relux-m3-payload-v1\0") ||
  UInt64BE(seed) || UInt32BE(generatorIDLength) || UTF8(generatorID) ||
  UInt64BE(flowIndex) || UInt64BE(j)
)
```

Blocks are concatenated and truncated to the declared payload length. The
source and sink independently compute SHA-256 over the complete logical byte
stream. A TCP/exec/relay run passes integrity only when byte count and digest
match in both directions. UDP rows also compare sequence, payload length,
digest, duplicate, late, and loss counts. DNS rows validate framing, ID/question
correlation, expected RCODE/answer semantics, terminal result count, attempt
count, and cleanup rather than treating a transport byte hash alone as proof.

## 3. Controlled fixtures and workload catalog

All network peers are owned fixtures named in the manifest. No public website,
public resolver, production profile, or public-user traffic is permitted.
Fixture binaries/images, configs, and generated corpora are revision/hash
pinned. The future command surface owned by `TASK-260715-1ok93q` is:

```text
swift run ReluxTunnelHarness benchmark --configuration <row.json>
swift run ReluxTunnelHarness validate-evidence --bundle <bundle-directory>
```

The current harness exposes only `smoke`; these commands are protocol targets,
not claims about current implementation.

| ID | Exact generator and traffic shape | Integrity/semantic check |
| --- | --- | --- |
| `WEB16` | 16 closed-loop clients. Each opens a new TCP connection, sends one deterministic HTTP/1.1 GET, receives a 64 KiB body, closes cleanly, then waits `20 + seed mod 181` ms. Continue for the steady interval. | Status/length plus per-response SHA-256; record connect, request-written, first-byte, last-byte, and close times. |
| `BULK-DL` | One connection continuously downloads deterministic 1 MiB chunks for 300 s. | Total byte count and stream SHA-256. |
| `BULK-UL` | One connection continuously uploads deterministic 1 MiB chunks for 300 s; fixture returns final count/hash. | Source and fixture count/hash equality. |
| `BULK-BI` | One full-duplex connection runs `BULK-DL` and `BULK-UL` concurrently for 300 s. | Independent directional count/hash equality and half-close result. |
| `IDLE-N` | Open N idle TCP flows; send one 1-byte liveness marker every 60 s; hold 900 s. | Exact open/close count, marker sequence, no unrequested data, cleanup. |
| `DNS16` | 16 logical clients issue controlled queries at aggregate 20 qps for 180 s. Corpus cycles A, AAAA, NXDOMAIN, 512-byte, TC=1, maximum 65,535-byte TCP message, one-under, and one-over-rejected cases against synthetic `qNNNN.m3.invalid.` names. Names are not emitted in retained diagnostics; the corpus hash is recorded. | Expected response/RCODE, one terminal result, exact M1/M2 attempts, timing, tombstone/late/duplicate counters, zero physical-resolver sentinel calls. |
| `UDP-BURST` | Deterministic payload sizes 64, 512, 1200, and 1472 bytes. During a 180 s row, send 10 s bursts at 100, 1,000, and 10,000 datagrams/s at seconds 30, 80, and 130; record actual applied rate. | Per-datagram sequence/length/hash; sent, received, duplicate, late, reorder, and reason-specific drop counts. |
| `MIXED` | Concurrent `BULK-DL`, `BULK-UL`, `WEB16`, `DNS16`, UDP 1200-byte traffic at 100 datagrams/s, and 100 `IDLE-N` flows. | All component checks plus aggregate reconciliation. |
| `SCALE-N` | N is 100, 250, 500, or injected configuration limit. Flow index modulo 20 assigns 0–13 idle TCP, 14–17 web-like TCP, 18 bulk TCP, 19 UDP association; DNS continues at 20 qps. Admission stops at the first declared ceiling and records the exact refusal. | Intended/admitted/active/closed flows, channel/session/association counts, all hashes, bounded refusal, cleanup. |
| `REKEY5G` | `MIXED` plus enough deterministic bulk traffic to transfer at least 5 GiB while exercising byte-triggered, time-triggered, server-requested, and simultaneous active direct/exec traffic rekeys. | Directional hashes, exact rekey start/end/generation, no channel migration, corruption, deadlock, or leak. |

DNS selected-SSH footprint rows are mandatory when the engine exists:

- `DNS-START-E1/E4/E8`: fresh provider/harness generation, 1/4/8 configured
  synthetic endpoints, cold selected-SSH session; record profile-load through M1
  DNS-ready and stop through zero ownership.
- `DNS-OPEN-COLD`: open a new `direct-tcpip` DNS channel on an authenticated
  selected-SSH session.
- `DNS-REUSE-WARM`: reuse the current endpoint connection for `DNS16`.
- `DNS-RETIRE`: idle close, cancellation, TCP EOF, framing error, timeout,
  promotion, late callback, and stop; record footprint before, peak, after, exact
  attempts, buffers, owners, descriptors, tasks, and zero cleanup.

Candidate endpoint counts/timings from `TASK-260721-3miqh4` may populate these
controlled rows, but remain non-authoritative until selected-SSH, ADR-009
residual-budget, physical startup/footprint, and independent review gates pass.

## 4. Impairment catalog

Impairment applies symmetrically at the controlled access-to-SSH fixture link,
not at a public interface. Delay values are added one-way. Loss is independent
per packet from the row seed. The harness records intended and observed values
from a 30 s preflight probe and fails setup if median RTT differs by more than
10 ms or observed loss by more than 0.25 percentage points from the configured
profile (blackhole excepted).

| ID | Added one-way delay | Jitter | Loss | Rate/queue | Use |
| --- | ---: | ---: | ---: | --- | --- |
| `I0-CLEAN` | 0 ms | 0 ms | 0% | no added limit | Reference and correctness |
| `I1-WIFI-GOOD` | 15 ms | deterministic uniform ±3 ms | 0.1% | no added limit | Representative access path |
| `I2-WIFI-POOR` | 50 ms | deterministic uniform ±10 ms | 1.0% | no added limit | HoL/retry behavior |
| `I3-SEVERE` | 100 ms | deterministic uniform ±20 ms | 3.0% | no added limit | Bounded resilience, not nominal-drop gate |
| `I4-CONGESTED` | 15 ms | deterministic uniform ±3 ms | 0.1% | 10 Mbit/s, 64 KiB FIFO | Queue/window/lane behavior |
| `I5-BLACKHOLE` | unchanged | unchanged | 100% during declared fault window | unchanged | Retry/failure/stop only |

The impairment adapter must restore its pre-run state during normal completion,
setup failure, cancellation, and process termination. A row records adapter,
host, config, start/end snapshots, and cleanup proof.

### 4.1 Deterministic impairment stream

The named PRNG is `SplitMix64-v1`, using unsigned 64-bit arithmetic modulo
`2^64`:

```text
state = state + 0x9E3779B97F4A7C15
z = state
z = (z xor (z >> 30)) * 0xBF58476D1CE4E5B9
z = (z xor (z >> 27)) * 0x94D049BB133111EB
output = z xor (z >> 31)
```

Each independent stream starts from the unsigned big-endian value of the first
eight bytes of:

```text
SHA256(
  UTF8("relux-m3-stream-v1\0") || UInt64BE(seed) ||
  UInt32BE(rowIDLength) || UTF8(rowID) ||
  UInt32BE(directionLength) || UTF8(direction) ||
  UInt32BE(streamNameLength) || UTF8(streamName)
)
```

`direction` is `uplink` or `downlink`; impairment `streamName` is `loss` or
`jitter`. Packets are numbered independently per direction at the controlled
shaper ingress, after the generator's segmentation/datagram formation and
before delay, loss, rate, or queue handling. The atomic adapter-enqueue order is
the packet order; its sequence number is retained. Each packet consumes one
loss output and at least one jitter output even when the profile value is zero
or the packet is later dropped, so changing one decision cannot shift the other
stream.

For loss probability `numerator/denominator`, drop when
`output < floor(numerator * 2^64 / denominator)`; zero never drops and 100%
always drops. The exact v1 fractions are 0/1, 1/1000, 1/100, 3/100, and 1/1.
For integer jitter range `[-J,+J]` nanoseconds, let `span=2J+1` and
`limit=floor(2^64/span)*span`; reject outputs `>=limit`, draw again from the
jitter stream, and otherwise use `(output mod span)-J`. Rate and FIFO queue
limits are deterministic adapter settings, not random draws. The packet trace
records direction, sequence, both accepted PRNG outputs, loss decision, jitter,
enqueue/dequeue time, and reason-specific drop.

## 5. Schedule, repetitions, sampling, and environment control

| Family | Warmup | Steady/fault schedule | Cooldown | Repetitions |
| --- | ---: | --- | ---: | ---: |
| WEB/DNS/UDP latency | 30 s | 180 s | 30 s | 10 |
| BULK/MIXED/throughput | 60 s | 300 s | 60 s | 10 |
| IDLE | 60 s | 900 s | 120 s | 5 |
| SCALE | 60 s before first stage | 180 s at 100, 250, 500, and injected limit; 60 s between stages | 120 s | 5 |
| Failure/recovery | 30 s healthy | fault at t=60 s; observe through t=300 s or terminal cleanup | 120 s | 10 |
| Energy | 120 s | 600 s | 180 s | 5 |
| Lifecycle | no aggregate warmup | 100 start/stop cycles; cancellation at each declared startup seam at least 10 times | 10 min final cleanup observation | 1 matrix |

`REKEY5G` uses 60 s warmup, then runs until at least 5 GiB and every declared
rekey trigger completes or a fixed two-hour steady cap expires, followed by
120 s cooldown, for five repetitions. Reaching the cap without 5 GiB or a
required trigger is red, not an exclusion.

For failure rows, fault time is measured from steady-state start. If a
contract-defined timeout is longer than the table, the row duration is the
declared timeout plus 120 s; it is never shortened after seeing a result.

Sampling rules:

- UTC timestamps: RFC 3339 with nanoseconds at row start/end and each lifecycle
  event; monotonic timestamps: continuous-clock nanoseconds from run start.
- Counters/events: lossless aggregate event accounting with bounded storage;
  overflow/coalescing is itself a red counter.
- Memory footprint, peak, advisory available memory, CPU, task/descriptor/socket
  counts, queues/windows/sessions/channels/associations: 1 Hz.
- Packet, byte, syscall, wakeup, and drop rates: monotonic counters sampled at
  1 Hz and stored as interval deltas.
- RTT: every 1 s per lane; TTFB/DNS/failure latency: per operation, summarized
  per repetition as simultaneous median, p95, and p99 integer nanoseconds. A
  single closed unavailable object makes the complete triplet unavailable; an
  available row may not omit or substitute any member of the triplet.
- Energy: Instruments Energy Log or the accepted platform collector at 1 Hz;
  collector/tool/version and unavailable fields are explicit.
- Instruments Time Profiler/Allocations/System Trace: one untuned reference and
  one candidate trace per workload/parameter family, after normal repetitions;
  tracing rows are analyzed separately and never substituted for low-overhead
  performance rows.

Before every repetition the operator/harness verifies and records:

1. same named device, power source, battery percentage, thermal state, display
   state, OS build, toolchain, source/dependency revisions, server/fixture pins,
   profile snapshot hash, and parameter-set hash;
2. no software update, indexing, backup, unrelated build, VPN, proxy, packet
   capture, or user workload; five minutes of idle settling before the first
   row and after a serious/critical thermal state;
3. fixed physical interface and controlled server path, except rows whose event
   is an interface/path change;
4. at least 20% free disk, no memory pressure for nominal rows, and current
   memory-ledger authority state;
5. time synchronization status; statistics use monotonic time even if wall time
   changes;
6. clean fixture sentinels, zero pre-run live owners, and the declared route/DNS
   baseline.

A thermal serious/critical transition, unrelated system interruption, fixture
crash, failed impairment preflight, collector overflow, or missing required raw
artifact invalidates the repetition. It is preserved as `invalid-environment`
with evidence. Product corruption, timeout, crash, leak, route/DNS fallback,
queue overflow, or cleanup failure is never an environmental exclusion.

## 6. Pre-registered candidate matrices

All values are injected and recorded. Candidate enumeration does not authorize
production defaults.

### 6.1 Parameter axes

- MTU: 1500, 4096, 8500.
- HEV baseline: UDP-in-TCP fixed; requested task stack 24,576; TCP buffer 4,096;
  max sessions 1,200; `udp-copy-buffer-nums=2`; record requested and effective
  values plus every cache/session/queue limit.
- Socket buffers: requested and Darwin-effective send/receive bytes.
- Packet bridge: batch-count and time budgets, maximum datagram, queue limits.
- Lanes: 1, 2, 4; roles and optional admissions recorded.
- Windows: 32 KiB, 64 KiB, and capped BDP; record formula inputs, cap, advertised
  credit, pending writes, and global reservation.
- Rekey: injected byte/time thresholds plus forced client/server triggers.
- Relay: fixed v1 constants plus all injected local caps and effective values.
- QUIC: Allow, Block UDP/443, Auto; Auto thresholds/hysteresis remain injected.
- Routes: Compatible and supported platform-scoped Fail-closed.
- Reconnect: injected attempt bounds, initial delay, multiplier, cap, jitter,
  stable reset, event coalescing, timeouts, old/new overlap.
- Memory: ledger revision, component ceilings, soft/pressure/critical/recovery
  watermarks, hysteresis, sampling cadence, action deadlines.
- DNS: policy artifact hash, authority/authorization state, endpoints, message,
  owner/queue/aggregate budgets, and all timing values; no profile-owned default.

### 6.2 Required matrix sets

- `M-REF`: every workload in section 3 at the current untuned parameter set
  under `I0`, `I2`, and `I4` where applicable.
- `M-PACKET`: each MTU with WEB16, BULK-BI, UDP-BURST, and MIXED under `I0` and
  `I2`; socket/batch/HEV candidates vary one factor at a time. Interaction
  corners additionally cross MTU 1500/8500 with minimum/maximum admitted
  buffer/batch candidates.
- `M-LANE`: lanes 1/2/4 × windows 32/64 KiB/capped-BDP with MIXED under `I0`,
  `I2`, and `I4`; each lane count also runs WEB16, DNS16, and BULK-BI. General
  and lane-A loss run under `I5`.
- `M-SCALE`: SCALE-100/250/500/configuration-limit under `I0` and `I2`, stopping
  at the predeclared ledger/admission ceiling without changing it mid-row.
- `M-REKEY`: REKEY5G for byte/time/server triggers under lanes 1/2/4 and 32/64
  KiB/capped-BDP windows; at least one `I2` row per trigger.
- `M-DNS`: DNS16 plus every DNS selected-SSH startup/open/reuse/retire row in
  section 3 for full/degraded modes and both endpoint family orders; all
  `TASK-260721-3miqh4` reliability triggers retain exact structural counts.
- `M-ROUTE-QUIC`: Allow/Block/Auto × full/degraded/reasserting/failed/stopping ×
  compatible/supported-fail-closed for controlled UDP/443, TCP fallback,
  unrelated UDP, and DNS sentinels; unsupported combinations are unavailable.
- `M-LIFECYCLE`: clean start/stop, cancellation seams, relay/DNS/lane/server
  loss, path change, endpoint replacement, NAT64/family change, sleep/wake,
  captive, app termination, memory pressure, and repeated cleanup.
- `M-FINAL`: locked accepted or explicitly provisional configuration repeats
  M-REF, every safety/failure row, and named physical support rows without
  parameter changes.

## 7. Required row and evidence schema

The machine contract is
`.research/fixtures/TASK-260715-2kchi0_m3-evidence-manifest-v1.schema.json`.
Every row records, at minimum:

- identity/status: schema/protocol revision, row/run/repetition IDs, matrix and
  workload IDs, seed, baseline/candidate pairing, execution class, pass/red/
  unavailable/invalid status, reason and owner;
- device/environment: alias, platform, model identifier, chip/architecture,
  installed memory, OS version/build, power/battery/thermal/display state,
  interface/family, provider/harness build and entitlements/provisioning class;
- provenance: Xcode/Swift/clang/Instruments and shaping-tool versions; git
  commit/tree-dirty flag; Package.resolved/native/HEV/SSH/relay/schema/vector
  revisions and hashes; fixture/server image/config/algorithm/host-key-set IDs;
- policy/config: redacted profile snapshot hash, capability, route/QUIC/DNS
  policy and authority state, and every MTU/HEV/socket/batch/lane/window/rekey/
  relay/reconnect/memory value including requested/effective values;
- traffic/schedule: generator/corpus/payload hashes, directions, payload sizes,
  rate, concurrency, intended/admitted flows, impairment intended/observed,
  warmup/steady/fault/cooldown, repetitions, clocks and timestamps;
- metrics/counters: throughput, TTFB, DNS latency, RTT, outage/failure latency,
  CPU, energy, footprint/peak/available memory, packets/bytes/syscalls/wakeups,
  lanes/channels/windows/rekeys/sessions/associations/owners/queues/drops/errors,
  routes/settings/generations, descriptors/tasks/timers/sockets and cleanup;
- evidence/privacy: content-addressed artifact references with SHA-256, bytes,
  producer/tool, capture authorization, privacy class, redaction action,
  retention/custodian, and manifest hash/sign-off;
- decisions: integrity/safety gates, exclusion evaluation, statistical summary,
  comparison result, production-authority state, reviewer and accepted update
  references.

Every object in schema v1 is closed and versioned; device, environment,
toolchain, revisions, server, algorithms, policy, parameter, traffic,
impairment, schedule, metric, counter, artifact, privacy, authority, and review
fields cannot be replaced by generic maps. Every required metric and counter is
present with its fixed unit, or as
`{available:false, reasonCode, reason, ownerTaskID}`. Unavailable values are
never omitted, zeroed, or guessed. Selected-SSH DNS parameters include endpoint,
message, live-owner, queued-wire, aggregate, every timeout, idle-close, and the
65,537-byte length-prefixed connection buffer, with equality accepted and
one-over rejected at the controlled hard envelope.

The row also carries one closed `comparison` value. A baseline, unpaired, or
not-yet-compared row carries the standard explicit unavailable object. An
available comparison is `comparisonResultVersion=1` and contains the stable
comparison group, closed parameter-family and candidate-set projection, every
paired baseline/candidate run and logical sample reference, exact multiplicity
inputs, interval ranks, safety status, and all sixteen named metric-family
results. Each named metric is either a fixed-unit comparison result or an
explicit unavailable object; production authorization requires every named
metric result to be available.

Schema proof fixtures are:

- `TASK-260715-2kchi0_valid-pass.json`;
- `TASK-260715-2kchi0_equality-boundary-valid.overlay.json`;
- `TASK-260715-2kchi0_one-over-invalid.overlay.json`;
- `TASK-260715-2kchi0_hostile-invalid.overlay.json`;
- `TASK-260715-2kchi0_multi-repetition-valid.overlay.json`;
- `TASK-260715-2kchi0_m3-valid.overlay.json`;
- `TASK-260715-2kchi0_production-authorized-m3-valid.overlay.json`;
- `TASK-260715-2kchi0_missing-review-statistics-invalid.overlay.json`;
- `TASK-260715-2kchi0_unavailable-measured-pass-invalid.overlay.json`;
- `TASK-260715-2kchi0_invalid-environment-measured-pass-invalid.overlay.json`;
- `TASK-260715-2kchi0_fixture-expectations.md`.

Ordinary overlays are recursively merged onto the valid fixture with
`jq -s '.[0] * .[1]'`. The expectations document gives the exact tagged-union
replacement expression for the multi-repetition fixture; the m=3 and production
fixtures are intentionally composed after it. Valid/equality/multi/m=3/
production fixtures must validate; one-over and every hostile/status fixture
must fail. These are contract fixtures, not benchmark rows.

## 8. Statistics, noise, exclusions, and decision rules

Raw operation samples remain immutable. Each repetition first produces its
declared integer-unit summary; cross-repetition comparison is paired by device,
row, seed, impairment, and execution-order block. Missing pairs are not
discarded: the comparison is red-insufficient-precision unless the row is an
explicit preserved environmental invalidation with its permitted linked rerun.

### 8.1 Exact paired estimator and bootstrap

For each pair, let `b` and `c` be the baseline and candidate integers. For a
higher-is-better metric, favorable absolute effect `d=c-b`; for a
lower-is-better metric, `d=b-c`. When `b != 0`, favorable percent effect is:

```text
effectPPM = roundHalfAwayFromZero(1_000_000 * d / abs(b))
```

All intermediate products, sums, and comparisons use unbounded signed integers
and exact rational arithmetic. `roundHalfAwayFromZero(p/q)` rounds the absolute
quotient to the nearest integer, resolves an exact half upward, then restores
the sign. A zero baseline makes percent effect explicitly unavailable with
`reasonCode=zero-baseline`; a metric whose rule requires percent then cannot
pass and is `red-insufficient-precision`. JSON non-finite numbers, floating
inputs, overflow, saturation, and implementation-dependent rounding are errors.

The point estimate is the median paired effect. Sort integers ascending; for an
odd count choose the middle element, and for an even count apply the same
round-half-away rule to the exact mean of the two middle elements. Report MAD,
minimum, and maximum using that median rule. Per-operation latency p95/p99 uses
nearest-rank indices `ceil(0.95*n)-1` and `ceil(0.99*n)-1` after ascending sort.

For one metric/multiplicity group, sort the exact repetition IDs by their UTF-8
bytes. Initialize the independent `bootstrap` SplitMix64 stream from the first
eight SHA-256 bytes of:

```text
UTF8("relux-m3-bootstrap-v1\0") ||
UInt32BE(groupIDLength) || UTF8(groupID) ||
UInt32BE(metricNameLength) || UTF8(metricName) ||
UInt32BE(repetitionIDCount) ||
for each repetitionID: UInt32BE(length) || UTF8(repetitionID)
```

For each of exactly 10,000 replicates, draw `n` outputs and map each unsigned
output `u` to paired index `floor(u*n/2^64)`. Sample pairs with replacement and
recompute median favorable absolute and PPM effects. Streams are reset only at
the start of a metric/group; replicates and draws are consumed in increasing
index order.

`comparisonGroupID` is `"m3cmp-"` plus the first 24 lower-case hex digits of
the SHA-256 of RFC 8785 JCS for exactly this closed projection:

```text
{
  protocolRevision, deviceAlias, executionClass, matrixID, workloadID,
  impairmentID, parameterFamily,
  candidateSet: { baselineCandidateID, candidateIDs, parameterNames }
}
```

`parameterFamily` is exactly one of `mtu`, `hev-memory`, `socket-buffer`,
`packet-bridge`, `lane-window`, `rekey`, `relay`, `quic-route`, `reconnect`,
`memory-ledger`, `dns-runtime`, or `reference`. `candidateIDs` and
`parameterNames` are unique UTF-8 byte-order-sorted arrays. `parameterNames`
uses only the schema-v1 injectable names enumerated by the comparison schema.
For each candidate, `candidateID` is `"cand-"` plus the first 24 lower-case hex
digits of SHA-256 over RFC 8785 JCS for the object formed by copying exactly the
listed `parameterNames` and their values from the row's canonical parameter/
policy configuration; `baselineCandidateID` uses the same rule. The projection
deliberately excludes row/run/repetition IDs, seed,
`baselineRunID`, metric name, execution order, results, timestamps, and review
state, so the ID is constant across every paired seed/repetition and every
metric in one candidate family. `TASK-260721-2ohf99` recomputes the projection,
hash, sort order, and exact candidate membership; a mismatch is invalid.

`m` is the pre-registered count of unique candidate IDs in that group,
including red candidates; it is never reduced after results. Coverage is
serialized in lowest terms as exact integers
`coverage={numerator:20*m-1, denominator:20*m}`. With sorted bootstrap values
and `B=10000`, the inclusive zero-based interval-rank object is:

```text
lowerIndex = floor(B/(40*m))
upperIndex = ceil(B*(1-1/(40*m))) - 1
```

No interpolation or PPM coverage rounding is used. For `m=1`, coverage is
`19/20` and indices are 250 and 9749. For `m=3`, coverage is `59/60` and indices
are 83 and 9916. The same resampled index vector is used for a metric's absolute
and PPM axes.

### 8.2 Closed comparison result and classification record

An available comparison result contains these exact structures:

1. `comparisonResultVersion=1`, the recomputable `comparisonGroupID`,
   `parameterFamily`, and the exact candidate-set projection above;
2. `pairedSamples`, sorted by repetition index, each with a unique pair ID,
   repetition index, seed, baseline and candidate run IDs, and bundle-relative
   baseline/candidate sample references;
3. `multiplicity` with `candidateCount=m`, `bootstrapCount=10000`, the exact
   coverage numerator/denominator, and exact lower/upper interval ranks;
4. all sixteen schema metric names. An available metric records its fixed unit,
   higher/lower-is-better direction, signed integer point absolute and PPM
   effects, signed integer absolute and PPM bootstrap bounds, the ordered pair
   IDs it consumed, classification, and `pass`/`red` safety status. A zero
   baseline uses the standard explicit unavailable object for each PPM field;
5. aggregate safety status. It is `pass` only when every row safety gate and
   every per-metric safety status is pass.

The row-level review repeats the stable comparison group, candidate count, and
exact coverage so authority can be checked without interpreting raw samples.
Production authorization requires an accepted review with a concrete reviewer
string and UTC review timestamp, an available row classification, stable group,
integer candidate count, exact coverage, at least one accepted-update lineage
reference, an available comparison result with all sixteen available metric
classifications, and every pre-existing safety/privacy/authority gate. Missing
or unavailable review/statistics fields make production authorization invalid.

Practical effect/regression boundaries are fixed for protocol v1:

| Metric family | Material improvement | Material regression |
| --- | --- | --- |
| Throughput/goodput | at least +5% | at most -5% |
| TTFB, DNS, RTT, outage/failure latency | at least 5% lower and 2 ms lower | at least 5% higher and 2 ms higher |
| CPU and energy | at least 5% lower | at least 5% higher |
| Physical footprint/peak | at least 5% and 1 MiB lower | at least 5% and 1 MiB higher, or any accepted ceiling breach |
| Packet/syscall/wakeup rate | at least 10% lower | at least 10% higher |
| Pressure drops/queue occupancy | at least 10% lower with unchanged offered load | at least 10% higher or any bound breach |

Classification uses inclusive equality for establishing improvement or
regression and strict inequality for ruling regression out:

1. any failed safety gate is `red-safety` before metric classification;
2. for a one-threshold metric, improvement is `lowerPPM >= improvementPPM`,
   regression is `upperPPM <= -regressionPPM`, insufficient precision is
   `lowerPPM <= -regressionPPM`, and the remaining case is neutral;
3. for latency and memory rules with percent plus absolute thresholds,
   improvement requires both lower bounds at or beyond both positive thresholds,
   regression requires both upper bounds at or beyond both negative thresholds,
   insufficient precision requires both lower bounds to reach the negative
   regression region, and the remaining case is neutral;
4. an accepted memory/queue/resource bound breach is `red-safety` regardless of
   the interval; queue/drop comparison requires byte-identical offered-load
   configuration.

Apply rules in that order, so established regression wins over overlapping
insufficient precision. `material-improvement` and `neutral-pass` require every
safety gate true. More samples require a new pre-registered revision; protocol
v1 never adds repetitions after inspecting results.

No automatic outlier deletion is allowed. A repetition may be excluded only
for a predeclared environmental invalidation in section 5. The original row,
raw references, reason, timestamps, and operator remain in the manifest. One
exact rerun with the same seed is permitted only when the invalidation occurred
before any product safety failure; both attempts remain linked. Failed setup,
crash, timeout, corrupt bytes, leaks, missing cleanup, and red results are never
silently dropped or averaged away.

## 9. Non-tradeable safety gates

Performance and energy can never compensate for any gate below:

1. **Byte/protocol correctness:** exact hashes/counts/semantics; zero corruption,
   unintended duplicate terminal result, or channel migration.
2. **DNS fail closed:** zero ordinary physical-resolver calls/sockets/packets in
   connected, degraded, reasserting, failed, stopping, fault, and cleanup rows.
3. **Route safety:** the SSH endpoint uses the declared physical path, only the
   current exact exclusion exists, no flow recursively re-enters the tunnel,
   and no ordinary application bypass occurs beyond a documented platform
   exception.
4. **Bounded resources:** every queue, owner, channel, session, association,
   window reservation, buffer, lane, retry, and reconnect overlap stays within
   its recorded accepted/provisional ledger. Collector overflow is red.
5. **Memory:** no accepted component/aggregate ceiling breach; ordered pressure
   actions occur; critical pressure releases old transport before replacement
   or stops explicitly; no success criterion relies on jetsam.
6. **Failure behavior:** terminal auth/host-key errors do not retry; transient
   retry, QUIC failure, cancellation, DNS exhaustion, lane/relay loss, and
   capability publication match the owning contract and deadline.
7. **Nominal drops:** `I0` non-saturated rows have zero ordinary unexplained
   packet/channel/DNS/relay drops. Induced pressure permits only declared
   reason-specific bounded drops/refusals.
8. **Cleanup:** exact live owners/sessions/lanes/channels/associations/routes/
   timers/tasks/sockets/descriptors return to their pre-run baseline. After the
   declared cooldown, physical footprint is no more than max(1 MiB, 5%) above
   pre-run baseline and the 100-cycle series has no positive monotonic resource
   trend. Any count leak is red even if footprint is noisy.

An executed row receives one primary status: `pass`, `red`, `unavailable`, or
`invalid-environment`. Legal reason/exclusion pairs are closed: `pass` requires
`measured-pass` and no exclusion; `red` requires `safety-failure`,
`statistical-regression`, or `insufficient-precision` and no exclusion;
`unavailable` requires one of the four `missing-*` reasons and no exclusion;
`invalid-environment` requires `environment-invalidation` and a permitted
environmental exclusion. `provisional` and `production-authorized` are separate
authority flags; they cannot convert red to pass.

## 10. Raw evidence, capture authorization, privacy, and retention

Before packet capture or Instruments collection, the operator records that the
device, access network, SSH host, resolver, and destination fixtures are owned
or expressly authorized and carry only generated traffic. Missing authorization
makes the row unavailable; it is not bypassed.

Artifact references are bundle-relative, content-addressed, and include SHA-256
and byte length. The manifest contains no absolute home path or account name.
Privacy classes are:

- `public-engineering`: schema, aggregate tables, synthetic configs, hashes;
- `internal-redacted`: privacy-scanned logs and summaries with no destinations,
  DNS names, full addresses, payloads, credentials, command stdin, or stable
  device identifiers;
- `restricted-local-raw`: authorized packet captures/Instruments `.trace` files
  retained by a named custodian outside board/git; the attached manifest stores
  a logical reference, hash, size, authorization, retention, and redacted
  derivative only;
- `prohibited`: private keys/passphrases, real payloads, public-user traffic,
  real DNS queries/destinations, providerConfiguration secrets, shell stdin, or
  unredacted stable identifiers. These are never collected or referenced.

Redaction is deterministic and versioned. It replaces fixture addresses, local
addresses, query names, profile IDs, paths, and account/device identifiers with
typed tokens while preserving family, event order, and aggregate cardinality.
The unredacted restricted file is never used as a board resource. Privacy scans
cover the bundle and archive member names/content before attachment.

Failed, red, invalid, and unavailable rows are retained beside passing rows.
Instruments traces record tool/template/version, time range, workload row,
device, hash, privacy class, custodian, and the exported aggregate call-tree or
allocation summary. A missing trace cannot be reconstructed or declared pass.

Every artifact uses a bundle-relative logical reference whose path segments
start with an alphanumeric character and contain only alphanumerics, `.`, `_`,
or `-`; absolute paths, drive prefixes, backslashes, empty segments, and `.` or
`..` traversal are invalid. Packet captures and Instruments traces require
row-level and artifact-level authorization, a task/role custodian, restricted
retention, `restricted-local-raw` classification, and a present redacted
derivative. The raw restricted file remains outside the attached bundle.

### 10.1 Required semantic validator rules

JSON Schema 2020-12 cannot express the following cross-field/filesystem rules.
`TASK-260721-2ohf99` is the sole implementation owner and must reject on any
failure:

1. build the exact section-2 projection, apply RFC 8785 JCS, recompute the two
   hashes and run/repetition IDs, and enforce row ordinal, pair, seed, family,
   repetition-count, execution-order, and baseline/candidate relationships;
2. require `utcEnd > utcStart`, `reviewedAtUTC >= utcEnd` when reviewed,
   monotonic end consistent with captured events, ordered fault windows, and no
   event outside the row interval;
3. enforce matrix/workload schedule values, `admittedFlows <= intendedFlows`,
   memory watermark ordering and ceiling containment, impairment profile values,
   preflight tolerance, and pre-state/restored-state equality;
4. resolve each logical reference beneath the bundle root without symlink or
   traversal escape; require unique references, on-disk existence where
   applicable, exact byte length/SHA-256, no unreferenced files, and capture/
   custodian/redaction/retention authorization consistency;
5. reconcile byte/DNS/route/resource/memory/drop/failure/cleanup gates with raw
   counters and required row-specific available metrics; a claimed pass with a
   missing required artifact/metric, nonzero fallback/loop/leak/overflow, or a
   false gate is red/rejected, never repaired;
6. rebuild the exact section-8 stable comparison projection; require byte-order
   sorted candidate/parameter arrays, candidate-count equality, one stable group
   across all paired seeds/repetitions/metrics, unique and ordered pair IDs,
   sample-reference ownership, and exact pair membership with no missing,
   duplicate, cross-group, or post-result-added candidate;
7. reproduce SplitMix64 impairment traces and the paired bootstrap, effect,
   multiplicity, quantile, equality-boundary, and classification rules exactly;
   verify signed point/bound values, `lower <= upper`, paired-sample ID lists,
   exact reduced coverage `(20*m-1)/(20*m)`, `bootstrapCount=10000`, and
   interval ranks for `m` (including m=3 indices 83/9916); reject non-finite,
   rounded-coverage, wrong-unit, wrong-direction, or unavailable-required values;
8. preserve duplicate, failed, red, invalid, unavailable, excluded, and rerun
   rows; enforce a single permitted rerun only for the declared environmental
   reasons and never after a product safety failure;
9. recompute `immutableManifestSHA256` as SHA-256 of RFC 8785 JCS for the
   complete row with only `review.immutableManifestSHA256` removed; verify
   immutable update parent hashes, concrete independent reviewer/time,
   comparison/result completeness, accepted-update lineage, accountable
   task/ADR links, effective date, rejected candidates, and rollback trigger
   before accepting any baseline/configuration update.

## 11. Configuration, threshold, and regression updates

Results never edit their originating protocol, baseline, raw artifact, or row.
An accepted update requires:

1. a new protocol/config revision and immutable parent hash;
2. accountable task/ADR ID, rationale, affected rows and devices;
3. before/after evidence under the same prior protocol plus the new protocol;
4. explicit rejected candidates and red rows;
5. updated regression baseline with effective date and rollback trigger;
6. independent review.

Threshold changes after viewing data do not apply retroactively. They require a
new evidence task and rerun. Unsupported device/network rows stay unavailable;
they are not filled from another platform. Release/marketing claims require a
separate accepted scope and cannot quote provisional engineering evidence.

## 12. Downstream traceability

Every listed task consumes the named row families and the full schema in
section 7. Contract tasks consume schema/field definitions; implementation
tasks must expose the events/counters required to execute the rows.

| Task | Required protocol coverage |
| --- | --- |
| `TASK-260715-3f9kv8` — Record the production lane-pool and scheduler contract | M-LANE/M-SCALE inputs, lane freshness/queues/RTT/admission/pinning/failure/cleanup fields. |
| `TASK-260715-3gj0ad` — Implement lane-pool lifecycle and same-host identity enforcement | M-LANE identity, lane-count, lifecycle, memory-admission and cleanup rows. |
| `TASK-260715-k6qq13` — Implement lane health, congestion, and admission signals | I0–I5 RTT/queue/window/freshness sampling and collector-overhead rows. |
| `TASK-260715-2px5ap` — Implement congestion-aware new-flow scheduling and immutable pinning | MIXED/SCALE deterministic assignment, starvation, capacity rejection, immutable pinning. |
| `TASK-260715-1cj49i` — Implement lane-local failure and control-lane recovery handoff | General/lane-A I5 faults, DNS/relay capability, no migration/fallback, cleanup. |
| `TASK-260715-1gz4r9` — Add lane-pool scheduler and failure-injection tests | Replay all lane/fault rows, seeds, counters, and exact failure outcomes. |
| `TASK-260715-1pn983` — Record the cross-layer memory, window, and rekey contract | Every parameter ledger field, DNS residual budget, ceilings, reservations, pressure actions. |
| `TASK-260715-3kimon` — Implement per-channel receive-window and budget policy | 32/64 KiB/capped-BDP M-LANE/M-SCALE/M-REKEY rows and reservation evidence. |
| `TASK-260715-3kjhkw` — Implement advisory memory sampling and watermark state control | 1 Hz footprint/peak/available-memory and pressure transition rows. |
| `TASK-260715-s3at1l` — Implement automatic byte, time, and server rekey coordination | REKEY5G triggers/generations/timings/hashes. |
| `TASK-260715-3j3luy` — Implement rekey lane isolation and bounded recovery | Active MIXED rekey/lane-failure rows and capability cleanup. |
| `TASK-260715-318m1v` — Enforce ordered pressure actions and reconnect-overlap reservations | SCALE/pressure/critical overlap, refusal, release-or-stop and ledger reconciliation. |
| `TASK-260715-200jez` — Add window, rekey, memory, and allocation-bound fault tests | Boundary/equality/one-over, stale callback, overflow, cleanup and REKEY5G replay. |
| `TASK-260715-1zikbu` — Record the reconnect state, generation, and ownership contract | Failure/lifecycle timestamps, retries, generations, routes, DNS, overlap and cleanup schema. |
| `TASK-260715-3e8l6b` — Implement normalized physical-path and viability event sources | Path event timestamps/source/currentness and unavailable platform fields. |
| `TASK-260715-2s8zr1` — Implement physical-interface endpoint retry and reconnect | Cached/fresh/actual endpoint and I5 retry/terminal/cancellation rows. |
| `TASK-260715-1j30es` — Implement the generation-safe reconnect and retry coordinator | Fault at t=60, bounded backoff, stale rejection, outage, capability and stop rows. |
| `TASK-260715-2lodgq` — Implement atomic SSH endpoint exclusion and settings replacement | Route snapshots/captures, exact exclusion, rollback and loop/fallback gates. |
| `TASK-260715-3ddzdd` — Integrate reasserting and leak-safe capability restoration | Full/degraded/reasserting/failure publication and traffic-sentinel rows. |
| `TASK-260715-2drjj5` — Add reconnect state, retry, route, DNS-leak, and cleanup tests | Deterministic M-LIFECYCLE fault/replay/leak/cleanup rows. |
| `TASK-260715-1je8v2` — Record the QUIC and route-mode policy contract | M-ROUTE-QUIC traffic/failure latency, platform support and exception fields. |
| `TASK-260715-1xsybm` — Implement validated compatible and fail-closed network settings | Mode/settings/exclusion/apply/rollback/unsupported rows. |
| `TASK-260715-2imxt0` — Implement the Auto QUIC lane-health evaluator | I0–I4 Auto inputs/freshness/hysteresis/reason and failure-latency rows. |
| `TASK-260715-3hxnbt` — Implement destination UDP/443 classification and bounded fast failure | Controlled UDP/443, unrelated UDP/DNS precedence and local-failure rows. |
| `TASK-260715-3425xv` — Integrate route-mode startup, change, reconnect, rollback, and stop | M-LIFECYCLE route-mode transitions and cleanup. |
| `TASK-260715-3gv53h` — Integrate Allow, Block, and Auto QUIC with capability generations | All policy × capability branches in M-ROUTE-QUIC. |
| `TASK-260715-pmg702` — Add QUIC, route-policy, rollback, and leak fault tests | Deterministic policy/mode/fault/sentinel/cleanup replay. |
| `TASK-260715-14u9bo` — Record the NAT64, sleep, captive, and lifecycle device matrix | Schema-compatible supported/unavailable physical row catalog. |
| `TASK-260715-330cst` — Implement NAT64 and endpoint-family transition hardening | Actual/synthesized endpoint/family/exclusion/traffic rows. |
| `TASK-260715-2bo0xl` — Implement sleep-wake reconnect coalescing and cancellation | Event coalescing, generations, overlap, outage and cleanup rows. |
| `TASK-260715-3rqfao` — Implement captive-network recovery state handling | Captive entry/exit, documented exceptions, no ordinary fallback and cleanup rows. |
| `TASK-260715-npvvmd` — Add NAT64, sleep, captive, app-termination, and lifecycle fault tests | Automated M-LIFECYCLE coverage and explicit physical deferrals. |
| `TASK-260715-1h2nc3` — Document the verified Apple platform exception and support matrix | Named device/OS available/red/unavailable evidence and capture references. |
| `TASK-260715-1r6k4t` — Implement unified bounded resource and performance instrumentation | Full metric/counter schema, units, sampling, overflow, privacy and overhead evidence. |
| `TASK-260721-2ohf99` — Implement the M3 evidence bundle validator and statistical reporter | Schema/authority/artifact/privacy/safety validation, deterministic paired statistics, immutable pass/red/unavailable/invalid reporting. |
| `TASK-260715-1ok93q` — Build the reproducible resilience benchmark and failure-injection harness | Every generator, seed, schedule, impairment, integrity check, fault trigger and evidence export. |
| `TASK-260715-38o3xg` — Tune packet bridge, HEV, MTU, buffer, batch, and memory parameters | M-PACKET/M-SCALE paired comparisons, safety gates and rejected candidates. |
| `TASK-260715-kblh3k` — Tune lane, window, rekey, and Auto QUIC parameters | M-LANE/M-REKEY/M-ROUTE-QUIC paired comparisons and regression gates. |
| `TASK-260715-2i7mld` — Tune reconnect, memory-watermark, overlap, retry, and energy parameters | M-LIFECYCLE/pressure/energy paired comparisons and terminal behavior. |
| `TASK-260715-3mnqn8` — Decide the HEV fork gate from Instruments evidence | Restricted trace manifest, call-tree/copy/syscall attribution, materiality rules. |
| `TASK-260715-yjpk5a` — Conditionally implement the approved minimal HEV callback-ingress fork | Same M-PACKET rows before/after, full safety gates and rollback trigger. |
| `TASK-260715-37eem9` — Run the physical multi-lane head-of-line and loss matrix | Named-device M-LANE under I0/I2/I4/I5, TTFB/DNS/throughput/resource/cleanup. |
| `TASK-260715-1k3wsk` — Run the physical rekey, memory-pressure, and soak matrix | Named-device REKEY5G/M-SCALE/pressure/overlap/energy evidence. |
| `TASK-260715-3hvz8n` — Run the physical Wi-Fi, cellular, loss, and endpoint reconnect matrix | Supported named-device path changes, I5, routes/DNS/outage/retry/cleanup. |
| `TASK-260715-gfptap` — Run the physical QUIC and route-safety matrix | Named-device M-ROUTE-QUIC captures, fast failure, exceptions, memory/energy. |
| `TASK-260715-1a1fwv` — Run the physical iPhone NAT64, sleep, captive, and lifecycle matrix | Deferred iPhone M-LIFECYCLE rows; unavailable until authorized hardware. |
| `TASK-260715-2wnw59` — Run the physical Mac IPv6, sleep, captive, and lifecycle matrix | Mandatory supported Mac M-LIFECYCLE rows and explicit unavailable gaps. |
| `TASK-260715-k5uxim` — Capture the untuned physical iPhone and Mac reference baselines | Immutable M-REF/M-PACKET/M-LANE/M-SCALE/M-DNS baseline; Mac first, iPhone deferred until available. |
| `TASK-260715-ixevcp` — Run and publish the final M3 resilience and performance acceptance matrix | M-FINAL, locked config, all pass/red/unavailable rows, regression baselines and raw manifest. |
| `TASK-260717-l639qp` — Ratify the M3 QUIC, route-mode, and reconnect policy contracts | Human ratification references only; no row may be relabeled or threshold changed. |

## 13. Completeness and open gates

The protocol covers workloads, impairments, concurrency, clocks, schedules,
statistics, practical effects, all requested metrics, raw evidence, capture
authorization, privacy, failure and cleanup, and every M3 implementation and
physical matrix task. The following are intentional gates, not missing guesses:

1. selected SSH engine plus controlled DNS `direct-tcpip` timing/footprint/
   cleanup evidence — `TASK-260715-1gjxer`;
2. accepted cross-layer ledger and residual DNS component budget —
   `TASK-260715-1pn983`;
3. physical provider startup/footprint and named-device rows — Mac via the M3
   physical tasks, iPhone deferred until authorized hardware;
4. user-affecting QUIC/route and reconnect ratification —
   `TASK-260717-l639qp`;
5. production MTU/HEV/lane/window/rekey/QUIC/reconnect/memory winners — only the
   later tuning and final-matrix tasks may select them from valid evidence.

No benchmark has been run and no candidate has been accepted by this protocol.
