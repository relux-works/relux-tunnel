# Relux Tunnel

Relux Proxy **v2** — a native macOS and iOS **full-tunnel system VPN** whose
external transport is one or more authenticated **SSH** connections to a
user-controlled host. To the OS it is a system VPN; on the wire it is SSH to
your own machine.

This repository is the home of the v2 product. The legacy menu-bar SOCKS app
(v0.1.0) lives in [`relux-works/relux-proxy`](https://github.com/relux-works/relux-proxy)
and remains buildable until the migration task explicitly retires it. Its
[preservation contract](docs/legacy-preservation.md) pins the independent
SwiftPM, defaults, system-SSH, bundle, packaging, and release identity.

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
- **Shared package**: `ReluxTunnelCore` and its compile-only iOS/macOS provider
  composition roots include the supervised public socket-pair packet bridge and
  are mapped in
  [`docs/core-adapter-boundaries.md`](docs/core-adapter-boundaries.md).
- **Native dependencies**: pinned custom-build C graphs use source-rebuilt
  static XCFrameworks behind `ReluxTunnelNativeAdapter`; see
  [`docs/native-dependency-packaging.md`](docs/native-dependency-packaging.md).

## macOS experiment harness

`ReluxTunnelHarness` is a standalone SwiftPM command-line target for fast
packet, SSH, relay, fault-injection, and metrics experiments without a Network
Extension lifecycle or generated workspace. Its support module composes the
same `ReluxTunnelCore` runtime contracts used by the providers.

The initial stable subcommand is `smoke`. It accepts a versioned JSON document
from a file or inline, exercises temporary-file, Unix-socket, and managed-task
cleanup, then writes one sorted-key JSON result to standard output:

```bash
swift run ReluxTunnelHarness smoke --configuration ./smoke.json
```

```json
{
  "schemaVersion": 1,
  "seed": 42,
  "sourceRevision": "replace-with-git-revision",
  "dependencyRevisions": {},
  "profileReference": {"value": "smoke-profile", "privacy": "sensitive"},
  "parameters": {
    "mode": {"value": "noop", "privacy": "public"}
  }
}
```

Configuration values marked `sensitive` are emitted as `<redacted>`. The output
records result and metric schema versions, source/dependency revisions, seed,
redacted configuration, duration, platform, and metrics. `SIGINT` and `SIGTERM`
cancel the active command and exit with codes 130 and 143 after cleanup.

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
- **Spawn policy** (Claude-only, `claude-fable-5` / `claude-opus-4-8`, never
  Codex): [`docs/spawn-policy.md`](docs/spawn-policy.md)

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

## Repository tools

| Tool | Purpose | Command | Output |
| --- | --- | --- | --- |
| `task-board` | Query and mutate the project board | `task-board q --format compact 'summary()'` | `.task-board/` |
| SwiftPM | Build/test the shared core, provider adapters, and standalone macOS harness | `make validate-core`; `swift run ReluxTunnelHarness smoke --configuration ./smoke.json` | `.build/`; task-scoped logs under `.temp/` |
| Core boundary guard | Reject forbidden Core/harness imports and invalid adapter or harness dependency direction | `make check-core-boundaries` | Terminal pass/fail report |
| Native dependency validator | Rebuild and inspect pinned static XCFramework slices, checksums, notices, and extension-safe linkage | `make validate-native` | `NativeDependencies/Artifacts/`; `.build/native-apple-matrix/` |
| Swift format | Check source formatting with the selected Xcode Swift toolchain | `swift format lint --recursive Sources Tests Package.swift` | Terminal diagnostics |
| Legacy preservation guard | Verify the independent v0.1.0 source, identity, and release contract | `make check-legacy LEGACY_ROOT=/path/to/relux-proxy` | Terminal pass/fail report |
| Legacy guard mutation tests | Prove accidental removal and identity/path migration fail closed | `make test-legacy-guard LEGACY_ROOT=/path/to/relux-proxy` | Disposable files under the system temporary directory; removed on exit |
| Tuist via Mise | Generate the future Apple workspace at the repository-pinned version | `mise exec -- tuist generate` (after generator files land) | Generated Xcode workspace (gitignored) |

Build/test evidence and other task-scoped scratch logs belong under `.temp/`.

## Security

This product hides tunneled destinations, DNS, and payloads from the on-path
network — but the exit host you choose sees your post-exit traffic, and a
long-lived SSH session is fingerprintable as SSH. It is **not** an anonymity or
DPI-evasion tool. Read [`.spec/threat-model.md`](.spec/threat-model.md) for the
full does-hide / does-not-hide matrix and residual-risk register.
