# relay/

Go implementation root for `relux-relay` (relay protocol v1). The authoritative
module is pinned to Go 1.26.5, the standard library only, `CGO_ENABLED=0`, and
`github.com/relux-works/relux-tunnel/relay`.

## Pinned portable build toolchain

`toolchain-manifest-v1.json` is the checked-in toolchain contract. It pins the
official Go 1.26.5 `gc` compiler and internal linker, every supported host
archive and SHA-256, the standard-library-only module lock, the absence of a C
SDK/sysroot, all four target/CPU baselines, minimum runtimes, linkage policy,
license identifiers and hashes, deterministic flags, CI action revision, and
the isolated cache/credential policy. `make relay-toolchain-check` rejects
manifest, `go.mod`, target, archive, license, or environment drift without
needing a Go installation or network access.

After downloading the one official Go archive for the build host, provision it
with the matching command below. Provisioning verifies the manifest-owned
archive name and SHA-256, retains the archive, compares the installed driver,
compiler, linker, runtime, standard-library sources, permissions, and every other
installed tree entry against the archive, and writes a path-free provenance
receipt. Missing, added, changed, duplicate, traversing, link, device, or other
unsafe entries fail closed. No build command downloads a toolchain or module.

## Supply-chain metadata and audit

`supply-chain-source-v1.json` is the authoritative relay-only supply-chain
input. `make relay-supply-chain-generate` deterministically produces the
machine-readable dependency inventory, SLSA-shaped source/build provenance,
and `PRODUCT_NOTICES.txt`, then refreshes the exact asset-manifest linkage.
`make relay-supply-chain-audit` is the clean fail-closed gate for the Git
revision and source hashes, `go.mod` lock, compiler archive, build recipe,
licenses and notice coverage, inventory/provenance drift, archive and asset
hashes, generated Swift linkage, sensitive data, exact immutable source URLs,
and the fixed application/runtime source scan that rejects enumerated
executable-download and loading surfaces. Every regular file under the runtime
roots must be a recognized scanned source kind or an exact reviewed exclusion;
new/unclassified kinds fail until policy and scanner review. This is a bounded
complete-classification check, not a semantic proof for arbitrary future
languages. The audit performs no network access and does not require signing
material.

The inventory is scoped to the relay bytes and their build inputs; it is a
vulnerability-review input, not the final product-wide SBOM. Syft remains a
build-only inspection tool and is recorded separately because it does not
affect relay executable bytes.

The executable operator procedure, including the accepted split source/recipe
pins, two-independent-build proof, exact expected hashes, strict update order,
four-native-runner gate, bundle integration, downstream bootstrap consumers,
rollback, and mismatch/compromise response, is the
[relay asset release runbook](../docs/relay-asset-release-runbook.md).

```sh
make relay-provision-go \
  RELAY_GO_ARCHIVE=.temp/relay-tools/go1.26.5.darwin-arm64.tar.gz
```

Set immutable source inputs once. `SOURCE_COMMIT` is the exact 40-character
lowercase commit represented by the binary. Release/CI callers additionally set
`RELAY_BUILD_CLEAN_FLAG=--require-clean`, which requires that value to equal
`HEAD` and rejects any tracked or untracked source change. The example epoch is
the selected commit time; the binary contains no timestamp.

```sh
export RELAY_VERSION=0.1.0
export SOURCE_COMMIT=0123456789abcdef0123456789abcdef01234567
export SOURCE_DATE_EPOCH=1784563200
```

There is one canonical clean command per target:

```sh
make relay-build-darwin-amd64 RELAY_VERSION="$RELAY_VERSION" SOURCE_COMMIT="$SOURCE_COMMIT" SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH" RELAY_BUILD_CLEAN_FLAG=--require-clean
make relay-build-darwin-arm64 RELAY_VERSION="$RELAY_VERSION" SOURCE_COMMIT="$SOURCE_COMMIT" SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH" RELAY_BUILD_CLEAN_FLAG=--require-clean
make relay-build-linux-amd64 RELAY_VERSION="$RELAY_VERSION" SOURCE_COMMIT="$SOURCE_COMMIT" SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH" RELAY_BUILD_CLEAN_FLAG=--require-clean
make relay-build-linux-arm64 RELAY_VERSION="$RELAY_VERSION" SOURCE_COMMIT="$SOURCE_COMMIT" SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH" RELAY_BUILD_CLEAN_FLAG=--require-clean
```

To produce and inspect the exact four-asset staging set in one command, the
caller must supply the currently approved total bundle budget in bytes:

```sh
make relay-portable-assets \
  RELAY_VERSION="$RELAY_VERSION" \
  SOURCE_COMMIT="$SOURCE_COMMIT" \
  SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH" \
  RELAY_BUNDLE_BUDGET_BYTES=<approved-total-bytes> \
  RELAY_BUILD_CLEAN_FLAG=--require-clean
```

The command writes the four executables under `.build/relay/portable/` and a
path-free `.build/relay/portable-assets-v1.json` evidence report. Inspection
requires exactly the four canonical target directories and filenames, checks
regular executable permissions, raw format and machine type, CPU baseline,
linkage, minimum runtime, dynamic-library inventory, absence of DWARF/debug
sections, sizes, and SHA-256 values. It records an over-budget measurement
before failing. The budget has no default so build tooling cannot silently
invent or change application bundle policy.

Clean mode is the default and deletes only that target's output and workspace
below `.build/relay/`. For local incremental iteration, append
`RELAY_CACHE_MODE=incremental`; it reuses only the same target-scoped workspace.
Both modes reject a workspace root or isolated environment child that is a
symlink or another non-directory type. Each resolved child must remain below the
resolved target workspace before it is exposed to the compiler.
Every mode constructs an environment allowlist with repository-local `HOME`,
`TMPDIR`, `GOCACHE`, `GOMODCACHE`, and `GOPATH`; sets `GOTOOLCHAIN=local`,
`GOPROXY=off`, `GOSUMDB=off`, `GOVCS=off`, `GOENV=off`, `GOWORK=off`,
`CGO_ENABLED=0`, `LC_ALL=C`, `LANG=C`, and `TZ=UTC`; and does not inherit SSH,
cloud, workstation-home, credential-helper, or proxy configuration.

Run the complete local/CI gate and extract dependency licenses with:

```sh
make relay-toolchain-ci RELAY_VERSION="$RELAY_VERSION" SOURCE_COMMIT="$SOURCE_COMMIT" SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH"
make relay-toolchain-licenses
```

