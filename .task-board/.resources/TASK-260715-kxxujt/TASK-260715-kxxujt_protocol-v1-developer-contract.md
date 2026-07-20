# Relay protocol v1 developer contract

Task: `TASK-260715-2z9b4a` — Document protocol compatibility, limits, and change gates  
Date: 2026-07-20  
Status: developer handoff, pending review  
Wire version: 1  
Schema SHA-256: `3dd1bc9d8d0c1f9127cad05913137754da61d2657e8d0b8c0b30108e331e8000`  
Canonical vector count/SHA-256: 89 / `e21e6ff50042bd982e8284b579e89a24e66c3437a9b701687ecf707fc57e6e76`

## 1. Purpose, authority, and non-scope

This is the developer-facing contract for relay protocol v1 after schema,
Swift/Go parity, canonical-vector, hostile-input, and conformance acceptance. It
consolidates the accepted behavior without changing it.

Authority, in descending order for generated wire facts and accepted behavior:

1. `Protocol/Relay/relay-v1.schema.json` and its checked-in generated Swift and
   Go outputs;
2. accepted ADR-005, ADR-006, ADR-021 and the accepted task decisions
   `TASK-260715-111tde` and `TASK-260715-18owh7`;
3. the independent canonical corpus in `Protocol/Relay/Vectors/v1/corpus.json`;
4. the paired Swift/Go handwritten codecs, handshake, and session state
   machines validated by `TASK-260715-297gq6`.

If this document and a generated artifact disagree, the schema and regenerated
outputs win and this document must be corrected. This document does not define
user help, remote installation instructions, UDP socket internals, final
supply-chain policy, protocol v2, or permission to alter accepted v1 behavior.

All multi-byte wire integers are unsigned big-endian (network byte order).
Checked conversion precedes indexing, slicing, allocation, resolution, socket
use, or queue admission.

## 2. Process identity preflight and protocol session

Build identity is deliberately outside the v1 hello. After authenticated SSH
and remote-file verification, bootstrap opens a separate exec channel for:

```text
<verified-path>/relux-relay --identity --protocol 1
```

Success is exactly one canonical JSON line, at most 512 bytes including LF,
EOF, and exit status zero. The fixed keys are `schemaVersion`,
`relayProtocolVersion`, `relayVersion`, `sourceCommit`, `os`, `arch`, and
`selfSha256`. Values are bounded: schema/protocol version 1, semantic relay
version, 40 lowercase hexadecimal commit characters, `linux|darwin`,
`amd64|arm64`, and 64 lowercase hexadecimal SHA-256 characters. Unknown keys,
extra stdout, invalid values, overflow, nonzero exit, or manifest mismatch
reject the asset/session. Stderr is bounded redacted diagnostics and never
identity evidence. Identity is bootstrap evidence, not a protocol frame and
not a substitute for remote-file SHA-256 verification.

Only after identity matches does bootstrap open the long-lived channel:

```text
<verified-path>/relux-relay --stdio --protocol 1
```

Its stdout is exclusively hello plus framed protocol bytes. Its stdin is
exclusively client hello plus framed protocol bytes. Stderr remains a separate
bounded diagnostic stream. No SFTP or shell secret belongs to this contract.

## 3. Hello wire layout and state

### 3.1 Client hello: exactly 12 bytes

| Byte offset | Field | Width | Value/meaning |
| ---: | --- | ---: | --- |
| 0 | `magic` | 4 | ASCII `RLXR`, bytes `52 4c 58 52` |
| 4 | `version` | 2 | `0x0001` |
| 6 | `flags` | 2 | Client request bits; reserved bits zero |
| 8 | `maxFrame` | 4 | Advertised maximum envelope body, `[2048, 65536]` |

### 3.2 Server hello: exactly 16 bytes

| Byte offset | Field | Width | Value/meaning |
| ---: | --- | ---: | --- |
| 0 | `magic` | 4 | ASCII `RLXR`, bytes `52 4c 58 52` |
| 4 | `version` | 2 | `0x0001` |
| 6 | `status` | 2 | Finite status below |
| 8 | `features` | 4 | Accepted feature subset; reserved bits zero |
| 12 | `maxFrame` | 4 | Server advertisement, `[2048, 65536]` |

