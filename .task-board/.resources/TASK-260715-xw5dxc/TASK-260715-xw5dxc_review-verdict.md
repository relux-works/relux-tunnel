# TASK-260715-xw5dxc — independent review verdict

## Verdict

Changes requested. Route to `to-dev`.

## Findings

1. **High — dual-family creation is not atomic and violates the explicit rollback contract.** The only admission API accepts one family at a time. When an association already owns IPv4 and opening IPv6 fails, `registryState.ensure` returns the socket failure without retiring the association or closing the first descriptor (`relay/internal/udp/registry.go:419-439`). The test explicitly requires that first family to remain usable and the association/socket/timer gauges to remain at 1 (`relay/internal/udp/registry_test.go:119-129`). This is the opposite of reviewer-focus item 1: partial dual-family creation failure must close the first descriptor exactly once and leave no admitted state. Rework must provide an atomic family-set admission path or equivalent transaction semantics, reserve every required credit before either descriptor is opened, and on any second-family failure close every descriptor created/owned by that attempted association exactly once with map/socket/timer/pending-close gauges restored to baseline.

2. **High — the required cleanup race matrix is not actually forced by tests.** The sole barrier-controlled descriptor race is `UseSocket` versus a remote close (`relay/internal/udp/registry_test.go:266-299`). Replacement, session loss, process shutdown, parent cancellation, expiry, and local close are covered only as sequential operations. That does not prove acceptance criterion 4 or reviewer-focus item 5 for descriptor use/activity racing each terminal path. Add barrier-controlled tests for descriptor use and activity versus local close, remote close, expiry, generation replacement, session shutdown/loss, and parent cancellation. Each must assert one linearized outcome, exactly-once close, stale generation/incarnation rejection, and restoration of association/socket/timer/event/task state to baseline across repeated runs under `-race`.

3. **Medium — the stale timer test does not exercise the arm/epoch rejection branch it claims to prove.** After activity re-arms the registry, `clock.fire(0)` writes to the stopped timer's old channel (`relay/internal/udp/registry_test.go:132-153`), but the owner loop has already stopped selecting that channel. The test never forces `expire(oldArm)`, never asserts `StaleTimerArmsIgnored`, and therefore does not prove the per-arm identity guard. Add a controlled seam that delivers an obsolete arm/epoch to the owner after rearm, then assert it is counted/ignored, cannot expire the live incarnation, and leaves exactly one current logical/physical timer until the real deadline.

## Fresh review evidence

Passed under pinned Go 1.26.5:

- `go test ./internal/udp -count=20`
- `go test -race ./internal/udp -count=1`
- selected lifecycle/resource tests `-count=100`
- `go test ./...`
- `go vet ./...`
- `go build ./...`

Also passed:

- `make relay-protocol-check` (89 vectors, 57 Swift protocol tests, schema/generation drift gate)
- `swift test` (318 tests in 28 suites)
- `swift build`
- pinned `gofmt -l relay/internal/udp`
- `git diff --check`
- production prohibition/privacy scans
- `task-board validate`

The production socket test did pass for IPv4 and IPv6 and proves `O_NONBLOCK`, `FD_CLOEXEC`, port zero, no peer, and post-retirement `EBADF`. No public listener, bind, connect, datagram I/O, DNS, SSH coupling, unsafe/cgo, or third-party dependency was found.