# Independent review focus — HEV-to-relay UDP datagram adapter

Give exactly one formal verdict: accept and set `done`, or attach actionable evidence and route to `to-dev`/`analysis`; do not repair producer code inline.

Independently audit the implementation against the task AC, the accepted HEV handoff, pinned upstream HEV `socks5.udp = tcp` implementation, and relay-v1 schema/codecs. In particular:

- Prove the real HEV TCP framing and SOCKS negotiation match production, not only fake peers. Confirm only authenticated process-local boundary-owned descriptors can reach adapter admission and no public proxy/API surface is introduced.
- Trace every split/coalesced/header/body boundary, checked arithmetic, domain/address/port shape, local and wire payload ceiling, retained bytes, queue charge, and association-admission ordering. Look for cross-association byte delivery, premature allocation, unbounded skip/retention, or parser desynchronization.
- Trace association generation/ID lifecycle through admit, submit, reply, local close, remote close/ack, UDP error, expiry, session loss, cancellation, late callback, and ID reuse. Challenge stale generation callbacks, pending-but-unadmitted channels, crossed closes, and exactly-once descriptor/registry cleanup.
- Audit both output directions under partial writes, EINTR, EAGAIN/backpressure, peer close/reset, SIGPIPE behavior, stalled consumers, timeout and cancellation. Reject busy-spin, blocking of actor/event-loop progress, detached unbounded work, retry-by-copy, hidden side queues, or double accounting.
- Verify relay response endpoint fidelity and the distinct consequences for survivable local-cap drops versus protocol wire oversize/invalid endpoints. Confirm errors and close outcomes are documented and association-local unless the protocol requires session failure.
- Confirm all public metrics/logs are bounded and destination/payload-free, and that no DNS resolution, SSH frame pump, relay socket behavior, or final resource-policy selection leaked into scope.
- Re-run the focused adapter suite repeatedly, focused ThreadSanitizer/concurrency checks, full Swift tests/build, relay protocol vector/drift gate, strict format/diff, privacy/public-proxy scans, and board validation. Add targeted deterministic regressions if inspection reveals an uncovered acceptance path, but do not modify product code as reviewer.

Preserve findings in a task-scoped review outcome and use literal board status semantics.