| Value | Status | Client consequence |
| ---: | --- | --- |
| `0x0000` | `ACCEPTED` | Validate features and limits, then publish the generation |
| `0x0001` | `UNSUPPORTED_VERSION` | Stable `unsupportedVersion`; close session; no downgrade guess |
| `0x0002` | `INVALID_CLIENT_HELLO` | Stable `invalidClientHello`; close session |
| `0x0003` | `RESOURCE_POLICY_REJECTED` | Stable `resourcePolicyRejected`; close session |
| `0x0004` | `RELAY_UNAVAILABLE` | Stable `relayUnavailable`; close session/degrade capability |
| other nonzero | Unknown rejection | Stable `relayRejected`; close session; raw value is not telemetry |

The client sends first. The server emits no envelope before accepting the full
client hello. The client publishes no usable session before accepting the full
server hello. Unknown magic, unsupported version, nonzero server status,
reserved client flag, impossible feature selection, unreasonable `maxFrame`,
timeout, EOF, duplicate/extended hello, or extra pre-hello stdout closes the
channel with a stable privacy-safe reason. There is no downgrade guessing.

Handshake ownership at the fixed boundary is exact:

- a read ending exactly at byte 12 or 16 publishes success immediately;
- a coalesced legal envelope remainder is handed to the envelope decoder;
- a coalesced remainder beginning with any available prefix of `RLXR` is
  rejected as `duplicateHello` before success is published;
- an `RLXR` prefix first received in a later read is post-handshake envelope
  input and closes the session through the normal framing path.

### 3.3 Feature negotiation

| Surface | Bit | Name | v1 status | Rule |
| --- | ---: | --- | --- | --- |
| Client hello flags | 0 | `dnsPriorityHint` | Allocated | Client requests capability |
| Server features | 0 | `dnsPriorityHint` | Allocated | Server confirms only if requested and supported |
| Envelope flags | 0 | `dnsPriority` | Allocated | Client-to-relay `UDP_DATAGRAM` only, after bit-0 negotiation |
| Client hello flags | 1 | `resourceLimitExchange` | Reserved | M0 must not set or accept |
| Server features | 1 | `resourceLimitExchange` | Reserved | M0 must not return or accept |
| Message types | `0x40–0x4F` | Resource governance | Reserved | M0 must not emit or accept |

The server feature set must be a subset of the client request and the server's
supported set. Every other bit is reserved zero. `dnsPriority` becomes sticky
for the association; changing it is rejected. The client derives it only from
the tunnel-owned DNS association. It affects bounded starvation-free scheduling
only: never authorization, admission, caps, error privilege, or logging.

## 4. Envelope and message contract

One ordered byte stream follows the hello. SSH read boundaries have no protocol
meaning; the decoder accepts every split and multiple frames per read.

| Byte offset | Field | Width | Length meaning |
| ---: | --- | ---: | --- |
| 0 | `frameLength` | 4 | Bytes from `type` through the end of payload; excludes this prefix |
| 4 | `type` | 1 | Generated message value |
| 5 | `flags` | 1 | Bit 0 only as negotiated above; bits 1–7 zero |
| 6 | `associationID` | 4 | Client-owned nonzero ID or zero as table requires |
| 10 | `payload` | `frameLength - 6` | Type-specific bytes |

`frameLength` must be at least 6 and no greater than both the effective
`maxFrame` and local hard cap. The decoder validates the four-byte prefix in
fixed storage before retaining or allocating a body. The largest legal v1 body
is 1733 bytes: 6 envelope bytes plus the 1727-byte maximum HEV record.

| Value | Name | Direction | Association ID | Flags | Payload and required behavior |
| ---: | --- | --- | --- | --- | --- |
| `0x10` | `UDP_DATAGRAM` | Both | Nonzero | Client→relay may use negotiated `dnsPriority`; otherwise zero | Exact HEV record in §5; first valid client datagram implicitly opens an association |
| `0x11` | `UDP_ERROR` | Relay→client | Nonzero | Zero | Exactly `code:u16`; finite association error; no text |
| `0x20` | `PING` | Client→relay | Zero | Zero | Exactly 8 opaque token bytes |
| `0x21` | `PONG` | Relay→client | Zero | Zero | Exact 8-byte copy of PING token |
| `0x30` | `CLOSE_ASSOCIATION` | Both | Nonzero | Zero | Empty; retire/ack association idempotently |
| `0x31` | `CLOSE_SESSION` | Both | Zero | Zero | Empty; end the generation and all associations |

