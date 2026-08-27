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

The macOS-only `mtu-matrix` subcommand runs a bounded, loopback-only physical
baseline across MTU 1500/4096/8500, IPv4/IPv6/dual stack, and nominal,
constrained-buffer, receiver-stall, and mixed bidirectional traffic. Its
configuration requires a task-scoped output below `.temp/` (or `/tmp`) and
limits each row to 64...2048 packets:

```bash
swift run ReluxTunnelHarness mtu-matrix --configuration .temp/TASK-ID/matrix-config.json
```

At the 64-packet floor, each half of a dual-stack receiver-stall row uses the
same measured 4096-byte fault-injection ceiling as constrained-buffer traffic;
larger receiver-stall samples request 32768 bytes. This keeps the lower bound a
real bounded queue-pressure run instead of depending on whether 32 packets fit
in the larger queue.

Output containment is bound during configuration parsing by traversing from a
filesystem-root descriptor with `O_DIRECTORY | O_NOFOLLOW`, retaining every
directory descriptor through the atomic temporary-file write, and rejecting a
later path traversal whose device/inode chain no longer matches. This covers
root symlinks, output-parent replacement, and swaps of ancestors above `.temp`.

The report records attempted/sent/received packets, sender refusals and receive
queue drops separately, bytes, `logicalBatchGroups` derived as ceil(sent/32),
p50/p95 latency, packet and byte rates, CPU, requested/effective buffers,
syscall counts, maximum successful datagram, fragmentation observation, and
production-owned descriptor recovery. Swift-task lifecycle is explicitly
unavailable because the synchronous runner owns no tasks; process threads are
not used as a proxy. The command never configures a VPN, route, DNS, interface,
or NetworkExtension.

The physical HEV/bridge memory matrix is an explicitly opted-in Swift Testing
run. It opens only numeric-loopback, process-owned resources; stages 100, 250,
and 500 idle UDP-in-TCP sessions; samples public Mach physical-footprint and
peak counters; and writes task-scoped raw JSON:

```bash
matrix_index_dir="$(mktemp -d .temp/TASK-260715-135rr8/candidate-index.XXXXXX)"
GIT_INDEX_FILE="$matrix_index_dir/index" git read-tree HEAD
GIT_INDEX_FILE="$matrix_index_dir/index" git add -A
candidate_tree="$(GIT_INDEX_FILE="$matrix_index_dir/index" git write-tree)"
RELUX_RUN_PHYSICAL_MEMORY_MATRIX=1 \
RELUX_MATRIX_RUN_ID=run-01 \
RELUX_CANDIDATE_TREE_OID="$candidate_tree" \
swift test \
  --filter HEVIntegrationTests.physicalMemoryAndConcurrencyMatrix
```

Repeat with distinct `RELUX_MATRIX_RUN_ID` values for independent evidence
rows. Each report is written below `.temp/TASK-260715-135rr8/`, carries the
exact candidate tree OID and HEV revision/source hash read from the pinned
native manifest, and includes its own measured 500-cycle lifecycle samples.
Before any HEV work or evidence emission, the entry point independently rebuilds
the working candidate OID through a task-local temporary Git index and rejects a
well-formed caller-supplied mismatch. It also hashes the linked macOS HEV archive
and compares the result with the manifest lock. Lifecycle analysis excludes a
fixed 10-sample allocator warmup, then records net footprint change,
increase/equal/decrease transition counts, and exact increase cycles. Bounded
evidence requires at least 500 preallocated samples and post-warmup maximum
resident-footprint drawup no greater than 256 KiB. It separately requires every
cycle to restore harness-owned boundary start/stop, HEV start/main-return, live
channel, queued batch, outstanding read, descriptor-close-stage, and cleanup
error counters. This deterministic release signal does not depend on when the
Darwin allocator returns resident pages to the OS. The ceiling remains 1% of the
upper 25 MiB provisional envelope; a larger upward excursion or any incomplete
owned-resource release fails closed. A bounded monotonic allocator rise remains
explicitly classified and reported instead of being called a release.
The observer reserves every retained sample before the baseline snapshot, so
its own Array capacity growth is excluded. Bounded opt-in 100/500/1000-cycle
diagnostics use `RELUX_RUN_EXTENDED_HEV_LIFECYCLE=1` and
`RELUX_LIFECYCLE_CYCLES=<row>`. The report records macOS
`os_proc_available_memory` as unavailable because the public SDK explicitly
excludes macOS, and records HEV queued bytes and process-wide Swift task counts
as unknown rather than substituting proxy zeros. The execution does not start a
NetworkExtension, change VPN/network settings, or induce global memory pressure.
The production matrix writes schema-2 raw evidence atomically before enforcing
the lifecycle verdict, so a failing 500-cycle attempt remains independently
auditable and exact-tree-bound.

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
- **Spawn policy** (serial Codex/Sol orchestrator, Claude/Opus 5 producer,
  independent Codex/Sol reviewer, lite context):
  [`docs/spawn-policy.md`](docs/spawn-policy.md)

