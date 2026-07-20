# relay/

Go implementation root for `relux-relay` (relay protocol v1). The authoritative
Go module scaffold (`go.mod` pinned per TASK-260715-3bdplx: Go 1.26.5,
standard library only, `CGO_ENABLED=0`, module
`github.com/relux-works/relux-tunnel/relay`) is owned by TASK-260715-27uz4n and
is not created here.

Current contents (TASK-260715-2azda7):

- `internal/protocol/generated_v1.go` — generated protocol v1 constants and
  typed metadata. Never edit by hand; regenerate with
  `make relay-protocol-generate` from the repository root. Drift is rejected by
  `make relay-protocol-check`.
- `internal/protocol/parity_test.go` — handwritten drift guard mirroring the
  Swift parity test.

Until the module scaffold lands, `scripts/tests/test-relay-protocol-go.sh`
(invoked by `make relay-protocol-check`) compiles and tests this package inside
a throwaway module under `.temp/relay-protocol-go-smoke/`. When
TASK-260715-27uz4n adds `relay/go.mod`, these files need no changes: the
package path `relay/internal/protocol` already matches the binding ADR, and the
smoke script can then be switched to plain `go test ./...` inside the module.
