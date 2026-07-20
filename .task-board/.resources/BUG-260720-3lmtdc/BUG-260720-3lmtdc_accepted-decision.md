# TASK-260715-18owh7 — Protocol v1 resource-limit exchange decision

Date: 2026-07-20
Status: decision record, ready for review (accountable architecture approval = reviewer acceptance of this task)
Wire version: relay protocol v1 (frozen binding: TASK-260715-111tde, accepted)
Milestone class: M0 injectable baselines with documented rationale; final tuning is an explicit M3 evidence gate (STORY-260715-1zzt0c, STORY-260715-19ii11)

## 1. The conflict this task resolves

`.spec/relay-protocol.md` §Resource limits and behavior requires:

> "Maximum frame, association count, queued bytes, datagram size, and idle
> timeout are negotiated/capped and included in diagnostics."

Protocol v1 as frozen by TASK-260715-111tde exchanges only two of those
concepts. Client hello (12 bytes): `magic[4]="RLXR" | version:u16=1 | flags:u16
| maxFrame:u32`. Server hello (16 bytes): `magic[4]="RLXR" | version:u16 |
status:u16 | features:u32 | maxFrame:u32`. Nothing else about resources is on
the wire, and the hello sizes are exact — extension bytes are illegal.

`.spec/security-privacy.md` independently requires:

> "The relay validates address families, lengths, association IDs, and datagram
> limits before opening or using sockets." and "Malformed packet, SOCKS, SSH
> channel, or relay frames are rejected within bounded memory and do not become
> arbitrary allocations."

The binding ADR (§4.2) deliberately left a typed slot: *"The broader
resource-limit result is represented in both languages as `RelayEffectiveLimits`.
Its exact fields/values and whether they are fixed local caps or a feature-gated
post-hello exchange are inserted only by the accepted TASK-260715-18owh7
decision."* This record fills that slot.

## 2. Facts, assumptions, and compatibility consequences

### 2.1 Facts (verified in-repo)

- F1. The v1 hellos are exactly 12/16 bytes; reserved client flags, extended
  hello bytes, and unknown pre-hello stdout are rejected (binding §4.2). Any
  hello growth is a v1-incompatible edit (binding §6).
- F2. The v1 `UDP_ERROR` vocabulary already contains unilateral-enforcement
  codes: `0x0004` association limit, `0x0005` datagram too large, `0x0006`
  queue saturated, `0x0009` idle expiry, `0x000A` resource limit. The frozen
  error surface presumes each peer may reject work without peer agreement.
- F3. Pinned HEV caps the UDP-in-TCP copy path at `UDP_BUF_SIZE = 1500` bytes
  per message (`.temp/TASK-260715-uopycx/hev-socks5-tunnel/src/core/src/`
  `hev-socks5-udp.c:26`). In `hev_socks5_udp_recvmmsg_tcp` a record whose
  `datlen > 1500 − addrlen` returns `-1` — a stream-fatal error, not a drop
  (`hev-socks5-udp.c:203-206`). `addrlen` is 7 (IPv4) or 19 (IPv6). So the
  relay→client reply path physically cannot deliver a UDP payload above
  1481 bytes (IPv6 source) without killing the HEV session, and HEV stays
  unmodified by ADR-020 (config-only policy).
- F4. The tunnel-side fwd path also uses stack copy buffers of
  `UDP_BUF_SIZE × udp-copy-buffer-nums` with `udp-copy-buffer-nums = 2` as the
  ADR-020 M0 baseline (`hev-socks5-session-udp.c:114`).
- F5. The iOS extension steady-state memory target is 25–30 MiB
  (`.spec/packet-plane.md` §Memory budget); ADR-009 counts relay buffers inside
  that single budget. HEV `max-session-count` baseline is 1200 (TCP + UDP).
- F6. Deployment couples peer versions: the client uploads and
  SHA-256-verifies the relay binary named by its own bundled manifest and runs
  an identity preflight before the stdio session (binding §4.1,
  `.spec/relay-protocol.md` §Deployment). A conforming client never opens a v1
  session against a relay build it did not itself pin. Version skew between
  peers is therefore an already-rejected state, not a live migration scenario.
- F7. No v1 peer has shipped; the protocol is greenfield. "Old peer" below
  means "any conforming implementation of the frozen v1 binding".