Unknown/unnegotiated message type, reserved/non-applicable flag, illegal
direction, illegal association ID, wrong fixed payload size, invalid
`frameLength`, truncated frame at EOF, or unrecoverable decoder state is
session-fatal. The peer closes the entire session generation; all associations
are cleaned up once. Remote bytes never become a log or UI string.

## 5. HEV UDP-in-TCP payload

`UDP_DATAGRAM` payload is exactly:

```text
MSGLEN:u16 | HDRLEN:u8 | ATYP:u8 | DST.ADDR:variable |
DST.PORT:u16 | DATA[MSGLEN]
```

| Field | Width | Contract |
| --- | ---: | --- |
| `MSGLEN` | 2 | UDP data length only; protocol ceiling 1472 |
| `HDRLEN` | 1 | Count from the first `MSGLEN` byte through `DST.PORT` |
| `ATYP` | 1 | `0x01` IPv4, `0x03` domain, `0x04` IPv6 |
| `DST.ADDR` IPv4 | 4 | `HDRLEN = 10` |
| `DST.ADDR` IPv6 | 16 | `HDRLEN = 22` |
| `DST.ADDR` domain | `1 + N` | One-byte `N`, then 1–248 opaque bytes; `HDRLEN = 7 + N` |
| `DST.PORT` | 2 | Unsigned big-endian; zero invalid for socket use |
| `DATA` | `MSGLEN` | Opaque UDP bytes; never fragmented by this protocol |

Outer envelope payload length must equal `HDRLEN + MSGLEN` exactly. A response
address/port is the source endpoint observed by the relay.

The codec preserves domain bytes and does not normalize, resolve, log, or add
IDNA. Before Go resolution/socket use, the UDP validation layer accepts only
ASCII DNS presentation form: total 1–248 bytes; labels 1–63; letters, digits,
and hyphen; no leading/trailing hyphen; at most one terminal dot. Unicode,
controls, NUL, empty interior labels, raw IP text, and invalid A-labels are
rejected. Callers supply punycode where needed.

Structural validation precedes the payload ceiling and local policy. A
trustworthy complete envelope with a nonzero association ID but malformed HEV
payload is association-fatal. No resolver or socket package is called by a
parser.

## 6. Association identity, errors, and close behavior

The client allocates nonzero `u32` IDs within one session generation. An
association opens implicitly on its first fully validated client datagram, and
the relay admits state only after validation and limit credit. Destinations are
per-datagram; association state is not authorization for later destinations.

ID lifecycle:

1. either peer may send `CLOSE_ASSOCIATION`;
2. that ID stops admitting datagrams and releases socket, queue, and timer state
   exactly once;
3. the receiver echoes one close only when needed to acknowledge an active
   peer-initiated close;
4. duplicate and crossed closes are idempotent;
5. the client reuses the ID only after relay close/ack proves old relay state is
   retired, or after the entire generation ends.

Idle expiry and an association-local terminal error send a finite `UDP_ERROR`
when safe, retire state, then close the association. Late replies are dropped
and counted. EOF, relay exit, framing failure, SSH lane loss, cancellation,
reset, or `CLOSE_SESSION` ends the generation and every association exactly
once. IDs never cross generations; late callbacks from an old generation are
ignored.

| Value | UDP error | Meaning | Default consequence |
| ---: | --- | --- | --- |
| `0x0001` | `INVALID_DATAGRAM` | Invalid datagram | Association-local reject/close as validated context permits |
| `0x0002` | `UNSUPPORTED_ADDRESS` | Unsupported address form | Association-local close |
| `0x0003` | `UNKNOWN_OR_CLOSED_ASSOCIATION` | ID is unknown/retired | Reject and close that ID without admitting state |
| `0x0004` | `ASSOCIATION_LIMIT` | Relay admission cap reached | Reject opening datagram; no state admitted; association remains unopened |
| `0x0005` | `DATAGRAM_TOO_LARGE` | Protocol violation or lowered policy cap | Split disposition in §7.2 |
| `0x0006` | `QUEUE_SATURATED` | Queue credit exhausted | Drop datagram; association survives; edge-triggered signal |
| `0x0007` | `RESOLUTION_FAILURE` | Resolver failure | Association-local terminal error/close when safe |
| `0x0008` | `SOCKET_FAILURE` | UDP socket failure | Association-local terminal error/close when safe |
| `0x0009` | `IDLE_EXPIRY` | Idle timer expired | Error when safe → retire → close association |
| `0x000A` | `RESOURCE_LIMIT` | Other finite resource rejection | Reject/close at the declared association scope |
| other | `unknownRelayError` | Future/unknown numeric code | One local association failure; raw value is not telemetry |

