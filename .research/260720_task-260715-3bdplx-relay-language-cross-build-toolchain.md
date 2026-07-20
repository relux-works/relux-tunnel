# TASK-260715-3bdplx — Relay language and cross-build toolchain decision

Date: 2026-07-20

Task: `TASK-260715-3bdplx` — Select the relay language and cross-build toolchain

Consumers: `TASK-260715-1ccx3l`, `TASK-260715-1g9cyt`, and the M2 relay build

Decision status: ready for review

## Key takeaways

- Select **Go 1.26.5**, the official `gc` compiler and Go modules. Use only the
  standard library in relay v1 and compile with `CGO_ENABLED=0`.
- Use the Go tool itself as the build system, with a GNU Make 3.81-compatible
  repository facade. Do not add GoReleaser, Zig, a C compiler, or an OS SDK to
  the release build.
- Build four assets: `relux-relay-linux-amd64`,
  `relux-relay-linux-arm64`, `relux-relay-darwin-amd64`, and
  `relux-relay-darwin-arm64`.
- The Linux assets are static ELF files with the Go runtime embedded and no
  libc dependency. They are **not musl-linked**: with cgo disabled, Go uses its
  own runtime/syscall layer, so no libc is linked at all. The macOS assets are
  near-static Mach-O files and retain the required OS dependencies
  `/usr/lib/libSystem.B.dylib` and `/usr/lib/libresolv.9.dylib`.
- A Go 1.26.5 hello-stdio plus UDP loopback proof cross-built all four targets
  twice byte-for-byte. macOS arm64 ran natively and macOS amd64 ran under
  Rosetta 2. Linux execution was not available on this macOS host; the exact
  gap and mandatory native release gates are recorded below.
- Generate one SPDX 2.3 JSON SBOM per binary with checksum-verified Syft
  1.48.0, ship Go's BSD-3-Clause license text, and make
  `relux-relay-manifest-v1.json` the application's authoritative asset index.
- Go's GC means memory is not intrinsically hard-bounded. The implementation
  must combine fixed protocol caps, bounded queues/maps/buffer pools, a soft
  `runtime/debug.SetMemoryLimit`, and native-host RSS tests. This is a real
  tradeoff, not a claim that the runtime provides a hard heap ceiling.

## Context and constraints

The executable runs as an ordinary child of `sshd`, communicates only through
stdin/stdout, opens outbound UDP sockets, and must not require root, a daemon,
a listener, firewall changes, or SFTP. The release bundle needs Linux and
macOS assets for x86_64 and arm64, an integrity manifest, SBOM/license output,
and reproducible builds. The protocol itself and remote installation are out
of scope for this task.

The source specifications require bounded allocations and queues, a versioned
handshake/build identity, and a manifest containing protocol version,
platform, size, and SHA-256 for every asset:

- [Remote relay protocol](../.spec/relay-protocol.md)
- [Security and privacy specification](../.spec/security-privacy.md)
- [Platform and distribution specification](../.spec/platform-distribution.md)
- [ADR-005 and ADR-006](../.spec/decisions.md)

## Candidate comparison

Scores are 1 (poor) through 5 (best for this relay). Binary and memory results
other than the Go proof are qualitative; no unmeasured numeric claims are made.

| Criterion | Go | Swift | Rust | C17 |
| --- | ---: | ---: | ---: | ---: |
| One-host four-target cross-build | 5 | 3 | 3 | 2 |
| Linux static/self-contained output | 5 | 5 | 5 | 5 |
| macOS self-contained output | 4 | 4 | 4 | 4 |
| UDP and stdio without third-party runtime deps | 5 | 4 | 5 | 5 |
| Predictable/hard-bounded memory | 3 | 3 | 5 | 5 |
| Memory-safety default | 4 | 4 | 5 | 1 |
| Reproducible build simplicity | 5 | 3 | 3 | 2 |
| Unit/race/fuzz test story | 5 | 4 | 5 | 4 |
| SBOM, pinning, vulnerability workflow | 5 | 4 | 5 | 3 |
| Expected team maintenance cost | 5 | 4 | 3 | 2 |
| **Total** | **46** | **38** | **43** | **33** |