The CI gate verifies pins, deliberate missing-input failure, pinned tests and
vet, offline dependency behavior, all four clean builds, binary metadata,
linkage, and license extraction. Linux outputs are static ELF64 executables with
no `PT_INTERP`, `PT_DYNAMIC`, libc, SDK, or sysroot. No Linux kernel-version
floor is claimed from static linkage alone. CI instead clean-builds and executes
native unprivileged smoke rows on the declared Ubuntu 24.04 x86_64 and arm64
fixtures documented in the
[GitHub-hosted runners reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
Darwin outputs use no build SDK/sysroot, carry an exact macOS 12.0
`LC_BUILD_VERSION`, and load only `libSystem.B.dylib` and
`libresolv.9.dylib`. Signing, notarization, packaging, upload, and installation
remain separate tasks.

## Target shells

- `cmd/relux-relay` accepts exactly `--identity --protocol 1` or
  `--stdio --protocol 1`. Identity emits one bounded canonical JSON line with
  the release version, source commit, target, and SHA-256 of the running
  executable. Stdio owns one bounded reader and one stdout writer; protocol
  stdout contains only the server hello and framed bytes. EOF, cancellation,
  SIGINT, and SIGTERM tear down the process-owned streams without listeners,
  daemonization, runtime files, privilege requests, or child processes.
  Exit statuses are fixed: `0` success, `64` unsupported invocation, `65`
  protocol rejection, `70` unavailable build/runtime configuration, `74`
  stream failure, and `130` SIGINT/SIGTERM or context cancellation. Release
  versions are ASCII semantic versions bounded to 64 bytes so the identity
  line always remains within its 512-byte limit.
- `cmd/relux-relay-protocol-test` provides `smoke` plus `run`. The runnable
  shell checks only the empty health configuration and one protocol-version
  mismatch against the existing generated/schema-backed handshake code.
- `manifest-v1.schema.json` freezes the application-consumed release manifest
  field names. `scripts/relay_release.py` builds and verifies the accepted
  Linux/macOS by amd64/arm64 matrix, deterministic checksums, SPDX 2.3 SBOMs,
  and combined repository/Go license notices. Its `verify-identity` boundary
  consumes the exact bounded identity line and rejects a target tuple, size,
  manifest SHA-256, or selected executable-byte mismatch before stdio launch.

## Portable runtime-boundary gate

`scripts/relay_asset_smoke.py` gates one manifest-selected executable on its
native runner or an explicitly named emulator. Native evidence fails unless
the unprivileged host OS and architecture exactly match the requested target;
emulation is recorded as emulation and `--require-native` turns it into an
explicit red gate with a task owner and native-evidence requirement.

After the manifest size/hash and raw ELF or Mach-O architecture checks, the
gate runs bounded identity and stdio subprocesses from read-only `cwd`, `HOME`,
and temporary directories. Before trusting a relay result, a live containment
probe proves that filesystem writes, public listeners, and descendant process
creation are denied. macOS uses its built-in sandbox; Linux uses Landlock plus
seccomp while still allowing Go runtime threads. An unavailable containment
primitive is an explicit red gate, not reduced evidence. The gate requires the
canonical self-hash identity, exact server hello with EOF exit, privacy-safe
protocol rejection, rejection of daemon/listener/payload/version arguments,
exit 130 on SIGTERM, no child processes, no sockets/listeners, no runtime
files, and complete fixture cleanup. Its bounded report contains only
target/runner identity, revisions, fixed-vocabulary semantic commands,
durations, observed exit codes, hashes, finite failures, and check results;
captured stdout, stderr, host paths, emulator paths, and payload markers are
never retained.

Run the deterministic local behavioral and workflow tests with:

```sh
python3 -m unittest scripts/tests/test_relay_asset_smoke.py
```

Run a native gate after `make relay-shell-release` by selecting the current
host asset and writing task-scoped evidence under `.build/relay/`:

```sh
python3 scripts/relay_asset_smoke.py \
  --target darwin/arm64 \
  --runner-kind native \
  --runner-name local-darwin-arm64 \
  --runner-owner TASK-260715-36gq4m \
  --require-native \
  --manifest .build/relay/apple-bundle-input/relux-relay-manifest-v1.json \
  --executable .build/relay/apple-bundle-input/relux-relay-darwin-arm64 \
  --evidence .build/relay/runtime-evidence/darwin-arm64/report.json
```

CI clean-builds the exact four-asset release manifest independently on
`macos-15-intel`, `macos-15`, `ubuntu-24.04`, and `ubuntu-24.04-arm`, runs the
matching asset natively, and retains the executable, SPDX document, manifest,
checksum file, and JSON report for 14 days. `fail-fast: false` preserves every
target-specific result when another row fails.

The entrypoint does not yet wire UDP association socket behavior, upload, SSH
execution, or release publication. The reusable SSH-independent UDP registry
is implemented in `internal/udp` for later session integration.

From the repository root, run:

```sh
mkdir -p .temp/relay-tools
curl -fL \
  -o .temp/relay-tools/go1.26.5.darwin-arm64.tar.gz \
  https://go.dev/dl/go1.26.5.darwin-arm64.tar.gz
curl -fL \
  -o .temp/relay-tools/syft_1.48.0_darwin_arm64.tar.gz \
  https://github.com/anchore/syft/releases/download/v1.48.0/syft_1.48.0_darwin_arm64.tar.gz
make relay-provision-tools \
  RELAY_GO_ARCHIVE=.temp/relay-tools/go1.26.5.darwin-arm64.tar.gz \
  RELAY_SYFT_ARCHIVE=.temp/relay-tools/syft_1.48.0_darwin_arm64.tar.gz
make relay-shell-test
make relay-shell-validate \
  RELAY_VERSION=0.1.0 \
  SOURCE_COMMIT=0123456789abcdef0123456789abcdef01234567
```

The provision commands never download tools. They accept only the official
archive name for the current Darwin/Linux amd64/arm64 host, verify the pinned
upstream SHA-256, retain the verified archive beside the installed tool, and
write a canonical path-free provenance receipt. Release builds recheck the
archive, compare the installed Go driver/compiler/linker and Syft executable
against archive members, compare the complete installed Go tree, require
`GOTOOLCHAIN=local`, and validate exact tool identity. Go is pinned to
`go1.26.5`; Syft is pinned to 1.48.0 commit
`3e2bc6ed095f7ec1a415fb38cfe1c319e95dfed6`. The accepted checksums for all
four provisioning hosts are declared in `scripts/relay_release.py`. Replace
`darwin-arm64` / `darwin_arm64` in the example with the current supported host
pair. After provisioning, build and SBOM generation are offline.

Automatic `GOTOOLCHAIN=go1.26.5` acquisition is a developer convenience only;
it is not used by `relay-shell-build`, `relay-shell-release`, or
`relay-shell-verify`. Release entry points fail closed when the provisioned
tool, provenance receipt, retained archive, checksum, version, commit, or host
platform is missing or mismatched.

The default Apple bundle input is `.build/relay/apple-bundle-input`; query it
with `make relay-print-apple-bundle-input`. Cross-built Linux binaries are not
executed on macOS. This repository CI owns native unprivileged Ubuntu 24.04
amd64 and arm64 smoke rows. Native macOS arm64 and Intel macOS runtime rows
remain release gates; Rosetta is recorded only as additional local evidence.

Current protocol contents:

- `internal/protocol/generated_v1.go` — generated protocol v1 constants and
  typed metadata. Never edit by hand; regenerate with
  `make relay-protocol-generate` from the repository root. Drift is rejected by
  `make relay-protocol-check`.
- `internal/protocol/parity_test.go` — handwritten drift guard mirroring the
  Swift parity test.
- `internal/protocol/codec.go` — bounded relay-envelope framing plus the exact
  HEV UDP payload codec. The datagram layer validates `HDRLEN`, address shape,
  port, and exact outer/`MSGLEN` arithmetic before applying the fixed 1472-byte
  wire ceiling or any lower local cap, and it slices or allocates decoded bytes
  only after every check succeeds.
- `internal/protocol/codec_test.go` and `datagram_test.go` — stream framing,
  HEV golden-vector, every-payload-size, allocation, malformed-input, and fuzz
  coverage shared with the Swift behavior contract.
- `internal/protocol/handshake.go` — bounded incremental protocol-v1 server
  hello state machine, feature intersection, maximum-frame negotiation,
  effective local-limit snapshot, deadline/cancellation events, and finite
  privacy-safe failures (TASK-260715-1y1g1u).
- `internal/protocol/handshake_test.go` — exact-wire, every-split, coalescing,
  boundary-limit, rejection, stale-generation, timeout, cancellation, and
  diagnostic tests for the server state machine.
- `internal/protocol/session.go` — generated-backed v1 transition table and the
  generation-safe session machine for direction, finite errors, bounded health
  echo, association/session close acknowledgement, and cleanup-once semantics.
- `internal/protocol/session_test.go` — deterministic paired-peer nominal,
  hostile, malformed-datagram, crossed/duplicate close, abrupt termination,
  late callback, counter, privacy, and post-handshake `RLXR` coverage.
- `internal/protocol/vectors_test.go` — strict loader and consumer for the
  canonical production-code-independent corpus in
  `Protocol/Relay/Vectors/v1/corpus.json`; failures name the stable vector ID
  without printing input or payload bytes.
- `internal/udp` — one-owner-goroutine association registry keyed by session
  generation, nonzero client ID, and an incarnation token. It admits bounded
  association/socket/logical-timer/pending-close state before descriptor
  creation. Domain work first obtains a socketless incarnation reservation;
  resolver completion may attach a family socket only through that exact
  token, so close, expiry, generation replacement, cancellation, or same-ID
  reuse cannot revive stale work. Single-family use stays lazy; callers that
  require both families use one atomic family-set transaction. Any family
  creation failure retires all staged and already-owned association sockets
  exactly once, leaving no partial association. Production sockets are
  nonblocking, close-on-exec, unconnected, and deliberately unbound; a later
  bounded `sendto` call may let the kernel choose an unprivileged ephemeral
  source port, while registry creation never exposes a public UDP listener.
- `internal/udp/io.go`, `resolver.go`, `resolver_scheduler.go`, and
  `system_io.go` — bounded nonblocking
  `sendto`/`recvmsg` operations through registry-owned descriptors; strict
  ASCII DNS presentation validation; a fixed resolver worker pool with bounded
  queued-job, copied-name, copied-payload, completion, deadline, inspected-result,
  accepted-result, and result-byte credit; deterministic family policy; exact
  response-source mapping; finite privacy-safe error/counter mapping; and
  round-robin socket turns with datagram, byte, visit, and monotonic-time
  budgets. Domain `Send` returns `pendingResolution` without waiting, and the
  caller drains bounded completions through `NextSendCompletion`. Readiness
  misses retain no retry buffer and never refresh idle activity. Reservation,
  existing-association admission, and family attachment preserve the current
  deadline; only a successful send or received datagram refreshes it. Scoped
  IPv6 resolver results are discarded before accepted-result byte credit or
  socket admission because protocol v1 cannot represent a zone. Callers may
  retry a send only after a readiness transition.
- `internal/udp/registry_test.go` and `io_test.go` — controlled-socket,
  resolver, receiver-stall, and fake-monotonic-clock coverage for duplicate
  IDs, every ceiling, partial creation failure, IPv4/IPv6/domain byte
  integrity, source preservation, truncation, pressure, fair budgets,
  cancellation, paused close/expiry/replacement/reuse races, fixed resolver
  worker/queue baselines, exact activity deadlines/arm epochs, scoped-result
  fallback, stale generations, real loopback I/O, descriptor properties, and
  repeated baseline recovery.

`scripts/tests/test-relay-protocol-go.sh` (invoked by
`make relay-protocol-check`) vets and tests this package directly inside the
pinned module with no dependency resolution.