- F8. QUIC defaults to a forced TCP fallback (ADR-010), so baseline UDP
  traffic is dominated by DNS, STUN/TURN, RTP/WebRTC, NTP, and game
  datagrams; these are overwhelmingly ≤ ~1200 bytes on the public internet.
- F9. `maxFrame` counts the envelope body (type through payload), excludes the
  4-byte prefix, and is already validated by both peers against "the protocol
  minimum and its injected local hard cap" (binding §4.2) — the minimum and
  hard cap values were unassigned until this record.

### 2.2 Assumptions (each individually marked)

- A1. Exit hosts provide at least the common Linux default of 1024 soft file
  descriptors to the relay process. (Mitigated: the association baseline keeps
  worst-case relay FD usage ≤ ~260.)
- A2. UDP replies larger than 1472 bytes (mostly large-EDNS DNS answers) are
  rare after DNS Flag Day 2020 (de-facto 1232-byte EDNS default). Not proven
  for this user population — measured in M3 via the oversized-reply drop
  counter (§7).
- A3. Applications that emit UDP datagrams above 1472 bytes into an 8500-MTU
  tunnel are rare and tolerate loss (UDP contract). Measured in M3 via the
  packet-plane "maximum observed datagram size" metric and the adapter
  oversized-inbound counter.

### 2.3 Compatibility consequences

- Because of F1, any limit exchange placed *in* the hello is v1-incompatible.
- Because of F2, unilateral local caps are already expressible in frozen v1
  error semantics with no new wire surface.
- Because of F3, the datagram ceiling is not free to negotiate upward: no
  negotiated value above 1481 is deliverable to the client at all while HEV
  stays pinned. A negotiation mechanism for this value would negotiate over a
  physically closed range.
- Because of F6+F7, both peer binaries always ship from one repository with
  shared generated constants (TASK-260715-2azda7); fixed schema constants are
  automatically consistent across a conforming pair.

## 3. Option comparison (AC2)

| Option | Old-peer behavior | Safety | Complexity | Vector impact | Rollout |
| --- | --- | --- | --- | --- | --- |
| **A. Fixed v1 schema constants + unilateral local caps (chosen)** | Zero new wire bytes; a conforming v1 peer sees byte-identical streams; nothing to misparse | Hard caps enforced locally on both sides regardless of peer claims; fail-closed on breach via existing F2 error codes | Lowest: no new states, frames, or timers | Boundary vectors only (existing message types at limit edges) | Immediate; values injectable, retune without wire change |
| B. Feature-gated post-hello `LIMITS` exchange (compatible v1 edit per binding §6) | Safe if gated on a new flag/feature bit; an old server rejects an unknown client flag with status `0x0002` (fail-closed, no misparse) | No safety gain: advertised limits are unverifiable claims, so local hard caps remain mandatory anyway (AC4 invariant); adds a lying-peer surface | New handshake phase, new frame, new state-machine states, ordering rules pre-traffic | New message type, new negative vectors, new fuzz surface | Needs both peers upgraded; buys only optimization (client-side early drop instead of relay-side drop) with zero M0 evidence of need |
| C. Hello extension (append limit fields to the 12/16-byte hellos) | **Misparse**: an old server reads exactly 12 bytes; appended bytes are consumed as the next frame's `frameLength:u32`, producing a garbage length and a session-fatal close at best | Fail-closed only by accident of framing; violates frozen exact hello sizes | Moderate | Full handshake vector rewrite | v1-incompatible edit; binding §6 forbids it without a version bump — rejected |
| D. Protocol v2 with limit fields in the hello | Clean version gate: old peer answers status `0x0001` unsupported version; no misparse | Same as B plus version-negotiation rules ("never guesses a lower framing format" — so a v2-only client cannot fall back) | Highest: parallel schema, parallel vectors, dual-version peers | Full parallel corpus | Absurd cost for a greenfield protocol whose peers are version-locked pairs (F6/F7) — rejected for M0; remains the correct vehicle if a future limit ever must be truly negotiated and B is insufficient |

**Decision: Option A for M0**, with a *reserved, compatible upgrade path to
Option B*: hello flag bit 1 + server feature bit 1 (working name
`resourceLimitExchange`) and envelope message-type range `0x40–0x4F` are
reserved in the schema for resource governance. They are names in the reserved
ranges only — no M0 implementation sets, accepts, or emits them; allocation
requires a future schema revision justified by M3 evidence (§7).

