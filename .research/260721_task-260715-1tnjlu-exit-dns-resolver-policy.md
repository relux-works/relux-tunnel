# TASK-260715-1tnjlu — baseline exit-side DNS resolver policy

Status: proposed for independent architecture review  
Decision owner: TASK-260715-1tnjlu  
Decision-log entry: ADR-022

## Context

M1 must accept device UDP and TCP DNS on tunnel-owned virtual addresses and
send upstream DNS through the authenticated SSH exit without allowing ordinary
queries to reach a physical resolver after routes apply. Existing requirements
select SSH DNS-over-TCP but do not identify the exit-side resolver. The missing
identity affects the immutable profile snapshot, M1 startup, M2 relay behavior,
M4 profile editing, migration, and leak tests.

Accepted project invariants are authoritative:

- `.spec/architecture.md` and ADR-005/ADR-007 make SSH the device-to-exit
  payload transport and require safe DNS in degraded mode.
- `.spec/security-privacy.md` requires ordinary DNS to fail closed and forbids
  destination/query logging.
- `.spec/routing-dns-lifecycle.md` requires SSH bootstrap before routes and
  prohibits physical resolver fallback.
- `TASK-260715-30zng6` assigns the versioned non-secret snapshot to the
  configuration source, requires DNS readiness before settings, and makes DNS
  health mandatory after settings.
- The accepted task input forbids vendor selection by taste, physical resolver
  inheritance, unapproved remote-shell parsing, and fake DNS.

## Options compared

| Policy | Privacy and operator expectation | Bootstrap and reliability | Platform and UX | M2/degraded compatibility, testability, cost | Verdict |
| --- | --- | --- | --- | --- | --- |
| Explicit per-profile numeric endpoints | User/exit operator chooses every recipient; Relux adds no resolver party. Query may reach only explicitly ordered endpoints. | No resolver-name bootstrap. Exit reachability is proven through SSH. Supports loopback/private/global IPv4 or IPv6. Misconfiguration is visible and fail-closed. | Adds a required profile field and migration remediation. Numeric literals avoid ambiguous client-vs-exit name resolution. | Same endpoints work for M1 TCP and M2 relay UDP/TCP. Controlled fixtures and physical sentinels are deterministic. Lowest new runtime/supply-chain cost. | **Selected.** |
| Documented Relux/product default | Simple first-run UX, but silently assigns a resolver operator and changes the product's “user-controlled exit” expectation. | A numeric default avoids bootstrap but can be blocked/unreachable from some exits; a hostname default reintroduces bootstrap. | Minimal UI, maximum policy/accountability burden. Regional/vendor availability becomes product infrastructure. | Easy fixture but poor operator control; requires vendor, privacy, legal, availability, and ownership approval that does not exist. | Rejected for baseline; no accountable vendor decision exists or is needed. |
| Exit-host discovery | May align with host policy when correctly discovered. | Linux/macOS/systemd/container resolver state is heterogeneous; loopback stubs may be namespace-specific. Shell/config parsing is brittle and becomes a security surface. | Hides the real recipient and produces difficult remediation. Requires an approved bounded discovery protocol, not ad hoc shell output. | Relay can use a discovered endpoint, but deterministic fixtures and migration are costly. Operational support is highest. | Rejected; separately approved discovery design required before reconsideration. |
| Tunneled DoH | Protects exit-to-resolver traffic and can pass networks blocking TCP/53. The DoH operator remains an explicit privacy party. | URI hostname, TLS identity, redirects, HTTP semantics, certificate status, and bootstrap addresses add circularity and failure modes. RFC 8484 explicitly notes DoH hostname bootstrap deadlock. | Requires URL/trust UI and an HTTP/TLS client in the extension. Certificate failures need product-visible remediation. | Can work in degraded mode but does not reuse M2 UDP directly and expands fixtures, dependencies, memory, and operations. | Deferred. A future `doh` resolver kind needs its own ADR and trust/bootstrap schema. |

The choice is derivable from accepted invariants: it selects no vendor, adds no
new trust party, and is the only compared policy that is deterministic without
an unapproved bootstrap/discovery mechanism. Per the accepted task input, an
independent Codex architecture reviewer is the accountable approval boundary;
no additional human product choice is required for this vendor-neutral policy.

## Exact profile and runtime contract

### Stored schema

`RuntimeConfigurationSnapshot` advances from schema 1 to schema 2 when this
field is implemented. The first M4 persisted profile schema must include the
same nested value rather than inventing a UI-only representation.

