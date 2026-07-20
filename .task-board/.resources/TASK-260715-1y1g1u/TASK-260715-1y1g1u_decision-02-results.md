# TASK-260715-1y1g1u decision-02 rework evidence

The Swift and Go every-split duplicate-hello tests now encode the approved
ownership boundary exactly: a read ending at 12/16 bytes publishes handshake
success, while any full or partial `RLXR` remainder already coalesced in the
completing callback is rejected as `duplicateHello`. The protocol spec and
logbook assign a later-read `RLXR` prefix to the post-handshake session/envelope
layer owned by `TASK-260715-1jvgcn`; no lookahead or transport barrier was added.

Validation passed: `make relay-protocol-check` (including Swift build and 19
selected protocol tests), full `swift test` (129 tests), CGO-disabled Go
vet/test with 92.6% statement coverage, strict Swift formatting, `gofmt`, core
boundary validation, `git diff --check`, and `task-board validate`.
