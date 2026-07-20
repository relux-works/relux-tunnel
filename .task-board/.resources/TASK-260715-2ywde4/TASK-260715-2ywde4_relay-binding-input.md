# TASK-260715-111tde — Relay protocol implementation and binding strategy

Date: 2026-07-20  
Status: binding decision, ready for review  
Wire version: relay protocol v1  
Apple language/module: Swift 6, `ReluxTunnelCore`  
Relay language/module: Go 1.26.5, `github.com/relux-works/relux-tunnel/relay`

## 1. Decision and authority

This record freezes the source ownership, code-generation, language boundary,
streaming, framing, test-reuse, dependency, and review contract for relay
protocol v1. It does not implement the protocol.

The binding authorities are:

- `.spec/relay-protocol.md`, `.spec/security-privacy.md`, and accepted ADR-005
  and ADR-006 in `.spec/decisions.md`;
- accepted `TASK-260715-3r0993` — Tuist 4.202.5 governs the generated Apple
  app/provider workspace, while SwiftPM remains authoritative for shared core;
- accepted `TASK-260715-2nfz7w` — relay framing is a component of the
  `ReluxTunnelCore` SwiftPM target, never an app/provider adapter concern;
- accepted `TASK-260715-3bdplx` — the remote implementation is Go 1.26.5,
  standard-library only, `CGO_ENABLED=0`, rooted at `relay/`;
- accepted `TASK-260720-100wu6` — the client binds to
  `SSHTransport.openExecChannel(request:policy:)` and the returned
  `SSHExecChannel`/`SSHByteChannel`, independent of the selected SSH engine;
- the reviewer-accepted override attached to this task, which deliberately
  removes Gate A0 and `TASK-260715-32umrc` as prerequisites. Neither controls
  this reusable wire contract or the existing SwiftPM core boundary.

`TASK-260715-18owh7` remains the sole authority for numeric association-count,
queued-byte, datagram-size, idle-timeout, and hard-ceiling values and for the
compatible v1 mechanism that exchanges or locally caps them. This decision
defines their typed slots and consumption but deliberately assigns no values.

## 2. Repository ownership

All paths below are exact. Generated files are checked in so the Apple and Go
builds never need the generator or schema at runtime.

| Artifact | Kind and owner | Contents | Primary validation |
| --- | --- | --- | --- |
| `Protocol/Relay/relay-v1.schema.json` | Handwritten authority; `TASK-260715-2azda7`, protocol owner | Canonical UTF-8/LF JSON: field order/width/endian, values, direction, flags/features, reserved ranges, error codes, limit names, and compatibility class | `make relay-protocol-check` |
| `scripts/relay-protocol-tool.py` | Handwritten build-only tool; `TASK-260715-2azda7`, protocol/tooling owner | Python-standard-library schema validation and canonical Swift/Go emission; no vector generation | Python unit/negative fixtures through `make relay-protocol-check` |
| `Sources/ReluxTunnelCore/RelayProtocol/Generated/RelayProtocolV1+Generated.swift` | Generated; Swift core owner | Constants, raw-value enums, widths, direction metadata, flag masks, limit keys, schema digest | Regenerate, byte-compare, `swift test` |
| `relay/internal/protocol/generated_v1.go` | Generated; Go relay owner | Same constants and metadata in Go; canonical `gofmt` output | Regenerate, byte-compare, `go test ./...` |
| `Sources/ReluxTunnelCore/RelayProtocol/RelayByteCodec.swift` | Handwritten; `TASK-260715-89h7cw`, Swift core owner | Big-endian cursor/writer and bounded incremental envelope codec | Swift Testing split/coalesce/allocation tests |
| `Sources/ReluxTunnelCore/RelayProtocol/RelayDatagramCodec.swift` | Handwritten; `TASK-260715-516lhy`, Swift core owner | HEV UDP-in-TCP payload codec | HEV golden vectors and Swift Testing |
| `Sources/ReluxTunnelCore/RelayProtocol/RelayHandshake.swift` | Handwritten; `TASK-260715-1y1g1u`, Swift core owner | Client hello state machine and negotiated result | Swift Testing plus cross-language vectors |
| `Sources/ReluxTunnelCore/RelayProtocol/RelaySession.swift` | Handwritten; `TASK-260715-1jvgcn`, Swift core owner | Direction/error/close/generation semantics | Paired-peer state tests |
| `Sources/ReluxTunnelCore/RelayProtocol/SSHRelaySessionPump.swift` | Handwritten; `TASK-260715-159pcp` and `TASK-260715-3e30tx`, Swift core owner | Long-lived `SSHExecChannel` launch binding, partial I/O, stderr/exit monitoring, bounded queues | Fake-channel/fault/backpressure tests |
| `relay/internal/protocol/codec.go` | Handwritten; `TASK-260715-89h7cw` and `TASK-260715-516lhy`, Go relay owner | Big-endian envelope and HEV payload codecs over bounded buffers | `go test ./...`, vectors, fuzz |
| `relay/internal/protocol/handshake.go` | Handwritten; `TASK-260715-1y1g1u`, Go relay owner | Server hello state machine and negotiated result | Go tests plus cross-language vectors |
| `relay/internal/protocol/session.go` | Handwritten; `TASK-260715-1jvgcn`, Go relay owner | Direction/error/close/generation semantics, no socket calls | Paired-peer state tests |
| `relay/internal/stdio/session.go` | Handwritten; `TASK-260715-2ywde4` and `TASK-260715-159pcp`, Go relay owner | Bounded stdin/stdout adapter and single stdout writer; stderr diagnostics only | Rootless stdio, contamination, EOF, and signal tests |
| `relay/internal/udp/` | Handwritten; `TASK-260715-xw5dxc`, `TASK-260715-3xpc6b`, `TASK-260715-z37ay7`, Go relay owner | Association registry, validation gate, resolution/socket I/O, bounded scheduling | Go unit/fuzz/pressure/soak tests |
| `Protocol/Relay/Vectors/v1/*.json` | Handwritten/independently audited; `TASK-260715-1q7u14`, protocol test owner | Synthetic wire hex, chunks, semantic values/errors, limits, provenance | Both language loaders plus `TASK-260715-297gq6` |
| `Tests/ReluxTunnelCoreTests/RelayProtocol/` | Handwritten; Swift test owner | Swift vector consumer, state, allocation, cancellation, and privacy checks | `swift test` |
| `relay/internal/protocol/*_test.go` and `relay/testdata/protocol/v1` | Handwritten; Go test owner | Go vector consumer, state, fuzz seeds, and allocation checks; testdata references the canonical corpus rather than copying it | `go test ./...` and Go fuzz commands |

