# Independent review focus — relay UDP association/socket registry

Review `TASK-260715-xw5dxc` independently from the implementation handoff. Treat the accepted binding, limits decision, developer contract, task AC, and execution brief as authoritative.

Pay special attention to these failure classes:

1. Admission must reject before descriptor creation when any association/socket/timer/pending-close ceiling would be exceeded; partial dual-family creation failure must close the first descriptor exactly once and leave no admitted state.
2. The unconnected/unbound socket policy must be real: IPv4/IPv6 descriptors are nonblocking, close-on-exec, port zero and not public listeners until future I/O; no privileged/public bind or destination persistence.
3. Owner-loop serialization and generation/incarnation tokens must prevent stale expiry, activity, close, reply/error, or descriptor operation from mutating reused association IDs.
4. Timer rearming must have identity/epoch protection against the same stale-callback ABA/orphan race previously found in the client registry.
5. Descriptor use versus close, crossed close, cancellation, process/session stop, replacement, expiry, and creation errors must close every socket once and restore descriptors, timers, tasks, callbacks, and maps to baseline.
6. Metrics/errors/resources must contain finite aggregate reasons only — no destination/domain/address/payload/credential/remote text.
7. Scope must remain registry-only: no datagram send/receive, DNS, public listener, SSH I/O, firewall/daemon work, or engine selection.

Run fresh focused tests repeatedly, Go race detector, all relay Go tests/vet/build, real descriptor assertions, relay protocol check, full Swift tests/build, formatting and diff checks, board validation, and privacy/resource scans. Inspect the actual tests to ensure they force the races and baseline conditions rather than only asserting happy-path counters. Route accepted work to `done`; otherwise attach a precise verdict and route to `to-dev`.