Why A wins: negotiation adds wire/state/fuzz surface but no safety (hard caps
must stay local regardless — a peer's advertised limit is an unverifiable
claim); the only limit where peer agreement prevents a *fatal* condition is
`maxFrame`, and v1 already negotiates it; the datagram ceiling is
HEV-pinned (F3) so there is nothing to negotiate; and every number here is an
M0 baseline expected to move in M3 — freezing wire semantics around unproven
numbers is the worst of both worlds. This is not implementation convenience:
options B–D were each evaluated against the frozen binding rules above.

## 4. Selected contract (AC3)

All wire integers remain unsigned big-endian (network byte order). Exactly one
resource limit is on the wire (`maxFrame`, already in the frozen hellos). One
is a fixed v1 wire constant (`maxUDPPayload`). Everything else is a unilateral
local cap with schema-owned name, default, floor, and hard ceiling. "May
lower" identifies the only permitted direction of runtime/config influence;
nothing may ever be raised above a hard ceiling by any input, wire or local.

### 4.1 Negotiated wire value

| Name | Wire location | Byte order/width | Default advertised | Protocol floor | Hard ceiling | Invalid value | Who may lower |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `maxFrame` | Client hello bytes 8–11, server hello bytes 12–15 | u32 BE | 4096 | 2048 | 65536 | Server: status `0x0002` + close; client: close with stable local reason (`unreasonableMaxFrame`) | Either peer via its advertisement; effective = min(client, server), each additionally clamped to its injected local hard cap before any body-sized allocation |

- Floor rationale: the largest legal v1 frame body is
  `6 + 255 + 1472 = 1733` bytes (envelope header + max HEV record: `HDRLEN`
  max 255, `MSGLEN` max 1472). Floor 2048 is the smallest power of two above
  it, so **every accepted hello can carry every legal v1 frame** — no
  mid-session "negotiated frame too small" state exists.
- Default rationale: 4096 gives ~2.4× headroom over 1733, matches the HEV
  `tcp-buffer-size` 4096 baseline, and bounds one decoder body buffer to one
  small allocation.
- Ceiling rationale: 65536 bounds the worst per-frame allocation a hostile or
  buggy peer can induce even before type-specific validation; per-type payload
  rules (fixed control sizes, HEV record arithmetic) bound accepted frames far
  lower in practice.

### 4.2 Fixed v1 wire constant

| Name | Value | Class | Who may lower |
| --- | --- | --- | --- |
| `maxUDPPayload` (ceiling on `MSGLEN`, the UDP data bytes in a `UDP_DATAGRAM`) | **1472 bytes** | Fixed v1 wire constant, schema-owned, compiled into both peers via generated constants; **not a wire field** | Either peer locally, config floor 512 (classic DNS payload); raising above 1472 is a v1-incompatible edit requiring the reserved feature gate or a version bump |

Derivation (both bounds are load-bearing):

1. HEV bound (F3): reply-path records must satisfy
   `addrlen + MSGLEN ≤ 1500` inside pinned HEV, worst case IPv6 `addrlen = 19`
   → `MSGLEN ≤ 1481`, and exceeding it is *HEV-stream-fatal*, not a drop.
2. Internet bound: 1472 = 1500 − 20 (IPv4) − 8 (UDP) is the largest payload
   that leaves the exit host unfragmented on a standard 1500-MTU egress.

1472 satisfies both with a 9-byte margin under the HEV bound and is the
standard, explainable number. The tunnel MTU hypothesis (8500, ADR-015) does
not move this ceiling: datagrams above it cannot transit pinned HEV reliably in
either direction (F3/F4), independent of tunnel MTU.

Enforcement is split into **violation** vs **policy**:

- `MSGLEN > 1472` — protocol violation by a nonconforming peer. The complete
  envelope and nonzero association ID are trustworthy, so per binding §4.3 it
  is association-fatal: the relay sends `UDP_ERROR 0x0005` then
  `CLOSE_ASSOCIATION`; the client (on an oversized reply) closes the
  association with `CLOSE_ASSOCIATION` and counts it.
- `localCap < MSGLEN ≤ 1472` where a peer lowered its own cap — policy drop,
  association survives. Relay inbound: drop + `UDP_ERROR 0x0005` (no close).
  Client outbound: local drop + counter before any wire bytes. Relay reply
  direction (socket → client): silent counted drop — the relay receives into a
  `localMaxUDPPayload + 1`-byte buffer, detects overflow/truncation, drops,
  increments `oversizedReplyDropped`; no error frame, because reply loss is
  ordinary UDP semantics and an external sender must not be able to drive the
  error channel.
