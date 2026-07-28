# SSH transport specification

## Transport interface

The packet tunnel extension embeds a native SSH client behind this conceptual
interface:

```swift
protocol SSHTransport {
    func connect(profile: SSHProfile) async throws -> SSHSession
    func openDirectTCPIP(
        destination: Endpoint,
        originator: Endpoint,
        policy: ChannelPolicy
    ) async throws -> SSHByteChannel
    func openExecChannel(command: String) async throws -> SSHExecChannel
    func requestRekey() async throws
    func metrics() async -> SSHTransportMetrics
    func close() async
}
```

The concrete API may differ, but the abstraction MUST provide host-key evidence,
bounded writes/backpressure, per-channel window policy, server-initiated rekey,
client-initiated rekey by byte/time threshold, keepalive, cancellation, and
connection metrics. SFTP is intentionally excluded.

## Engine decision (ADR-014, ADR-023)

Vanilla SwiftNIO SSH is not an acceptable production engine at the inspected
upstream commit because child channel receive windows are hard-coded to 16 MiB
and client-initiated rekey is internal/test-only. Three rounds of pinned-source
analysis then showed that the original full-fidelity contract also exceeded the
public surface of *every* candidate, including `libssh2`.

**libssh2 is the selected primary engine** (ADR-014). The minimal `ReluxNIOSSH`
fork is retained as recorded comparative evidence and receives no further fork
work unless new evidence invalidates libssh2.

The contract is therefore split into two tiers. Both are binding; they differ
only in *when* the evidence is owed.

### Tier 1 — M0-viability-mandatory

The selected engine MUST pass every row before the working macOS client path
proceeds. A red row routes to the alternate engine or back to analysis; it is
never a reason to weaken a row.

| Gate | Required evidence |
| --- | --- |
| Apple targets | Static or source integration works in the macOS harness and the macOS packet-tunnel extension (iOS deferred, ADR-024) |
| Host verification | Raw host key/fingerprint is available **before** authentication acceptance |
| Authentication | Ed25519 and at least one broadly deployed fallback key type work against target servers |
| Direct TCP | Concurrent `direct-tcpip` channels open, backpressure, and close independently at the counts the macOS harness can drive |
| Exec | Bidirectional stdio exec channel supports relay bootstrap, exec/stdin upload, and long-lived framing |
| Client rekey | Client-initiated rekey by byte and time threshold succeeds under active traffic |
| Algorithms | The real `relux` server and a documented compatibility matrix pass |
| Bounded memory | Buffers, queues, and advertised credit stay bounded and inside the recorded harness budget |
| Lifecycle | Cancellation, network loss, and reconnect do not leak channels, tasks, sockets, or descriptors |
| Errors | Failures map to privacy-safe categories with no host, credential, or path leakage |

### Tier 2 — M3 evidence-gated (deferred, not waived)

M0 adapters MUST surface each of these as an explicit not-reported or
unsupported state. Fabricating a value, or silently substituting a weaker
behavior, fails the adapter.

| Deferred semantic | Why it is deferred | Owner |
| --- | --- | --- |
| Consumer-driven receive-window credit with an immutable per-channel cap | `libssh2_channel_read` auto-adjusts credit on read entry, before consumer delivery; NIOSSH has the equivalent frame-delivery problem | `TASK-260728-3cveay` |
| RFC 4254 channel-open rejection reason taxonomy | libssh2 collapses the RFC reason codes | `TASK-260728-3cveay` |
| Exact exec-exit metadata: `status(0)` vs `notReported`, and `coreDumped` | The public surface cannot distinguish absent metadata from status 0 | `TASK-260728-3cveay` |
| Deep rekey/keepalive observability: server-initiated KEX lifecycle and generation, reply-correlated keepalive RTT/timeout/miss | No server-KEX lifecycle or reply-correlated global-request result is exposed | `TASK-260728-3cveay` |

Multi-gigabyte rekey soak, staged hundreds-of-channels scale, and extension
memory-budget numbers are M3 physical evidence
(`TASK-260715-2xx2tk`, `TASK-260715-1k3wsk`), not M0 selection inputs.

## Lane pool

One TCP connection creates cross-flow head-of-line blocking. The transport uses
two to four SSH connections to the same host:

- **Lane A — control:** relay exec, health, and latency-sensitive DNS/control;
- **Lanes B and C — general:** ordinary TCP flows;
- **Lane D — bulk:** optional/reserved capacity for new likely bulk flows.

All lanes use the same verified host identity and profile credentials. Opening
optional lanes is constrained by memory pressure and server limits.

A flow is pinned to one lane until close. Live flows are never migrated because
that would reorder the byte stream. New flows use congestion-aware assignment
based on writable window, queued bytes, RTT/health, open-channel count, port,
and best-effort destination metadata. Lane D cannot retroactively adopt a flow
that later turns out to be an elephant.

## Channel windows

Initial candidate receive windows:

- control and ordinary flows: 32–64 KiB;
- bulk flows: calculated from a capped bandwidth-delay product and memory budget;
- relay channel: small bounded control window plus enough credit for configured
  maximum UDP frame bursts.

An advertised receive window cannot be revoked. Under pressure the transport
withholds `WINDOW_ADJUST` and gives smaller initial windows to new channels.
Window policy is measured per lane and channel; it MUST NOT multiply a large
default by the maximum session count.

## Rekey and connection health

- Rekey thresholds are configured by transferred bytes and elapsed time.
- Client-initiated and server-initiated rekeys are supported.
- New channel assignment may pause during key exchange, while existing channel
  state remains valid.
- A failed rekey fails only its lane first; the lane pool stops assigning new
  flows there and re-establishes it without migrating existing flows.
- Failure of lane A restarts relay/control capability and may temporarily enter
  degraded mode; it does not silently leak UDP or DNS.
- Keepalive distinguishes SSH liveness from application traffic and cannot be
  the sole path-change detector.

## QUIC policy

`Auto` rejects new destination UDP/443 flows quickly when SSH lane loss/latency
indicates QUIC-over-SSH will underperform a TCP fallback. `Allow QUIC` forwards
normally through the relay. `Block UDP/443` always sends a local unreachable or
equivalent fast failure. The policy MUST NOT drop unrelated UDP/443 silently for
long timeouts.

## Compatibility and non-goals

The baseline supports direct SSH hosts. `ProxyJump`, password prompts, agent
forwarding, X11, arbitrary port-forward UI, and interactive shells are outside
the initial engine surface. Adding them requires an explicit threat-model and
memory-budget update.
