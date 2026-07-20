# TASK-260715-1y1g1u review round 3

Date: 2026-07-20
Verdict: accepted

## Acceptance evidence

1. Exact v1 wire and stream contract: Swift encodes the generated 12-byte client hello and decodes only the exact generated 16-byte server hello; Go uses the generated layouts with fixed 12-byte storage and emits the exact 16-byte reply. Standalone decoders reject truncated and extended inputs. Incremental state machines preserve legal coalesced frame bytes, reject coalesced full or partial RLXR duplicate prefixes, and publish success immediately at the approved exact boundary.
2. Stable fail-closed reasons: magic, version, status, reserved flags, feature subset, maxFrame, timeout, EOF, cancellation, transport failure, duplicate, trailing, and stale-generation paths map to finite local code, phase, scope, and disposition values. Swift perform-level failures cancel, reset, and close. Go failures return Close=true and generated rejection status where applicable.
3. Negotiation and limits: features are request and support intersection. effectiveMaxFrame is bounded by the peer proposal and local configured cap in both peers. Every local-only RelayEffectiveLimits value is min of its generated peer default or fixed constant and injected configuration; configuration is range-checked before handshake completion.
4. Cross-language boundaries: Swift and Go tests cover every hello split, legal coalesced frame handoff, every coalesced or partial duplicate-magic split, and the decision-02 exact-boundary ownership rule with fixed hello storage or bounded reads.
5. Coverage and privacy: tests exercise declared success and failure mappings, boundary limits, stale callbacks, cancellation, perform-level transport and EOF cleanup, and diagnostics that never reflect peer bytes or unknown numeric status.

## Architecture fit

The Swift client remains in ReluxTunnelCore RelayProtocol and depends only on the candidate-neutral SSHByteChannel plus shared runtime clock and cancellation seams. The Go relay remains standard-library-only under relay/internal/protocol, uses encoding/binary BigEndian and fixed hello storage, and adds no FFI, cgo, unsafe, runtime schema parsing, or transport coupling. The later-read RLXR ownership handoff is recorded for TASK-260715-1jvgcn.

## Independent validation

- make relay-protocol-check: passed, including schema drift, 12 negative fixtures, Go smoke vet/test, Swift build, and 19 selected protocol tests.
- swift test: 129 tests in 14 suites passed.
- CGO_ENABLED=0 Go test coverage: 92.6 percent.
- swift format lint --strict: passed for both changed Swift files.
- gofmt -d: clean for both changed Go files.
- scripts/check-core-boundaries.sh: passed.
- git diff --check: passed.
- task-board validate: passed.

Scratch logs: .temp/TASK-260715-1y1g1u/review-03/. Local Go is 1.25.5; the accepted pinned Go 1.26.5 module gate remains owned by TASK-260715-27uz4n and is not a defect in this task.