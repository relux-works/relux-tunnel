# relay/

Go implementation root for `relux-relay` (relay protocol v1). The authoritative
module is pinned to Go 1.26.5, the standard library only, `CGO_ENABLED=0`, and
`github.com/relux-works/relux-tunnel/relay`.

## Target shells

- `cmd/relux-relay` provides only `smoke`, a deterministic JSON metadata and
  empty-health contract. It reports executable version, protocol version,
  source revision, and `GOOS/GOARCH`, and explicitly reports
  `relayBehaviorImplemented: false`.
- `cmd/relux-relay-protocol-test` provides `smoke` plus `run`. The runnable
  shell checks only the empty health configuration and one protocol-version
  mismatch against the existing generated/schema-backed handshake code.
- `manifest-v1.schema.json` freezes the application-consumed release manifest
  field names. `scripts/relay_release.py` builds and verifies the accepted
  Linux/macOS by amd64/arm64 matrix, deterministic checksums, SPDX 2.3 SBOMs,
  and combined repository/Go license notices.

The command shells do not yet wire UDP association handling, upload, SSH
execution, or release publication. The reusable SSH-independent UDP registry
is implemented in `internal/udp` for later stdio/session integration.

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
against archive members, require `GOTOOLCHAIN=local`, and validate exact tool
identity. Go is pinned to `go1.26.5`; Syft is pinned to 1.48.0 commit
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
executed on macOS. Native Linux amd64, Linux arm64, macOS arm64, and Intel macOS
runtime rows remain mandatory release-CI gates; Rosetta is recorded only as
additional local evidence.

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
