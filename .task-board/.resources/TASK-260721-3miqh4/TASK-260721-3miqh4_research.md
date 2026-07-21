# TASK-260721-3miqh4 — evidence-gated DNSRuntimePolicyV1

Status: rework evidence packet; numeric policy remains a **non-authoritative candidate** pending independent review and missing accepted inputs  
Date: 2026-07-21  
Owner: `TASK-260721-3miqh4` — Establish evidence-gated DNS profile and runtime limits  
Machine vector: `.research/fixtures/TASK-260721-3miqh4_dns-runtime-policy-v1.json`

## Key takeaways

- The protocol-derived ceiling is exact: a 65,535-byte DNS message plus its
  two-byte TCP length field needs a 65,537-byte contiguous wire reservation.
  The harness accepts that boundary, rejects a 65,536-byte message, and covers
  split-prefix, split-body, bytewise partial-write, and coalesced-frame cases.
- The corrected candidate ledger is 3,686,706 / 4,194,304 bytes at the default
  envelope and 7,635,554 / 8,388,608 bytes at the hard envelope. This proves
  internal DNS accounting only; it does not prove composition inside the
  packet-tunnel extension.
- State-specific timing now covers startup, M1 with an already-ready or cold
  TCP connection, and M2's bounded relay/UDP phase followed by ready or cold
  TCP fallback. The candidate default requires 34,000 ms on the worst M2 path
  and proposes 35,000 ms; the hard envelope requires 132,000 ms and proposes
  135,000 ms.
- Reliability is exercised by an explicit transaction-owner/event-trace
  simulator. It covers both IPv4-to-IPv6 and IPv6-to-IPv4 orders,
  cancellation/tombstones, late callbacks, duplicate detection before
  suppression, all five M2 fallback triggers, malformed/mismatched no-shopping,
  same-endpoint TCP, later promotion, and one terminal response maximum.
- Cleanup is observed through live counters for transactions, queued bytes,
  reservations, tombstones, connections, connection buffers, and fixed bytes.
  Every scenario and all nine regenerated raw trials end at zero ownership;
  memory trials also record zero descriptor delta.
- Production authorization is stopped. ADR-014 still has no selected SSH
  engine or controlled `direct-tcpip` results, and ADR-009 has no accepted
  residual component ledger. The 4/8 MiB and timing figures therefore remain
  injectable candidates, not production defaults or accepted hard caps.

## 1. Decision boundary

ADR-022 decides resolver identity, ordered endpoints, fail-closed behavior, and
M1/M2 attempt structure. This task investigates numeric runtime policy only.
It does not select a resolver vendor, add a profile default, change `dns53`,
permit physical fallback, or implement production listener, upstream, cache,
relay, or UI code.

`DNSRuntimePolicyV1` is versioned, injected, and non-profile. The user profile
stores only the resolver identity required by ADR-022. Production composition
must fail closed when an accepted policy is absent, unsupported, or invalid.

## 2. Fact-checked requirements

### 2.1 Primary protocol facts