| JSON path | Type | Default | Validation and meaning |
| --- | --- | --- | --- |
| `dnsResolver` | object | none; required | Non-secret resolver identity included in the immutable profile revision. |
| `dnsResolver.schemaVersion` | unsigned 16-bit integer | none; required value `1` | Unknown versions fail before credentials/routes. |
| `dnsResolver.kind` | string enum | none; required value `dns53` | Classic DNS service. No implicit `doh`, discovery, or system mode. |
| `dnsResolver.endpoints` | ordered array | none; required non-empty | Authoritative failover order. The accepted injected `DNSRuntimePolicyV1` supplies the production count ceiling; empty or policy-oversized arrays fail validation. |
| `dnsResolver.endpoints[].address` | string | none | Canonical numeric IPv4 or IPv6 literal, no brackets or zone ID. |
| `dnsResolver.endpoints[].port` | unsigned 16-bit integer | `53` when absent | Range 1–65535. Part of endpoint and cache-generation identity. |

Editor normalization parses first and then encodes canonical dotted-decimal
IPv4 or RFC 5952 IPv6; the persisted/runtime snapshot decoder requires that
canonical form and rejects non-canonical stored input. Validation derives family
from bytes and deduplicates normalized
`(family,address,port)` tuples. It permits loopback, RFC 1918, globally scoped,
and IPv6 unique-local endpoints because the user may operate a resolver on or
behind the exit. It rejects unspecified, multicast, IPv4 limited broadcast,
IPv4/IPv6 link-local, scoped/zone-qualified, IPv4-mapped IPv6, non-canonical,
duplicate, and hostname input. Both families are optional; there is no local
Happy Eyeballs or physical-family preference. The SSH server opens the numeric
destination from the exit side, so NAT64 synthesis is not applied to resolver
endpoints.

ADR-022 intentionally does not freeze an endpoint-count ceiling without
evidence. `TASK-260721-3miqh4` must select that ceiling together with runtime
byte/capacity/timing values. Until its independent review accepts a production
`DNSRuntimePolicyV1`, profile publication and runtime composition have no local
fallback limit and remain blocked. This is a validation-policy dependency, not
a user-visible field or a snapshot default.

### Transport and limits

Transport is capability policy, not a user-editable profile field:

- M1 and degraded mode: DNS-over-TCP to the selected endpoint via SSH
  `direct-tcpip`; port is the endpoint port (default 53).
- M2 full mode: DNS-over-UDP through the authenticated relay to the same
  endpoint, with the M1 TCP path retained for client TCP, TC, oversize, timeout,
  and relay failure.
- No ordinary upstream DNS operation opens a device physical socket or invokes
  the device resolver after settings.

`DNSRuntimePolicyV1` is injected, versioned, and non-profile. It must contain:

- the configured endpoint-count ceiling;
- maximum DNS message bytes;
- maximum in-flight queries;
- maximum queued wire bytes and aggregate DNS bytes;
- SSH channel-open, complete-response, total logical-query,
  startup-readiness, and reusable-idle deadlines; and
- the structural M1/M2 attempt policy frozen below.

ADR-022 supplies no production numeric defaults or hard caps. RFC 7766 requires
bounded connection management but does not justify the previously proposed
5/5/15/10-second, 32/128-query, or one-to-four endpoint values. Those values are
removed, not renamed as provisional defaults. `TASK-260721-3miqh4` must compare
candidates, measure controlled fixtures, derive a DNS component budget from the
accepted extension/runtime budget, select exact defaults and ceilings, and obtain
independent architecture acceptance before schema, transport, relay, or M4
consumers proceed.

The policy validator rejects nonpositive or internally inconsistent values.
Admission reserves the encoded request, one maximum response, TCP framing,
correlation/tombstone metadata, connection read/write buffers, retry-batch
ownership, and queued bytes. The sum of live reservations must not exceed the
policy aggregate DNS budget. A count limit alone is never treated as memory
proof. Test/harness code injects explicit vectors; production composition fails
closed if the accepted policy is absent or unsupported.

One runtime configuration generation has one active endpoint and at most one
reusable TCP connection. Its connection epoch owns unique upstream message IDs,
canonical question correlation, bounded ordered pipelining, out-of-order response
dispatch, and tombstones. An ID is not reused while live or tombstoned. A response
is delivered only after epoch, ID, and question validation, with the original
client ID restored. One atomic terminal claim prevents duplicate visible answers.

### Address selection, retries, and failure

1. Before settings, validate the resolver object and accepted injected policy,
   authenticate SSH, and attempt `direct-tcpip` serially in stored endpoint
   order under one injected startup-readiness deadline. RFC 4254 `direct-tcpip`
   makes the SSH server connect to the specified host and port, so resolver
   reachability is evaluated from the exit. Opening the channel is the readiness
   probe; do not invent a probe name.
2. Install tunnel routes/DNS only after safe DNS reports ready. The physical
   resolver may have been used earlier only to bootstrap the SSH hostname, as
   already required by the startup contract; it is never a resolver candidate
   for ordinary queries.