The Swift files remain in the existing `ReluxTunnelCore` target. There is no
Swift/Go FFI, generated Xcode target, NetworkExtension import, concrete SSH
engine import, or runtime schema parser. The Go module remains independent of
the Apple workspace.

## 3. Schema and deterministic generation contract

`relay-v1.schema.json` is a small protocol-definition document, not a runtime
JSON Schema dependency. It uses JSON primitives only, canonical object keys,
decimal unsigned values, explicit widths, and named compatibility classes. The
tool rejects duplicate values, overflow, overlapping reserved ranges, missing
direction or length semantics, unknown schema keys, undeclared limits, and any
v1 edit classified as incompatible without an explicit protocol-version bump.

There is one regeneration command, always run from the repository root:

```sh
make relay-protocol-generate
```

The Make target sets `LC_ALL=C`, `LANG=C`, `TZ=UTC`, and `PYTHONHASHSEED=0`,
runs `scripts/relay-protocol-tool.py generate`, emits both files in a fixed
order with no timestamps or absolute paths, and runs `gofmt` on the Go output.
The emitter itself produces canonical Swift formatting. Generated headers name
the source schema, schema SHA-256, generator format version, and the command
above; they say that manual edits are forbidden.

The CI drift gate is:

```sh
make relay-protocol-check
```

It validates the schema and negative fixtures, generates twice into two fresh
task-local temporary roots, byte-compares those roots, byte-compares each result
with both checked-in outputs, verifies the embedded schema digest, runs a
deliberate stale/manual-edit fixture that must fail, then compiles/tests both
bindings. It is network-free after the repository's pinned toolchains exist.
Any schema PR must contain both generated diffs and affected vectors. A
schema-only diff or hand-edited generated file is a failing change, not a review
exception.

The generator never emits codecs, state machines, socket behavior, queue
policy, tests, or vectors. That keeps generated review mechanical and keeps
behavior in handwritten, fuzzable code.

## 4. Protocol v1 wire contract

All integers are unsigned big-endian (network byte order). Implementations use
checked conversions before indexing, slicing, allocating, resolving, or opening
a socket.

### 4.1 Identity preflight and long-lived exec session

The fixed v1 hello has no build-identity field. To satisfy the supply-chain
contract without changing that hello or contaminating framed stdout, bootstrap
uses a separate authenticated exec channel before the long-lived session:

```text
<verified-path>/relux-relay --identity --protocol 1
```

It emits exactly one canonical JSON line, at most 512 bytes including LF, with
this fixed key set and no free-form values:

```json
{"schemaVersion":1,"relayProtocolVersion":1,"relayVersion":"<semver>","sourceCommit":"<40 lowercase hex>","os":"linux|darwin","arch":"amd64|arm64","selfSha256":"<64 lowercase hex>"}
```

EOF and exit status zero are mandatory. Extra stdout, an unknown key/version,
invalid bounded value, nonzero exit, overflow, or mismatch with
`relux-relay-manifest-v1.json` rejects the asset/session. Stderr is drained into
a bounded redacted diagnostic sink and is never identity evidence. This command
also provides the protocol-level self-hash fallback used when host checksum
utilities are unavailable. The identity record is bootstrap evidence; it is not
a relay protocol frame and does not relax remote file SHA-256 verification.

Only after identity matches does the client open:

```text
<verified-path>/relux-relay --stdio --protocol 1
```

Its stdout contains only hello and framed protocol bytes. Stderr remains a
separate bounded diagnostic stream. No SFTP or shell secret is involved.

### 4.2 Hello

Client hello is exactly 12 bytes:

```text
magic[4]="RLXR" | version:u16=1 | flags:u16 | maxFrame:u32
```

Server hello is exactly 16 bytes:

```text
magic[4]="RLXR" | version:u16=1 | status:u16 | features:u32 | maxFrame:u32
```

The client sends first. The server emits no envelope before accepting the full
client hello. The client publishes no usable session before accepting the full
server hello. Unknown magic, unsupported version, nonzero status, reserved
client flags, impossible feature selection, unreasonable `maxFrame`, timeout,
EOF, duplicate hello, or extra pre-hello stdout closes the channel with a stable
local reason. There is no downgrade guessing.

Server status values are schema-owned and exact: `0x0000` accepted,
`0x0001` unsupported version, `0x0002` invalid client hello, `0x0003` resource
policy rejected, and `0x0004` relay unavailable. Unknown nonzero values map to
one local `relayRejected` reason; their raw value is not a metric dimension.

`maxFrame` counts the envelope body described below, not its four-byte prefix.
Each peer validates it against the protocol minimum and its injected local hard
cap before any body-sized allocation. Effective `maxFrame` is no greater than
either peer's accepted value.

Client flag bit 0 requests the v1 `dnsPriorityHint` capability. Server feature
bit 0 confirms it. The server's returned feature set must be a subset of the
client request and its own supported features; all other bits remain reserved
until added through the compatibility rules. The priority capability changes
scheduling only, never authorization, admission, limits, or error privilege.

The broader resource-limit result is represented in both languages as
`RelayEffectiveLimits`. Its exact fields/values and whether they are fixed local
caps or a feature-gated post-hello exchange are inserted only by the accepted
`TASK-260715-18owh7` decision. No implementation may infer peer values that were
not sent or exceed a local hard cap.

### 4.3 Envelope and multiplexing

After hello, one ordered byte stream carries:

```text
frameLength:u32 | type:u8 | flags:u8 | associationID:u32 |
payload[frameLength - 6]
```

`frameLength` covers `type` through payload. It excludes the four-byte prefix,
must be at least 6, and must not exceed effective `maxFrame` or the local hard
cap. The decoder validates the prefix using fixed storage before retaining or
allocating a body. It accepts every stream split and multiple frames per read;
SSH read boundaries have no protocol meaning.

Message metadata is:

| Value | Name | Direction | Association ID | Payload |
| ---: | --- | --- | --- | --- |
| `0x10` | `UDP_DATAGRAM` | both | nonzero | HEV payload below |
| `0x11` | `UDP_ERROR` | relay to client | nonzero | exactly `code:u16`; no text |
| `0x20` | `PING` | client to relay | zero | exactly 8 opaque token bytes |
| `0x21` | `PONG` | relay to client | zero | exact 8 bytes copied from PING |
| `0x30` | `CLOSE_ASSOCIATION` | both | nonzero | empty |
| `0x31` | `CLOSE_SESSION` | both | zero | empty |

Envelope flag bit 0 is `dnsPriority` and is valid only on client-to-relay
`UDP_DATAGRAM` after `dnsPriorityHint` negotiation. Bits 1–7 are reserved zero;
all flags on other frames are zero. The client derives this hint only from the
tunnel-owned DNS association, never from an arbitrary user destination. The
relay makes it sticky for that association and rejects an attempt to change it.
Priority selects a bounded starvation-free queue but never bypasses a cap.

