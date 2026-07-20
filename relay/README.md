# relay/

Go implementation root for `relux-relay` (relay protocol v1). The authoritative
Go module scaffold (`go.mod` pinned per TASK-260715-3bdplx: Go 1.26.5,
standard library only, `CGO_ENABLED=0`, module
`github.com/relux-works/relux-tunnel/relay`) is owned by TASK-260715-27uz4n and
is not created here.

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

Until the module scaffold lands, `scripts/tests/test-relay-protocol-go.sh`
(invoked by `make relay-protocol-check`) compiles and tests this package inside
a throwaway module under `.temp/relay-protocol-go-smoke/`. When
TASK-260715-27uz4n adds `relay/go.mod`, these files need no changes: the
package path `relay/internal/protocol` already matches the binding ADR, and the
smoke script can then be switched to plain `go test ./...` inside the module.
