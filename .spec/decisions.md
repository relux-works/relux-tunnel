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
| ADR-016 | Open | Confirm exact deployment targets during the multi-target project migration |
| ADR-017 | Open | Confirm whether Tuist remains the best project generator for the combined Swift/C/relay build |
| ADR-018 | Accepted | Ship macOS in-app self-update via Sparkle 2.x with an EdDSA-signed appcast; every payload is an already-notarized Developer ID build; iOS updates stay with the App Store |

## Decision rationale

The accepted decisions preserve the product invariant that device-to-exit
payload transport is SSH while avoiding TCP-over-TCP for application TCP. They
also keep the iOS extension memory budget and public-API boundary ahead of code
reuse convenience.

Open items are deliberately concentrated in M0. No implementation task may
silently resolve them through a local workaround; the evidence and selected
tradeoff must update this log.
