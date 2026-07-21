# TASK-260715-3xpc6b final independent recovery review

Verdict: accepted; route to done.

## Source and architecture evidence

- Existing-association Reserve, Ensure, and EnsureTokenFamilies paths do not touch the idle deadline. New state receives one initial bounded deadline; UseSocketOperation touches only when the nonblocking callback reports real activity.
- Numeric and resolved-domain tests assert exact fake-clock deadlines and timer-arm counts. Successful sends rearm; EAGAIN, ENOBUFS, resolver failure, caller cancellation, and terminal socket errors do not.
- Zoned IPv6 resolver results are discarded before Unmap, accepted-result byte credit, family/socket admission, or send. Scoped-only results open no descriptor and send nothing; a later in-cap unzoned result is selected exactly. The production SendTo seam also rejects zones.
- Domain work reserves an incarnation before lookup and runs through a fixed worker/job/completion-credit scheduler with bounded copied name, payload, and result bytes. Close, expiry, replacement, shutdown, parent/caller cancellation, queued cancellation, and same-ID reuse barriers suppress stale socket work and restore baselines.
- MSG_TRUNC is surfaced before sockaddr conversion; mapped numeric IPv6 rejects before registry admission. Receive turns enforce target, socket-visit, datagram, byte, and monotonic-time budgets with round-robin continuation.
- Production owns only unbound, nonblocking, close-on-exec association sockets. It adds no listener, privileged bind, recursive DNS, cache, ICMP/application parsing, SSH coupling, or destination/payload diagnostics. Command-shell wiring remains intentionally outside this task and is documented for later integration.

## Fresh verification

- Go 1.26.5 UDP tests count=100: passed.
- Go 1.26.5 race tests for UDP and protocol count=10: passed.
- Full relay Go tests, go vet, and CGO-disabled build: passed.
- UDP statement coverage: 85.5%.
- UDP test cross-builds: linux/amd64, linux/arm64, darwin/amd64, darwin/arm64 passed.
- make relay-protocol-check passed: 89 vectors, 57 Swift protocol tests, generator/drift checks, and Swift build.
- Full Swift suite passed: 318 tests; standalone Swift build passed.
- Strict recursive Swift format, gofmt diff, git diff check, board validation, privacy/prohibition/resource scans: passed.
- APFS had 29 GiB available during the recovery review; no ENOSPC recurrence.

No blocking or rework finding remains.