## 7. Resource limits and enforcement

### 7.1 Limit classes and effective values

| Name | Class | Width/unit | Client default | Relay default | Floor | Client hard ceiling | Relay hard ceiling | Peer advertised / effective rule |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| `maxFrame` | Negotiated wire | u32 bytes | 4096 | 4096 | 2048 | 65536 | 65536 | Both hellos advertise; effective = min(client, server), with each value validated against the local hard cap before body allocation |
| `maxUDPPayload` | Fixed v1 wire constant, not a field | u16 bytes | 1472 | 1472 | 512 | 1472 | 1472 | No peer value; local may lower only; raising above 1472 is incompatible without a feature/new version |
| `maxAssociations` | Local cap | u32 count | 256 | 256 | 1 | 1024 | 1024 | Never serialized in M0; local immutable snapshot |
| `perAssociationQueuedBytes` | Local cap, per direction | u32 bytes | 32 KiB | 64 KiB | 4 KiB | 256 KiB | 256 KiB | Never serialized in M0 |
| `aggregateQueuedBytes` | Local cap, per direction/session | u32 bytes | 1 MiB | 4 MiB | 64 KiB | 4 MiB | 16 MiB | Never serialized in M0 |
| `controlReservedBytes` | Local carve-out | u32 bytes | 16 KiB | 64 KiB | 4 KiB | 256 KiB | 256 KiB | Never serialized in M0 |
| `dnsPriorityWeight` | Local scheduling ratio | u8 ratio-to-one | 4:1 | 4:1 | 1:1 | 16:1 | 16:1 | Never serialized in M0; no extra admission credit |
| `idleTimeout` | Local cap | u32 milliseconds | 60,000 | 120,000 | 10,000 | 600,000 | 600,000 | Never serialized in M0; client≤relay is convention, not negotiated invariant |

Runtime/config injection may select only `[floor, hardCeiling]` and may never
raise a schema default/constant. Out-of-range configuration fails closed at
startup: nonzero relay exit before any hello byte, or typed provider-start
failure. There is no silent clamp. The only peer-controlled value is
`maxFrame`, and it is lower-only through `min` after range validation.

One immutable local-only `RelayEffectiveLimits` is created at handshake
completion for each generation:

```text
RelayEffectiveLimits {
  effectiveMaxFrame:         u32
  maxUDPPayload:             u16
  maxAssociations:           u32
  perAssociationQueuedBytes: u32
  aggregateQueuedBytes:      u32
  controlReservedBytes:      u32
  dnsPriorityWeight:         u8   // :1 ordinary
  idleTimeoutMilliseconds:   u32
}
```

Swift passes it to the session pump, association registry, and capability
snapshot. Go passes it to UDP admission and scheduling. It is never serialized
to the peer in M0.

### 7.2 Limit breach and saturation behavior

| Condition | Disposition | Close scope |
| --- | --- | --- |
| Hello `maxFrame < 2048` or `> 65536` | Server status `0x0002` then close; client uses stable `unreasonableMaxFrame` and closes/degrades | Session |
| Envelope length `< 6`, `> effectiveMaxFrame`, or `> local hard cap` | Reject before body-sized allocation | Session |
| `MSGLEN > 1472` from a peer | Protocol violation; relay emits `0x0005` then closes; client closes and counts oversized reply | Association |
| `localMaxUDPPayload < MSGLEN <= 1472` | Local policy drop; relay inbound may emit `0x0005`; client outbound drops before wire | None; association survives |
| Oversized socket reply | Receive into `localMaxUDPPayload + 1`, detect/truncate, silent counted drop | None; association survives |
| Oversized HEV ingress | Swift adapter bounded-skip discard; never frame whole record; increment `hevOversizedInbound` | None |
| New association above `maxAssociations` | Relay `0x0004`, no state/socket; client typed local failure before wire | None; association unopened |
| Per-association/aggregate/class queue credit exhausted | Drop newest; increment aggregate counter; never block or retry without bound | None; association survives |
| Control reservation exhausted | Terminal close proceeds without queue growth; excess nonterminal control work drops/counts | Terminal path remains available |
| Idle expiry | Relay `0x0009` when safe → retire → close; client sends close/retire on observed close | Association |

