# TASK-260715-1gjxer — ADR-014 binding M0 SSH engine selection

- Status: Accepted
- Decision date: 2026-07-28
- Evidence refresh: 2026-08-18
- Decision owner: human owner approval recorded by `TASK-260715-1gjxer`
- Contract authority: ADR-023 and `TASK-260728-yx2fca_ssh-transport-conformance-contract.md`
- Selected engine: libssh2
- Comparative candidate retained: ReluxNIOSSH

## Decision

Select the pinned libssh2 adapter as the M0 primary SSH engine. The decision is
binding for M1 and M2 composition. ReluxNIOSSH remains preserved comparative
evidence and receives no additional adapter or fork work unless a revalidation
trigger below produces new evidence that invalidates libssh2.

This decision uses the owner-approved M0 viability boundary. It does not waive
a mandatory red gate. Consumer-driven receive credit, RFC channel-open reason
taxonomy, exact exec-exit presence and `coreDumped`, and deep server-rekey /
keepalive observability remain explicit M3 obligations. Physical scale,
extension memory, deep-observability, multi-gigabyte soak, and production DNS
budget numbers are not asserted here.

## Evidence rules

- `PASS` means the candidate row was executed or independently source/build
  verified under the accepted M0 contract.
- `FAIL` means existing evidence proves a mandatory candidate surface does not
  conform. No threshold was changed after the result.
- `NOT RUN` means there is no conforming candidate adapter with which to run the
  row; the exact reason and retained evidence are named. `NOT RUN` is not pass.
- The selected engine has no `FAIL` or `NOT RUN` M0 row. A future red mandatory
  libssh2 row reopens ADR-014 and routes work to analysis or the retained
  ReluxNIOSSH branch; it cannot be relabeled or waived.

## Row-level comparative M0 gate matrix

