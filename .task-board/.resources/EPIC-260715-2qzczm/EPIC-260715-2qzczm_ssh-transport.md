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

## Engine decision gate

Vanilla SwiftNIO SSH is not an acceptable production engine at the inspected
upstream commit because child channel receive windows are hard-coded to 16 MiB
and client-initiated rekey is internal/test-only. The first spike compares:

1. a minimal `ReluxNIOSSH` fork that makes receive windows configurable and
   exposes safe automatic byte/time rekey; and
2. `libssh2`, including custom channel windows, rekey behavior, algorithm
   compatibility, cancellation, and Network Extension integration.

The selected engine MUST pass all of these gates:

| Gate | Required evidence |
| --- | --- |
| Apple targets | Static or source integration works in iOS and macOS packet-tunnel extensions |
| Host verification | Raw host key/fingerprint is available before authentication acceptance |
| Authentication | Ed25519 and at least one broadly deployed fallback key type work against target servers |
| Direct TCP | Hundreds of concurrent `direct-tcpip` channels can open, backpressure, and close independently |
| Exec | Bidirectional stdio exec channel supports relay bootstrap and long-lived framing |
| Windows | Initial receive window and adjustment policy are configurable per channel |
| Rekey | Client byte/time thresholds and server requests survive active multi-gigabyte TCP and UDP traffic |
| Algorithms | The real `relux` server and a documented compatibility matrix pass |
| Memory | Channel count and buffered-data tests remain inside the extension budget |
| Lifecycle | Cancellation, network loss, and reconnect do not leak channels, tasks, or descriptors |

The engine choice is recorded as an architecture decision only after this
matrix has evidence. A red result triggers the alternate engine; it is not a
reason to weaken the gates.

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
