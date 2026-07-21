# Execution brief — relay UDP association and socket registry

Implement `TASK-260715-xw5dxc` against the accepted relay binding and protocol-v1 developer contract already attached to the task. Work only in the SSH-independent relay/core seam; do not select an SSH engine or couple this registry to provider/workspace gates.

Required implementation properties:

1. Actor/owner-task isolated mapping keyed by nonzero client association ID plus relay-session generation.
2. Bounded admission before descriptor creation: configured association, socket, timer, allocator/pending-close ceilings must fail fast with typed protocol-local reasons and finite aggregate counters.
3. Lazy family-specific IPv4/IPv6 UDP sockets, nonblocking and rootless, with no public listener. Document and test the connected-versus-unconnected socket policy.
4. Exactly-once descriptor close and timer/task cleanup on association close, expiry, session close/loss/replacement, process termination seam, cancellation, and all creation failures.
5. Injected monotonic clock with per-arm identity/epoch so the client-registry stale timer ABA/orphan defect cannot recur here.
6. Session/generation isolation: stale timers, replies, closes, or errors must never resolve to later state even if the numeric association ID is reused after terminal retirement.
7. No destination, domain, payload, credential, socket address, or remote text in logs/metrics/resources; aggregate bounded counters only.
8. Do not implement datagram send/receive, DNS resolution, public inbound sockets, privileged ports, daemon persistence, firewall changes, or SSH I/O.

Testing must use fake clock and controlled socket seams and cover IPv4-only, IPv6-only, dual family, duplicate/conflicting IDs, admission and descriptor exhaustion, partial creation failure, expiry, activity/rearm ABA ordering, crossed close, session replacement/loss, cancellation, descriptor close exactly once, and repeated restoration of descriptors/timers/tasks/callbacks to baseline. Exercise real rootless/nonblocking socket properties where the harness permits.

Run focused tests repeatedly, full Swift tests, relay protocol checks, build, strict format/diff checks, board validation, and privacy/resource scans. Attach task-scoped results and logbook outcomes, remove raw spawn logs, and route to `to-review`; do not stop at implementation-only status.