- [RFC 1035 section 4.2.2](https://www.rfc-editor.org/rfc/rfc1035.html#section-4.2.2)
  places a two-byte length field before the DNS message and excludes those two
  bytes from the encoded length.
- [RFC 5936 section 2](https://www.rfc-editor.org/rfc/rfc5936.html#section-2)
  makes the resulting maximum DNS message size explicit: 65,535 octets.
- [RFC 7766](https://www.rfc-editor.org/rfc/rfc7766.html) requires TCP support,
  supports connection reuse and pipelining, forbids reuse of an in-flight
  message ID, requires out-of-order response matching by ID and question, and
  recommends minimizing concurrent regular-query connections.
- [RFC 4254 section 7.2](https://www.rfc-editor.org/rfc/rfc4254.html#section-7.2)
  puts the target host and port in `direct-tcpip`; resolver reachability is
  therefore evaluated by the SSH exit, not by device resolver selection.
- [RFC 9210](https://www.rfc-editor.org/rfc/rfc9210.html) reports deployed idle
  timeout defaults from 2 to 30 seconds and identifies 10 seconds as a
  reasonable starting point. It does not justify channel-open, response,
  startup, or logical deadlines.

No RFC selects endpoint cardinality, in-flight count, queued bytes, component
memory, channel-open time, response time, or total logical deadline. Those need
accepted product/runtime evidence.

### 2.2 Repository facts and missing evidence

| Input | Verified state | Consequence |
| --- | --- | --- |
| ADR-009 and `.spec/packet-plane.md` | Accepted accounting principle and provisional 25–30 MiB whole-extension target; no residual DNS slice | A local 4/8 MiB envelope cannot authorize production composition. |
| ADR-022 and accepted `TASK-260715-1tnjlu` evidence | One active endpoint, at most one reusable TCP connection, serial promotion, one retry batch, one terminal claim, M2 one UDP plus bounded M1 TCP | Structural attempt equations are authoritative. |
| `TASK-260715-2ny6z4` — SSH transport conformance contract | Caller deadlines and bounded buffers/windows are required; 32/64 KiB window candidates are test rows | It defines what to measure, not selected-engine results. |
| ADR-014 / `TASK-260715-1gjxer` — M0 SSH engine selection | Open/backlog behind both candidate functional matrices | No accepted engine, adapter-owned byte ledger, or `direct-tcpip` latency distribution exists. |
| `TASK-260715-1pn983` — cross-layer memory/window/rekey contract | Backlog and blocked by engine selection plus packet/runtime dependencies | No accepted residual component budget exists. |
| `TASK-260715-2kchi0` — M3 measurement protocol | Backlog | It supplies no accepted production timing/startup results. |

This is the exact stop-line boundary required by rework 01. Local Python RSS
and loopback timings are retained as reproducible harness observations only.

## 3. Candidate matrix

Candidates were fixed before the rework runs. The two full-message candidates
remain useful for downstream measurement design, but neither is authorized.

| Candidate | Endpoints | DNS message | Live owners | Queued wire | Aggregate | Exact local ledger | Disposition |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Lean | 2 | 4 KiB | 8 | 64 KiB | 2 MiB | 434,354 B | Rejected: protocol-visible response truncation. |
| Bounded-16K | 4 | 16 KiB | 16 | 256 KiB | 2 MiB | 1,327,458 B | Rejected: protocol-visible response truncation. |
| Full-wire candidate default | 4 | 65,535 B | 16 | 256 KiB | 4 MiB | 3,686,706 B | Candidate only; requires accepted residual budget and selected-SSH rows. |
| Full-wire candidate hard envelope | 8 | 65,535 B | 32 | 1 MiB | 8 MiB | 7,635,554 B | Conservative validator candidate only; not a production composition permission. |

The endpoint candidates are 2, 4, and 8. Four can express two ordered fixture
endpoints per family; eight bounds profile and serial-attempt growth. This is a
clean candidate envelope, not evidence of user demand or operator deployment.

## 4. Candidate DNSRuntimePolicyV1 values

| Field | Candidate default | Minimum | Candidate hard ceiling | Meaning |
| --- | ---: | ---: | ---: | --- |
| `maxConfiguredEndpoints` | 4 | 1 | 8 | Ordered profile endpoints; still no endpoint identity default. |
| `maxDNSMessageBytes` | 65,535 | 65,535 | 65,535 | Protocol-derived message limit; framing is separate. |
| `maxInFlightQueries` | 16 | 1 | 32 | Counts admitted, retry-held, and tombstoned owners. |
| `maxQueuedWireBytes` | 262,144 | 512 | 1,048,576 | Independent queue/copy ownership. |
| `maxAggregateDNSBytes` | 4,194,304 | 262,144 | 8,388,608 | Local DNS ledger cap, pending cross-layer budget acceptance. |
| `channelOpenTimeoutMilliseconds` | 2,000 | 250 | 5,000 | One selected-SSH channel-open slice. Candidate only. |
| `responseTimeoutMilliseconds` | 5,000 | 500 | 10,000 | Complete correlated framed TCP response. Candidate only. |
| `relayUDPPhaseTimeoutMilliseconds` | 5,000 | 500 | 10,000 | One association/session/send/receive phase or typed failure. Candidate only. |
| `dispatchAllowanceMilliseconds` | 1,000 | 1 | 2,000 | One non-resetting scheduling/terminal-publication allowance. Candidate only. |
| `logicalQueryTimeoutMilliseconds` | 35,000 | 1,000 | 135,000 | One monotonic M1/M2 deadline; never resets. |
| `startupReadinessTimeoutMilliseconds` | 10,000 | 250 | 45,000 | One startup deadline over serial channel opens. |
| `idleCloseTimeoutMilliseconds` | 10,000 | 2,000 | 30,000 | Applies only with no queued or outstanding work. |

The extra relay/UDP and dispatch fields make previously hidden M2 and
scheduling time explicit. If production uses a different policy shape, it must
preserve the same state equations and version the schema.

## 5. Exact wire and byte accounting

Let `M` be maximum DNS message bytes, `N` live owners, `Q` queued wire bytes,
`E` endpoints, and `A` aggregate DNS bytes.

One owner reserves request, maximum response, one coordinated-retry request,
all three two-byte prefixes, and 1,024 bytes of correlation/tombstone state:

```text
R = 3 × (M + 2) + 1024
```

The component ledger is:

```text
L = N × R
  + Q
  + 65,537 read buffer
  + 65,537 write buffer
  + 65,536 manager/base state
  + 65,536 diagnostics reserve
  + E × 64 endpoint metadata

Validation requires L <= A.
```

Default-candidate proof:

```text
R = 3 × (65,535 + 2) + 1,024 = 197,635
L = 16 × 197,635 + 262,144 + 65,537 + 65,537
    + 65,536 + 65,536 + 4 × 64
  = 3,686,706 <= 4,194,304
headroom = 507,598 bytes
```

Hard-envelope proof:

```text
L = 32 × 197,635 + 1,048,576 + 65,537 + 65,537
    + 65,536 + 65,536 + 8 × 64
  = 7,635,554 <= 8,388,608
headroom = 753,054 bytes
```

The 1,024-byte per-owner metadata reservation contains a designed 480-byte
subledger (epoch/generation 16; IDs/flags 16; question correlation 64;
deadline/terminal/cancellation 64; task/queue handles 128; retry/tombstone 64;
alignment/slack 128), leaving 544 bytes implementation headroom. The 65,536-byte
manager reserve covers ID occupancy, owner/tombstone containers, timers,
retry/admission state, epoch state, fixed metrics, and allocator slack.

The isolated allocation trial constructs each ledger category independently.
It is a consistency test, not proof of the eventual Swift allocator or provider
footprint.

## 6. State-specific timing equations

Let `E` be endpoint count, `O` channel-open slice, `R` complete-response slice,
`U` relay/UDP phase, and `D` dispatch allowance.

```text
startup cold serial = E×O + D
M1 ready connection = E×R + (E−1)×O + D
M1 cold connection  = E×(O+R) + D
M2 ready TCP        = U + M1 ready
M2 cold TCP         = U + M1 cold
```

“Ready” means the active generation already owns a reusable TCP connection.
“Cold” means idle close or full-mode operation requires a same-endpoint TCP
open before the first TCP attempt. Later endpoints always need one serial open.
`U` includes association/session work, datagram-size rejection, one UDP send,
response wait, or typed transport failure as applicable. No phase resets the
logical deadline.

| Requirement | Candidate default required / configured | Hard required / configured |
| --- | ---: | ---: |
| Startup cold serial | 9,000 / 10,000 ms | 42,000 / 45,000 ms |
| M1 ready | 27,000 / 35,000 ms | 117,000 / 135,000 ms |
| M1 cold | 29,000 / 35,000 ms | 122,000 / 135,000 ms |
| M2 ready TCP | 32,000 / 35,000 ms | 127,000 / 135,000 ms |
| M2 cold TCP | 34,000 / 35,000 ms | 132,000 / 135,000 ms |

Twenty machine vectors pass independently frozen default/hard requirements
through `validate_policy`: equality and one-millisecond-under mutations for
startup, M1-ready, M1-cold, M2-ready, and M2-cold. Each vector changes exactly
one timeout field and asserts the relationship-specific error tag. Equality
removes that tag for every relationship; startup and governing M2-cold equality
also leave the whole policy valid, while the intermediate logical-deadline rows
retain only the expected stronger-path errors.

## 7. Structural attempts and terminal ownership

- Startup opens at most `E` `direct-tcpip` channels, serially in stored order.
- M1 permits one TCP attempt per endpoint. A coordinated retry batch opens the
  promoted endpoint once; individual owners do not reopen it.
- M2 permits at most one UDP attempt. Valid non-truncated data is terminal.
  TC, local/negotiated datagram-size failure, UDP timeout, relay-association
  failure, or relay-session failure may hand the same owner to M1.
- M2 TCP first targets the active endpoint. Only M1 may promote to later
  not-yet-attempted endpoints, preserving `1 UDP + E TCP` maximum.
- Malformed or mismatched UDP is rejected without shopping. Cancellation does
  not promote. One atomic terminal claim suppresses late UDP/TCP callbacks.

## 8. Controlled evidence

Three fresh runs used five warmups and 30 measured iterations per latency
fixture. All sockets used numeric IPv4/IPv6 loopback or a closed loopback port.
The harness replaces `socket.getaddrinfo` with a failing sentinel; all three
runs recorded zero calls. No public resolver, external endpoint, or physical
resolver was used.

Observed results:

- both IPv4-failure→IPv6-success and IPv6-failure→IPv4-success took exactly two
  serial attempts;
- maximum wire success was 65,535 message bytes / 65,537 framed bytes;
  65,536 message bytes was rejected;
- split two-byte prefix, 997-byte body chunks, bytewise partial writes, and two
  coalesced frames parsed correctly;
- ordinary loopback median-of-run-medians was 0.368 ms; maximum run p99 was
  0.590 ms;
- the injected 100 ms responder median-of-run-medians was 103.772 ms; maximum
  run p99 was 110.378 ms;
- unreachable, malformed TCP, and stalling fixtures reached bounded failure;
- the 16-owner concurrent failure used two connection epochs and one
  coordinated retry batch, delivered 16 visible responses, then recorded one
  attempted retired-epoch duplicate before suppression;
- cancellation created a tombstone, suppressed a late callback, retired the
  tombstone, and delivered zero visible responses;
- each M2 fallback trigger used one UDP attempt and one same-endpoint TCP
  attempt; the promotion row used one UDP plus exactly two TCP attempts;
  malformed and mismatched rows used no TCP attempt;
- late UDP after TCP terminal and cancellation during TCP each produced no
  duplicate visible response.

Every scenario is compared with an exact expected projection before it can be
recorded: UDP attempts/transmissions, TCP attempt count and endpoint order,
terminal owner identities/outcomes, pre-dedup duplicates, suppressed late
callbacks, cancellation/tombstone creation and retirement, connection epochs,
coordinated retry batches, complete event signature, and zero cleanup ownership.
The event traces, exact counts, assertion result, and trace digest are in each
raw run under `measurements.fixtures.transactionOwnerSimulation`.

## 9. Cleanup and footprint observations

Every event trace records current and peak ownership for transactions, queued
wire bytes, reservations, tombstones, connections, connection buffers, and
fixed bytes. All traces end with every counter at zero. Fixture teardown records
equal baseline/cleanup descriptor counts and aborts the run on any delta.

Three isolated default trials constructed exactly 3,686,706 tracked bytes;
three hard trials constructed exactly 7,635,554 tracked bytes. All ended with
zero tracked ownership and zero descriptor delta. Maximum incremental local
physical footprint was 3,932,160 bytes for the default candidate and 7,749,656
bytes for the hard candidate. These Mac/Python observations are deliberately
non-authoritative for iOS or the selected Swift/SSH runtime.

## 10. Evidence-gate verdict

### Proven now

- exact DNS/TCP wire maximum and one-byte-over rejection;
- self-consistent per-owner, queue, connection-buffer, fixed, retry, and
  aggregate equations for the candidate envelopes;
- fail-closed validation relationships and 20 real default/hard mutation vectors;
- fail-closed authority verification for candidate classification, both
  authorization booleans, exact blocker IDs, the later physical gate, and all
  required structural contracts;
- ADR-022 attempt/terminal structure with exact deterministic event-trace assertions;
- controlled loopback repeatability, zero resolver-sentinel calls, and observed
  fixture ownership cleanup.

### Not proven; production remains blocked

1. `TASK-260715-1gjxer` must select an SSH engine from accepted candidate
   matrices and publish adapter/window/allocator/lifecycle evidence.
2. The selected engine must run controlled `direct-tcpip` open, complete
   response, concurrent failure, cancellation, retry-batch, idle-close, and
   cleanup rows on the baseline Mac and physical iPhone.
3. `TASK-260715-1pn983` must publish the accepted whole-extension ledger,
   including packet sockets, HEV, SSH windows/pending writes, relay, DNS cache,
   diagnostics, lanes, rekey, and reconnect overlap, and assign the residual
   DNS component budget.
4. A physical provider startup row must supply the accepted startup contract;
   `TASK-260715-2kchi0` may define the reproducibility protocol but currently
   has no outcome.

Until those inputs exist, the JSON's `productionAuthorization.permitted` is
false, ADR-022 stays Proposed, and downstream consumers must not copy the
candidate values into production composition or profile UX.

## 11. Revalidation triggers

Re-run and re-review the policy when any of these changes:

- selected SSH engine, fork pin, adapter, event-loop model, receive window,
  maximum packet, queued write behavior, or channel-open API;
- accepted HEV/lwIP task stack, TCP buffers, caches, MTU, session cap, bridge
  socket buffers, or relay framing/datagram limits;
- diagnostics encoding ceiling or correlation/tombstone implementation size;
- endpoint, in-flight, queue, cache, lane, rekey, or reconnect-overlap policy;
- minimum OS, Xcode/Swift toolchain, baseline iPhone/Mac, or Network Extension
  memory behavior;
- controlled selected-SSH p99 or timeout/cleanup rows exceed the reviewed
  policy assumptions;
- RFC transport requirements or ADR-022 structural ownership changes.

Any increased field must re-prove all cross-field equations and the complete
extension ledger. Silent headroom borrowing is forbidden.

## 12. Reproduction and artifacts

```bash
python3 -m py_compile scripts/dns-policy-evidence.py
python3 scripts/dns-policy-evidence.py --self-test-only
python3 scripts/dns-policy-evidence.py \
  --verify-policy .research/fixtures/TASK-260721-3miqh4_dns-runtime-policy-v1.json
python3 scripts/dns-policy-evidence.py --warmup 5 --repeats 30 \
  --output .research/raw/TASK-260721-3miqh4_measurements-run-01.json
python3 scripts/dns-policy-evidence.py --memory-trial hard \
  --output .research/raw/TASK-260721-3miqh4_memory-hard-01.json
```

Primary artifacts:

- `scripts/dns-policy-evidence.py`
- `.research/fixtures/TASK-260721-3miqh4_dns-runtime-policy-v1.json`
- `.research/raw/TASK-260721-3miqh4_measurement-summary.json`
- `.research/raw/TASK-260721-3miqh4_measurements-run-01.json` through `-03.json`
- `.research/raw/TASK-260721-3miqh4_memory-default-01.json` through `-03.json`
- `.research/raw/TASK-260721-3miqh4_memory-hard-01.json` through `-03.json`

## References

- `.spec/decisions.md` — ADR-009, ADR-014, ADR-022
- `.spec/packet-plane.md`
- `.spec/routing-dns-lifecycle.md`
- `.spec/ssh-transport.md`
- `TASK-260715-1tnjlu` accepted resolver-policy evidence
- `TASK-260715-2ny6z4` accepted SSH conformance contract
- [RFC 1035](https://www.rfc-editor.org/rfc/rfc1035.html)
- [RFC 5936](https://www.rfc-editor.org/rfc/rfc5936.html)
- [RFC 7766](https://www.rfc-editor.org/rfc/rfc7766.html)
- [RFC 4254](https://www.rfc-editor.org/rfc/rfc4254.html)
- [RFC 9210](https://www.rfc-editor.org/rfc/rfc9210.html)
