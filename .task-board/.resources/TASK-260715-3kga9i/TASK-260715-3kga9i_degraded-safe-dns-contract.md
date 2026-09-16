# TASK-260715-2zmw58 — degraded safe-DNS fallback contract

Decision owner: `TASK-260715-2zmw58`  
Resolver authority: accepted `TASK-260715-1tnjlu` / ADR-022  
Capability authority: accepted `TASK-260715-30lv40`, contract `m2-capability-contract/1`  
Decision status: derived M2 handoff; no second resolver policy is selected

## 1. Binding decision

Degraded M2 uses the already selected M1 resolver identity and the M1
DNS-over-TCP implementation over the current authenticated SSH session. It does
not define a DoH alternative, a product/vendor resolver, exit-host discovery,
hostname bootstrap, fake DNS, or a physical resolver fallback.

The accepted M1 decision is explicit and accountably reviewed: each profile
supplies an ordered, non-empty array of canonical numeric `dns53` endpoints.
M1 and degraded mode reach the generation-global active endpoint only through
SSH `direct-tcpip`. The accepted decision explicitly deferred DoH; therefore
this contract has no URL, certificate, redirect, hostname-bootstrap, or trust
fields. A `doh`, discovery, system, hostname, or unknown resolver kind is
configuration-invalid rather than a fallback candidate.

## 2. Exact identity and schema mapping

| JSON path / runtime input | Exact degraded-mode rule |
| --- | --- |
| `dnsResolver` | Required non-secret object in `RuntimeConfigurationSnapshot` schema 2. No object default. |
| `dnsResolver.schemaVersion` | Required unsigned value `1`; unknown values fail before credentials, SSH, or routes. |
| `dnsResolver.kind` | Required literal `dns53`; no implicit DoH/system/discovery mode. |
| `dnsResolver.endpoints` | Required non-empty ordered array. Its production ceiling comes only from an accepted `DNSRuntimePolicyV1`; there is no local fallback ceiling. |
| `dnsResolver.endpoints[].address` | Canonical numeric IPv4 or RFC 5952 IPv6 literal. Hostnames, brackets, zone IDs, unspecified, multicast, limited broadcast, link-local, IPv4-mapped IPv6, non-canonical, and duplicate normalized tuples are rejected. Loopback, private/unique-local, and global addresses are allowed because the exit operator owns reachability. |
| `dnsResolver.endpoints[].port` | Unsigned `1...65535`; omitted value defaults exactly to `53`. The port is part of resolver identity. |
| endpoint order | Authoritative order across address families. Family is derived from parsed bytes. There is no IPv4/IPv6 preference, Happy Eyeballs, parallel racing, NAT64 synthesis, or per-query selection. |
| resolver identity | Ordered `(schemaVersion, kind, family, canonicalAddress, port)` tuples plus the profile/configuration generation. Endpoint promotion adds a new resolver/cache transport generation without rewriting the stored order. |

Profiles missing `dnsResolver` are preserved but marked
`requiresResolverConfiguration`; connect is disabled before Keychain access,
SSH, settings, or routes. Editors require at least one endpoint and never
prefill a resolver. Resolver kind, endpoint, order, address, or port changes
increment the profile revision and runtime configuration generation, cancel
old transactions, close DNS channels, and clear the cache generation.

## 3. Numeric policy: exact fail-closed status

`DNSRuntimePolicyV1` is versioned, injected, and not stored in the user profile.
It must supply all of these production values together:

- configured endpoint-count ceiling;
- maximum DNS message bytes;
- maximum in-flight queries;
- maximum queued wire bytes and aggregate DNS bytes;
- SSH channel-open deadline;
- complete-response deadline;
- total logical-query deadline;
- startup-readiness deadline; and
- reusable-connection idle-close deadline.

There are deliberately no embedded numeric defaults or hard caps in ADR-022 or
this M2 mapping. `TASK-260721-3miqh4` remains the existing accountable evidence
gate; its current candidate has `productionAuthorization=false` and is not an
accepted production policy. Until that task is independently accepted,
production `PolicyAuthorized(g)` is false and `TunnelRuntimeCoordinator.start()`
must fail before routes with finite reason `production_policy_unauthorized`.
Only explicitly marked test roots may inject test vectors, and those vectors
must never serialize or attest production authorization.

