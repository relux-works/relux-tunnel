# Fresh rework review — relay UDP association/socket registry

Independently verify rework 01 against the original task AC and every finding in `TASK-260715-xw5dxc_review-verdict.md`.

Acceptance requires direct evidence that:

1. `EnsureFamilies` reserves the complete family-set budget before descriptor creation and atomically rolls back all newly created and already owned sockets/state on any completion failure. The lazy `Ensure` path must not preserve a half-completed dual-family association either.
2. The rollback tests assert exactly-once descriptor close and zero association/socket/timer/event/task/pending-close state after second-family failure.
3. A controlled obsolete arm/epoch is actually delivered to the owner after rearm, increments the stale-arm counter, cannot alter/expire the live association, and leaves exactly one current timer until its real deadline.
4. Barrier-controlled descriptor-use and activity races cover local close, remote close, expiry, generation replacement, session shutdown/loss, process termination, and parent cancellation. Each row proves a permitted linearization, exactly-once close, stale-token rejection, and full baseline restoration across repeated race-detector runs.
5. The rootless, unbound, unconnected, nonblocking, close-on-exec, registry-only, privacy-safe and SSH-independent constraints remain intact.

Inspect production code and tests; do not accept producer summaries as evidence. Run fresh pinned focused/repeated/race tests, full relay Go tests/vet/build, real descriptor checks, protocol check, full Swift tests/build, gofmt/diff checks, board validation and privacy/resource scans. Route accepted work to `done`; otherwise attach an actionable verdict and route to `to-dev`.