Unknown v1 message type, nonzero reserved flag, illegal direction, illegal
association ID, impossible fixed payload size, invalid length, or unrecoverable
decoder state is session-fatal. A malformed datagram whose complete envelope
and nonzero association ID are trustworthy is association-fatal. Remote bytes
never become a log/UI string.

### 4.4 HEV UDP payload

`UDP_DATAGRAM` carries the exact HEV UDP-in-TCP record:

```text
MSGLEN:u16 | HDRLEN:u8 | ATYP:u8 | DST.ADDR:variable |
DST.PORT:u16 | DATA[MSGLEN]
```

- `MSGLEN` is the UDP data length only.
- `HDRLEN` counts from the first `MSGLEN` byte through `DST.PORT`; therefore it
  is 10 for IPv4, 22 for IPv6, and `7 + domainLength` for a domain.
- outer payload length must equal `HDRLEN + MSGLEN` exactly.
- `ATYP` is SOCKS/HEV `0x01` IPv4 (4 bytes), `0x03` domain (one length byte then
  1–248 wire bytes, bounded by the one-byte `HDRLEN`), or `0x04` IPv6 (16 bytes).
- port is unsigned big-endian. A zero port is invalid for socket use.
- domain bytes are an opaque wire value in the codec. Before resolution, the Go
  layer accepts only ASCII DNS presentation form: total 1–248 bytes, labels
  1–63 bytes, letters/digits/hyphen with no leading/trailing hyphen, and at most
  one terminal dot. Unicode, empty interior labels, controls, NUL, raw IP text,
  and invalid A-labels are rejected. Callers provide punycode when needed; no
  IDNA runtime dependency is added. The codec never normalizes or logs the bytes.
- response address/port is the source endpoint observed by the relay.
- datagrams are never fragmented by this protocol.

Outer length, `MSGLEN`, `HDRLEN`, address form/length, port, association state,
and the `TASK-260715-18owh7` datagram ceiling all pass before the Go relay
creates/selects/resolves/sends on a socket. A parser never calls a resolver or
socket package.

### 4.5 Association lifecycle

The client allocates nonzero `u32` IDs within one relay-session generation. An
association opens implicitly on its first fully validated client datagram. The
relay admits state only after validation and limit credit. Destinations remain
per-datagram; an association is not authorization to bypass validation on later
destinations.

An ID is not reused until retirement is observed:

1. either peer may send `CLOSE_ASSOCIATION`;
2. it stops admitting datagrams, releases socket/queue/timer state once, and
   echoes one close only when needed to acknowledge an active peer-initiated
   close;
3. duplicate/crossed close is idempotent;
4. the client may reuse the ID only after the relay's close/ack proves the old
   relay state is retired, or after the whole session generation ends.

Idle expiry and association-local terminal error send a finite `UDP_ERROR` when
safe, retire relay state, then close the association. Late UDP replies are
dropped and counted. Session EOF, relay exit, framing failure, SSH lane loss,
cancellation, reset, or `CLOSE_SESSION` ends the generation and all associations
exactly once; IDs never cross generations.

`UDP_ERROR` codes are schema-owned finite values:

| Value | Meaning |
| ---: | --- |
| `0x0001` | invalid datagram |
| `0x0002` | unsupported address |
| `0x0003` | unknown or closed association |
| `0x0004` | association limit |
| `0x0005` | datagram too large |
| `0x0006` | queue saturated |
| `0x0007` | resolution failure |
| `0x0008` | socket failure |
| `0x0009` | idle expiry |
| `0x000A` | resource limit |

Unknown numeric error codes map to one local `unknownRelayError` association
failure without exposing the raw value as high-cardinality telemetry.

### 4.6 Flow control and cancellation

Swift uses the accepted asynchronous `SSHExecChannel` directly:

- `read(maximumBytes:)` is always called with a positive configured bound;
- `writeSome` may accept only a prefix, and the pump retries only the suffix;
- `finishWriting`, stderr drain, `waitForExit`, cancel/reset, and idempotent close
  follow `TASK-260720-100wu6` semantics;
- no `readToEnd`, blocking syscall, detached task per datagram, busy polling, or
  unchecked peer-sized `Data` allocation is permitted in the extension.

The Swift codec uses checked shifts over byte collections and fixed-prefix
storage. It does not use alignment-dependent `UnsafeRawBufferPointer.load`.
Retained bytes are bounded by one accepted frame plus fixed decoder state and
the injected queue budget.

