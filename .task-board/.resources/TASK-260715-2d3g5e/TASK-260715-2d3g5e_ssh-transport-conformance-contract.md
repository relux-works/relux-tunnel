# SSH transport conformance contract

- Revision: 2026-07-28 M0 viability
- Supersedes: the full-fidelity M0 scope recorded by `TASK-260715-2ny6z4`
- Decision: ADR-014 and ADR-023
- M3 semantic owner: `TASK-260728-3cveay`

## Authority and interpretation

This is the candidate-neutral contract implemented by
`Sources/ReluxTunnelCore/SSHContracts.swift`. It preserves the behavioral,
security, memory, privacy, and lifecycle invariants of the reviewed
`TASK-260715-2ny6z4` contract while changing when four exact reporting
semantics must be delivered.

Every requirement below is either **M0-viability-mandatory** or
**M3-deferred**. Deferred means evidence-gated and still binding. It never means
optional, silently waived, inferred, or replaced by a convenient constant.
An M0 adapter that cannot report a deferred semantic MUST return a typed
`notReported` or `unsupported` state.

libssh2 is the primary candidate. ReluxNIOSSH remains comparative evidence and
MUST receive no further fork work unless new evidence invalidates libssh2.
For M0 acceptance, the common suite MUST execute every applicable row against
the production libssh2 adapter. ReluxNIOSSH MUST remain a first-class matrix
entry whose unavailable/deferred status is asserted explicitly; it MUST NOT be
represented by a fake adapter, treated as a passing implementation, or trigger
new adapter/fork work contrary to ADR-014 and ADR-027.

## Requirement registry

### M0-viability-mandatory

| Requirement | Binding M0 evidence |
| --- | --- |
| Apple target integration | The static/source graph builds for the macOS harness and packet-tunnel extension with extension-safe public APIs. iOS delivery remains deferred by ADR-024, not by this SSH decision. |
| Candidate-neutral injection | Core imports no engine types. TCP readiness/I/O, host policy, credential provider, clock, cancellation, logger, observer, metrics, identity generation, and experiment recording remain injected and fakeable. |
| Host key before authentication | Exact raw wire key, negotiated host-key algorithm, and canonical SHA-256 fingerprint reach the host policy before credential lookup or any authentication request. Unknown, changed, algorithm-rejected, and policy-rejected hosts fail closed before auth. |
| Approved public-key authentication | Noninteractive Ed25519 plus an approved deployed fallback work through opaque external signing. Password prompts, agent forwarding, and silent algorithm downgrade are not fallbacks. |
| Approved algorithm policy | KEX, host-key, cipher, MAC, and user-key algorithms are caller constrained; forbidden SHA-1/CBC choices never appear as a compatibility workaround. |
| `direct-tcpip` | Destination and originator are transmitted verbatim; concurrent channels have independent bounded reads, partial writes, EOF, cancel, reset, and close. |
| Exec and stdin upload | One accepted exec request exposes bounded stdin/stdout/stderr and long-lived framing. Relay upload uses exec/stdin only, drains output concurrently, and never invokes SFTP. |
| Client-initiated rekey | Byte-threshold, time-threshold, test, and manual triggers use the production KEX path under active traffic. Rekey failure/timeout stays connection-fatal. |
| Server-initiated rekey handling | Inbound server KEX remains protocol-correct under active traffic without loss, duplication, reordering, or unbounded buffering. Exact reason/lifecycle/generation reporting is the M3 semantic below. |
| Bounded buffers and backpressure | Caller-owned read buffers, queued writes, write-call size, pending operations, callback bridges, and teardown queues have hard positive bounds. A missing exact receive-credit semantic does not permit unbounded buffering. |
| Deterministic cancellation | Resolution, connect, KEX, host decision, credential lookup, auth, open, read, write, EOF, exec, upload, rekey, keepalive, and close waits keep the reviewed operation/channel/connection cleanup scopes. |
| Bounded lifecycle | One serialized owner closes channels, timers, engine session, and socket exactly once; reconnect/network-loss cycles restore owned resources to baseline within injected deadlines. |
| Keychain-only secrets | Configuration and the SSH seam carry opaque credential references and public signing material only. Private keys and passphrases remain in the approved Keychain-backed credential provider and never cross this boundary as configuration bytes. |
| Privacy-safe errors and diagnostics | Typed errors preserve code, phase, scope, retry, and teardown without engine prose or host, user, endpoint, fingerprint, credential, command, path, stream, or payload data. |
| Connection keepalive | The adapter sends the configured SSH keepalive on bounded monotonic scheduling and applies its available failure signal. Exact reply correlation and derived RTT/miss telemetry are the M3 semantic below. |
| Available observability | Connection/channel state, mandatory operation counts, bounded-buffer gauges, protected/payload byte counts, client-rekey triggers/results, keepalive sends, and any cheaply available facts remain typed and privacy-safe. Unavailable deep facts use explicit deferred states. |