The validator rejects absent, unsupported, nonpositive, or cross-field
inconsistent values. Admission must reserve encoded request, one maximum
response, TCP framing, correlation/tombstone metadata, connection buffers,
retry-batch ownership, and queued bytes within the aggregate DNS budget. A
query-count limit alone is not memory evidence.

## 4. Transport priority, pooling, and retries

### Degraded mode

Both tunnel-owned client UDP DNS and client TCP DNS enter `VirtualDNSIngress`.
Every upstream request uses TCP length framing through the current authenticated
SSH session to the active numeric endpoint. General relay UDP is unavailable
and is not attempted. There is no physical socket or device resolver branch.

One runtime configuration generation owns one active endpoint and at most one
reusable TCP connection. Its connection epoch owns upstream IDs, canonical
question correlation, bounded ordered pipelining, out-of-order dispatch, and
tombstones. The accepted injected idle deadline controls clean pool retirement;
a later reopen still targets the same active endpoint under the logical
deadline. IDs are not reused while live or tombstoned, and one atomic terminal
claim permits one visible result.

The retry rules are structural and exact even while numeric deadlines remain
injected:

1. Startup opens `direct-tcpip` serially in stored endpoint order under the one
   startup-readiness deadline; each endpoint is attempted at most once.
2. A channel-open failure before query admission may promote to the next
   not-yet-attempted endpoint.
3. A complete correlated response with any RCODE is authoritative and never
   triggers resolver shopping.
4. EOF, ambiguous partial write, framing/correlation failure, response timeout,
   or SSH/channel loss after admission retires the entire epoch. Already
   terminal/cancelled queries stay terminal; expired queries fail; other
   idempotent QUERY owners enter one admission-ordered coordinated retry batch.
5. One coordinator opens each later endpoint at most once and reissues each
   eligible query at most once on that endpoint under the original logical
   deadline. Individual queries cannot reopen connections or race families.
6. Cancellation claims only its query, publishes no answer, never promotes,
   and retains a tombstone when bytes may have left the client.
7. Endpoint exhaustion returns bounded SERVFAIL when safe, stops DNS admission,
   invalidates cache/transport generation, emits mandatory `safe_dns_lost`,
   publishes no usable capability, and invokes settings teardown.

### Full-mode seam and relay restoration

In full mode, an eligible client UDP query receives at most one relay UDP
transmission to the same active endpoint. Only TC=1, a local or negotiated
datagram-size failure, UDP response timeout, or typed relay
association/session transport failure may hand the same logical query to the
M1 TCP owner. Client TCP DNS always enters M1 TCP. M1 may then promote only
through later not-yet-attempted configured endpoints. The structural maximum is
one relay UDP transmission plus at most one TCP attempt per configured endpoint.

Restoring a fresh validated relay generation changes transport priority for new
eligible client UDP queries only after the atomic Full transition. It does not
select a resolver, reorder endpoints, replay already terminal queries, or retry
a valid DNS response. Existing transaction owners retain their one terminal
claim. Relay restoration alone does not invalidate cache entries because the
resolver identity is unchanged; a simultaneous resolver/profile change or M1
endpoint promotion does invalidate them.

## 5. TC, oversize, cache, and DNSSEC

- A complete valid upstream TCP response is authoritative even when its TC bit
  is set; degraded mode does not shop resolvers after it.
- A client UDP response is encoded within the client's advertised or baseline
  size. When the complete permitted answer does not fit, the listener/cache
  layer returns a protocol-correct TC response so the client can retry TCP.
- Client TCP receives the complete response within the accepted maximum DNS
  message bound. A response beyond that bound or invalid TCP framing is
  connection-fatal and cannot be cached.
- Malformed, truncated, transient-failure, or policy-excluded responses never
  populate the cache. Cache entries are keyed by canonical question and the
  current resolver/cache generation; client IDs are restored only after
  correlation. Endpoint promotion and profile/resolver changes clear the
  generation. A pure full/degraded transport switch at the same resolver does
  not.