| Mandatory gate | libssh2 selected-engine result and evidence | ReluxNIOSSH comparative result and evidence |
| --- | --- | --- |
| macOS target / extension integration | **PASS.** `TASK-260715-1ozsb6` round-12 reviewer: application-extension release builds for macOS arm64/x86_64 provider and harness; `TASK-260715-1u2vpc` independently repeated all four builds. | **NOT RUN — no conforming adapter.** The pinned fork itself builds (`TASK-260715-nzdzv3`: 323 upstream + 10 fork tests), but `TASK-260715-1af33i` never produced an extension adapter, so candidate integration was not claimed. |
| candidate-neutral injection boundary | **PASS.** `TASK-260715-1ozsb6` accepted boundary scan: libssh2 types remain inside `ReluxTunnelLibSSH2Adapter`; resolver, connector, host policy, credential signer, clock, cancellation, logger, observer, metrics, identity, and factory are injected. | **FAIL.** `TASK-260715-1af33i_adapter-api-blocker.md`: NIOSSH requires a NIO channel/owned socket while the neutral seam exposes fakeable bytes; downcast, second socket, and socketpair pump were rejected. |
| pre-auth raw host evidence / fail closed | **PASS.** `TASK-260715-1u2vpc` E-HOSTAUTH and accepted conformance tests: raw wire key and negotiated host-key algorithm reach policy before credential lookup; six rejected cases record credential/auth/channel opens as zero. | **NOT RUN — no adapter.** Pinned source exposes host-key validation during KEX, but no neutral-adapter row exists; retained source audit is `TASK-260715-28ok1k`. |
| approved public-key authentication | **PASS.** Live OpenSSH Ed25519 opaque external signer plus P-256 fallback; host policy precedes credential lookup and resources return to zero (`TASK-260715-1ozsb6`, `TASK-260715-1u2vpc`). | **FAIL.** `TASK-260715-1af33i_fork-api-blocker.md`: public NIOSSH authentication requires a concrete private key and has no async opaque external-signer offer; exporting or downcasting secret material was rejected. |
| approved algorithm policy / compatibility | **PASS.** Real OpenSSH exact primary and fallback rows: curve25519-sha256 / ssh-ed25519 / aes256-ctr / hmac-sha2-256 and diffie-hellman-group14-sha256 / ecdsa-sha2-nistp256 / aes128-ctr / hmac-sha2-512; SHA-1 and CBC are excluded. Negotiated values equal the allowlists (`TASK-260715-1u2vpc` E-ALGO). | **FAIL.** `TASK-260715-1af33i_fork-api-blocker.md`: caller KEX/host-key allowlists and exact negotiated KEX/host-key/cipher/MAC are not public. Guessing from configured capabilities was rejected. |
| concurrent `direct-tcpip` | **PASS.** Real loopback OpenSSH direct echo, exact destination/originator, sibling isolation across rejection/timeout/reset/cancel, bounded partial I/O, and independent close (`TASK-260715-1u2vpc` E-CHANNELS and `TASK-260715-2d3g5e`). | **FAIL.** Source supports direct-tcpip, but the accepted neutral byte connector cannot host NIOSSH without violating ownership/injection (`TASK-260715-1af33i_adapter-api-blocker.md`). No fake adapter pass is recorded. |
| exec, long-lived exec, exec/stdin upload | **PASS.** Concurrent exec, 128 KiB long-lived stdout, bounded stdin upload to `cat >/dev/null`, and sibling isolation pass against real OpenSSH; no SFTP surface is used (`TASK-260715-1u2vpc` E-CHANNELS). | **NOT RUN — no adapter.** Upstream source has session/exec/write/half-close primitives, but the end-to-end neutral-adapter row was not executable. |
| client byte/time/manual rekey under traffic | **PASS.** Public allowlisted fork call reaches production KEX; 4 KiB byte trigger with 6 KiB traffic, injected 100 ms time trigger, manual/test coalescing, post-KEX traffic, and C fixture rekey after three EAGAIN results pass (`TASK-260720-3vwls7`, `TASK-260715-1ozsb6`, `TASK-260715-1u2vpc`). | **NOT RUN — no adapter.** The retained fork implements public manual/byte/time rekey and its fork tests pass, but the active real-server adapter matrix `TASK-260715-3ikonq` was not run. |
| server-initiated rekey safety | **PASS.** OpenSSH `RekeyLimit 32K 0` produces 16 observed server KEX transitions while channel traffic remains byte-exact and post-rekey channels work (`TASK-260715-1u2vpc` E-REKEY). | **NOT RUN — no adapter.** The fork exposes server-KEX state, but no candidate adapter row exists. |
| bounded buffers / backpressure / harness memory | **PASS.** 64 KiB transport and initial channel window, 16 KiB read buffer, 32 KiB queued writes, 8 KiB write call, and 64 pending-operation cap pass; excess returns `resourceLimitExceeded` and cleanup is zero (`TASK-260715-1u2vpc` E-BACKPRESSURE). The controlled five-run macOS row below measured a bounded whole-test-process envelope; it is not an extension-footprint claim. | **FAIL.** `TASK-260715-1af33i_adapter-api-blocker.md`: a 16 KiB NIOSSH frame can earn full credit before a 1 KiB API read and no public intake/packet bound reconciles adapter buffering. Exact consumer-credit reporting is M3 for both engines, but bounded adapter intake remains M0 and is not proved here. |
| deterministic cancellation / leak-free lifecycle | **PASS.** Fifteen named cancellation sites, failed handshake, non-cooperative dependency, repeated channel cancellation, and three connect/close cycles restore channels/socket/session/tasks/custom allocations/buffered bytes to zero (`TASK-260715-1u2vpc` E-CANCEL; accepted `TASK-260715-2d3g5e`). | **NOT RUN — no adapter.** Source inspection alone cannot prove neutral-operation cancellation or lifecycle cleanup. |
| privacy-safe errors and diagnostics | **PASS.** Stable typed phase/scope/retry/teardown mapping plus populated error/log/observer/metric/snapshot surfaces exclude host, user, endpoint, fingerprint, credential, command, path, stream, and payload sentinels (`TASK-260715-2d3g5e`). | **NOT RUN — no adapter.** No production diagnostic surface exists to exercise. |
| Keychain-only secret posture | **PASS.** The seam carries an opaque credential reference and external signer; accepted system-domain Keychain resolver evidence is `TASK-260715-1o9wjz`, and the live Ed25519 row never exports the key. | **FAIL.** The only public NIOSSH offer requires a concrete `NIOSSHPrivateKey`; the neutral opaque signer cannot reach it (`TASK-260715-1af33i_fork-api-blocker.md`). |
| keepalive and available observability | **PASS.** Bounded manual/automatic keepalive transmission and fatal failure handling pass; cheap state/counters/gauges reconcile and unavailable deep values are explicit `unsupported`/`notReported` (`TASK-260715-1u2vpc`, `TASK-260715-2d3g5e`). | **FAIL.** Generic reply-requiring global request is internal and exact negotiated algorithm reporting is absent; a TCP forwarding request is not a keepalive (`TASK-260715-1af33i_fork-api-blocker.md`). |
| real-server compatibility | **PASS.** `approvedRealReluxHostCompatibility` executes the selected `LibSSH2TransportFactory` against the owner-approved real `relux` SSH service, not a protocol fake or reachability proxy. Three consecutive privacy-safe runs exited 0 in 23.171, 22.654, and 21.904 s. Every run proved raw host-policy evaluation before credential lookup, SSH-agent-backed Ed25519 public-key authentication, two concurrent `direct-tcpip` channels to an authorized loopback service, long-lived exec, 48 KiB exec/stdin upload, manual client rekey, five cancelled exec/read operations, and exact zero adapter ownership. Negotiation was `curve25519-sha256` / `ssh-ed25519` / `aes256-ctr` / `hmac-sha2-256` in both directions; counters were auth 1, direct 2, exec 7, successful rekeys 1. The outer owner-approved alias supplies only a local byte-forwarding path to the same real sshd; no host, address, account, key path, key material, command output, or remote content is retained. `TASK-260715-39xz9g` remains fixture/access authority, while this row is the candidate execution authority. | **NOT RUN — no adapter.** Real-host fixture reachability exists, but no ReluxNIOSSH candidate driver was executed. |

