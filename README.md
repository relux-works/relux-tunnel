# Relux Tunnel

Relux Proxy **v2** — a native macOS and iOS **full-tunnel system VPN** whose
external transport is one or more authenticated **SSH** connections to a
user-controlled host. To the OS it is a system VPN; on the wire it is SSH to
your own machine.

This repository is the home of the v2 product. The legacy menu-bar SOCKS app
(v0.1.0) lives in [`relux-works/relux-proxy`](https://github.com/relux-works/relux-proxy)
and remains buildable until the migration task explicitly retires it.

## Architecture (one glance)

```
NEPacketTunnelFlow
      ↕  public AF_UNIX/SOCK_DGRAM packet bridge (no utun-FD discovery)
HEV + lwIP  (userspace TCP/IP, low-memory tuned)
      ↕  internal SOCKS5 (component boundary, not a user proxy)
SSHProxyAdapter
      ↕  2–4 pinned SSH lanes
remote sshd  →  relux-relay (rootless, exec/stdio)  →  Internet
```

- **TCP** rides SSH `direct-tcpip` (local termination — no TCP-over-TCP).
- **UDP/DNS** ride a rootless `relux-relay` uploaded over the same SSH session.
- **Degraded mode**: TCP + safe DNS-over-TCP when the relay is unavailable.
- **Full spec**: see [`.spec/`](.spec/) — start with `.spec/README.md`,
  `architecture.md`, `decisions.md` (ADR log), and `threat-model.md`.

## Planning and execution

Work is tracked on a file-based board in [`.task-board/`](.task-board/), driven
by the `task-board` CLI (project-management skill). Six delivery epics
(M0–M5) hold agent-autonomous work; a seventh epic,
`manual-validation-and-approvals`, isolates every human-in-the-loop step
(physical-device validation, Apple portal actions, App Review, legal/product
decisions, credential ceremonies) so the delivery epics run without stalling an
agent loop.

- Board overview: `task-board q --format compact 'summary()'`
- Plan a milestone: `task-board q 'plan(EPIC-… , mode=children)'`
- Planning snapshots: [`.planning/`](.planning/)

## Distribution

- **macOS**: Developer ID + hardened runtime + notarization + stapling, stable
  `ReluxProxy.dmg` from authenticated GitHub releases, plus **in-app self-update**
  (Sparkle 2.x, EdDSA-signed appcast — every payload is an already-notarized
  build). See ADR-018 and `.spec/platform-distribution.md`.
- **iOS**: Apple Distribution via TestFlight/App Store; the App Store owns iOS
  updates.

## CI

`ci.yml` runs board + spec structural validation with no Apple credentials on
every push/PR. The full quality-gate pipeline (build matrix, signing/notarization
verification, relay reproducibility, SBOM/secret scanning, serialized release
orchestration) is built out under the M5 CI story.

## Security

This product hides tunneled destinations, DNS, and payloads from the on-path
network — but the exit host you choose sees your post-exit traffic, and a
long-lived SSH session is fingerprintable as SSH. It is **not** an anonymity or
DPI-evasion tool. Read [`.spec/threat-model.md`](.spec/threat-model.md) for the
full does-hide / does-not-hide matrix and residual-risk register.
