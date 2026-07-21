# Independent review focus — relay UDP I/O and response mapping

Review `TASK-260715-3xpc6b` independently against its AC, accepted protocol developer contract, execution brief, and the accepted registry/codec behavior. Do not rely on producer summaries.

High-risk review areas:

1. The relay session must enforce the normative pre-side-effect order: envelope/type/direction, association-capacity admission, complete HEV structure, protocol/local payload caps, resolver-form validation, queue credit, then resolver/socket work. Prove malformed or over-cap input cannot create state or perform I/O.
2. Numeric IPv4/IPv6 sends and received replies must preserve exact bytes and source family/address/port. No datagram splitting, silent address rewriting, zone leakage, or activity refresh on EAGAIN/error.
3. Domain resolution must bound inspected results (including invalid entries), accepted result count, copied bytes, name bytes, concurrency, deadline and family policy. Cancellation and stale generations must suppress send/reply and release every reservation. No destination cache/history/log/resource leakage.
4. EAGAIN/readiness handling and receiver stalls must make at most bounded syscall attempts with no busy-spin, hidden retry buffer or unbounded goroutine/queue. Round-robin turns must enforce socket/datagram/byte/time budgets and provide finite progress for admitted sockets.
5. Error/drop mapping must be finite and contract-correct for invalid address/port/family, resolver failures, unreachable/permission/closed sockets, truncation/oversize, pressure and cancellation.
6. Close/expiry/session replacement/loss/process stop/cancellation races must not emit late responses or mutate reused association IDs, and all buffers, resolver slots, readiness registrations, tasks/goroutines and registry resources must return to baseline.
7. Scope/privacy: no public listener, privileged bind, DNS recursion, arbitrary cache, ICMP/application parsing, SSH coupling or destination/payload diagnostics.

Inspect the actual production code and tests. Use `go-testing-tools` closed-loop review: deterministic fakes as the correctness oracle, real loopback as integration evidence, invariant/baseline assertions after forced interleavings. Run fresh pinned focused/repeated/race tests, full relay Go tests/vet/build/coverage/cross-compile checks, protocol gate, full Swift tests/build, gofmt/diff checks, board validation and privacy/prohibition/resource scans. Route accepted work to `done`; otherwise attach an actionable verdict and route to `to-dev`.
