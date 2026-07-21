# Execution brief — relay UDP I/O, destination resolution, response mapping

Implement `TASK-260715-3xpc6b` on top of the accepted protocol codec (`516lhy`) and relay registry (`xw5dxc`). Keep this SSH-independent and rootless. The registry remains the sole owner of association sockets and lifecycle; this task adds bounded datagram I/O and resolution through explicit seams.

Required behavior:

1. Send byte-exact numeric IPv4/IPv6 datagrams through the association-owned family socket. Receive replies with exact observed source family/address/port/payload preserved in the generated response record.
2. Domain inputs use a cancellable injected resolver with strict name-byte, concurrent-request, result-count, deadline, memory and family-policy caps. Do not cache, log, persist or expose destination names/addresses by default.
3. Follow the accepted validation order before any socket/resolver work: envelope/type/direction, association admission, complete HEV structure, protocol/local payload caps, resolver-form rules, then queue credit.
4. Never split a datagram. Detect truncation/oversize before forwarding/materialization where possible; map invalid port/address/family, resolver failure, unreachable/permission/closed-socket errors to the generated finite error/drop contract.
5. EAGAIN/readiness transitions and receiver stall must not busy-spin, retain unbounded retry buffers or create hidden queues. Every event-loop turn has injected datagram/byte/time budgets and guarantees finite progress across active associations under unsaturated load.
6. Cancellation, association close/expiry, session replacement/loss, process stop and resolver/socket races must release reservations, buffers, goroutines/tasks, readiness registrations and descriptors exactly once. Stale generation/incarnation work cannot emit a reply or mutate reused state.
7. No public listener, privileged bind, recursive DNS service, arbitrary cache, ICMP tunneling, application parsing, SSH coupling, destination-level diagnostics or payload logging.

Use `go-testing-tools` closed-loop principles: isolate socket, readiness, monotonic clock and resolver I/O behind narrow fakes; assert invariants after each forced interleaving; use table-driven error mapping and deterministic barrier-controlled cancellation/fairness tests rather than sleeps.

Testing must cover controlled IPv4, IPv6, dual-stack, opaque domain, multiple resolver results, time/count/memory/concurrency caps, invalid inputs, source preservation, truncation/oversize, EAGAIN, receiver stall, per-turn fairness, cancellation and stale-generation races. Include real loopback UDP tests where possible, but keep deterministic fakes as the correctness oracle. Repeatedly prove byte integrity, no busy-spin, bounded allocation/queueing and full resource baselines under the pinned Go race detector.

Run focused/repeated/race tests, full relay Go tests/vet/build and coverage, relay protocol check, full Swift tests/build, gofmt/diff checks, board validation and privacy/prohibition/resource scans. Attach task-scoped results/logbook evidence, remove raw spawn logs and route to `to-review`; do not stop at implementation-only status.