Each queued frame charges `max(4 + frameLength, 64)` bytes against both
per-association and aggregate budgets. Reservation is atomic before enqueue and
released exactly once. `0x0006` is edge-triggered at most once per association
per saturation episode; an episode ends at queue occupancy at or below 50% of
`perAssociationQueuedBytes`. DNS/ordinary work uses bounded starvation-free
weighted round-robin. Control close/error/health traffic has reserved bounded
credit. No queue, map, pool, side buffer, retry, or task/goroutine-per-datagram
may grow without a bound.

### 7.3 Normative validation-before-socket order

For client-to-relay datagrams:

1. read `frameLength` into fixed four-byte storage and require
   `[6, effectiveMaxFrame]`;
2. validate type, flags, direction, and association ID;
3. check existing association or reserve new association credit;
4. validate HEV structure, address arithmetic, exact lengths, and nonzero port;
5. enforce the 1472 protocol ceiling, then any lower local policy cap;
6. validate resolver-form domain bytes, still without resolution;
7. atomically reserve queue/class credit;
8. only now create/select a socket, resolve, and send.

Reply direction is bounded receive → oversize/truncation drop → active-state
check → queue reservation → single stdout writer. The client mirrors validation
before HEV delivery and never writes a record whose HEV address length plus UDP
data exceeds 1500. `19 + 1472 = 1491`, so every conforming IPv6 reply remains
under the pinned HEV fatal boundary.

## 8. Failure-scope table

| Failure class | Stable scope/disposition | Required consequence |
| --- | --- | --- |
| Unknown magic/version; reserved hello flags/features; impossible feature selection; malformed/truncated/extended/duplicate hello; unreasonable frame; timeout/EOF before hello | Session / `closeSession` | No usable generation; close channel; degrade through bootstrap/capability owner |
| Unknown message type, reserved/invalid flags, illegal direction/ID, impossible fixed payload size | Session / `closeSession` | End generation and all associations once |
| Frame prefix below minimum/above effective maximum; truncated body at EOF; unrecoverable decoder state | Session / `closeSession` | Fail before unbounded allocation; end generation |
| Trustworthy envelope and nonzero ID with malformed `HDRLEN`, address, port, or length arithmetic | Association / `closeAssociation` | Reject materialization/socket use; retire/close that ID |
| Protocol UDP payload >1472 | Association / `closeAssociation` | `0x0005` when safe, retire, close |
| Lower local UDP cap exceeded | Association / `rejectDatagram` | Drop/count; no association close |
| Association or queue policy admission failure | Association-local reject/drop | `0x0004` or edge-triggered `0x0006`; no session close |
| EOF, transport failure, relay exit, lane loss, cancellation, reset, `CLOSE_SESSION` | Session generation | Clean every live association and generation-owned resource exactly once |

Public Swift/Go failures contain only stable code, phase, scope (`session` or
association), and disposition (`rejectDatagram`, `closeAssociation`, or
`closeSession`). Remote text, raw bytes, raw OS errors, and unknown numeric
values never enter public errors or metric dimensions.

## 9. Generator, schema, and vector ownership

| Artifact | Ownership | Change rule |
| --- | --- | --- |
| `Protocol/Relay/relay-v1.schema.json` | Handwritten protocol authority (`TASK-260715-2azda7`) | Canonical UTF-8/LF JSON; change first; compatibility classify |
| `scripts/relay-protocol-tool.py` | Handwritten build-only Python standard-library tool | Validates strict schema/frozen v1 and emits constants only |
| Swift/Go generated files | Generated, checked in | Never hand edit; schema digest and parity lines must match |
| Swift/Go codecs, handshake, session | Handwritten core/protocol owners | Behavior remains fuzzable; generated metadata drives values |
| `Protocol/Relay/Vectors/v1/corpus.json` | Independent handwritten/audited oracle workflow | Synthetic only; identifiers immutable; append replacements |
| Swift/Go vector consumers | Language test owners | Strict keys, digest, provenance, feature/limit references |

