# Delivery plan

This document defines milestone intent. The canonical task order and dependency
phases are generated from `.task-board/` and saved under `.planning/`.
Implementation is not authorized by this planning branch.

## Estimates

The current engineering estimate is 23–36 working days for a production-capable
baseline after architecture and entitlement gates, excluding uncertain App
Review elapsed time. A failed SSH-engine candidate may add 3–4 days for the
alternate integration. Estimates are planning ranges, not commitments.

## M0 — viability spikes (3–5 days)

- Resolve platform-intent and provisioning gates A0/P0.
- Create the shared package/CLI harness and disposable physical-iPhone provider
  shell needed for measurements.
- Prove public packetFlow/socketpair/HEV bridge on device.
- Benchmark MTU/buffering/memory and decide whether an HEV fork is justified.
- Complete the NIOSSH-fork versus libssh2 matrix, including channel windows and
  multi-gigabyte rekey, and record one engine decision.

Exit: no unresolved stop-the-line platform, packet bridge, memory, or SSH-engine
assumption remains for the baseline.

## M1 — system VPN with TCP and safe DNS (5–8 days)

- Establish the multi-target project and host/extension profile boundary.
- Implement host-key verified public-key SSH on one lane.
- Connect HEV SOCKS TCP to `direct-tcpip`.
- Install IPv4/IPv6 routes and a leak-free DNS-over-TCP path.
- Show system VPN state, profile fields, connect/disconnect, errors, and external
  IP evidence on iOS and macOS.

Exit: one `relux` profile provides stable full-device TCP and DNS on physical
iPhone and Mac.

## M2 — UDP relay and degraded mode (4–6 days)

- Freeze relay v1 conformance vectors and portable build matrix.
- Implement exec upload, verification, atomic install, stdio lifecycle, UDP
  association/resource limits, and health.
- Connect HEV UDP-in-TCP framing to the relay.
- Provide full and degraded capability modes with DNS behavior in both.

Exit: representative UDP works through the exit host, while every relay failure
falls back safely to TCP + leak-free DNS or an explicit failure.

## M3 — resilience and performance (7–10 days)

- Add two-to-four lane pool, per-channel window policy, congestion-aware new-flow
  assignment, and QUIC modes.
- Implement physical-path endpoint resolution, route rebuilding, `reasserting`,
  retry/backoff, and bounded transport overlap.
- Cover Wi-Fi/cellular, NAT64, sleep/wake, captive network, kill-switch modes,
  lane/rekey failures, and memory pressure.
- Tune HEV/socket buffers/MTU only from measurements.

Exit: the validation matrix passes without routing loops, ordinary DNS leaks,
unbounded buffers, or avoidable extension termination.

## M4 — product and release (4–7 days)

- Complete profile/key/host-trust UX, accessibility, diagnostics, privacy
  disclosure, support export, and settings.
- Finish macOS signing/notarization and iOS archive/TestFlight pipelines.
- Generate relay manifest, third-party notices, SBOM, checksums, stable macOS
  asset, release notes, and App Review package.
- Run release-candidate regression on the supported device/OS matrix.

Exit: reviewed, signed release candidates install through intended channels and
the App Review submission is complete.

## Critical dependencies

```text
A0/P0 platform viability
  -> M0 packet bridge + M0 SSH engine
  -> M1 TCP/DNS system VPN
  -> M2 relay/UDP/degraded mode
  -> M3 resilience/lane pool
  -> M4 distribution
```

UI/profile foundations that do not encode unproven transport assumptions may
overlap late M0/M1. Release and privacy work starts early as specifications and
CI scaffolding but cannot pass until behavior is stable.

## Explicit deferrals

ProxyJump/OpenSSH config import, password-only auth, shared exit services,
Android/Windows clients, traffic obfuscation, fake DNS, selective per-app VPN,
and advanced policy routing are not baseline milestones. They require separate
product approval and board epics.
