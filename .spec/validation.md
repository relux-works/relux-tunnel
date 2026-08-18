# Validation strategy

## Principles

The riskiest assumptions are proven before broad UI work. Packet, SSH, relay,
and lifecycle components are testable in `ReluxTunnelCore` or a macOS CLI
harness; only Apple-specific packetFlow, entitlement, and lifecycle behavior
require a signed provider on real hardware. Per ADR-024, macOS remains the
active physical platform, but the current development Mac is build-only. All
network-mutating macOS physical rows require the separate host gate
`TASK-260819-25e1ys` and the fail-closed preflight in
`scripts/physical-test-host-preflight.sh`. Physical-iPhone and jetsam rows are
deferred with iOS and are recorded as named deferred gaps, never as passes.

No validation on the build host may install a system extension or VPN app,
persist a real VPN preference, call `startVPNTunnel`, activate a provider, or
change routes or DNS. Build, compile, unit, harness, simulator, inspection, and
unsigned-provider validation remain local-safe. `docs/build-host-safety.md` is
the authoritative host-operation policy.

Tests MUST record device/OS, source revision, dependency revisions, configuration,
duration, traffic shape, loss/latency conditions, peak physical footprint,
available-memory samples, channel/association counts, and drop/error counters.

## Architecture gates

| Gate | Pass condition | Path |
| --- | --- | --- |
| A0 Platform intent | Evidence supports the architecture's Network Extension entitlement/App Store use, or the data plane is revised | **Release path only** (ADR-013). Not a gate for the macOS prototype; mandatory before iOS submission and before dependent public distribution claims |
| P0 Provisioning | Relux Works host and packet-tunnel App IDs install and launch on a dedicated physical Mac distinct from the build host | Prototype. macOS-only (ADR-024), gated by `TASK-260819-25e1ys`; the physical-iPhone row is deferred with iOS |
| M0 Bridge | Public packetFlow/socketpair bridge passes IPv4/IPv6, MTU, backpressure, cleanup, and physical memory tests on the Apple-silicon Mac | Prototype |
| M0 SSH | The selected engine passes every Tier-1 M0-viability row in `ssh-transport.md`; Tier-2 semantics are surfaced as explicit not-reported/unsupported states | Prototype (ADR-023) |
| M1 TCP/DNS | Full-device TCP and leak-free DNS work through one SSH host across representative apps on macOS | Prototype |
| M2 UDP | Relay protocol, deployment, UDP/DNS, resource limits, and degraded mode pass | Prototype |
| M3 Resilience | Lanes, HoL mitigation, QUIC policies, path changes, NAT64, sleep/wake, route safety, and the four deferred SSH Tier-2 semantics pass | Post-prototype |
| M4 Release | UX, accessibility, privacy, signing, notarization, CI, and the macOS distribution matrix pass | Release path |
| M5 App Store | TestFlight and App Review package pass | Deferred with iOS |

## Packet-plane matrix

- MTU: 1500, 4096, 8500;
- address family: IPv4, native IPv6, dual stack, IPv6-only/NAT64;
- socket pressure: normal, constrained buffers, deliberate receiver stall;
- traffic: short web flows, large download/upload, many idle connections, DNS,
  datagram bursts, and mixed bidirectional load;
- lifecycle: start/stop loops, cancellation during start, UI termination, provider
  stop reason, sleep/wake, and memory warning/pressure;
- scale: staged 100, 250, 500, and configuration-limit concurrent flows, subject
  to the measured device budget rather than an unconditional maximum.

Pass conditions include no descriptor/task growth across repeated cycles, no
unbounded queue, correct reason-specific drops under induced saturation, and no
ordinary loss under a non-saturated nominal run.

## SSH matrix

- target servers: current OpenSSH Linux/macOS plus documented older algorithm
  profiles supported by product scope;
- keys/host keys: Ed25519 and approved fallbacks;
- channels: control, small interactive-like flows, bulk, early close, half-close,
  server reset, and hundreds of concurrent opens;
- loss simulation: representative Wi-Fi latency/loss and lane comparison at
  one, two, and four SSH connections;
- window profiles: 32 KiB, 64 KiB, and capped BDP bulk windows;
- rekey: at least 5 GiB mixed traffic, explicit client threshold, server-initiated
  request, simultaneous active direct-tcpip and relay traffic;
- reconnect: lane-local failure, control-lane failure, host unreachable, auth
  rejection, and host-key change.

## Relay and protocol tests

- golden encode/decode vectors for every message/address type;
- incremental and coalesced stream reads;
- malformed/oversized lengths, unknown types/flags, association reuse, idle
  expiry, queue pressure, DNS priority, and process exit;
- Linux/macOS x86_64/arm64 build and smoke execution;
- upload interruption, checksum mismatch, noexec/read-only home, missing hash
  tools, incompatible version, and atomic upgrade;
- degraded TCP + DNS-over-TCP behavior when relay is unavailable.

## Routing and leak tests

Automated or repeatable captures verify:

- SSH connects before default routes and remains outside its own tunnel;
- only documented endpoint/system exceptions use the physical path;
- DNS never falls back to a physical resolver in connected/reasserting states;
- external IPv4/IPv6 and DNS observations match the exit path;
- Wi-Fi to cellular, cellular to Wi-Fi, IPv4 to NAT64, captive network,
  sleep/wake, and server-address changes rebuild state without deadlock;
- compatible and fail-closed modes match their disclosures.

## Memory and performance

The 25–30 MiB steady-state target is measured, not asserted. Report physical
footprint, peak, `os_proc_available_memory()`, HEV sessions, channel windows,
queued bytes, lane count, and reconnect overlap.

The first baseline establishes throughput, time-to-first-byte, DNS latency,
energy, CPU, packet rate, and syscall rate. Later optimizations require a before
and after measurement. A HEV fork is justified only by a demonstrated material
bottleneck and validated regression coverage.

## Security and release validation

- host-key first-use/change cases and Keychain access boundaries;
- malformed packet/SOCKS/SSH/relay fuzz targets with bounded allocations;
- log/support-export redaction tests;
- dependency licenses, notices, SBOM, pinned revisions, and relay hash manifest;
- exact entitlements and nested code signatures in archived apps;
- macOS notarization/stapling/Gatekeeper install; iOS/TestFlight install is
  **deferred with iOS (ADR-024)** and is not a gate for the macOS-first goal;
- privacy disclosure checked against actual behavior; the App Review notes check
  is **deferred with the App Store branch (ADR-013)** and re-arms unchanged
  before any submission.
