# Rework 01 — relay UDP I/O and resolver lifecycle

Close every blocking finding in `TASK-260715-3xpc6b_review.md` without weakening the task AC or accepted protocol ordering.

Required changes:

1. **Incarnation before resolution.** Reserve association capacity and obtain an incarnation-scoped token before any domain resolver side effect. Complete family/socket admission and send only if that exact token remains active. Close, expiry, session replacement/loss, process stop and parent cancellation must invalidate/cancel all pending work; same-generation ID reuse must not let old resolution reopen, send through, or mutate the new association.
2. **Bounded asynchronous resolver jobs.** `Send`/event-loop work must not synchronously block for resolver timeout and must not spawn one goroutine per datagram. Add a fixed-capacity worker/job scheduler with explicit concurrent-job, queued-job, copied-name/result-byte, inspected-result, accepted-result and deadline limits, plus cancellation and baseline accounting. Excess work rejects before job/goroutine/resource creation. Completion revalidates generation+incarnation before socket work.
3. **Truncation before sockaddr conversion.** After `recvmsg`, return the truncation signal before endpoint conversion/allocation. A truncated datagram with an unsupported/scoped source must be a counted nonterminal oversize/truncation drop, not an association-terminal address failure.
4. **Reject mapped IPv6 before admission.** Detect IPv4-mapped IPv6 and other unsupported numeric forms before registry `Ensure` or any socket/resolver work. Prove zero state, descriptors, resolver calls and send attempts.

Add deterministic no-sleep/barrier tests that pause resolution and force close, expiry, cancellation, session replacement/loss and same-generation ID reuse. Assert no stale send/reopen/reply, exact terminal behavior and zero jobs/workers/queues/names/results/readiness/buffers/registry resources afterward. Prove the event-loop remains responsive while resolution is paused and fixed worker/job limits reject atomically. Add combined truncation+unsupported-source precedence and mapped-IPv6 no-side-effect tests.

Preserve exact source mapping, fair per-turn budgets, readiness-only retry, rootless/no-listener policy, finite privacy-safe counters and SSH independence. Use `go-testing-tools` closed-loop seams and invariant baseline assertions.

Run fresh focused/repeated/race tests, full relay Go tests/vet/build/coverage/cross-compile checks, protocol gate, full Swift tests/build, gofmt/diff checks, board validation and privacy/prohibition/resource scans. Update task-scoped results/logbook, remove raw spawn logs and return to `to-review` only after all findings are closed.