- DNSSEC is transparent, not locally validated. Preserve DNSSEC record types,
  EDNS DO, and CD/AD semantics plus wire questions, except for transaction-ID
  correlation and protocol-correct cached TTL aging. Never claim the AD bit is
  locally trusted validation.

## 6. Readiness and fail-safe behavior

`DNSConsumerFactory.prepareSafeDNS(...)` returns only after all of these are
true for the current generation: schema and production policy authorization
passed; SSH identity/authentication and session are current; one configured
endpoint accepted an SSH `direct-tcpip` channel under the startup deadline;
the virtual UDP and TCP DNS ingress paths are prepared; correlation, byte,
deadline, cancellation, and cache-generation owners are registered; and no
physical fallback edge exists. Opening the channel is the readiness probe; no
probe query name is invented.

That prepared fact is not yet public degraded readiness. The production call
site `TunnelRuntimeCoordinator.runStartup()` must also commit current settings,
activate packet reads, call `requireMandatoryHealth()`, and prove accepted
`BaseReady(g)` before the serialized capability writer may publish Degraded
`(tcp,safeDNS,udp)=(1,1,0)`. Authenticated SSH, a configured endpoint, or a
system VPN `connected` status alone is insufficient.

During bounded connection-epoch recovery, the DNS component may hold or reject
new arrivals only within the injected policy and may never fall back. If its
current readiness cannot be proven at a snapshot decision point, `BaseReady(g)`
is false and no full/degraded usable snapshot may be asserted; this introduces
no new service mode. Successful promotion re-establishes readiness on the next
configured endpoint. Exhaustion, SSH loss, profile change, cancellation/stop,
or a current mandatory DNS health event reaches
`TunnelRuntimeCoordinator.receive(_:)`, closes all admission, publishes all
bits false before cleanup, clears settings, and cannot be converted into an M2
relay-only reprobe.

## 7. Privacy, diagnostics, and UI

Allowed diagnostics are bounded aggregate counts and finite local facts:
readiness/health state, finite reason, resolver endpoint count and family mix,
active endpoint ordinal (not address), policy version/authorization state,
connection/cache generation, retry/promotion counts, byte/count high-water
marks, and cleanup counters.

Forbidden diagnostics and UI fields include query names, full resolver
addresses, destinations, payloads, client/app/flow identifiers, credentials,
profile/host identifiers, remote stdout/stderr, raw OS/resolver error strings,
and unknown peer values. The UI reads system session status plus a current
provider snapshot, maps finite local reasons to bundled copy, and never infers
safe DNS from `connected`, relay presence, or a cached model. Legacy remediation
is configuration-owned; final copy and actions remain UI-owned.

## 8. Negative evidence required from downstream implementation

Positive readiness tests are insufficient. The following negative shapes must
drive the named production call sites and fail if the gate is narrowed:

| Gate / production call site | Required negative proof |
| --- | --- |
| `ConfigurationSnapshotSource.loadValidatedSnapshot(...)` called by `TunnelRuntimeCoordinator.runStartup()` | Remove `dnsResolver`; use hostname, unknown kind/version, duplicate/noncanonical endpoint, invalid port, empty/over-policy array, and prove refusal before Keychain/SSH/routes. |
| Production policy composition in `TunnelRuntimeCoordinator.start()` / `runStartup()` | Supply a correctly shaped but candidate/self-minted or `productionAuthorization=false` policy; remove each authority-critical field in turn; require `production_policy_unauthorized`, zero settings calls, and zero usable snapshots. |
| `DNSConsumerFactory.prepareSafeDNS(...)` | Narrow readiness to authenticated SSH, configured identity, or an allocated consumer while channel-open/ingress/health proof is absent; require startup refusal and no settings. |
| `TunnelRuntimeCoordinator.receive(_:)` mandatory DNS-health path | Cause timeout, EOF, malformed frame, endpoint exhaustion, SSH loss, and stale-generation events through the real health sink. Current mandatory loss must close admission and clear settings; stale input must not mutate state. |
| `VirtualDNSIngress` and SSH direct-tcpip construction seam in `TASK-260715-3260rm` | Attempt physical resolver, system resolver, hostname discovery, unapproved DoH, vendor default, and per-query family racing on startup, retry, restoration, and cancellation branches; physical/resolver sentinels must remain zero. |
| Cache/TC delivery seam in `TASK-260715-2hawz9` | Narrow generation identity by omitting order/port/promotion or retain malformed/truncated/transient entries; require cache miss/invalidation and protocol-correct client TC behavior. |

