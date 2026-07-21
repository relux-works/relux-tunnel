# Architecture decision log

| ID | Status | Decision |
| --- | --- | --- |
| ADR-001 | Accepted | Build a system VPN around `NEPacketTunnelProvider`; keep the live SSH transport inside the extension |
| ADR-002 | Accepted | Use HEV/lwIP instead of writing a TCP/IP stack |
| ADR-003 | Accepted | Bridge `NEPacketTunnelFlow` through a public nonblocking `AF_UNIX/SOCK_DGRAM` socket pair; do not discover the utun FD |
| ADR-004 | Accepted | Fix HEV's internal UDP mode to UDP-in-TCP and reuse its datagram address framing |
| ADR-005 | Accepted | Use SSH `direct-tcpip` for TCP and a rootless exec/stdio relay for UDP |
| ADR-006 | Accepted | Upload the relay through exec stdin; do not add SFTP to `SSHTransport` |
| ADR-007 | Accepted | Support full and degraded TCP + safe-DNS modes instead of failing solely because UDP relay is unavailable |
| ADR-008 | Accepted | Use 2–4 SSH lanes, pin live flows, and assign only new flows using congestion-aware policy |
| ADR-009 | Accepted | Treat channel windows, lane count, HEV limits, and reconnect overlap as one memory budget |
| ADR-010 | Accepted | Expose configurable QUIC behavior; default `Auto` may force a fast TCP fallback |
| ADR-011 | Accepted | Develop packet/SSH/relay core through an SPM macOS harness while proving packetFlow, lifecycle, and memory on physical iPhone |
| ADR-012 | Accepted | Make compatible and platform-scoped fail-closed route modes explicit user choices |
| ADR-013 | Gate | Obtain evidence that local TCP termination + remote `direct-tcpip` is acceptable under Apple's packet-tunnel intended-use guidance |
| ADR-014 | Open | Select a minimal SwiftNIO SSH fork or libssh2 only after per-channel windows, rekey, compatibility, memory, and lifecycle tests |
| ADR-015 | Open | Select the production MTU from physical-device tests of 1500, 4096, and 8500 |
| ADR-016 | Accepted | Set new Apple targets to iOS 18.0 and macOS 15.0; preserve the legacy SwiftPM product at macOS 14.0; require minimum/current CI plus named physical baselines per TASK-260715-3r0993 |
| ADR-017 | Accepted | Use Tuist 4.202.5 pinned exactly by repository-local Mise; generate with an explicit Xcode pin and deterministic graph/project comparison per TASK-260715-3r0993 |
| ADR-018 | Accepted | Ship macOS in-app self-update via Sparkle 2.x with an EdDSA-signed appcast; every payload is an already-notarized Developer ID build; iOS updates stay with the App Store |
| ADR-019 | Accepted | Package custom-build C dependencies such as HEV and libssh2 as locally rebuilt static XCFramework SwiftPM `binaryTarget`s behind named native adapter modules; keep reviewable source packages such as ReluxNIOSSH as source dependencies and keep all native dependencies out of `ReluxTunnelCore` proper |
| ADR-020 | Accepted | Set HEV `udp-copy-buffer-nums` M0 baseline to 2 (injectable), so the effective task stack stays 24576; the pinned HEV computes task stack = 20480 + max(tcp-buffer-size, 1500 × udp-copy-buffer-nums) and the default 10 silently forces 35480. Final value is an M3 physical-UDP evidence gate; HEV stays unmodified (config only). Resolves the TASK-260715-1vv52g stop-the-line. |
| ADR-021 | Accepted | Keep protocol v1 resource limits as fixed schema constants and unilateral local caps (no wire exchange beyond the existing `maxFrame` min-negotiation): `maxUDPPayload` frozen at 1472 by the pinned HEV 1500-byte UDP copy-buffer bound; association/queue/idle values are injectable M0 baselines with schema-owned floors and hard ceilings; hello flag bit 1, feature bit 1, and message types `0x40–0x4F` reserved for an evidence-gated M3 limits exchange (TASK-260715-18owh7) |
| ADR-022 | Proposed | Require an ordered, explicit per-profile `dnsResolver` containing a non-empty list of numeric IPv4/IPv6 DNS endpoints; select generation-scoped DNS-over-TCP through authenticated SSH for M1 and the same endpoints for M2 relay UDP with explicitly bounded TCP retry. There is no Relux/product resolver default, exit-host discovery, hostname resolver endpoint, tunneled DoH, or physical-resolver fallback in the baseline. TASK-260715-1tnjlu owns schema and failure invariants; TASK-260721-3miqh4 must select every numeric endpoint, byte, capacity, and timing default/ceiling from evidence before implementation consumers proceed. Independent architecture review is the approval boundary. |

## Decision rationale

The accepted decisions preserve the product invariant that device-to-exit
payload transport is SSH while avoiding TCP-over-TCP for application TCP. They
also keep the iOS extension memory budget and public-API boundary ahead of code
reuse convenience.

Open items are deliberately concentrated in M0. No implementation task may
silently resolve them through a local workaround; the evidence and selected
tradeoff must update this log.