The generator emits constants, raw-value enums, layouts, direction/flag/limit
metadata, reserved ranges, and the schema digest. It never emits codecs, state
machines, sockets, queue policy, tests, or vectors. Runtime never parses schema
or vectors. Generated files contain no timestamp or absolute path.

Every protocol PR includes the schema, both generated diffs, affected vectors,
compatibility classification, and results from the full gate. A schema-only
diff or hand-edited generated file is a failure, not a review exception.

## 10. Compatibility and version decision tree

The linked activity diagram is the compact decision tree. The normative rules
are:

1. No wire-visible change: keep wire v1; update handwritten behavior/tests only
   if it does not reinterpret accepted bytes.
2. New UDP error code only: it may append in v1 if old peers already map the
   unknown numeric code to `unknownRelayError` at association scope. Existing
   numeric meanings never change.
3. Optional feature: it is v1-compatible only when all of these are true:
   - allocate a previously reserved client flag and corresponding server
     feature in the schema;
   - client requests it before use; server returns only the intersection;
   - absence preserves old behavior and safety;
   - no new flag/message/sequence is sent until the feature is confirmed;
   - an old server seeing the newly allocated request fails closed with
     `0x0002`, and an old client never receives an unsolicited feature/message;
   - local hard caps remain authoritative regardless of advertised values.
4. Optional post-hello messages are allowed only behind a negotiated feature.
   An unknown unnegotiated v1 message remains session-fatal.
5. Use a new protocol version with a parallel schema, generated bindings, and
   vector corpus if any field width/order, hello size, length meaning, existing
   numeric value, required sequence, or behavior would make an old v1 peer
   misparse accepted bytes. Appending bytes to the exact 12/16-byte hello is
   specifically incompatible because an old peer consumes them as a frame
   prefix.
6. Never guess a downgrade. A new version follows an explicit version gate;
   unsupported version receives `0x0001` and closes.

The reserved `resourceLimitExchange` bit 1 and message range `0x40–0x4F` are a
named future option, not permission to emit them. Allocation requires M3
evidence that peer-limit knowledge materially avoids waste. Raising the 1472
UDP ceiling additionally requires the HEV fork decision because negotiation
cannot remove the pinned 1500-byte copy-path bound.

## 11. Diagnostics and privacy contract

Permitted default diagnostics: protocol/build version, finite stable error,
phase/state/scope/disposition, redacted address family, configured/effective
limits, queue occupancy/high-water marks, aggregate drops/counts, maximum
concurrent associations, and generation-local opaque IDs.

Required aggregate counters include `associationRejected`,
`oversizedDatagramRejected`, `oversizedReplyDropped`, `hevOversizedInbound`,
`queueSaturatedDropped`, `idleExpired`, and `resourceLimitRejected`.

Forbidden in docs, examples, public errors, logs, metrics, crash annotations,
and support artifacts: real destinations, DNS names, full addresses, payloads,
traffic samples, credentials, private keys, passphrases, profile secrets,
command stdin, shell secrets, remote-controlled text, raw OS/resolver errors, or
raw unknown protocol numbers. Canonical vectors use documentation ranges,
`.example`, opaque boundary byte `x`, and fixed public payload patterns only.

## 12. Reproduction, CI, fuzz, and release gates

Run every command from the repository root.

| Command | Expected artifacts/output | Failure gate |
| --- | --- | --- |
| `make relay-protocol-generate` | Rewrites both generated bindings; prints schema SHA-256 `3dd1…8000` | Validation error or noncanonical Go output is nonzero; a protocol PR must commit both diffs |
| `make relay-protocol-vectors-generate` | Rewrites `Protocol/Relay/Vectors/v1/corpus.json`; prints 89 and `e21e…e76` | Oracle/schema/coverage error is nonzero |
| `make relay-protocol-vectors-check` | `count=89`, corpus SHA, `deterministic=2/2` | `relay protocol vector error: checked-in corpus drift; run make relay-protocol-vectors-generate` |
| `make relay-protocol-conformance-check` | Vector check, Go vet/tests, strict corpus consumer, 57 Swift protocol tests, matched hostile semantic records/bounds | Any vector, parity, test, formatting, vet, allocation, cleanup, or privacy mismatch is nonzero |
| `make relay-protocol-hostile-diagnostics` | Go hostile corpus with `checkptr=2`; Swift hostile test with AddressSanitizer | Pointer, sanitizer, bound, cleanup, or semantic mismatch is nonzero |
| `./scripts/tests/test-relay-protocol-go.sh -fuzz FuzzHostileInputDecoder -fuzztime 30s` | Go fuzz PASS; seed summary; no crash/hang/leak | Fuzz failure prints reproducer and exits nonzero; input/payload bytes must not enter diagnostics |
| `make relay-protocol-check` | Full release-quality local gate: all conformance plus 12 negative fixtures, double generation, checked-in byte comparison, embedded digest checks, stale/manual-edit self-test, Swift build | Incompatible v1 schema: `incompatible v1 edit … (requires a wireVersion bump)`; generated drift: `checked-in generated outputs are stale or hand-edited …`; any earlier stage nonzero blocks merge/release |
| `task-board validate` | Valid board hierarchy/resources/dependencies | Missing resource, malformed status/dependency, or broken reference is nonzero |