Tests must obtain evidence through the composed production entry point, not by
calling a guard helper with caller-supplied authority. Mutants should narrow one
required fact or bypass one recovery path; deleting the whole gate is not proof.

## 9. Concrete downstream impact map and dependency audit

No new Story, Task, Bug, or research item is justified. The accepted M1 choice,
the existing numeric evidence gate, and the existing atomic consumer tasks cover
every requirement. Adding another resolver, DoH research, or duplicate planning
task would exceed the spec.

| Concern | Concrete owner and impact |
| --- | --- |
| Numeric evidence gate | `TASK-260721-3miqh4`: independently authorize all `DNSRuntimePolicyV1` values. Its current candidate is not production authority. |
| Profile schema/migration | `TASK-260721-33o8fc`: implement schema-2 `dnsResolver`, canonical validation, no-inference legacy remediation, and policy-ceiling consumption. |
| M1 upstream/listener/cache | `TASK-260715-5o6jqg`, `TASK-260715-1e0x1u`, `TASK-260715-2hawz9`: implement direct-tcpip TCP, both client transports, pooling/correlation/promotion, TC/cache/failure semantics. |
| Full-mode DNS seam | `TASK-260715-28jdml`: one relay UDP attempt plus enumerated same-endpoint M1 TCP handoff, never a second resolver policy. |
| Degraded integration | `TASK-260715-3260rm`: compose the selected M1 components into M2 readiness, health, cache generation, restoration, and cleanup. It is already blocked by this decision and the M1 implementation leaves; the numeric policy gate is inherited through `TASK-260715-5o6jqg`, so a redundant edge is not added. |
| Capability state/transition | `TASK-260715-3edgwz`, `TASK-260715-ak0s72`, `TASK-260715-uh8kk6`, `TASK-260715-kxxujt`: project safeDNS truth, apply mandatory failure, forbid UDP/physical fallback, and restore full only after fresh relay proof. |
| State and leak tests | `TASK-260715-1vg1mb`, `TASK-260715-2y78ah`, `TASK-260715-336ljl`, macOS `TASK-260715-2wqffe`, deferred iOS `TASK-260715-2qr5aj`: cover fixtures, gates, transitions, physical sentinels, and late/cancellation paths. |
| Documentation | `TASK-260715-3kga9i`, `TASK-260715-1o4h97`: publish mode/traffic/failure, migration, resolver reachability, system exceptions, and no-fallback evidence without absolute kill-switch claims. |
| Profile and UI | `TASK-260721-2raag7`: endpoint editing and legacy remediation without prefill. `TASK-260715-2a1cp7`: system-status plus current-provider-snapshot presentation and local finite-reason mapping. |

The current dependency chain is the smallest nonredundant mapping:
accepted `TASK-260715-1tnjlu` and `TASK-260715-30lv40` -> this decision ->
`TASK-260715-3260rm` -> degraded policy/state tests -> composed leak tests ->
documentation. Numeric/profile/M1 implementation prerequisites already converge
on the integration task through existing edges. No literal-spec gap remains
unowned, and the one unresolved numeric authorization question remains on the
existing exact research task rather than being guessed here.

## 10. Source evidence

- Accepted M1 resolver outcome SHA-256:
  `48bca1e99a24aa2cb335615960dbb14faa6bce5bb04b5b93fcb52ad67ddfdc2c`.
- Accepted M1 reviewer outcome SHA-256:
  `45208cc89f19d4a721ef4cafae4709428dbaf6c30a60a3962156cd3fb5d15e1a`.
- Binding post-acceptance capability contract SHA-256:
  `5b57540c86a0b48595863174e416229babee72cdb2705dd4bbb81bbefdc9ab69`.

