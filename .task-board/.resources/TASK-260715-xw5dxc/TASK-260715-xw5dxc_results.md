# TASK-260715-xw5dxc — relay UDP registry rework results

## Rework delivered

- Added atomic EnsureFamilies admission. The complete canonical family set is capacity-checked before descriptor creation, sockets are staged outside live state, and any family failure closes every staged or already-owned association socket exactly once and restores map, socket, timer, event, task, and callback baselines. Lazy single-family admission remains available; a failed later family completion also retires partial ownership.
- Added a private owner-loop timer-arm delivery seam. Tests submit a real obsolete arm after rearm and prove one live association, one logical timer, one physical timer, and an incremented finite stale-arm counter remain until the current deadline.
- Added a 20-cycle barrier-controlled matrix for descriptor use plus activity racing local close, remote close, idle expiry, generation replacement, session close, session loss, process termination, and parent cancellation. Every row proves a permitted linearization, exact close counts, stale generation or incarnation rejection where reuse is possible, terminal owner closure otherwise, and baseline restoration.
- Updated relay documentation with the atomic family-set and rollback policy. No datagram I/O, DNS, bind/listen/connect, SSH coupling, public listener, privileged port, destination state, or new dependency was introduced.

## Verification

- Pinned Go 1.26.5: UDP package 20 repeated runs passed; whole package race test 3 runs passed; focused rollback/stale-arm/race matrix race test 10 runs passed; latest package race test 5 runs passed.
- Full relay go test ./..., go vet ./..., and go build ./... passed with CGO disabled and module reads locked. UDP statement coverage is 90.5 percent.
- Real descriptor properties passed 20 runs: IPv4/IPv6 family, nonblocking, close-on-exec, local port zero, no peer, and post-close bad-descriptor state.
- make relay-protocol-check passed 89 vectors, 57 Swift protocol tests, schema/generation drift checks, negative fixtures, and Swift build.
- Full Swift: the first 318-test run observed one unrelated provider-adapter expectation mismatch; the affected 10-test suite passed immediately in isolation and a fresh full 318-test run passed. A fresh swift build passed. No Swift files changed.
- gofmt -l, git diff --check, production scope/privacy/prohibition scans, and task-board validate passed. No operator directives were pending.
