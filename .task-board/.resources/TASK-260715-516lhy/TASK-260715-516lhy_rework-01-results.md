# TASK-260715-516lhy — review rework round 1

The Swift and Go HEV decoders now complete ATYP, recomputed HDRLEN, address,
port, and exact checked outer-length validation before applying protocol or
local MSGLEN limits. Mirrored tables cover malformed 513-byte and 1473-byte
declarations at every structural stage and prove association-close disposition
with zero decoded materialization. A structurally valid 1473-byte record takes
the protocol-violation close path; the retained structurally valid 513-byte
record takes the lowered-local-cap reject path.

Validation passed on 2026-07-20: `make relay-protocol-check`; full `swift test`
(150 tests / 16 suites); Go vet/test (91.3% coverage); `FuzzDatagramCodec` for
3 seconds (1,135,854 executions); strict Swift format; gofmt; core-boundary
guard; and `git diff --check`.

The installed Go toolchain is 1.25.5 and the repository has no authoritative
relay module yet, so the repository's accepted synthesized Go 1.25 smoke module
was used. The pinned Go 1.26.5 relay module remains owned by
TASK-260715-27uz4n.