3. Accept baseline opcode QUERY only. The active endpoint is generation-global,
   not independently selected by each query. M1 sends at most one TCP attempt per
   configured endpoint for a logical query, serially and under one injected
   logical deadline. Parallel endpoint racing is forbidden.
4. A complete correlated response, including NXDOMAIN, SERVFAIL, or REFUSED, is
   authoritative and causes no resolver shopping. Channel-open failure before
   admission may promote once to the next not-yet-attempted endpoint. EOF,
   partial-write ambiguity, framing/correlation failure, response timeout, or
   SSH/channel loss after admission is connection-fatal: one manager atomically
   retires the epoch and snapshots every in-flight owner.
5. Already terminal or cancelled queries stay terminal; expired queries fail.
   Other idempotent QUERY operations whose logical deadline and later-endpoint
   budget remain enter one admission-ordered retry batch. A single coordinator
   opens the next endpoint once, promotes it generation-wide, reissues each
   eligible query with a new epoch/ID at most once there, and holds or rejects new
   arrivals within policy bounds. Individual queries cannot reopen connections.
   Late retired-epoch callbacks are discarded. Promotion invalidates the cache
   and transport generation; safe DNS is recovering only during this bounded
   attempt and becomes ready on the promoted connection.
6. Per-query cancellation claims that query only and publishes no answer. If its
   bytes may already be on the connection, its upstream ID remains tombstoned
   until the response is consumed or the epoch retires. Cancellation never
   promotes an endpoint. A response timeout is connection-fatal so a late answer
   cannot be confused with another owner.
7. Exhaustion returns bounded SERVFAIL when the listener can safely respond,
   reports mandatory DNS health loss, stops admission, publishes safe DNS false,
   and invokes settings teardown. It never falls back to the physical resolver.
8. Profile/resolver revision change cancels old transactions, closes resolver
   channels, and clears the cache generation before new readiness.

### M2 UDP-to-TCP ownership

M2 does not weaken the M1 no-shopping rule:

1. Client TCP DNS enters M1 TCP directly. An eligible client UDP query gets at
   most one relay UDP transmission to the active endpoint.
2. A complete valid non-truncated UDP response, including any RCODE, ends the
   logical query. Malformed or mismatched UDP data is rejected and does not
   select another resolver.
3. M2 alone may request same-endpoint TCP after TC=1, a local or negotiated
   relay-datagram size failure before a valid response, UDP response timeout, or
   a typed relay association/session transport failure.
4. M1 owns that TCP work. If TCP fails at the active endpoint, M1 may promote
   serially through later not-yet-attempted endpoints once each under the same
   logical deadline. It never retries after a valid DNS response.
5. The structural maximum is therefore one UDP attempt plus at most one TCP
   attempt per configured endpoint. One transaction owner and terminal claim
   prevent duplicate client answers across UDP, TCP, promotion, and late data.

DNSSEC is transparent, not validated by Relux. Preserve wire questions,
DNSSEC record types, EDNS DO, and CD/AD semantics; only transaction-ID
correlation and protocol-correct cached TTL aging may change the relayed message.
Do not claim that an AD bit from an untrusted resolver proves validation.

### Migration

- A stored profile or runtime snapshot without `dnsResolver` is not upgraded by
  guessing. Preserve it but mark it `requiresResolverConfiguration`; connect is
  disabled before Keychain access, SSH, or routes.
- M4 must require at least one resolver endpoint on create/edit and give legacy
  profiles a remediation path. The UI may explain loopback when the user's exit
  actually runs a local resolver, but it must not prefill it.
- Controlled test fixtures gain explicit numeric endpoints owned by the fixture.
  No test uses a public vendor as an ambient dependency.
- Resolver endpoint/order/port/kind changes increment the profile revision and
  runtime configuration generation and invalidate cache/channel state.
- Unknown future resolver kinds/versions are preserved only by storage that can
  safely round-trip them; the M1 loader rejects them before side effects.

## Privacy proof

After routes apply, every ordinary query has only this path:

`OS -> tunnel DNS address -> VirtualDNSIngress -> authenticated SSH channel ->
explicit exit-side endpoint`.

The profile contains no hostname resolver endpoint, so the path cannot invoke
device DNS to bootstrap its upstream. The only physical-path DNS permitted by
the existing architecture is the pre-route (or explicitly required-interface
reconnect) resolution of the SSH transport hostname. Resolver exhaustion maps
to SERVFAIL plus mandatory health loss/settings teardown. There is no code-path
policy edge from the DNS consumer to `NWConnection`/socket on the physical
interface or to the OS resolver. TASK-260715-336ljl and physical tasks
TASK-260715-2wqffe/TASK-260715-2qr5aj must prove this with a sentinel/capture.

## Downstream impact map