The ReluxNIOSSH `FAIL` and `NOT RUN` rows are preserved comparison evidence,
not waived libssh2 requirements. They explain why further fork work has lower
value while libssh2 remains green.

## Exact selected dependency pins and packaging

| Component | Binding pin and integrity | License / redistribution |
| --- | --- | --- |
| libssh2 | untagged `1.11.2_DEV`, commit `a34302491c164d53c900fec9b3cbb050ecebe719`; archive SHA-256 `744ba3e9a8e7a877038e94a74459340052a105ad599605a5b6d0d6bc5ec2c87c` | BSD-3-Clause; `COPYING` SHA-256 `a83a4da224ebeaaaea5efb4cd1ef1ab0998c1bd719d6f70b05e1d5c491372137`; reproduce notice, conditions, disclaimer. |
| OpenSSL | tag `openssl-3.5.7`, commit `8cf17aaeb4599f8af87fefd810b5b5fee90fe69e`; archive SHA-256 `a8c0d28a529ca480f9f36cf5792e2cd21984552a3c8e4aa11a24aa31aeac98e8` | Apache-2.0; license SHA-256 `7d5450cb2d142651b8afa315b5f238efc805dad827d91ba367d8516bc9d49e7a`; acknowledgements SHA-256 `58dee45791f007ced048114717f86672778fe75c551827c57e760861446ce3c3`. |
| Relux libssh2 delta | one patch, SHA-256 `79e2464813e3c3add9486b2fb8c9e50004b48b246bbc771b5dd1675a152fa30e`; maximum one patch / six changed paths; public header SHA-256 `aa542cff4e0e64927983da8c50b0315cd24c6d097fcdd42809d2e3b0878625bf` | No crypto or algorithm changes and no private-header export. Combined notice is `NativeDependencies/Generated/LIBSSH2_OPENSSL_THIRD_PARTY_NOTICES.txt`. |
| retained ReluxNIOSSH | SwiftNIO SSH `0.14.1`, commit `31cdc3c3391a10460dedf1170530cf651d2ca496`; archive SHA-256 `0b135087e76cb03e33f544484f21e1c3ba3b967f8a0ba2aead960ce4d0d06e6a`; fork patch SHA-256 `1241622deca47f05a139998a94b2ce988935bb0e288f26cf57dc71f3d23317a4` | Apache-2.0; license SHA-256 `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`; preserve attribution. |

The selected artifact is a statically linked `ReluxLibSSH2.xcframework`
SwiftPM binary target containing libssh2 plus libcrypto, built from verified
archives before patching. Runtime downloads are prohibited. Pin identity is
the commit plus hashes; the stale libssh2 numeric version macro is not evidence.

## Adapter and configuration boundary

`ReluxTunnelCore` owns candidate-neutral transport/session/channel contracts.
Only `ReluxTunnelLibSSH2Adapter` imports the public XCFramework module. The
selected adapter is composed only in the approved macOS provider and harness;
the shared core and deferred iOS graph contain no libssh2 type. One serialized
owner services each mutable libssh2 session and its socket, channels, KEX,
timers, callback bridge, allocation accounting, and teardown.

The following remain injected rather than hidden engine defaults:

- resolver and connected-byte transport; host-key policy before credential
  lookup; opaque credential provider/external signer;
- clock, timeouts, cancellation, logger, observer, metrics, identity, and
  factory;
- exact KEX, host-key, cipher, MAC, and user-key allowlists;
- channel initial window, local read/write/call/pending-operation bounds;
- byte, time, manual, and test rekey trigger policy and timeout;
- keepalive interval/reply policy.

