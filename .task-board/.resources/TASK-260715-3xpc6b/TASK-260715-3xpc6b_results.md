# TASK-260715-3xpc6b results

## Rework implementation

- Added socketless registry reservation and exact-token family attachment. Domain work owns an incarnation before lookup, and stale completion cannot attach to a reused association ID.
- Replaced synchronous domain lookup with a fixed resolver worker pool, bounded queued jobs, copied-name/result/payload accounting, deadline and concurrency caps, and bounded completion credit. Domain `Send` returns `pendingResolution`; `NextSendCompletion` drains results and releases admission credit.
- Association close, idle expiry, generation replacement, session loss, process shutdown, caller cancellation, and registry-parent cancellation invalidate resolver work. Active and queued jobs recheck lifecycle state before resolver and socket operations; shutdown returns workers, jobs, buffers, results, completions, sockets, timers, and registry state to baseline.
- Moved IPv4-mapped IPv6 rejection before registry admission and descriptor work.
- Moved `MSG_TRUNC` handling before sockaddr conversion/materialization, preserving truncation as a counted nonterminal drop even when the source endpoint would otherwise be unsupported.
- Preserved numeric IPv4/IPv6 and resolved-domain byte integrity, exact observed reply source mapping, readiness-only retry, finite socket/error mapping, fair turn budgets, and privacy-safe aggregate diagnostics.
- Separated association/socket admission from activity refresh. New state receives one bounded initial deadline, while existing reservation, `Ensure`, and token-scoped family attachment do not rearm it; only a successful send or received datagram does.
- Rejected scoped resolver IPv6 results before accepted-result byte credit, family/socket admission, or send, with a defensive system-socket preflight against zone stripping.

## Deterministic tests

- Barrier-controlled close, idle-expiry, caller-cancel, generation-replacement, session-loss, parent-cancel, queued-job-cancel, and same-generation ID-reuse races.
- Fixed worker/queue/completion/name/payload/result baselines and atomic excess-job rejection without resolver/socket work.
- Mapped-IPv6 zero-state/zero-descriptor/zero-send preflight.
- Combined truncation plus unsupported-source precedence with association survival and oversize counter proof.
- Injected-clock numeric and resolved-domain tests assert exact deadlines and timer-arm epochs for success, `EAGAIN`, `ENOBUFS`, resolver failure, cancellation, and terminal send errors, including IPv4-to-IPv6 family attachment.
- Scoped-only resolver output proves zero descriptor/send work and full cleanup; a later in-cap unzoned IPv6 result proves deterministic byte-exact fallback.
- Existing IPv4, IPv6, dual-stack, domain policy/result bounds, pressure, fairness, real loopback, receiver stall, oversize, source preservation, cleanup, and privacy tests remain green.

## Verification

- Pinned Go 1.26.5 UDP tests: `-count=100` passed.
- Pinned Go 1.26.5 UDP and protocol race tests: `-count=10` passed.
- Pinned Go 1.26.5 full relay tests, `go vet ./...`, and `CGO_ENABLED=0 go build ./...` passed.
- UDP statement coverage: 85.5%.
- UDP tests cross-built with CGO disabled for linux/amd64, linux/arm64, darwin/amd64, and darwin/arm64.
- `make relay-protocol-check` passed: 89 vectors, Go conformance/vet, 57 Swift protocol tests, schema regeneration/drift checks, and Swift build.
- Full Swift suite passed 318 tests; `swift build`, strict `swift format lint`, pinned gofmt, and `git diff --check` passed.
- Privacy/prohibition/resource scans and `task-board validate` passed.

The first full Swift run observed an unrelated existing packet-frame fuzz counter mismatch (505 versus 506). The affected test passed immediately in isolation and a fresh full 318-test run passed without Swift changes; this anomaly is recorded in `LOGBOOK.md`.