| Task | Required impact |
| --- | --- |
| `TASK-260721-3miqh4` — Establish evidence-gated DNS profile and runtime limits | Select exact endpoint-count, message, byte, capacity, and timing defaults/ceilings from memory accounting and controlled fixtures; publish accepted `DNSRuntimePolicyV1` vectors before all numeric consumers. |
| `TASK-260721-33o8fc` — Extend the M1 profile snapshot with the explicit DNS resolver schema | Add `dnsResolver` to runtime/profile schema 2, consume the accepted endpoint-count policy, implement canonical validation and typed no-inference migration, and publish boundary golden vectors. |
| `TASK-260715-5o6jqg` — Implement exit-side DNS-over-TCP through SSH direct-tcpip | Implement the generation-global active endpoint, one connection epoch, correlation/tombstones, atomic in-flight classification, one coordinated retry batch/promotion, late-epoch rejection, policy byte reservations, cache invalidation, and typed health loss. |
| `TASK-260715-1e0x1u` / `TASK-260715-2hawz9` — DNS listener and cache/fallback | Accept only QUERY; key cache generation by resolver identity; preserve DNSSEC semantics; return bounded SERVFAIL without physical fallback. |
| `TASK-260715-2pml0c` / `TASK-260715-12tbjl` / `TASK-260715-30ugfm` — routing/settings/startup | Require schema-valid resolver and safe upstream readiness before settings; withdraw capability and clear settings on mandatory DNS health loss. |
| `TASK-260715-28jdml` — Integrate full-mode DNS over relay | Give M2 one UDP attempt at the active endpoint and only the enumerated same-endpoint TCP triggers; hand TCP connection/promotion ownership to M1, cap work structurally at one UDP plus one TCP per configured endpoint, and deliver one visible result. |
| `TASK-260715-2zmw58` / `TASK-260715-3260rm` — degraded policy/integration | Treat M1 SSH DNS-over-TCP as the selected baseline; do not add DoH or another resolver identity. |
| `TASK-260715-1o4h97` — routing/DNS documentation | Publish fields/defaults, operator reachability, migration, failure table, compatible-mode caveats, and no-fallback proof. |
| `TASK-260715-336ljl` — integrated harness validation | Add v4-only, v6-only, dual ordered promotion, loopback, multi-in-flight connection failure, one coordinated retry batch, late-epoch rejection, cancellation/deadline split, byte-policy boundaries, cache invalidation, exhaustion, DNSSEC transparency, and physical-sentinel cases. |
| `TASK-260715-2wqffe` / `TASK-260715-2qr5aj` — physical leak evidence | Record configured fixture identity and prove zero post-settings ordinary physical DNS on macOS and deferred iOS respectively. |
| `TASK-260721-2raag7` — Add the explicit exit-resolver profile experience on iOS and macOS | Integrate ordered endpoint editing using the accepted count ceiling and legacy remediation after the base M4 repository/model/platform editors; never prefill a resolver. It blocks the existing cross-platform UI matrix `TASK-260715-1kfqgp`. |
| `TASK-260715-2hhh7x`, `TASK-260715-28bwf4`, `TASK-260715-1y5r8p`, `TASK-260715-n8i3tv`, `TASK-260715-2lakiq` — M4 profile contract/storage/model/base UI | Preserve one resolver representation through the base profile stack so TASK-260721-2raag7 adds a focused product slice rather than a second schema. |

## References

Project evidence:

- `.spec/architecture.md`
- `.spec/security-privacy.md`
- `.spec/routing-dns-lifecycle.md`
- `.spec/relay-protocol.md`
- `.spec/validation.md`
- `.spec/decisions.md`
- Board outcomes `TASK-260715-30zng6_runtime-contract.md` and the accepted
  `TASK-260715-lovbdz` runtime message/schema implementation.

Protocol evidence:

- RFC 1035, DNS transport and TCP/UDP port 53:
  <https://www.rfc-editor.org/rfc/rfc1035.html#section-4.2>
- RFC 7766, required TCP support, reuse, bounded connection management,
  retry, response reordering, and framing:
  <https://www.rfc-editor.org/rfc/rfc7766.html>
- RFC 4254 section 7.2, `direct-tcpip` makes the SSH server connect to the
  specified target host and port:
  <https://www.rfc-editor.org/rfc/rfc4254.html#section-7.2>
- RFC 8484, DoH TLS/HTTP semantics and hostname/certificate bootstrap
  circularity: <https://www.rfc-editor.org/rfc/rfc8484.html>
- RFC 4035, DNSSEC-aware stub behavior and DO/CD/AD semantics:
  <https://www.rfc-editor.org/rfc/rfc4035.html>
- RFC 5952, canonical IPv6 text representation:
  <https://www.rfc-editor.org/rfc/rfc5952.html>