## Distribution

- **macOS**: Developer ID + hardened runtime + notarization + stapling, stable
  `ReluxProxy.dmg` from authenticated GitHub releases, plus the accepted
  **in-app self-update design**: exact Sparkle 2.9.4, a public HTTPS signed feed,
  EdDSA-signed final DMGs that are already Developer ID signed/notarized/stapled,
  and a separately activated packet-tunnel system extension. Implementation and
  physical update evidence remain release gates. See ADR-018,
  `.spec/platform-distribution.md`, and
  [the dated decision](.research/260721_macos-self-update.md).
- **iOS**: Apple Distribution via TestFlight/App Store; the App Store owns iOS
  updates.

## CI

`ci.yml` runs board + spec structural validation with no Apple credentials on
every push/PR. The full quality-gate pipeline (build matrix, signing/notarization
verification, relay reproducibility, SBOM/secret scanning, serialized release
orchestration) is built out under the M5 CI story.

## Repository tools

For a clean checkout, target ownership, signing-input boundaries, artifact
locations, dependency updates, troubleshooting, validation status, and legacy
coexistence, use the
[`generated-project developer workflow`](docs/generated-workspace-foundation.md).
The complete local build-host-safe gate is:

```bash
mise trust "$PWD/mise.toml"
make credential-free-validate LEGACY_ROOT="$PWD/../relux-proxy"
```

