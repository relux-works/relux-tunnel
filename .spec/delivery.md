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

- Resolve the macOS provisioning gate P0. Gate A0 moves to the release path
  (ADR-013) and does not gate this milestone.
- Create the shared package/CLI harness and the disposable macOS packet-tunnel
  provider shell needed for measurements.
- Prove the public packetFlow/socketpair/HEV bridge on the Apple-silicon Mac.
- Benchmark MTU/buffering/memory and decide whether an HEV fork is justified.
- Integrate the libssh2 adapter against the Tier-1 M0-viability SSH contract
  (ADR-023) and record the engine ADR (ADR-014). Retain the ReluxNIOSSH
  comparative evidence without blocking the working-client path.

Exit: no unresolved stop-the-line platform, packet bridge, memory, or SSH-engine
assumption remains for the baseline, and every M0-deferred SSH semantic has a
named M3 owner task rather than a waiver.

## M1 — system VPN with TCP and safe DNS (5–8 days)

- Establish the multi-target project and host/extension profile boundary.
- Implement host-key verified public-key SSH on one lane.
- Connect HEV SOCKS TCP to `direct-tcpip`.
- Install IPv4/IPv6 routes and a leak-free DNS-over-TCP path.
- Show system VPN state, profile fields, connect/disconnect, errors, and external
  IP evidence on macOS.

Exit: one `relux` profile provides stable full-device TCP and DNS on the
physical Apple-silicon Mac. The iOS equivalent is deferred (ADR-024).

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
- Finish macOS signing/notarization. **Deferred (ADR-024):** the iOS
  archive/TestFlight pipeline is not part of this goal's M4 and is not an M4
  exit condition; it re-arms unchanged when iOS resumes.
- Generate relay manifest, third-party notices, SBOM, checksums, stable macOS
  asset, and release notes. **Deferred (ADR-013/ADR-024):** the App Review
  package belongs to the App Store branch, not to this goal's M4.
- Run release-candidate regression on the supported macOS device/OS matrix; the
  physical-iPhone rows are named deferred gaps, never inferred from Mac results.

Exit for this goal: reviewed, Developer ID-signed, notarized macOS release
candidates install through the direct-distribution channel with working
self-update. **Deferred exit condition (ADR-013/ADR-024):** iOS TestFlight
distribution and a complete App Review submission remain required before iOS or
App Store release, and are re-armed unchanged when that branch resumes.

## Critical dependencies

```text
approved Apple identifier/entitlement matrix (ypo7yo, autonomous)
  -> Ceremony C1 = ONE board node, TASK-260728-q5kjta (up-front human permission
     sitting: Keychain + portal + macOS App IDs/profiles + named notarytool
     Keychain profile + Sparkle key generation/custody; owner decision D1
     batched into the same conversation)
  -> agent evidence, unattended: apc34w, 3jloqy, dveo1o, ziprhs
  -> agent builds and review-accepts the disposable macOS probe (1r0fxv)
  -> Approval A1 (brief: approve the probe's system VPN / system extension)
  -> P0 macOS provisioning viability (9yp8to)
  -> sign-off S1 (owner acknowledges the P0 verdict, 2ayxqn AC5)
  -> M0 SSH matrix + engine selection (1u2vpc -> 1gjxer): AFTER P0, because the
     matrix scope includes the Gate-P0 provider smoke on this Mac
  -> M1 TCP/DNS system VPN on macOS
  -> M2 relay/UDP/degraded mode
  -> M3 resilience/lane pool + the four deferred SSH semantics
  -> M4 macOS signed/notarized distribution
  -> (deferred) A0 evidence -> iOS targets -> M5 TestFlight/App Store
```

Gate A0 no longer sits at the head of this chain (ADR-013); it gates the iOS and
App Store branch. A Linux CI runner is not on the critical path (ADR-024).
UI/profile foundations that do not encode unproven transport assumptions may
overlap late M0/M1. Release and privacy work starts early as specifications and
CI scaffolding but cannot pass until behavior is stable.

The M0 harness core — the libssh2 adapter integration (`1ozsb6`, behind the
`yx2fca` contract re-scope) and the common transport conformance tests
(`2d3g5e`) — runs **before** C1 on the SPM harness. Only the full functional and
rekey matrix `1u2vpc` waits for P0, because its scope contains a Gate-P0 provider
smoke on the physical Apple-silicon Mac; that dependency is enforced, not
assumed.

Sparkle key generation sits in C1, but `SUPublicEDKey` pinning and appcast
sign/verify evidence depend on the generated macOS target and the appcast
pipeline and land in M4 (ADR-026). The notarization path is not ready until the
named Keychain profile is stored, verified, and the source-file disposition is
recorded (ADR-025).

The board is the canonical order. `.task-board/.resources/TASK-260728-3a2dnr/`
holds the current serial wave plan, the Ceremony C1 script, and the Approval A1
script.

## Explicit deferrals

ProxyJump/OpenSSH config import, password-only auth, shared exit services,
Android/Windows clients, traffic obfuscation, fake DNS, selective per-app VPN,
and advanced policy routing are not baseline milestones. They require separate
product approval and board epics.
