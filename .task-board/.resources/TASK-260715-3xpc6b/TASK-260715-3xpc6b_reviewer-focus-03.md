# Final fresh review — relay UDP I/O rework 02

Independently review the complete `TASK-260715-3xpc6b` implementation, with special focus on the two findings in `TASK-260715-3xpc6b_review-02.md` and preservation of all previously closed findings.

Require direct evidence that:

1. Existing-association `Reserve`, `Ensure`, and token-family attachment do not touch/rearm idle state. Newly created/socketless state still receives one bounded initial deadline. Only a successful outbound send refreshes activity.
2. Deterministic injected-clock tests cover numeric and resolved-domain existing associations and assert exact deadline/timer epoch behavior: success refreshes; EAGAIN, ENOBUFS, resolver failure/cancellation and terminal send errors do not.
3. Zoned IPv6 resolver results are rejected before accepted-result byte credit, socket/family admission and send. With only zoned results, no descriptor/send side effect occurs; with a later in-cap unzoned result, fallback is deterministic and byte/address exact.
4. Incarnation-first fixed async resolver scheduling, close/expiry/cancellation/reuse barriers, bounded jobs/workers/queues/completions, truncation-before-sockaddr, mapped-numeric preflight, fairness, source fidelity, finite errors, privacy and rootless/SSH-independent scope remain intact.

Inspect production and tests rather than summaries. Run fresh pinned focused/repeated/race tests, full relay Go tests/vet/build/coverage/cross-build, protocol gate, full Swift tests/build, gofmt/diff checks, board validation and privacy/prohibition/resource scans. Route accepted work to `done`; otherwise attach an actionable verdict and route to `to-dev`.