Approved algorithm profiles are the primary and fallback rows in the matrix.
RSA-SHA1, group1/SHA-1 KEX, HMAC-SHA1, CBC, password/interactive fallback,
agent forwarding, SFTP, ProxyJump, and silent downgrade are outside M0.

Initial receive windows for control and ordinary flows remain injectable in the
accepted candidate range **32–64 KiB**. The M0 evidence row used 64 KiB with
16/32/8 KiB read/queued-write/write-call bounds. Bulk/relay window winners and
an immutable consumer-credit cap remain M3 ledger decisions; libssh2 reports
that exact deferred semantic as `unsupported` rather than fabricating it.

Rekey byte threshold, elapsed-time threshold, and timeout are injected values.
The accepted **M0 configuration envelope** is concrete and intentionally
separate from a production tuning winner:

| Injected field | M0 accepted range | Evidence and authority |
| --- | --- | --- |
| protected bytes per direction | **4 KiB–5 GiB inclusive** | 4 KiB executes the automatic production KEX path; 5 GiB is the preregistered M3 upper candidate. |
| elapsed time | **100 ms–1 hour inclusive** | 100 ms executes the injected-clock automatic production KEX path; one hour is the preregistered M3 upper candidate. |
| rekey completion timeout | **10 s exactly for M0 composition** | 10 s is the executed bounded timeout. A wider production range is unresolved rather than guessed. |

M1/M2 composition must inject values inside this envelope and may not silently
use the broader positive-only constructor domain. The final winners and any
wider timeout range remain owned by `TASK-260715-1pn983` and the M3 tuning/final
matrix; changing this envelope requires a new preregistered evidence revision.
The 4 KiB, 100 ms, and 10 s probes are evidence values, not production defaults.

This closes a literal-spec gap exposed by independent review: the SSH specs
require injectable byte/time rekey and a bounded failure timeout but do not
state an admissible M0 numeric envelope. Before adding the guardrail, the check
covered `.spec/ssh-transport.md`, the conformance contract, ADR-023, the M3
protocol, and downstream `TASK-260715-1pn983`; none selected a production
winner. The guardrail therefore names the gap, uses only an executed lower
probe and preregistered upper candidates, leaves the unproved timeout range
explicitly unresolved, and does not assert physical scale, extension budget,
lane policy, profile UX, or release approval.

## Controlled selected-engine direct-tcpip timing, memory, and cleanup row

On current source `2064698ca526260d9994582852486301bb06a752`, five consecutive
already-built executions of
`swift test --skip-build --filter successfulM0FlowsAndLifecycleBaseline` ran on
the named macOS harness and all exited 0. Each execution used real loopback
OpenSSH, opened and echo-tested one `direct-tcpip` channel, exercised concurrent
exec/upload/rekey/keepalive/cancellation in the first of three lifecycle
iterations, then required an exact zero owned snapshot after every iteration.

| Measurement | Observed value |
| --- | --- |
| test-body duration | 11.058, 11.101, 11.071, 11.144, 11.084 s; median 11.084 s; maximum / nearest-rank p95 11.144 s |
| whole command elapsed | 12.23, 11.59, 11.54, 11.64, 11.59 s; median 11.59 s; maximum / nearest-rank p95 12.23 s |
| whole `swift test` maximum RSS | 71,254,016 B first run; 58,703,872 B on each later run; maximum 71,254,016 B |
| macOS reported peak memory footprint | 17,891,952; 15,778,368; 15,811,136; 15,663,680; 17,416,768 B; maximum 17,891,952 B |
| selected-adapter owned cleanup after each iteration | channels 0; socket false; session false; automatic tasks 0; custom allocations 0; buffered bytes 0 |
| test result | **PASS, 5/5, exit 0** |

This is a conservative controlled M0 lifecycle envelope containing a real
direct-tcpip exchange, not an isolated channel-open p99, DNS production policy,
physical provider footprint, extension footprint, scale slope, or residual DNS
budget. `DNS-START-E1/E4/E8`, `DNS-OPEN-COLD`, `DNS-REUSE-WARM`, and
`DNS-RETIRE` remain M3 protocol rows. The row satisfies the selection/DNS
handoff need for selected-engine timing, bounded harness memory, and cleanup
evidence without authorizing the candidate DNS timeout or memory numbers.

## M3-deferred semantics and physical gates

All four semantics are owned by `TASK-260728-3cveay`:

1. consumer-driven receive credit with an immutable per-channel cap —
   `unsupported`;
2. RFC 4254 channel-open rejection reason taxonomy — `unsupported` for a
   channel rejection and `notApplicable` elsewhere;
