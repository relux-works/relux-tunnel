# ``ReluxTunnelCore``

Platform-neutral contracts for the Relux packet-tunnel runtime.

## Contract ownership

| Contract | Specification / decision | Boundary only in M0 |
| --- | --- | --- |
| `TunnelEndpoint`, `TunnelConfigurationReference`, `TunnelConfiguration` | `architecture.md` control/state ownership; `routing-dns-lifecycle.md` startup step 1 | UUID-backed non-secret provider reference; no persistence, Keychain data, route, or UI semantics |
| `PacketFlow`, `TunnelPacket`, `PacketFlowBridge` | `packet-plane.md`; ADR-003 | Public datagram socket pair and scoped descriptor borrow; no HEV implementation, tuning defaults, or utun discovery |
| `SSHTransport` and channel/upload types | `ssh-transport.md`; ADR-005, ADR-006, ADR-014 | No engine selection, lane policy, authentication, or relay bootstrap |
| `InternalSOCKSComponent` | `architecture.md` packet plane; `packet-plane.md`; ADR-004 | Process-local component seam only; not a user proxy |
| `TunnelRuntime`, `TunnelProviderLifecycle`, `TunnelProviderAdapter` | accepted VPN lifecycle contract | Shared generation-safe start/stop/failure joining, four-command read-only routing, and bounded cleanup; no reconnect or mutable RPC |
| `OwnedVPNManagerRepository`, `VPNSessionController` | accepted VPN lifecycle contract sections 3–7 | Fresh exact-owned session commands, system-authoritative status, provider-authoritative capability projection, and bounded host waits; no forwarding ownership or reconnect |
| `ProviderMessageCodec`, `RuntimeMessageCodec` | Accepted M1 runtime contract section 9 | Exact legacy version query plus bounded deterministic v1 configuration, command, snapshot, diagnostics, and error models |
| Clock, logging, cancellation, metrics, memory pressure | `packet-plane.md` backpressure/memory/metrics; `ssh-transport.md` lifecycle/rekey metrics; `validation.md` | Injected observation/control seams with no production policy defaults |

The module imports Foundation for portable data and coding primitives. It must
not import NetworkExtension, SwiftUI, UIKit, or AppKit, and it must not depend on
containing-app or generated-target modules.

## Topics

### Runtime messages

- <doc:RuntimeMessages>