### Go

Go's official toolchain directly accepts `GOOS`/`GOARCH`; the supported list
includes all four required pairs. The standard library exposes UDP sockets and
ordinary `os.Stdin`/`os.Stdout`. With cgo disabled, one toolchain produced all
four assets without a target libc, C compiler, or Apple SDK selection.

Strengths:

- smallest build/tooling surface of the candidates;
- standard-library `net`, buffered I/O, timers, contexts, tests, race detector,
  profiles, and native coverage-guided fuzzing;
- Go module checksums, embedded build information, `govulncheck`, and mature Go
  binary cataloging in Syft;
- goroutines and deadlines fit a small stdio/UDP state machine without an async
  runtime dependency.

Tradeoffs:

- the GC and scheduler are embedded and consume baseline memory;
- `debug.SetMemoryLimit` is a soft limit, not an allocation guarantee;
- output is larger than a minimal C or carefully stripped Rust executable;
- macOS still requires system dylibs, as every supported Darwin executable
  does.

The proof's stripped binaries were 1.90–2.03 MB. The short-lived macOS proof
measured 4,685,824-byte peak RSS on arm64 and 6,373,376-byte peak RSS for the
x86_64 binary under Rosetta. Those numbers describe the proof only, not the
future relay.

### Swift

Swift is viable, but it creates a second Swift toolchain lane separate from the
Xcode compiler already selected for the Apple application. The local Xcode
toolchain was Swift 6.3.2 and `swift sdk list` reported no installed SDKs.
Swift's official Static Linux SDK documentation currently shows Swift 6.3.3,
requires a matching open-source Swift toolchain (the Xcode toolchain cannot be
used), and supports both `x86_64-swift-linux-musl` and
`aarch64-swift-linux-musl` static outputs.

The static SDK is strong technology, but it adds a matching compiler/SDK pair,
Musl-specific conditional imports for some packages, and a larger dependency
surface if Foundation Networking or SwiftNIO is used. Fully static Apple
binaries are impossible because Darwin system calls must go through
`libSystem`. Swift's shared-language maintenance benefit does not outweigh this
release-toolchain split for a small remote helper.

