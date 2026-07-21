# Fresh rework review — relay UDP I/O and resolver lifecycle

Independently verify rework 01 against the original task AC and all four findings in `TASK-260715-3xpc6b_review.md`.

Acceptance requires source and test evidence that:

1. Every domain send receives a socketless registry reservation and exact generation/incarnation token before resolver side effects. Family/socket attachment and send revalidate that exact token; close, expiry, replacement/loss, process stop, parent cancellation and same-generation ID reuse cannot reopen, send through or mutate a new incarnation.
2. Resolution uses a fixed bounded scheduler — not synchronous event-loop blocking and not one goroutine per datagram. Worker count, active jobs, queued jobs, completion credit, copied name/result bytes, inspected/accepted result counts and deadlines are bounded and observable through aggregate baseline accounting. Excess rejects before work/resource creation.
3. Barrier tests pause active and queued resolution and force close, expiry, cancellation, generation replacement/loss, process/parent stop and same-ID reuse. They prove event-loop responsiveness, no stale send/reply/reopen and zero worker/job/queue/completion/name/result/readiness/buffer/registry resources afterward.
4. `MSG_TRUNC` is handled before source sockaddr conversion/materialization. Combined truncation+unsupported-source input is a counted nonterminal drop.
5. IPv4-mapped IPv6 and other unsupported numeric forms reject before registry/socket/resolver side effects, with zero state/descriptors/calls.
6. Existing byte/source fidelity, finite error/drop mapping, readiness-only retry, fair per-turn budgets, rootless/no-listener behavior, privacy and SSH independence remain intact.

Use `go-testing-tools` closed-loop review. Inspect production/tests, run fresh pinned focused/repeated/race tests, full relay Go tests/vet/build/coverage/cross-build, protocol gate, full Swift tests/build, gofmt/diff checks, board validation and privacy/prohibition/resource scans. Route accepted work to `done`; otherwise attach a precise verdict and route to `to-dev`.