Go binds protocol code to `io.Reader`/`io.Writer`,
`encoding/binary.BigEndian`, and checked fixed-capacity buffers. Blocking OS
stdin/stdout operations are confined to one reader goroutine and one writer
goroutine; they never block the association coordinator. The writer is the only
stdout owner, so frames cannot interleave. Internal channels/maps/pools are
bounded by injected limits. `io.ReadAll`, unbounded `bufio` growth, a goroutine
per datagram, cgo, `unsafe`, reflection, and runtime schema parsing are
forbidden.

Both peers have bounded control, DNS-priority, and ordinary work queues. Control
close/error/health traffic has reserved bounded credit; DNS priority is
starvation-free; ordinary traffic continues to make progress. Saturation drops
datagrams and increments aggregate counters rather than waiting or retrying
without a bound. Numeric queue partitions and fairness weights belong to
`TASK-260715-18owh7`/`TASK-260715-z37ay7`.

Cancellation releases pending buffers and generation-owned state. A transport
or session failure is never retried inside the codec; bootstrap/capability
policy owns any new process/session generation.

## 5. Error, privacy, dependency, and trust boundaries

Public Swift and Go errors contain a generated stable code, phase, scope
(`session` or association), and disposition (`rejectDatagram`,
`closeAssociation`, or `closeSession`). They contain no peer text, destination,
domain, payload, command, path, engine object, or raw OS error. OS/resolver
details may exist only in a sensitive local diagnostic sink and must not become
metrics dimensions or control flow.

| Boundary | Allowed dependency/license surface | Forbidden |
| --- | --- | --- |
| Apple runtime | Swift standard library and Foundation already used by `ReluxTunnelCore`; existing project license/notices | New package, NetworkExtension in core, concrete SSH engine, FFI, unsafe load, runtime schema/vector parsing |
| Relay runtime | Go 1.26.5 standard library, Go BSD-3-Clause notice, project license; `CGO_ENABLED=0` | Third-party module, cgo, `unsafe`, dynamic plugin, libc assumption on Linux |
| Generator | Checked `scripts/relay-protocol-tool.py` and Python standard library, build-time only | Network access, template download, runtime inclusion, nondeterministic host data |
| Tests | Swift Testing, Go `testing`/fuzz, canonical synthetic JSON vectors | Real traffic, destinations, DNS names, secrets, shared production encoder as vector oracle |

Any proposed runtime dependency, Go `unsafe`, cgo, Swift unsafe primitive, or
cross-language FFI requires a new task-scoped security/license/maintenance
decision before use.

Trust flows from reviewed specs/ADRs to the schema, generator, generated diffs,
handwritten codecs, and independently audited vectors. CI proves generated
drift and cross-language behavior. Runtime trusts only compiled code and
injected hard limits. Release trust additionally requires pinned source/toolchain,
two-clean-build evidence, SBOM/notices, the signed app bundle, manifest SHA-256,
authenticated upload, remote checksum/identity match, and a successful current
generation hello. The remote byte stream and stderr remain untrusted even after
SSH authentication.

Default diagnostics may include protocol/build version, finite error, state,
family, configured/effective limits, aggregate counts, queue occupancy, drops,
and generation-local opaque IDs. They never include payload, domain,
destination, full address, command stdin, profile/credential data, or
remote-controlled text.

## 6. Version and review rules

- In-place v1 edits may only allocate a reserved flag/feature and behavior that
  is negotiated before use and safely absent for an old peer, or add an error
  code that old peers already map to `unknownRelayError`.
- Changing a field width/order, length meaning, hello size, existing numeric
  value, required message sequence, or behavior an old v1 peer would misparse
  requires a new protocol version and parallel schema/vectors.
- Optional post-hello messages are legal only after a negotiated feature says
  both peers understand them; unknown unnegotiated v1 message types remain
  session-fatal.
- Every protocol PR includes schema, both generated outputs, affected canonical
  vectors, compatibility classification, and the output of
  `make relay-protocol-check` plus cross-language tests.
- Generated diffs are reviewed mechanically against the schema. Hand edits are
  never accepted. The protocol owner and both Swift/Go owners review incompatible
  or security-relevant changes.

## 7. Consumer and validation map

