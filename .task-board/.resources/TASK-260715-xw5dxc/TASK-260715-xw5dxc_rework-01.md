# Rework 01 — relay UDP socket registry

Address every finding in `TASK-260715-xw5dxc_review-verdict.md` without weakening the accepted task AC or reviewer focus.

Required changes:

1. **Atomic family-set admission.** Add an API/transaction that admits the complete required family set for an association. Reserve all association/socket/timer/pending-close credits before opening either descriptor. If any family creation fails, close every descriptor created or already owned by that attempted association exactly once and leave no association, socket, timer, event, task, or pending-close state. Replace the current test that preserves IPv4 after IPv6 failure with deterministic rollback evidence. Preserve lazy single-family admission where appropriate, but dual-family admission itself must be atomic.
2. **Forced cleanup race matrix.** Add barrier-controlled descriptor-use and activity races against local close, remote close, expiry, generation replacement, session shutdown/loss, process termination seam, and parent cancellation. Repeat under the pinned race detector. For each row prove a permitted linearized result, exactly-once close, stale generation/incarnation rejection, and complete restoration of association/socket/timer/event/task/callback state.
3. **Real stale-arm delivery.** Add a controlled test seam that explicitly submits an obsolete timer arm/epoch to the owner after a replacement arm is installed. Assert the stale arm is counted and ignored, cannot expire or mutate the live association, and leaves exactly one current logical/physical timer until the current deadline. Do not merely write to a channel no longer selected by the owner loop.

Keep the socket policy rootless, unbound, unconnected, nonblocking, close-on-exec, registry-only, privacy-safe, and SSH-independent. Do not introduce sleeps as correctness synchronization or unbounded goroutines/queues.

Run fresh focused/repeated/race tests, all relay Go tests/vet/build, real descriptor assertions, relay protocol check, full Swift tests/build, gofmt, diff checks, board validation, and privacy/resource scans. Update the task-scoped results/logbook with rework evidence, remove raw spawn logs, and route back to `to-review` only when all findings are closed.
