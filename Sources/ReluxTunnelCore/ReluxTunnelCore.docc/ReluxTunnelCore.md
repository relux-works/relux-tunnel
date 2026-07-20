# ``ReluxTunnelCore``

Platform-neutral contracts for the Relux packet-tunnel runtime.

## Contract ownership

| Contract | Specification / decision | Boundary only in M0 |
| --- | --- | --- |
| `TunnelEndpoint`, `TunnelConfigurationReference`, `TunnelConfiguration` | `architecture.md` control/state ownership; `routing-dns-lifecycle.md` startup step 1 | No persistence, Keychain, route, or UI semantics |
| `PacketFlow`, `TunnelPacket`, `PacketFlowBridge` | `packet-plane.md`; ADR-003 | Public datagram socket pair and scoped descriptor borrow; no HEV implementation, tuning defaults, or utun discovery |
| `SSHTransport` and channel/upload types | `ssh-transport.md`; ADR-005, ADR-006, ADR-014 | No engine selection, lane policy, authentication, or relay bootstrap |
| `InternalSOCKSComponent` | `architecture.md` packet plane; `packet-plane.md`; ADR-004 | Process-local component seam only; not a user proxy |
| `TunnelRuntime`, `TunnelProviderLifecycle` | `architecture.md` provider ownership; `routing-dns-lifecycle.md` | No route, DNS, reconnect, or capability implementation |
| `ProviderMessageCodec` | `architecture.md` versioned app-message snapshot | Version query only; later message kinds require their owning spec |
| Clock, logging, cancellation, metrics, memory pressure | `packet-plane.md` backpressure/memory/metrics; `ssh-transport.md` lifecycle/rekey metrics; `validation.md` | Injected observation/control seams with no production policy defaults |

The module imports Foundation for portable data and coding primitives. It must
not import NetworkExtension, SwiftUI, UIKit, or AppKit, and it must not depend on
containing-app or generated-target modules.