3. exact exec-exit presence and signal `coreDumped` — `notReported`;
4. server-KEX lifecycle/generation and reply-correlated keepalive RTT, timeout,
   and miss telemetry — `unsupported`.

Physical multi-gigabyte soak and 100/250/500/1,000-channel scale remain `NOT
RUN — M3` under `TASK-260715-2xx2tk`. Physical rekey/memory/extension footprint
and soak remain `NOT RUN — M3` under `TASK-260715-1k3wsk`. Exact DNS startup,
open/reuse/retire footprint is governed by the M3 evidence protocol and still
requires the residual component ledger from `TASK-260715-1pn983`. No physical
or extension-budget number is inferred from the macOS harness process row.

## Maintenance, security monitoring, and ownership

- Current libssh2 delta provenance/rebuild owner: `TASK-260720-3vwls7` evidence
  and `Dependencies/ReluxLibSSH2/PATCH_MANIFEST.json`.
- Ongoing selected-engine fork/upstream-rebase owner: `TASK-260728-3cveay` for
  the next required public semantic delta; every rebase must preserve the
  one-patch/six-path ceiling or reopen ADR-014.
- Native package owner obligation: verify both archives before extraction,
  exact patch/header/artifact locks, static/extension-safe slices, minimum OS,
  forbidden symbols/paths, and combined notices through
  `make validate-libssh2` and source-negative gates.
- Security owner obligation: monitor libssh2 and OpenSSL advisories/releases and
  issues #2023, #1925, #1810, #1672, #1491, #1490, #1370, #1218, #1188, #792,
  and #671. Re-audit immediately before any signed artifact/release and prefer
  a signed libssh2 1.11.2+ release only after it contains all six recorded fixes
  and passes the unchanged matrix. No silent pin movement is permitted.
- ReluxNIOSSH is frozen comparative evidence. Its rebase procedure remains
  reproducible, but no owner may execute additional fork work unless ADR-014 is
  reopened by new libssh2-invalidating evidence.

## Residual risks and revalidation triggers

Residual risks: the selected libssh2 pin is untagged; static OpenSSL increases
native attack surface, rebuild burden, and possible duplicate-crypto footprint;
libssh2 session/channel lookup is mutable and partly O(n); OpenSSL allocations
are outside libssh2 custom allocator accounting; issue #2023 remains unresolved;
exact deep semantics and physical scale/footprint are still M3 gates; the
controlled direct-tcpip row is a whole-cycle envelope rather than open-only
latency; the real-host row uses an owner-approved local byte-forwarding path and
does not replace later physical-provider, impairment, footprint, or scale rows.

Reopen ADR-014 and route to analysis or the retained candidate if any of these
occurs:

- a mandatory selected-engine row becomes red, leaks a resource, loses or
  corrupts traffic, violates host-before-auth, exports secret material, or
  requires a weakened threshold;
- a new libssh2/OpenSSL advisory affects the pin, issue #2023 is confirmed
  against the selected algorithms, or a signed release changes relevant code;
- the patch exceeds one allowlisted patch/six paths, changes crypto/algorithms,
  exports private headers, or cannot rebase cleanly;
- macOS/Xcode/deployment targets, OpenSSH server policy, approved algorithms,
  real relux host policy, Keychain boundary, or adapter/core boundary changes;
- M3 physical scale, memory, soak, DNS, or deep-observability evidence is red;
- new evidence makes ReluxNIOSSH conform at materially lower security,
  maintenance, or footprint cost.

Rejected evidence is retained and never relabeled: the historical aggregate-red
libssh2 log in `TASK-260715-1u2vpc_evidence.zip`, early failing byte-threshold
tests, every ReluxNIOSSH blocker, and every `NOT RUN` M3 row. Later accepted
reruns explain the disposition; they do not erase failures.

## Downstream readiness

After independent acceptance of this ADR, the selected engine/pin/boundary is
ready for `TASK-260720-1qhxqa` (binding manifest), the M1 profile/bootstrap,
direct-TCP, and runtime composition path, and the M2 stdio relay launch and
handshake path including `TASK-260715-2hhh7x`, `TASK-260715-2uipar`, and
`TASK-260715-159pcp`. It also supplies selected-engine evidence to
`TASK-260721-3miqh4` while leaving its residual DNS budget and physical rows
gated. M3 consumers `TASK-260715-3f9kv8`, `TASK-260715-1pn983`,
`TASK-260715-s3at1l`, and `TASK-260728-3cveay` consume the decision without
turning deferred values into defaults.

No new story, task, research task, dependency, or diagram is required. The
existing board is the smallest decomposition and already links this task to its
accepted upstream evidence and downstream consumers.
