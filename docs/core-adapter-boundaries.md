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

## Deliberately deferred behavior

- Real HEV startup/quit/join integration, MTU selection, and final socket-buffer
  and work-slice values remain later packet-plane work (ADR-003 and ADR-015).
- `SSHTransport` is injectable; it does not choose ReluxNIOSSH or libssh2
  (ADR-014). Upload is explicitly exec-stdin rather than SFTP (ADR-006).
- Internal SOCKS is a process-local component seam and not a user proxy.
- The provider codec implements only the M0 version query. State snapshots,
  commands, compatibility ranges, and host-side projection belong to later
  lifecycle specifications.
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