Primary evidence: [Swift Static Linux SDK guide](https://www.swift.org/documentation/articles/static-linux-getting-started.html).

### Rust

Rust is the strongest alternative when hard memory predictability dominates.
Its official targets include `aarch64-unknown-linux-musl`,
`x86_64-unknown-linux-musl`, `aarch64-apple-darwin`, and
`x86_64-apple-darwin`; the musl targets support fully static Linux output. Rust
also provides excellent memory safety and protocol-fuzz support.

The local Rust 1.91.0 installation had only the two Darwin targets installed.
The Linux musl standard libraries/linkers were absent, so a complete local Rust
matrix would require more target/linker provisioning than Go. Cargo dependency
and license tooling is good, but `cargo-fuzz`, cross-linker configuration, and
team ownership add maintenance surface. Select Rust instead only if the Go RSS
gate fails during the protocol spike; do not mix Go and Rust implementations.

Primary evidence: [Rust platform support](https://doc.rust-lang.org/rustc/platform-support.html) and [Apple Darwin target details](https://doc.rust-lang.org/rustc/platform-support/apple-darwin.html).

### C17

C17 with POSIX sockets can produce the smallest runtime and deterministic
allocation behavior. It was rejected because the local Apple Clang 21 setup has
no Linux musl sysroot/cross compiler, four-target builds need externally managed
compiler/sysroot pairs, and every parser/ownership path would require manual
memory-safety review. Sanitizers and libFuzzer are strong, but this protocol is
an untrusted length-prefixed parser where memory safety matters more than saving
the Go runtime's few megabytes.

## Selected toolchain contract

### Language, compiler, and build system

| Item | Exact decision |
| --- | --- |
| Language | Go 1.26 language and standard library |
| Compiler | Official Go `gc` toolchain `go1.26.5` |
| Linker | Go internal linker; `CGO_ENABLED=0` |
| Module | `github.com/relux-works/relux-tunnel/relay` in repository directory `relay/` |
| Module declarations | `go 1.26.0` and `toolchain go1.26.5` |
| Build interface | Go command wrapped by the root Makefile; Makefile must remain GNU Make 3.81 compatible |
| SBOM tool | Anchore Syft 1.48.0, commit `3e2bc6ed095f7ec1a415fb38cfe1c319e95dfed6` |
| Vulnerability tool | `golang.org/x/vuln/cmd/govulncheck@v1.6.0`, isolated in `tools/go.mod` |

Official Go 1.26.5 archive checksums for bootstrap verification:

| Archive | SHA-256 |
| --- | --- |
| `go1.26.5.darwin-amd64.tar.gz` | `6231d8d3b8f5552ec6cbf6d685bdd5482e1e703214b120e89b3bf0d7bf1ef725` |
| `go1.26.5.darwin-arm64.tar.gz` | `efb87ff28af9a188d0536ef5d42e63dd52ba8263cd7344a993cc48dd11dedb6a` |
| `go1.26.5.linux-amd64.tar.gz` | `5c2c3b16caefa1d968a94c1daca04a7ca301a496d9b086e17ad77bb81393f053` |
| `go1.26.5.linux-arm64.tar.gz` | `fe4789e92b1f33358680864bbe8704289e7bb5fc207d80623c308935bd696d49` |

The release environment must install one of these checksum-verified toolchains,
set `GOTOOLCHAIN=local`, and fail if `go version` is not exactly
`go1.26.5`. Automatic toolchain download is acceptable for developer setup but
not for a release build.

### Dependency policy

Relay v1 imports the standard library only. `go.mod` must contain no `require`,
`replace`, or `exclude` directives. This means the shipped binary contains the
relay and Go runtime/standard library, but no third-party Go module.

If a third-party dependency is later proposed, it requires a task-scoped
security/license/maintenance review. An accepted dependency must use an exact
module version, retain `go.sum`, be vendored for network-free release builds,
pass `go mod verify`, appear in the SPDX SBOM and notices, and introduce no cgo.
Release builds then use `-mod=vendor`. Local `replace` directives are forbidden
in release commits.

Build-only tools live outside `relay/go.mod`. Syft is a checksum-verified
standalone binary; govulncheck is pinned in `tools/go.mod`. Neither becomes a
relay runtime dependency.

### Target and output matrix

Go uses target pairs rather than LLVM-style triples. Both are listed to avoid a
fake musl ABI claim for cgo-free Go binaries.

| Canonical target | Go target | CPU baseline | Output name | Runtime dependency |
| --- | --- | --- | --- | --- |
| `x86_64-unknown-linux` | `linux/amd64` | `GOAMD64=v1` | `relux-relay-linux-amd64` | Linux syscall ABI only; no libc/interpreter |
| `aarch64-unknown-linux` | `linux/arm64` | `GOARM64=v8.0` | `relux-relay-linux-arm64` | Linux syscall ABI only; no libc/interpreter |
| `x86_64-apple-darwin` | `darwin/amd64` | Go amd64 v1 | `relux-relay-darwin-amd64` | macOS `libSystem` and `libresolv` |
| `aarch64-apple-darwin` | `darwin/arm64` | ARMv8.0 | `relux-relay-darwin-arm64` | macOS `libSystem` and `libresolv` |

Supported host floor for this contract is Linux kernel 4.4 or newer and macOS
12.0 or newer. Go 1.26 officially supports Linux kernel 3.2+ in general and
macOS 12+, but the product deliberately chooses Linux 4.4 as the conservative
common floor for both x86_64 and arm64. `uname -m` maps `x86_64` to `amd64` and
both `arm64` and `aarch64` to `arm64`; `uname -s` maps `Linux` to `linux` and
`Darwin` to `darwin`. Any other value is unsupported and enters degraded mode.

### Reproducible build invocation

The implementation should place the command at `relay/cmd/relux-relay` and
build from a clean tree with a fixed version and source commit:

```sh
env \
  GOTOOLCHAIN=local \
  CGO_ENABLED=0 \
  GOOS="$GOOS" \
  GOARCH="$GOARCH" \
  GOAMD64="$GOAMD64" \
  GOARM64="$GOARM64" \
  TZ=UTC \
  LC_ALL=C \
  go build \
    -mod=readonly \
    -trimpath \
    -buildvcs=false \
    -tags=netgo,osusergo \
    -ldflags="-s -w -buildid= \
      -X github.com/relux-works/relux-tunnel/relay/internal/buildinfo.Version=$RELAY_VERSION \
      -X github.com/relux-works/relux-tunnel/relay/internal/buildinfo.Commit=$SOURCE_COMMIT" \
    -o "$OUTPUT" \
    ./cmd/relux-relay
```

The Makefile must set only the architecture variable applicable to the current
target (`GOAMD64=v1` or `GOARM64=v8.0`), build targets in the fixed table order,
and reject a dirty or missing version/commit for release mode. It must not embed
a build timestamp or absolute path. `-buildvcs=false` makes the explicit commit
field authoritative. Source tar inputs, protocol schema/vectors, Go toolchain,
Syft, and tool modules are all pinned before release.

Reproducibility gate:

1. build all four binaries in two clean directories from the same commit and
   exact toolchain;
2. compare each pair byte-for-byte and compare SHA-256;
3. scan the accepted copy with Syft;
4. generate the manifest only after binary and SBOM checksums exist;
5. keep timestamps/provenance in a separate attestation, not inside the binary.

Individual relay binaries should not be mutated by post-build timestamped code
signing. Integrity is provided by the signed Apple application bundle, the
asset manifest/SHA-256 verification, and release provenance. A future decision
to distribute relay binaries independently must define detached signing rather
than silently changing this byte-reproducible contract.

## Artifact and manifest contract

Each release directory contains:

```text
relux-relay-manifest-v1.json
relux-relay-SHA256SUMS
relux-relay-linux-amd64
relux-relay-linux-amd64.spdx.json
relux-relay-linux-arm64
relux-relay-linux-arm64.spdx.json
relux-relay-darwin-amd64
relux-relay-darwin-amd64.spdx.json
relux-relay-darwin-arm64
relux-relay-darwin-arm64.spdx.json
THIRD_PARTY_NOTICES/Go-BSD-3-Clause.txt
```

`relux-relay-manifest-v1.json` is UTF-8 JSON with these required fields. The
`artifacts` array is sorted by `(os, arch)` and uses lower-case SHA-256 hex:

```json
{
  "schemaVersion": 1,
  "relayProtocolVersion": 1,
  "relayVersion": "0.1.0",
  "sourceCommit": "40 lowercase hexadecimal characters",
  "toolchain": {
    "go": "go1.26.5",
    "cgoEnabled": false,
    "syft": "1.48.0"
  },
  "artifacts": [
    {
      "os": "darwin",
      "arch": "amd64",
      "goTarget": "darwin/amd64",
      "canonicalTarget": "x86_64-apple-darwin",
      "filename": "relux-relay-darwin-amd64",
      "size": 0,
      "sha256": "64 lowercase hexadecimal characters",
      "sbom": "relux-relay-darwin-amd64.spdx.json",
      "sbomSha256": "64 lowercase hexadecimal characters"
    }
  ]
}
```

`size` is the exact non-negative byte count and must be greater than zero for a
binary. The example uses zero only as a schema placeholder. The real manifest
contains all four entries. The parser rejects unknown schema versions,
duplicates, missing targets, noncanonical names, invalid sizes/hashes, and any
protocol version other than the client-supported version.

`relux-relay-SHA256SUMS` contains the four binaries, four SBOMs, manifest, and
notice file as sorted lines in the form:

```text
<64 lowercase hex characters><two spaces><relative POSIX path><LF>
```

The JSON manifest is what the application consumes for target selection and
upload verification. `SHA256SUMS` is the human/CI audit surface.

Syft invocation is exact:

```sh
syft scan "file:$BINARY" -o "spdx-json=$BINARY.spdx.json"
```

Syft's official documentation supports SPDX JSON output. The proof scanner was
the immutable v1.48.0 release; the downloaded Darwin arm64 archive SHA-256 was
`fef3e6d5df336a0a4c3e421e503119d1e221cf82a3ef5e426a791fcd81667e87`.
The proof SBOM detected the command package, `stdlib@go1.26.5` with declared
`BSD-3-Clause`, and the binary package for every target.

SPDX scan timestamps/document namespaces can vary, so byte-identical SBOMs are
not part of the binary reproducibility claim. Their contents and package set
must pass policy, and their exact produced bytes are bound by
`sbomSha256` in the release manifest.

Because relay v1 has no third-party modules, notices contain the repository
license plus the exact Go 1.26.5 `LICENSE` text. The Go license file used in the
proof had SHA-256
`911f8f5782931320f5b8d1160a76365b83aea6447ee6c04fa6d5591467db9dad`.
Any later dependency must add its license text and attribution before the
release gate can pass.

## Memory, testing, and security policy

### Bounded memory

The implementation must:

- parse the fixed header before allocating payload storage and reject lengths
  above the negotiated hard maximum;
- cap association count, total queued bytes, per-association queue length,
  datagram size, and buffer-pool capacity with fixed integers derived from the
  protocol configuration;
- never use `io.ReadAll` or an unbounded channel/map on stdin or UDP data;
- reuse fixed-capacity buffers and release association state on close/expiry;
- call `debug.SetMemoryLimit` with a configured soft limit (initial CI budget:
  32 MiB) while treating native RSS tests—not this API—as the acceptance gate;
- expose only aggregate memory/counter diagnostics, never payloads or
  destinations.

If the relay cannot meet the 32 MiB RSS gate under maximum negotiated state,
the protocol implementation task must first reduce buffer/state caps. If the Go
runtime remains the cause after that evidence, reopen this decision and compare
the same workload in Rust; do not add hidden GC tuning flags as a forced fit.

### Tests and fuzzing

Required commands/policies for the implementation:

- `go test ./...` for units, golden vectors, fragmented/multiple stream reads,
  UDP loopback, cancellation, deadlines, and limit enforcement;
- `go test -race ./...` on native Linux amd64/arm64 and macOS arm64/amd64 test
  jobs (test builds may enable cgo; release builds may not);
- `go test -fuzz=FuzzFrameDecoder -fuzztime=60s` on pull requests and a longer
  scheduled corpus run; every discovered crash becomes a checked-in regression
  seed;
- `go vet ./...` and `govulncheck ./...` with govulncheck v1.6.0;
- an integration test that starts the real binary with pipes, completes the
  protocol hello, sends UDP to a local echo server, verifies the reply, and
  asserts bounded shutdown;
- native release smoke execution for every OS/architecture before bundling.

Go's official security documentation confirms native fuzzing in the standard
toolchain and `govulncheck` integration. Fuzzing supports coverage
instrumentation on both amd64 and arm64.

## Minimal hello-stdio and UDP proof

### Environment

- Host: macOS 26.5, Darwin 25.5.0, Apple arm64, unprivileged user.
- Selected toolchain: downloaded official Go 1.26.5 via Go's verified toolchain
  mechanism; `GOTOOLCHAIN=go1.26.5 go version` returned
  `go version go1.26.5 darwin/arm64`.
- Rosetta 2 was available: `arch -x86_64 /usr/bin/uname -m` returned `x86_64`.
- Docker, Podman, Zig, QEMU, and a Linux VM/runtime were absent.

The proof reads one newline-terminated string from stdin, writes it to stdout,
opens an IPv4 UDP socket on loopback, sends `relux-udp-proof` from a second UDP
socket, echoes the datagram, validates the bytes, and prints `udp:ok`. Errors go
to stderr with a nonzero exit status. Source is preserved for this run at
`.temp/TASK-260715-3bdplx/hello_udp.go`; the relevant API boundary is standard
library `bufio`, `os`, `net`, and `time` only.

Each target used:

```sh
CGO_ENABLED=0 GOOS=<os> GOARCH=<arch> \
GOAMD64=v1 GOARM64=v8.0 GOTOOLCHAIN=go1.26.5 \
go build -trimpath -buildvcs=false -ldflags='-s -w -buildid=' \
  -o <output> .temp/TASK-260715-3bdplx/hello_udp.go
```

Only the architecture-specific microarchitecture variable was set for the
actual corresponding build. The matrix was built in two separate directories;
all four `cmp` checks succeeded and both passes produced identical hashes.

| Target | Size (bytes) | SHA-256 | Format/link proof | Runtime proof |
| --- | ---: | --- | --- | --- |
| `darwin/amd64` | 2,030,192 | `c81ff90522bfcceb2edc8374fe55a0432786bd3eb03bdf2d366f824a06337378` | Mach-O x86_64; min macOS 12; `libSystem` + `libresolv` | Passed stdio + UDP under Rosetta 2 |
| `darwin/arm64` | 1,967,666 | `71ea84d0b0aaf7cf0d9a1114915c731a29383d877620025ab71e61279087b723` | Mach-O arm64; min macOS 12; `libSystem` + `libresolv` | Passed stdio + UDP natively |
| `linux/amd64` | 1,953,918 | `69f250d59b82060f2bf710460da21265b51b050c3cf9c879f901b251707a673d` | ELF x86-64, static, stripped, no dynamic section | Not executable on this macOS host |
| `linux/arm64` | 1,900,670 | `1bd29079f12912dd9b614933c327c731338db453e267ca7bb11c9ed3a9509d36` | ELF AArch64, static, stripped, no dynamic section | Not executable on this macOS host |

Both executed targets printed:

```text
stdio:hello
udp:ok
```

`go version -m` on both Linux outputs reported `go1.26.5`,
`CGO_ENABLED=0`, the correct `GOOS`/`GOARCH`, `GOAMD64=v1` or
`GOARM64=v8.0`, and `-trimpath=true`. `objdump -p` showed no entries in the
Linux dynamic section. Syft 1.48.0 successfully emitted SPDX JSON for every
binary.

### Evidence boundary and release stop-line

All four required assets were actually cross-built. Therefore there is no
cross-build blocker and the dependent target-shell/toolchain tasks can begin.
The local environment cannot claim native Linux execution or native Intel Mac
hardware execution:

- Linux gap: no Docker, Podman, QEMU, or Linux VM/runtime was installed.
- Intel Mac gap: execution used Rosetta 2 on Apple silicon, not Intel hardware.

Official Go primary evidence lists all four target pairs and supports Go 1.26
on macOS 12+ and Linux. This is enough to select the toolchain, but it is not a
waiver for release testing. The release pipeline is stop-the-line unless the
same real hello/UDP integration smoke passes on native Linux amd64, native
Linux arm64, native macOS arm64, and native macOS amd64. QEMU and Rosetta may be
additional pull-request coverage but cannot be the only release evidence.

## Upgrade policy

- Track Go's supported releases (the two newest major releases). Never release
  from an unsupported major.
- Apply Go security patch releases within 48 hours of publication and ordinary
  patch releases within 14 days. Adopt a new major within 30 days after its
  first stable release, after the full target/reproducibility/fuzz/RSS gate.
- Review Syft and govulncheck monthly. Security fixes follow the same 48-hour
  rule; ordinary upgrades are grouped with the next maintenance cycle.
- Keep relay v1 standard-library-only. Review any dependency proposal before it
  enters `go.mod`; do not allow automated dependency merging without the
  license/SBOM/native matrix gates.
- Every toolchain/dependency upgrade regenerates all binaries, SBOMs, notices,
  and manifest; repeats two-clean-build comparison; runs native four-target
  stdio/UDP smoke, race tests, golden tests, fuzz seeds, and maximum-state RSS;
  and records the evidence in a task-scoped outcome.
- Revisit this language decision if Go raises the supported OS floor beyond the
  product's declared remote-host floor, requires cgo for a needed capability,
  or fails the 32 MiB maximum-state RSS gate after application buffers/state are
  demonstrably bounded.

## Implementation handoff

`TASK-260715-1ccx3l` can implement target-shell selection using the exact
`Linux`/`Darwin` and `x86_64`/`arm64`/`aarch64` mappings and output names above.
It should parse `relux-relay-manifest-v1.json`, verify byte size and SHA-256,
then follow the existing quoted upload/atomic rename protocol.

`TASK-260715-1g9cyt` can add the isolated `relay/` Go module, pin Go 1.26.5 and
Syft 1.48.0 in the repository tool manager, and add Makefile targets without
linking Go into any Apple target. The Apple bundle consumes files and the JSON
manifest only; there is no Swift/Go FFI seam.

The M2 relay build can begin with standard-library `os.Stdin`, `os.Stdout`,
`os.Stderr`, `net.UDPConn`, contexts/deadlines, fixed protocol caps, and the test
matrix above. No language, libc, cross-linker, artifact-name, checksum, SBOM, or
upgrade-policy decision remains open.

## Fact-check references

Primary/official sources used:

1. [Go release history and support policy](https://go.dev/doc/devel/release) —
   Go 1.26.5 release date/security fixes and two-major support policy.
2. [Installing Go from source: target environment](https://go.dev/doc/install/source#environment) —
   exact `GOOS`/`GOARCH` target pairs and cross-compilation semantics.
3. [Go minimum requirements](https://go.dev/wiki/MinimumRequirements) — Linux
   and macOS floors and CPU baseline notes.
4. [Go `net` package](https://pkg.go.dev/net) and
   [Go `os` package](https://pkg.go.dev/os) — UDP and stdio primitives.
5. [Go dependency management](https://go.dev/doc/modules/managing-dependencies)
   and [Go modules reference](https://go.dev/ref/mod) — `go.mod`, `go.sum`,
   authentication, pinning, and `replace` caveats.
6. [Go security](https://go.dev/doc/security/) and
   [Go fuzzing](https://go.dev/doc/security/fuzz/) — govulncheck and built-in
   fuzz support on amd64/arm64.
7. [Go `debug.SetMemoryLimit`](https://pkg.go.dev/runtime/debug#SetMemoryLimit) —
   soft runtime memory limit semantics.
8. [Swift Static Linux SDK guide](https://www.swift.org/documentation/articles/static-linux-getting-started.html) —
   musl static targets, matching open-source toolchain requirement, and Darwin
   static-link limitation.
9. [Rust target platform support](https://doc.rust-lang.org/rustc/platform-support.html) —
   required Linux musl and Apple targets.
10. [Syft repository and output formats](https://github.com/anchore/syft) and
    [immutable Syft 1.48.0 release](https://github.com/anchore/syft/releases/tag/v1.48.0) —
    SPDX JSON generation and selected scanner provenance.

Local command evidence was collected on 2026-07-20 under
`.temp/TASK-260715-3bdplx/`. It includes the proof source, two build trees,
four SPDX JSON files, exact tool outputs, and the checksum-verified Syft
archive. `.temp/` is intentionally not the persistent outcome; this document
records the durable evidence and decision.