`make relay-protocol-check` is the single command that CI and release jobs must
invoke. `TASK-260715-1m3edc` owns adding it to shared-core/protocol CI.
`TASK-260715-36gq4m` owns consuming it in the four-target relay release matrix.
Until `TASK-260715-27uz4n` lands `relay/go.mod` pinned to Go 1.26.5, the helper
builds a temporary standard-library-only Go 1.25 module with `CGO_ENABLED=0`.
That is valid local conformance evidence, but not the Go 1.26.5 release
toolchain gate. Release additionally requires the four target builds, identity
and stdio smoke, manifest/checksum, reproducibility, SBOM/notices, signing, and
upload/identity match owned by their dedicated build/bootstrap/supply-chain
tasks; this document does not redefine those policies.

Verification on 2026-07-20 reproduced both generated outputs and the corpus
without drift, passed every tabled command, and ran the 30-second Go fuzz gate
for 12,766,542 executions with three new coverage-interesting inputs and no
failure.

## 13. Consumer handoff

Existing atomic tasks cover every consumer; no duplicates are required.

| Consumer group | Concrete tasks | Contract sections consumed |
| --- | --- | --- |
| Schema/codec/state/vector | `TASK-260715-2azda7`, `1y1g1u`, `89h7cw`, `516lhy`, `1jvgcn`, `1q7u14`, `297gq6` | §§3–10, 12 |
| Portable build and entrypoint | `TASK-260715-27uz4n`, `2ywde4`, `24icoz`, `1ue4oy`, `vtot05`, `mocqmr`, `1q03sa` | §§2, 9, 12 |
| Bootstrap/session | `TASK-260715-2uipar`, `1bj8hu`, `fve0hj`, `19lr1c`, `159pcp`, `9h7pf8`, `2lfgwo` | §§2–4, 6, 8, 11–12 |
| UDP admission and scheduling | `TASK-260715-22gz6h`, `xw5dxc`, `3xpc6b`, `3e30tx`, `z37ay7` | §§4–8 |
| UDP adapter/test/operations | `TASK-260715-1loqwb`, `28jdml`, `1ut6ot`, `cqm7m5`, `24e2o1` | §§5–8, 11–12 |
| Capability/degraded mode | `TASK-260715-3edgwz`, `ak0s72`, `kxxujt`, `uh8kk6`, `1vg1mb`, `2y78ah`, `3kga9i` | §§2–3, 6–8, 11 |
| CI/release orchestration | `TASK-260715-1m3edc`, `36gq4m` | §§9–12 |

M3 tuning consumes aggregate evidence only: oversized reply/HEV ingress and
maximum datagram size; association/queue high-water marks versus the device
memory ledger; idle-expiry rates; and demonstrated waste that could justify
allocating `resourceLimitExchange`. No M0 baseline is silently promoted into a
new wire promise.

## 14. Completeness disposition

The accepted task graph already contains atomic implementation, testing,
build, bootstrap, UDP, capability, documentation, CI, and release consumers
with descriptions, acceptance criteria, and dependencies. No unresearched
protocol choice remains. The only observed delivery gaps are already owned:

- GitHub Actions does not yet run the protocol gate — `TASK-260715-1m3edc` and
  `TASK-260715-36gq4m`;
- the local Go smoke uses 1.25.5 rather than the required release Go 1.26.5 —
  `TASK-260715-27uz4n`.

Neither gap changes v1 bytes or blocks publication of this contract. Both must
remain visible in CI/release handoff and must not be reported as release proof
until their owner tasks pass.