- Client-side HEV ingress: an inbound HEV record from lwIP with
  `datlen > 1472` (possible with large tunnel MTU) is discarded by the Swift
  adapter with a bounded skip (never buffered whole, never framed to the
  relay) and counted (`hevOversizedInbound`).

### 4.3 Unilateral local caps (schema-owned defaults, injectable)

Every value below is a named schema constant (class `localCap`) with
`{default, floor, hardCeiling}`; runtime injection may pick any value in
`[floor, hardCeiling]`; outside that range the process fails closed at startup
(§4.5). Client and relay defaults differ deliberately; each peer owns its own
values and never learns the peer's (M0 has no exchange).

| Name | Client default | Relay default | Floor | Hard ceiling | Breach behavior |
| --- | --- | --- | --- | --- | --- |
| `maxAssociations` (concurrent, per session generation) | 256 | 256 | 1 | 1024 | Relay: reject opening datagram, `UDP_ERROR 0x0004`, no state admitted. Client: typed fast local failure to HEV before any wire bytes |
| `perAssociationQueuedBytes` (per direction) | 32 KiB | 64 KiB | 4 KiB | 256 KiB | Drop newest frame for that association + counter; `0x0006` edge-triggered (below) |
| `aggregateQueuedBytes` (per direction, whole session) | 1 MiB | 4 MiB | 64 KiB | client 4 MiB / relay 16 MiB | Drop newest + counter; never blocks the SSH pump or stdio loop, never an unbounded side buffer |
| `controlReservedBytes` (carve-out of aggregate for PING/PONG/UDP_ERROR/CLOSE) | 16 KiB | 64 KiB | 4 KiB | 256 KiB | Control credit exhausted → the terminal close path still proceeds (close needs no queue growth); excess non-terminal control work is dropped + counted |
| `dnsPriorityWeight` : ordinary weight | 4 : 1 | 4 : 1 | 1 : 1 | 16 : 1 | Weighted round-robin; DNS priority is starvation-free scheduling only, never extra admission credit (binding §4.3) |
| `idleTimeout` (no admitted datagram in either direction) | 60 s | 120 s | 10 s | 600 s | Relay: `UDP_ERROR 0x0009` when safe → retire state → `CLOSE_ASSOCIATION` (binding §4.5). Client: `CLOSE_ASSOCIATION`, retire on observed close |

Rationale:

- `maxAssociations = 256`: covers DNS plus aggressive multi-app UDP (VoIP,
  WebRTC, several games) with large margin; keeps relay worst-case FDs
  (256 sockets + stdio + internals) far below the 1024 nofile assumption (A1);
  256 UDP sessions leave HEV's 1200 `max-session-count` dominated by TCP (F5).
  Ceiling 1024 stays under both bounds even if an operator maxes the config.
- Queued-byte defaults: client worst case is
  2 directions × 1 MiB = 2 MiB of relay queue memory, a bounded, testable
  slice of the 25–30 MiB budget next to SSH windows and HEV sessions
  (ADR-009 ledger, F5); hard ceiling 4 MiB/direction bounds even a
  worst-config client at 8 MiB. The relay defaults (4 MiB/direction) absorb
  exit-host bursts cheaply; ceiling 16 MiB/direction keeps a maxed relay ~32
  MiB — polite on a shared user host (`.spec/security-privacy.md` §Abuse
  boundaries).
- Per-association 32/64 KiB ≈ 22/44 max-size datagrams: enough for a burst,
  small enough that one association cannot monopolize the aggregate.
- Byte accounting: each queued frame charges
  `max(4 + frameLength, 64)` bytes (prefix + body, floored) against both the
  per-association and aggregate budgets, so floods of tiny datagrams cannot
  evade byte accounting through per-entry overhead. Reservation is
  atomic-before-enqueue and released exactly once on every terminal path
  (matches TASK-260715-z37ay7 AC2).
- `0x0006` emission is edge-triggered: at most one `UDP_ERROR 0x0006` per
  association per saturation episode; an episode ends when that association's
  queue drains to ≤ 50% of `perAssociationQueuedBytes`. Drops themselves are
  always counted; the error frame is a bounded signal, not a per-drop echo
  (prevents error-channel amplification under flood).