No row above is removed or softened by the M3 split.

### M3-deferred, evidence-gated, not waived

| Deferred semantic | Exact pinned-source evidence for deferral | Required M0 state | Owner |
| --- | --- | --- | --- |
| Consumer-driven receive-window credit with an immutable per-channel cap | At libssh2 pin `a34302491c164d53c900fec9b3cbb050ecebe719`, patched `src/channel.c:1921-1938` auto-adjusts before copying bytes to the caller and may grow beyond the initial cap. Public APIs have no manual-window read mode. ReluxNIOSSH returns credit at child-pipeline frame delivery (`SSHChildChannel.swift:684-707`), before API-sized prefix consumption. | `receiveWindow()` and window counters/gauges return `reported`, `notReported`, or `unsupported`; Swift counters MUST NOT pretend to undo wire credit. | `TASK-260728-3cveay` |
| RFC 4254 channel-open rejection reason taxonomy | Patched libssh2 `src/channel.c:259-289` parses all four RFC reasons, maps every branch to `LIBSSH2_ERROR_CHANNEL_FAILURE`, frees the packet, and exposes no public reason accessor. Diagnostic prose is not control flow. | Every `channelOpenRejected` error requires `reported`, `notReported`, or `unsupported`; every other error uses `notApplicable`. No silent absence, hard-coded `other`, or parsed error string is permitted. | `TASK-260728-3cveay` |
| Exact exec-exit status and `coreDumped` metadata | Patched libssh2 stores `exit_status = 0` without a presence bit (`src/libssh2_priv.h:452-468`, `src/packet.c:1106-1128`) and discards RFC `core dumped` (`src/packet.c:1130-1173`). Public API cannot distinguish explicit status 0 from absence or report the bit. | `SSHExecExit` distinguishes `status`, `signal`, `notReported`, and `unsupported`; signal `coreDumped` is itself a deferred report. An adapter MUST NOT hard-code status 0 or `false`. | `TASK-260728-3cveay` |
| Deep rekey and keepalive observability | At the reviewed libssh2 public header/patch pair (header SHA-256 `27da2886742f5d20c169a88b9fad43a25fabd9fd509d8a74ff41bcf877e5badd`, patch SHA-256 `873b3c2bad8ba481f7122922d075333f736853f8efab6cd39edc35098d111924`), server KEX lifecycle/generation and keepalive reply correlation were not public. The later six-file patch added candidate evidence, but M0 no longer binds the neutral seam to exact server-KEX generation or reply-correlated RTT/timeout/miss reporting. | Session/snapshot generation, server-rekey counts, active-KEX state, keepalive acknowledgement/timeout/miss/RTT, and manual keepalive RTT use deferred reports. Client rekey and keepalive transmission remain mandatory. | `TASK-260728-3cveay` |

The accepted libssh2 third-round artifact remains pinned by public-header
SHA-256 `aa542cff4e0e64927983da8c50b0315cd24c6d097fcdd42809d2e3b0878625bf`
and fork-patch SHA-256
`79e2464813e3c3add9486b2fb8c9e50004b48b246bbc771b5dd1675a152fa30e`.

## Neutral seam requirements

`SSHConformanceRequirement` is exhaustive and maps each semantic requirement to
`m0ViabilityMandatory` or `m3Deferred(ownerTaskID:)`.
`SSHDeferredSemanticReport<Value>` has exactly three evidence states:
`reported(Value)`, `notReported`, and `unsupported`.
`SSHChannelOpenReasonReport` adds `notApplicable` for non-channel-open errors;
validated error construction rejects `notApplicable` for `channelOpenRejected`
and rejects deferred reason states for all other error codes.

Factories disclose all four M3 capabilities through
`SSHDeferredSemanticCapabilities`. Runtime surfaces use deferred reports at the
points where the public candidate API may lack exact evidence:

| Surface | Deferred value |
| --- | --- |
| `SSHChannelPolicy.consumerReceiveWindowCredit` | Exact initial-window/immutable-cap/consumer-credit policy with a matching channel initial window, or an explicit unsupported state while mandatory read-buffer bounds remain active |
| `SSHByteChannel.receiveWindow()` | Consumer-credit/cap snapshot |
| `SSHTransportError.channelOpenReason` | RFC open-rejection reason |
| `SSHExecExit` / `SSHExecSignal.coreDumped` | Status presence, signal metadata, and core-dump bit |
| `SSHSession` and `SSHTransportSnapshot` | KEX generation |
| `SSHTransportCounters` / `SSHTransportGauges` | Window adjustments/credit, server KEX, active KEX, keepalive reply/timeout/miss/RTT |
| `SSHTransport.sendKeepalive()` | Reply-correlated monotonic RTT |