| Tool | Purpose | Command | Output |
| --- | --- | --- | --- |
| `task-board` | Query and mutate the project board | `task-board q --format compact 'summary()'` | `.task-board/` |
| Tuist 4.202.5 via Mise | Generate the credential-free Apple workspace; validate deterministic foundation state; build/test the macOS host and embedded packet-tunnel system extension in unsigned Debug and Release | `make credential-free-validate LEGACY_ROOT=/path/to/relux-proxy`; or `make workspace-generate`, `make workspace-validate`, and `make macos-targets-validate`; see [`docs/generated-workspace-foundation.md`](docs/generated-workspace-foundation.md) | Ignored `ReluxTunnel.xcworkspace` and `ReluxTunnelApp.xcodeproj`; full logs under `.temp/TASK-260715-sbrrp7/credential-free-validation/`; foundation evidence under `.temp/TASK-260715-2btjwm/`; target evidence under `.temp/TASK-260715-uyju7n/` |
| Apple UI-test and screenshot gate | Compile the shared identifier/launch/Page Object contracts, build native macOS UI tests unsigned without launching them, run the isolated iOS Simulator smoke, extract step-named screenshots from xcresult, and produce controlled snapshot-diff artifacts | `make apple-ui-test-contract`; `make apple-ui-test-smoke`; see [`docs/apple-ui-test-validation.md`](docs/apple-ui-test-validation.md) | Unique runs under `.temp/TASK-260715-1idq8c/apple-ui-test/`, including Xcode logs, native macOS `.xctestrun` inventory, iOS `.xcresult`, extracted PNGs/manifest, `reference.png`, `failed.png`, `diff.png`, and `summary.txt` |
| SSH M0 matrix fixtures | Provision, validate, and orchestrate the privacy-safe Linux/macOS/compatibility/real-host fixture contract, real direct-tcpip failure listeners, long-lived stdio echo/sink, latency/loss proxies, external secret references, exact rotation policy, durable partial-prepare ownership journaling, fail-closed teardown, and a streaming 5 GiB source/sink with exact count and SHA-256 but no retained payload | `make ssh-fixtures-test`; `make ssh-fixtures-lifecycle`; `python3 scripts/ssh_matrix_fixture.py orchestration-preflight`; with the two candidate drivers configured, `python3 scripts/ssh_matrix_fixture.py orchestrate --output .temp/TASK-260715-39xz9g/matrix-report.json`; see `.research/fixtures/TASK-260715-39xz9g_ssh-matrix-orchestration-v1.md` | Public fixture manifest/contract under `.research/fixtures/`; privacy-safe reports and task-scoped logs under `.temp/TASK-260715-39xz9g/`; transient keys/routes only under the gitignored task state directory and removed by teardown |
| Disposable macOS packet-tunnel probe | Generate, lint, test, archive, and fail-closed inspect the separate Gate P0 host/provider pair with approved development IDs, profiles, nesting, and entitlements. Dedicated host only: signing and this probe are prohibited on the build host; follow [`docs/build-host-safety.md`](docs/build-host-safety.md). | Dedicated-host-only command: `Probes/macOSPacketTunnelProbe/Scripts/build-and-inspect.sh` | Generated project under `Probes/macOSPacketTunnelProbe/`; signed archive, metadata, and logs under `.temp/TASK-260715-1r0fxv/` |
| DNS policy evidence harness | Validate candidate `DNSRuntimePolicyV1` wire/accounting boundaries, 20 real default/hard timing mutations, fail-closed authority structure, and exact reliability event traces; run numeric-loopback IPv4/IPv6, maximum framing, failure/cancellation/tombstones, all M2 UDP/TCP triggers, resolver sentinel, footprint, and observed cleanup without public or physical resolver access. Candidate values remain blocked on exact SSH/memory task IDs and the later physical gate. | `python3 scripts/dns-policy-evidence.py --self-test-only`; `python3 scripts/dns-policy-evidence.py --emit-policy --output .research/fixtures/TASK-260721-3miqh4_dns-runtime-policy-v1.json`; `python3 scripts/dns-policy-evidence.py --verify-policy .research/fixtures/TASK-260721-3miqh4_dns-runtime-policy-v1.json`; `python3 scripts/dns-policy-evidence.py --warmup 5 --repeats 30 --output .research/raw/TASK-260721-3miqh4_measurements-run-01.json`; `python3 scripts/dns-policy-evidence.py --memory-trial hard --output .research/raw/TASK-260721-3miqh4_memory-hard-01.json` | `.research/raw/TASK-260721-3miqh4_*.json`; policy vectors under `.research/fixtures/`; scratch/tool checks under `.temp/TASK-260721-3miqh4/` and `.temp/BUG-260721-17f093/` |
| SwiftPM | Build/test the shared core, provider adapters, standalone macOS smoke, and bounded loopback MTU/socket-pressure matrix | `make validate-core`; `swift run ReluxTunnelHarness smoke --configuration ./smoke.json`; `swift run ReluxTunnelHarness mtu-matrix --configuration .temp/TASK-ID/matrix-config.json` | `.build/`; task-scoped reports and logs under `.temp/` |
| Core boundary guard | Reject forbidden Core/harness imports and invalid adapter or harness dependency direction | `make check-core-boundaries` | Terminal pass/fail report |
| Relay protocol schema/codegen, canonical vectors, conformance, and hostile-input diagnostics | Validate the canonical relay protocol v1 schema, deterministic Swift/Go bindings, production-code-independent vectors, shared hostile corpus, bounded decoder work/allocation/cleanup, and runtime diagnostics; the gates reject schema/vector/generated/semantic drift | `make relay-protocol-generate`; `make relay-protocol-vectors-generate`; `make relay-protocol-conformance-check`; `make relay-protocol-hostile-diagnostics`; `make relay-protocol-check`; `./scripts/tests/test-relay-protocol-go.sh -fuzz FuzzHostileInputDecoder -fuzztime 30s` | `Protocol/Relay/relay-v1.schema.json` (authority); `Protocol/Relay/Vectors/v1/corpus.json`; `Protocol/Relay/Fuzz/v1/regression-seeds.json`; generated bindings plus handwritten codecs/session tests; scratch under `.temp/relay-protocol-check/` and `.temp/TASK-*/` |
| Relay portable toolchain and target-shell builder | Verify `relay/toolchain-manifest-v1.json`; offline-provision and whole-tree-verify checksum-pinned Go 1.26.5 plus Syft 1.48.0; run credential-isolated clean or incremental builds with no-follow, resolved-containment checks for each Darwin/Linux amd64/arm64 target; verify the exact four-asset layout, compiler/internal-linker and CPU metadata, format, linkage, stripped debug disposition, minimum runtime, explicit total bundle budget, exact missing/tampered-input failures, reproducibility, native unprivileged Ubuntu 24.04 amd64/arm64 smoke, SBOM, and licenses | `make relay-toolchain-check`; `make relay-provision-go RELAY_GO_ARCHIVE=.temp/relay-tools/<official-go-archive>`; `make relay-build-linux-amd64 RELAY_VERSION=0.1.0 SOURCE_COMMIT=<40-lowercase-hex> SOURCE_DATE_EPOCH=<epoch> RELAY_BUILD_CLEAN_FLAG=--require-clean` (replace target suffix for the other three); `make relay-portable-assets RELAY_VERSION=0.1.0 SOURCE_COMMIT=<40-lowercase-hex> SOURCE_DATE_EPOCH=<epoch> RELAY_BUNDLE_BUDGET_BYTES=<approved-total-bytes> RELAY_BUILD_CLEAN_FLAG=--require-clean`; `make relay-toolchain-ci ...`; `make relay-toolchain-native-linux-smoke ...`; `make relay-shell-validate ...` | Manifest in `relay/toolchain-manifest-v1.json`; exact target outputs under `.build/relay/portable/`; inspection report at `.build/relay/portable-assets-v1.json`; isolated work under `.build/relay/work/`; extracted licenses under `.build/relay/toolchain-licenses/`; release bundle/test/reproducibility outputs under `.build/relay/` |
| Trusted relay asset manifest | Verify the accepted board archive digest, exact four executable members, platform headers, embedded build identity, canonical manifest schema/order, bundle byte sizes and SHA-256 values, immutable generated Swift lookup, and generated-workspace resource inclusion | `make relay-asset-bundle-generate`; `make relay-asset-bundle-check`; `make relay-asset-manifest-test` | Source/schema under `relay/`; typed lookup under `Sources/ReluxTunnelCore/RelayAssets/`; ignored application resource folder under `.build/relay/relay-assets-v1/` |
| Relay supply-chain audit | Generate and fail-closed audit exact source/build provenance, commit/version-specific source URLs, approved license/notice mappings, scoped dependency inventory, asset-manifest linkage, M2/M5 ownership, and an immutable application/runtime scan for executable-download surfaces | `make relay-supply-chain-generate`; `make relay-supply-chain-test`; `make relay-supply-chain-audit` | Authoritative metadata and generated inventory/provenance/notices under `relay/`; temporary relay bundle under `.build/relay/relay-assets-v1/` |
| Native dependency validator | Rebuild and inspect pinned static XCFramework slices, checksums, notices, required HEV symbols, and extension-safe linkage | `make validate-native`; `./scripts/native-dependency-tool.py verify --dependency hev-lwip --source-dir /path/to/pinned/hev-socks5-tunnel` | `NativeDependencies/Artifacts/`; bundled notices; `.build/native-apple-matrix/` |
| ReluxLibSSH2 fork builder | Verify the six-file rekey/global-request observation patch, exact libssh2/OpenSSL source pins, static XCFramework lock, public headers, notices, and real client/server rekey plus reply/timeout behavior | `make validate-libssh2`; `make test-libssh2-source-gates`; `make build-libssh2 LIBSSH2_SOURCE_ARCHIVE=/path/to/libssh2.tar.gz OPENSSL_SOURCE_ARCHIVE=/path/to/openssl-3.5.7.tar.gz` | `Dependencies/ReluxLibSSH2/`; `NativeDependencies/Artifacts/ReluxLibSSH2.xcframework`; `NativeDependencies/Generated/LIBSSH2_OPENSSL_THIRD_PARTY_NOTICES.txt`; task logs under `.temp/` |
| ReluxNIOSSH fork verifier | Verify the audited SwiftNIO SSH pin, license, exact patch allowlist, full fork tests, and build; generate an upstream diff or rebase conflict report | `make validate-reluxniossh`; `python3 scripts/reluxniossh-fork-tool.py diff --output .temp/TASK-260715-nzdzv3/ReluxNIOSSH-upstream.patch`; `python3 scripts/reluxniossh-fork-tool.py conflict-test --upstream-ref <ref>` | `Dependencies/ReluxNIOSSH/`; requested diffs under `.temp/` |
| Swift format | Check source formatting with the selected Xcode Swift toolchain | `swift format lint --recursive Sources Tests Package.swift` | Terminal diagnostics |
| Packet-frame fuzz suite | Deterministic hostile-frame fuzz plus allocation/runtime bounds for the packet bridge; seed, iteration, and ceiling knobs documented in [`docs/packet-frame-fuzzing.md`](docs/packet-frame-fuzzing.md) | `swift test --filter PacketFrameFuzzTests` (bounded run is part of `swift test`) | `PACKET_FRAME_FUZZ_REPORT` evidence lines; task logs under `.temp/` |
| Legacy preservation guard | Verify the independent v0.1.0 source, identity, and release contract | `make check-legacy LEGACY_ROOT=/path/to/relux-proxy` | Terminal pass/fail report |
| Legacy guard mutation tests | Prove accidental removal and identity/path migration fail closed | `make test-legacy-guard LEGACY_ROOT=/path/to/relux-proxy` | Disposable files under the system temporary directory; removed on exit |

Build/test evidence and other task-scoped scratch logs belong under `.temp/`.

Release engineers updating or rolling back the four relay assets must follow
the [relay asset release runbook](docs/relay-asset-release-runbook.md). It is
the authoritative ordered procedure for the split source/recipe pins, exact
archive and manifest verification, native runtime rows, bundle integration,
downstream bootstrap gates, incident response, and M2/M5 ownership boundary.

## Security

This product hides tunneled destinations, DNS, and payloads from the on-path
network — but the exit host you choose sees your post-exit traffic, and a
long-lived SSH session is fingerprintable as SSH. It is **not** an anonymity or
DPI-evasion tool. Read [`.spec/threat-model.md`](.spec/threat-model.md) for the
full does-hide / does-not-hide matrix and residual-risk register.