- `idleTimeout`: relay 120 s honors the RFC 4787 REQ-5 floor for UDP mappings
  (real apps keepalive at 15–25 s; DNS completes in seconds). Client 60 s is
  deliberately shorter so the client normally closes first, shrinking the
  crossed-expiry window in which a late client datagram would implicitly
  reopen an association the relay just retired; that race remains safe and
  self-healing either way (the orphan reopened association is reaped by the
  relay's own idle timer), the stagger just makes it rare. The `client ≤
  relay` stagger is a convention, not a cross-peer invariant — M0 cannot
  enforce it without an exchange, and correctness does not depend on it.

### 4.4 Validation-before-socket order (normative)

Relay, client→destination direction (each step fails closed; no resolver or
socket call before step 8):

1. Read 4-byte prefix into fixed storage; `frameLength ∈ [6, effectiveMaxFrame]`
   else session-fatal.
2. Type/flags/direction/associationID legality (binding §4.3) else
   session-fatal.
3. Association admission: existing ID → activity credit; new ID →
   `activeAssociations < maxAssociations` else `0x0004`, no state admitted.
4. HEV record structural validation: `HDRLEN` vs `ATYP` arithmetic, outer
   payload `== HDRLEN + MSGLEN`, port ≠ 0, address-form bounds.
5. `MSGLEN ≤ 1472` else violation path (`0x0005` + close, §4.2);
   `MSGLEN ≤ localMaxUDPPayload` else policy drop (`0x0005`).
6. Domain names: resolver-form acceptance rules (binding §4.4) — still no
   resolver call.
7. Queue credit: atomic reserve against per-association + aggregate +
   class budgets else drop (+ edge-triggered `0x0006`).
8. Only now: create/select socket, resolve, send (TASK-260715-xw5dxc /
   TASK-260715-3xpc6b ownership).

Relay, reply direction: bounded `recv` into `localMaxUDPPayload + 1` buffer →
oversize = silent counted drop → association still open? → queue credit →
frame emit by the single stdout writer. The client mirrors the same order
against its own caps before handing bytes to HEV, with one extra HEV-fatality
rule: the Swift adapter never writes a record whose `addrlen + datlen` exceeds
1500 into the HEV stream, because pinned HEV treats that as stream-fatal (F3).
The 1472 constant makes this bound hold by construction for every conforming
reply (worst case `19 + 1472 = 1491 ≤ 1500`); a nonconforming oversized reply
is already association-fatal at step 5 and never reaches the HEV write.

### 4.5 Invalid configuration and runtime breach

- Injected config outside `[floor, hardCeiling]` for any limit: **fail-closed
  at startup**. Relay: exit nonzero before emitting any hello byte, with a
  bounded stderr diagnostic. Client: typed provider start failure. No silent
  clamping — a clamped limit hides an operator error and falsifies
  diagnostics.
- Runtime breach is always drop/reject + aggregate counter, never blocking,
  never unbounded retry, never allocate-then-check (F2 codes; §4.3 table).
- Hello `maxFrame` outside `[2048, 65536]`: server answers status `0x0002`
  and closes; client closes with a stable local reason and enters the
  degraded-capability path. No downgrade guessing.

### 4.6 `RelayEffectiveLimits` (typed slot from the binding, both languages)

One immutable snapshot per session generation, derived at handshake
completion; every field is `min(schema default-or-constant, injected config)`
plus the negotiated `maxFrame`:

```text
RelayEffectiveLimits {
  effectiveMaxFrame:            u32   // min(ours, peer's, local hard cap)
  maxUDPPayload:                u16   // min(1472, local config)
  maxAssociations:              u32
  perAssociationQueuedBytes:    u32
  aggregateQueuedBytes:         u32
  controlReservedBytes:         u32
  dnsPriorityWeight:            u8    // : 1 ordinary
  idleTimeoutMilliseconds:      u32
}
```

Local-only (never serialized to the peer in M0). The Swift instance feeds the
session pump, association registry, and the capability snapshot
(TASK-260715-3edgwz AC2 "effective limits"); the Go instance feeds
`relay/internal/udp/` admission and scheduling.

### 4.7 Diagnostics

- At generation start, both peers log configured + effective limit values
  (explicitly permitted by binding §5 and `.spec/security-privacy.md`
  §Diagnostics).
- Aggregate reason counters (no per-destination dimensions):
  `associationRejected (0x0004)`, `oversizedDatagramRejected (0x0005)`,
  `oversizedReplyDropped`, `hevOversizedInbound`, `queueSaturatedDropped
  (0x0006)`, `idleExpired (0x0009)`, `resourceLimitRejected (0x000A)`, plus
  queue high-water occupancy per class and max concurrent associations.
  These counters are the M3 evidence feed (§7).
- Raw peer-supplied numbers never become log strings or metric dimensions
  (binding §5).

## 5. Old-peer and hard-cap proofs (AC4)

**No v1 peer can misparse extended bytes, because there are none.** M0 adds
zero bytes anywhere on the wire: hellos remain exactly 12/16 bytes, no new
message type, flag, feature bit, or error code is *emitted* by any M0
implementation. The reserved names (`flag bit 1`, `feature bit 1`,
`0x40–0x4F`) exist only in the schema's reserved ranges; a conforming v1 peer
that ever received them would follow the already-frozen fail-closed rules —
reserved client flag → status `0x0002` + close; unnegotiated message type →
session-fatal — which are deterministic rejections, not misparses. Option C
was rejected precisely because it is the only option with a real misparse
(appended hello bytes reinterpreted as a garbage `frameLength`). Deployment
coupling (F6) additionally makes a mixed-version pair unreachable: a client
only speaks to the relay build its own manifest pinned and verified.

**Neither peer can allocate or admit work above its local hard cap.** No limit
value crosses the wire except `maxFrame`, and `maxFrame` is validated against
the protocol floor and the local injected hard cap *before any body-sized
allocation* (binding §4.2, §4.4 order above); its wire influence is
lower-only (`min` rule). Every other limit is derived exclusively from
`min(schema constant/default, local config)` — there is no wire input to
raise anything, and config inputs above a hard ceiling kill the process at
startup instead of running with them (§4.5). Queue admission is
reserve-before-enqueue with single release; association admission is
check-before-state; datagram validation completes before resolver/socket use
(§4.4). A lying or hostile peer can therefore, at worst, waste its own credit
— it cannot move any local bound.

## 6. Downstream impact map by concrete ID (AC5)

Direct blocks (already linked on the board; unchanged):
`TASK-260715-2azda7`, `TASK-260715-22gz6h`, `TASK-260715-xw5dxc`,
`TASK-260715-z37ay7`, `TASK-260715-3edgwz`. All other consumers receive the
values transitively through the generated schema (2azda7 → 1y1g1u/89h7cw/516lhy
→ 1jvgcn → 1q7u14 → 297gq6 → 2z9b4a), so no new dependency links are required;
notes were added to each task below.

| Task | What it consumes from this decision |
| --- | --- |
| `TASK-260715-2azda7` (schema/constants) | New schema `limits` section: per-limit `{name, class ∈ negotiatedWire/fixedWireConstant/localCap, width, unit, default, floor, hardCeiling}` for every §4.1–§4.3 row; reserved flag bit 1, feature bit 1, message types `0x40–0x4F` (resource governance); validation must reject defaults outside `[floor, ceiling]` and any edit to a `fixedWireConstant` without a version/feature gate |
| `TASK-260715-1y1g1u` (handshake) | `maxFrame` accept range `[2048, 65536]`, default advertisement 4096, out-of-range behavior (server `0x0002`/client `unreasonableMaxFrame` close), effective-min rule, `RelayEffectiveLimits` construction at handshake completion |
| `TASK-260715-89h7cw` (envelope codec) | `frameLength ∈ [6, effectiveMaxFrame]` with hard cap clamp before allocation; max legal body 1733 |
| `TASK-260715-516lhy` (HEV payload codec) | `MSGLEN ≤ 1472` structural ceiling; violation-vs-policy split; bounded-skip discard rule for oversized HEV-ingress records (`hevOversizedInbound`) |
| `TASK-260715-1jvgcn` (session semantics) | Violation vs policy dispositions for `0x0005`; edge-triggered `0x0006` contract; `0x0009` idle-expiry sequence |
| `TASK-260715-1q7u14` (vectors) | Boundary vectors: MSGLEN 1472 accept / 1473 violation; frame body 1733 accept / 1734 reject at floor; hello `maxFrame` 2047 reject / 2048 accept / 65536 accept / 65537 reject; limits metadata references schema constants, never literal copies |
| `TASK-260715-297gq6` (conformance/fuzz) | Cross-language equivalence at every §4.4 enforcement step; fuzz must prove no allocation above effective `maxFrame` and no socket call before step 8 |
| `TASK-260715-2z9b4a` (docs) | Publish §4 tables, violation-vs-policy split, M3 evidence gates, reserved upgrade path |
| `TASK-260715-22gz6h` (client registry) | `maxAssociations` local admission (typed fast failure, no wire bytes), client 60 s idle GC + stagger rationale, allocator-search ceiling independent of this decision |
| `TASK-260715-xw5dxc` (relay registry) | `maxAssociations` check-before-socket (`0x0004`), relay 120 s idle expiry (`0x0009` → retire → close), per-association socket-buffer sizing stays relay-local config |
| `TASK-260715-z37ay7` (limits/fairness) | Whole §4.3 table incl. `controlReservedBytes`, `dnsPriorityWeight` 4:1 WRR, `max(frame, 64)` charge rule, atomic reserve/release, edge-triggered `0x0006`, reply-direction silent drop |
| `TASK-260715-3xpc6b` (validation gate) | §4.4 numbered order is the normative pre-socket sequence |
| `TASK-260715-3edgwz` (capability snapshot) | `RelayEffectiveLimits` field list (§4.6) versioned into the snapshot schema |
| `STORY-260715-1zzt0c` / `STORY-260715-19ii11` (M3) | §7 evidence gates and the counter list in §4.7 |

## 7. M3 evidence gates (explicit)

Every numeric value in §4 is an M0 baseline, injectable end-to-end; none is
final. Final tuning is gated on physical-device instrumentation
(STORY-260715-19ii11) and the memory-ledger story (STORY-260715-1zzt0c):

- G1. `maxUDPPayload` sufficiency: `oversizedReplyDropped` +
  `hevOversizedInbound` + packet-plane max-observed-datagram-size decide
  whether 1472 hurts real traffic. Raising it requires an HEV fork decision
  (packet-plane fork policy) — it is HEV-bound, not negotiation-bound.
- G2. `maxAssociations` and queue budgets: high-water counters vs the 25–30
  MiB ledger under real multi-app load.
- G3. Idle timers: `idleExpired` rate vs app keepalive reality (REQ-5
  tension) on physical devices.
- G4. Whether the reserved `resourceLimitExchange` feature is worth allocating
  at all: only if measurements show material waste from client-side late
  drops that peer-limit knowledge would avoid. Until then the reservation
  stays a name.

## 8. Approval and ADR entry

Accountable architecture approval = reviewer acceptance of this task
(TASK-260715-18owh7 → review). Until accepted, this task remains the sole
explicit blocker for `TASK-260715-2azda7`, `TASK-260715-22gz6h`,
`TASK-260715-xw5dxc`, `TASK-260715-z37ay7`, `TASK-260715-3edgwz`.

Proposed decision-log row for `.spec/decisions.md` (to be committed on
acceptance, per repo convention):

> | ADR-021 | Accepted | Keep protocol v1 resource limits as fixed schema
> constants and unilateral local caps (no wire exchange beyond the existing
> `maxFrame` min-negotiation): `maxUDPPayload` frozen at 1472 by the pinned
> HEV 1500-byte UDP copy-buffer bound; association/queue/idle values are
> injectable M0 baselines with schema-owned floors and hard ceilings; hello
> flag bit 1, feature bit 1, and message types `0x40–0x4F` reserved for an
> evidence-gated M3 limits exchange (TASK-260715-18owh7) |

## 9. Artifacts

- This record: `.task-board` resource `TASK-260715-18owh7_decision.md`.
- Diagram (enforcement order, both directions):
  `diagrams/TASK-260715-18owh7_limit-enforcement-points.puml`, validated and
  rendered with PlantUML 1.2026.6/Smetana to
  `diagrams/artefacts/TASK-260715-18owh7_limit-enforcement-points.svg`.
- Diagram (limit classes and ownership):
  `diagrams/TASK-260715-18owh7_limit-ownership.dot` — source authoritative;
  the workstation Graphviz `dot` still lacks `libltdl.7.dylib` (known since
  TASK-260715-111tde) and PlantUML's `@startdot` path shells out to that same
  broken binary, so no rendered artifact is produced for it.
