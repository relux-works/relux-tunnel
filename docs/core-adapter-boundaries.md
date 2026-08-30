# ReluxTunnelCore and platform-adapter boundaries

This document records the source boundary introduced by
`TASK-260715-2nfz7w`. It implements the M0 seams in `.spec/architecture.md`,
`.spec/packet-plane.md`, `.spec/ssh-transport.md`, and
`.spec/routing-dns-lifecycle.md` without selecting future engines or policies.

## Dependency direction

```text
ReluxProxyIOSTunnel (later) ─> ReluxTunnelIOSAdapter ─┐
                                                     ├─> ReluxTunnelCore
ReluxProxyMacTunnel (later) ─> ReluxTunnelMacOSAdapter┤
ReluxTunnelHarness ─────────> ReluxTunnelHarnessSupport┘
                               │
                               └─> ReluxTunnelNativeAdapter ─> static native binaryTarget
```

`ReluxTunnelCore` has no dependency on either adapter, any containing app,
generated target state, or UI framework. Only the two named adapter modules
import `NetworkExtension`. Their production initializers wrap public
`NEPacketTunnelFlow`; their protocol-based initializers let both composition
roots run against the same Swift Testing contracts before Gate P0 workspace
targets exist.

`ReluxTunnelNativeAdapter` is the only shared package target that directly
imports packaged C modules. Provider adapters and harness support may depend on
it, while the dependency direction remains native adapter to Core contracts.
The manifest, rebuild, notice, and archive checks are described in
[`native-dependency-packaging.md`](native-dependency-packaging.md).

## Implemented packet bridge

`ReluxTunnelCore` now owns the public `AF_UNIX`/`SOCK_DGRAM`
`PacketFlowBridge`: checked four-byte network-order family framing, bounded
forward and reverse pumps, run-scoped metrics, injected readiness/socket seams,
and an exclusive endpoint-B borrow that is joined before B then A are closed.
It uses the shared `PacketFlowAdapterBoundary` for the public
`NEPacketTunnelFlow` callback transition and contains no utun discovery.

## Implemented bounded TCP admission

`ReluxTunnelCore` owns a generation-scoped `TCPAdmissionRegistry` with
caller-injected handshake, reserved-flow, concurrent-open, and aggregate
queued-byte ceilings. Flow configuration is rejected unless it remains under
both the injected measured-safe flow ceiling and HEV session ceiling. Atomic
reservation tokens account for parsing, opening, streaming, half-closed,
channel, directional-buffer, byte-total, peak, pressure, and finite terminal
state without choosing an SSH engine or implementing downstream close policy.
Identifiers are never reused within a generation; allocation fails closed with
a finite capacity reason before `UInt64` wrap can create an ABA collision.

Admission is non-waiting and has no side queue. A pressure rejection carries
the documented SOCKS5 general-failure reply (`REP=01`) and
`shouldOpenSSHChannel=false`, so callers can fail quickly before invoking the
SSH transport. Runtime snapshots use only fixed aggregate counters, gauges,
terminal/pressure tokens, and channel-open latency buckets; the API accepts no
hostname, address, port, payload, credential, flow ID, or destination label.
Registry current-state gauges use one fixed-size generation-scoped atomic
coalescer. Snapshot reconciliation therefore converges to the registry's latest
absolute state even when the separately bounded event lane drops intermediate
counter or histogram updates; the ingestion-drop counter remains observable.
Counters and histogram buckets remain saturating monotonic totals of accepted
ingestion events and may conservatively undercount when that signal increases.

## Deliberately deferred behavior

- Real HEV startup/quit/join integration, MTU selection, and final socket-buffer
  and work-slice values remain later packet-plane work (ADR-003 and ADR-015).
- `SSHTransport` is injectable; it does not choose ReluxNIOSSH or libssh2
  (ADR-014). Upload is explicitly exec-stdin rather than SFTP (ADR-006).
- Internal SOCKS is a process-local component seam and not a user proxy.
- The frozen M0 version query remains supported. Versioned v1 runtime commands,
  compatibility ranges, snapshots, diagnostics, and host-side projection are
  now implemented in the shared package; see
  [`m1-runtime-ownership-and-operations.md`](m1-runtime-ownership-and-operations.md).
  Concrete generated provider-subclass wiring remains outside this package
  boundary.
- Route, DNS, reconnect, relay framing, profile persistence, Keychain access,
  UI, and concrete provider subclasses are outside this package change.

All packet, SSH, and SOCKS numeric limits require caller-supplied values; this
boundary does not promote the measurement candidates in the specs to defaults.

## Verification

Run from the repository root:

```sh
make check-core-boundaries
make check-native-dependencies
make core-test
make core-build
```

The boundary check rejects forbidden imports in the core and verifies the
SwiftPM dependency graph. `core-test` runs the common iOS/macOS lifecycle,
packet-flow adapter, packet-bridge ownership/framing/fault-injection, and
version-message contracts through injected dependencies.