| Consumer task(s) | Concrete input/interface | Required validation/handoff |
| --- | --- | --- |
| `TASK-260715-18owh7` | Hello/envelope compatibility slots and `RelayEffectiveLimits` | Approved exact wire-or-local-cap decision; no old-peer misparse |
| `TASK-260715-2azda7` | Schema/tool/generated paths and flag/error metadata | `make relay-protocol-check`, stale/manual-edit negative fixture |
| `TASK-260715-1y1g1u` | Exact 12/16-byte hello, active feature subset, effective max frame/limits | Swift/Go every-split/coalesced handshake tests |
| `TASK-260715-89h7cw` | Envelope layout and bounded stream rules | Swift Testing and `go test ./...`; all splits/coalescing/allocation bounds |
| `TASK-260715-516lhy` | Exact HEV payload length/address semantics | Byte parity with HEV fixture; property/fuzz tests |
| `TASK-260715-1jvgcn` | Message direction, ID, error, close, generation table | Paired-peer duplicate/crossed/EOF/cancel tests |
| `TASK-260715-1q7u14`, `TASK-260715-297gq6`, `TASK-260715-2z9b4a` | Canonical vector format, schema digest/version, compatibility rules | Independent oracle audit; both loaders; cross-language fuzz/doc drift gates |
| `TASK-260715-27uz4n`, `TASK-260715-2ywde4`, `TASK-260715-24icoz`, `TASK-260715-1ue4oy`, `TASK-260715-vtot05`, `TASK-260715-mocqmr`, `TASK-260715-1q03sa` | Go module/toolchain ceiling, generated Go source, identity JSON, schema/vectors, manifest v1 | Pinned four-target clean builds, rootless identity/stdio smoke, SBOM/license, reproducibility |
| `TASK-260715-2uipar`, `TASK-260715-1bj8hu`, `TASK-260715-fve0hj`, `TASK-260715-19lr1c`, `TASK-260715-159pcp`, `TASK-260715-9h7pf8`, `TASK-260715-2lfgwo` | Manifest identity tuple, `--identity --protocol 1`, `--stdio --protocol 1`, `SSHExecChannel`, hello/session errors | Authenticated exec, bounded stdout/stderr, identity/EOF/exit/cancel/failure matrix; no SFTP |
| `TASK-260715-22gz6h`, `TASK-260715-xw5dxc`, `TASK-260715-3xpc6b`, `TASK-260715-3e30tx`, `TASK-260715-z37ay7` | Validated datagrams, lifecycle, effective limits, queue classes, async/stdio pumps | Pre-socket validation spies, registry lifecycle, bounded pressure/fairness/DNS priority |
| `TASK-260715-1loqwb`, `TASK-260715-28jdml`, `TASK-260715-1ut6ot`, `TASK-260715-cqm7m5`, `TASK-260715-24e2o1` | HEV codec, internal DNS priority source, association/session interfaces, vectors | HEV parity, DNS scheduling without privilege, conformance/fuzz/soak/privacy metrics |
| `TASK-260715-3edgwz`, `TASK-260715-ak0s72`, `TASK-260715-kxxujt`, `TASK-260715-uh8kk6`, `TASK-260715-1vg1mb`, `TASK-260715-2y78ah`, `TASK-260715-3kga9i` | Validated build/protocol identity, features, effective limits, generation/health/error state | Truthful full/degraded snapshots, failure/reprobe generation tests, zero physical fallback |

All listed implementation tasks already have atomic descriptions, scope,
acceptance criteria, and dependency links. Creating duplicates would split
ownership. The one unresolved decision is already represented by the unblocked,
development-ready `TASK-260715-18owh7`; it blocks only the consumers that need
its exact limits.

## 8. Residual assumptions and disposition

1. Numeric resource values and the compatible broader-limit exchange are not
   assumed here. They are an explicit blocking decision in
   `TASK-260715-18owh7`.
2. Build identity is deliberately a bounded preflight exec record rather than a
   new v1 hello field, stderr convention, or new mandatory frame. This avoids an
   incompatible hello change and makes the already authoritative manifest the
   comparison source.
3. DNS priority uses a negotiated scheduling hint. It grants no admission,
   authorization, limit, or logging privilege and therefore remains compatible
   with the security statement that DNS has no protocol privilege.
4. Domain payloads remain byte-preserving in the codec; exact safe resolver-name
   acceptance belongs to the Go UDP resolution task and must run before socket
   use. No IDNA dependency is introduced by this binding.
5. The Apple workspace generator and Gate A0 remain outside this reusable
   contract by explicit reviewer override. No downstream relay task has an
   unresolved implementation language, project boundary, transport engine, or
   FFI choice.
