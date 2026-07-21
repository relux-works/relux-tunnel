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
  composition roots include the supervised public socket-pair packet bridge,
  bounded deterministic v1 runtime configuration/message codecs, and the
  injectable owned `NETunnelProviderManager` repository plus a generation-safe
  host session controller whose system status and provider capability authorities
  remain separate behind thin public-API host seams. Core also contains the
  injectable, non-waiting TCP handshake/flow/open/queued-byte admission registry
  and its fixed-cardinality aggregate diagnostics; the module boundaries are mapped in
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
  "profileReference": {"value": "11111111-1111-1111-1111-111111111111", "privacy": "sensitive"},
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
| DNS policy evidence harness | Validate candidate `DNSRuntimePolicyV1` wire/accounting boundaries, 20 real default/hard timing mutations, fail-closed authority structure, and exact reliability event traces; run numeric-loopback IPv4/IPv6, maximum framing, failure/cancellation/tombstones, all M2 UDP/TCP triggers, resolver sentinel, footprint, and observed cleanup without public or physical resolver access. Candidate values remain blocked on exact SSH/memory task IDs and the later physical gate. | `python3 scripts/dns-policy-evidence.py --self-test-only`; `python3 scripts/dns-policy-evidence.py --emit-policy --output .research/fixtures/TASK-260721-3miqh4_dns-runtime-policy-v1.json`; `python3 scripts/dns-policy-evidence.py --verify-policy .research/fixtures/TASK-260721-3miqh4_dns-runtime-policy-v1.json`; `python3 scripts/dns-policy-evidence.py --warmup 5 --repeats 30 --output .research/raw/TASK-260721-3miqh4_measurements-run-01.json`; `python3 scripts/dns-policy-evidence.py --memory-trial hard --output .research/raw/TASK-260721-3miqh4_memory-hard-01.json` | `.research/raw/TASK-260721-3miqh4_*.json`; policy vectors under `.research/fixtures/`; scratch/tool checks under `.temp/TASK-260721-3miqh4/` and `.temp/BUG-260721-17f093/` |
| SwiftPM | Build/test the shared core, provider adapters, and standalone macOS harness | `make validate-core`; `swift run ReluxTunnelHarness smoke --configuration ./smoke.json` | `.build/`; task-scoped logs under `.temp/` |
| Core boundary guard | Reject forbidden Core/harness imports and invalid adapter or harness dependency direction | `make check-core-boundaries` | Terminal pass/fail report |
| Relay protocol schema/codegen, canonical vectors, conformance, and hostile-input diagnostics | Validate the canonical relay protocol v1 schema, deterministic Swift/Go bindings, production-code-independent vectors, shared hostile corpus, bounded decoder work/allocation/cleanup, and runtime diagnostics; the gates reject schema/vector/generated/semantic drift | `make relay-protocol-generate`; `make relay-protocol-vectors-generate`; `make relay-protocol-conformance-check`; `make relay-protocol-hostile-diagnostics`; `make relay-protocol-check`; `./scripts/tests/test-relay-protocol-go.sh -fuzz FuzzHostileInputDecoder -fuzztime 30s` | `Protocol/Relay/relay-v1.schema.json` (authority); `Protocol/Relay/Vectors/v1/corpus.json`; `Protocol/Relay/Fuzz/v1/regression-seeds.json`; generated bindings plus handwritten codecs/session tests; scratch under `.temp/relay-protocol-check/` and `.temp/TASK-*/` |
| Relay portable toolchain and target-shell builder | Verify `relay/toolchain-manifest-v1.json`; offline-provision and whole-tree-verify checksum-pinned Go 1.26.5 plus Syft 1.48.0; run credential-isolated clean or incremental builds with no-follow, resolved-containment checks for each Darwin/Linux amd64/arm64 target; verify compiler/internal-linker and CPU metadata, linkage, exact missing/tampered-input failures, reproducibility, native unprivileged Ubuntu 24.04 amd64/arm64 smoke, SBOM, and licenses | `make relay-toolchain-check`; `make relay-provision-go RELAY_GO_ARCHIVE=.temp/relay-tools/<official-go-archive>`; `make relay-build-linux-amd64 RELAY_VERSION=0.1.0 SOURCE_COMMIT=<40-lowercase-hex> SOURCE_DATE_EPOCH=<epoch> RELAY_BUILD_CLEAN_FLAG=--require-clean` (replace target suffix for the other three); `make relay-toolchain-ci ...`; `make relay-toolchain-native-linux-smoke ...`; `make relay-shell-validate ...` | Manifest in `relay/toolchain-manifest-v1.json`; target outputs under `.build/relay/portable/`; isolated work under `.build/relay/work/`; extracted licenses under `.build/relay/toolchain-licenses/`; release bundle/test/reproducibility outputs under `.build/relay/` |
| Native dependency validator | Rebuild and inspect pinned static XCFramework slices, checksums, notices, required HEV symbols, and extension-safe linkage | `make validate-native`; `./scripts/native-dependency-tool.py verify --dependency hev-lwip --source-dir /path/to/pinned/hev-socks5-tunnel` | `NativeDependencies/Artifacts/`; bundled notices; `.build/native-apple-matrix/` |
| ReluxLibSSH2 fork builder | Verify the six-file rekey/global-request observation patch, exact libssh2/OpenSSL source pins, static XCFramework lock, public headers, notices, and real client/server rekey plus reply/timeout behavior | `make validate-libssh2`; `make test-libssh2-source-gates`; `make build-libssh2 LIBSSH2_SOURCE_ARCHIVE=/path/to/libssh2.tar.gz OPENSSL_SOURCE_ARCHIVE=/path/to/openssl-3.5.7.tar.gz` | `Dependencies/ReluxLibSSH2/`; `NativeDependencies/Artifacts/ReluxLibSSH2.xcframework`; `NativeDependencies/Generated/LIBSSH2_OPENSSL_THIRD_PARTY_NOTICES.txt`; task logs under `.temp/` |
| ReluxNIOSSH fork verifier | Verify the audited SwiftNIO SSH pin, license, exact patch allowlist, full fork tests, and build; generate an upstream diff or rebase conflict report | `make validate-reluxniossh`; `python3 scripts/reluxniossh-fork-tool.py diff --output .temp/TASK-260715-nzdzv3/ReluxNIOSSH-upstream.patch`; `python3 scripts/reluxniossh-fork-tool.py conflict-test --upstream-ref <ref>` | `Dependencies/ReluxNIOSSH/`; requested diffs under `.temp/` |
| Swift format | Check source formatting with the selected Xcode Swift toolchain | `swift format lint --recursive Sources Tests Package.swift` | Terminal diagnostics |
| Packet-frame fuzz suite | Deterministic hostile-frame fuzz plus allocation/runtime bounds for the packet bridge; seed, iteration, and ceiling knobs documented in [`docs/packet-frame-fuzzing.md`](docs/packet-frame-fuzzing.md) | `swift test --filter PacketFrameFuzzTests` (bounded run is part of `swift test`) | `PACKET_FRAME_FUZZ_REPORT` evidence lines; task logs under `.temp/` |
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
