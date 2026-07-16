# Product specification

## Product statement

Relux Proxy is a native macOS and iOS VPN client that routes device traffic to a
user-controlled SSH host. To the operating system it is a system VPN; on the
external network its application transport is one or more authenticated SSH
connections to the user's machine.

Relux Proxy is not a hosted VPN provider. Relux Works does not operate an exit
network, inspect tunneled traffic, or require a Relux account for the baseline
product.

## Users and primary journey

The primary user owns or administers an SSH-accessible macOS or Linux machine.
They want ordinary applications—not only a configured browser—to use that
machine as the network exit.

1. The user creates a profile with a display name, SSH host, port, account, and
   authentication key.
2. The app verifies or asks the user to trust the server host key.
3. The user enables the VPN and grants the system VPN permission.
4. The app reports connection progress and the active capability mode.
5. Device TCP, DNS, and, when the relay is available, UDP traffic exits through
   the selected SSH machine.
6. The user can disconnect, inspect a privacy-safe diagnostic summary, or switch
   profiles.

## Functional requirements

- Profiles MUST support a custom display name, hostname or address, SSH port,
  account name, and private-key selection.
- The app MUST expose connect and disconnect controls and these observable
  states: disconnected, connecting, connected/full, connected/degraded,
  reasserting, disconnecting, and failed.
- The system VPN indicator MUST reflect the Network Extension session, not only
  the UI process.
- Full mode MUST carry IPv4, IPv6, TCP, UDP, and DNS through the selected host.
- Degraded mode MUST carry TCP and leak-free DNS when the remote UDP relay cannot
  run. The UI MUST identify the missing capability without describing the whole
  VPN as failed.
- Failed mode MUST be reserved for failures of SSH reachability,
  authentication, host-key verification, tunnel setup, or another requirement
  without which safe forwarding is impossible.
- The extension MUST continue operating if the containing UI app is suspended
  or terminated.
- The user MUST be able to choose a QUIC policy: `Auto`, `Allow QUIC`, or
  `Block UDP/443`. `Auto` SHOULD fail UDP/443 quickly so clients fall back to
  HTTP/2 when tunnel conditions make QUIC-over-SSH counterproductive.
- The user MUST be able to choose a compatible routing mode or a fail-closed
  mode within the exclusions guaranteed by Apple platforms.

## Authentication and profile scope

The first production scope supports SSH public-key authentication. Imported or
generated private keys and optional passphrases are stored in Keychain and
shared only with the packet tunnel extension's access group. Password-only
authentication, agent forwarding, and arbitrary interactive shell sessions are
not first-release requirements.

OpenSSH configuration import and `ProxyJump` are post-baseline profile features.
The architecture MUST leave room for them, but they do not block the first
single-host `relux` prototype.

## Success criteria

- A physical iPhone and a supported Mac show the system VPN state and can browse,
  resolve DNS, and use representative TCP and UDP applications through `relux`.
- External IP and DNS observations match the selected exit host/resolver, with
  no ordinary DNS fallback to the physical network.
- Wi-Fi/cellular changes, sleep/wake, and transient SSH loss converge to either
  a working session or an explicit failure without a routing loop.
- Memory pressure produces controlled backpressure or reconnect rather than an
  avoidable extension jetsam termination.
- Multi-gigabyte transfers survive client- and server-initiated SSH rekeying.
- Signing, entitlements, privacy disclosures, TestFlight/App Store packaging,
  and macOS distribution pass their documented release gates.

## Non-goals

- Hiding that a long-lived SSH session exists from traffic analysis or defeating
  sophisticated DPI.
- Providing an anonymous exit network or routing through Relux Works servers.
- Embedding a Linux userspace or shell emulator such as iSH.
- Implementing a new TCP/IP stack.
- Requiring root, `PermitTunnel`, or `ssh -w` on the remote host for the baseline.
- Exposing the internal SOCKS endpoint as a general public proxy service.
- Guaranteed support for every SSH server algorithm in the first release.

## Product constraints

- iOS cannot launch `/usr/bin/ssh`; SSH runs in-process in the packet tunnel
  extension.
- iOS extension memory and lifecycle behavior are binding constraints. A
  physical iPhone is required for milestone gates.
- The initial remote relay MUST run without root and MUST NOT listen on an
  external port.
- The product MUST comply with Apple's VPN privacy rules and disclose any system
  traffic that Apple always excludes from a VPN.