The remaining protocols preserve the reviewed full-fidelity semantics for
connect, host verification, public-key authentication, `direct-tcpip`, exec,
upload, client rekey, bounded partial reads/writes, EOF, cancel, reset, close,
timeouts, lifecycle ownership, stable errors, and privacy.

## Conformance rows

| Row | M0 viability assertion | M3 evidence |
| --- | --- | --- |
| E-ALGO | Approved real-server and compatibility algorithms; forbidden downgrade absent. | Broader compatibility evidence may extend later without changing M0 security policy. |
| E-HOSTAUTH | Full reviewed host-before-auth ordering and approved public-key outcomes. | None of this row is deferred. |
| E-CHANNELS | Direct/exec/upload byte semantics, bounded streams, EOF/reset/cancel/sibling isolation. | Exact RFC rejection taxonomy and exact exec-exit presence/`coreDumped`. |
| E-BACKPRESSURE | Write/read/queue bounds and byte-exact partial-write/cancellation semantics. | None of this row is deferred. |
| E-WINDOW | Configured initial window where public, bounded adapter intake/read buffers, no unbounded credit-side storage. | Consumer-earned credit, immutable advertised cap, exact adjustments and snapshots. |
| E-REKEY | Client byte/time/manual production trigger, active traffic survival, fatal failure semantics. | Exact server-KEX lifecycle/reason/generation and deep event reconciliation. |
| E-KEEPALIVE | Bounded configured keepalive transmission and available failure behavior. | Reply-correlated RTT, timeout and consecutive-miss telemetry. |
| E-CANCEL | All reviewed cancellation sites, scopes, deadlines, and cleanup cycles. | None of this row is deferred. |
| E-ERRORS | Stable privacy-safe code/phase/scope/retry/teardown. | Exact RFC channel-open reason only. |
| E-METRICS-PRIVACY | Mandatory cheap metrics reconcile; sentinel privacy scan passes. | Deferred fields reconcile when reported and otherwise assert `notReported`/`unsupported`. |
| E-INJECTION | Same type-erased factory and injected dependencies. | None of this row is deferred. |

Multi-gigabyte soak, staged 100/250/500/1,000-channel scale, physical footprint,
and extension memory numbers remain M3 physical validation owned by
`TASK-260715-2xx2tk` and `TASK-260715-1k3wsk`. They are not fabricated M0
selection results and are distinct from the four deferred seam semantics.

## Consumer mapping

| Consumer | Contract use |
| --- | --- |
| `TASK-260715-1ozsb6` — integrate libssh2 candidate adapter | MUST pass every M0-viability row and disclose all four deferred states. Existing blocker packets remain evidence, not current M0 red rows. |
| `TASK-260715-2d3g5e` — add common SSH transport conformance tests | MUST execute every Tier-1 M0 behavior row against the production libssh2 adapter, assert explicit M3 states, and retain ReluxNIOSSH as an explicit unavailable/deferred matrix entry without fabricating an adapter or doing further fork work. M3 exact-value tests belong to `TASK-260728-3cveay`. |
| `TASK-260715-1u2vpc` — run libssh2 functional and rekey matrix | MUST label M0 viability results separately from M3 deferred/physical rows; absent deep evidence is an explicit state, never a skipped or green value. |

## Retained blocker evidence

The scope decision does not delete or supersede the facts in these board-owned
artifacts:

- `TASK-260715-1ozsb6_libssh2-rekey-blocker.md` — original public client-rekey
  gap; client rekey remains M0 mandatory and is satisfied only through the
  separately reviewed public fork seam.
- `TASK-260715-1ozsb6_server-rekey-keepalive-blocker.md` — pinned server-KEX and
  keepalive reply-correlation evidence.
- `TASK-260715-1ozsb6_third-public-api-blocker.md` — pinned libssh2 receive
  credit, RFC reason, and exec-exit evidence.
- `TASK-260715-1af33i_adapter-api-blocker.md` and
  `TASK-260715-1af33i_window-gap-test-01.log` — ReluxNIOSSH frame-delivery credit
  and neutral TCP ownership evidence.
- `TASK-260715-28ok1k_ssh-engine-candidate-audit.md` — original comparative
  candidate pins, security baseline, and capability matrix.

These artifacts remain referenced so M3 work can reproduce the exact gaps and
so the M0 decision cannot be mistaken for proof that the public APIs expose
them.
