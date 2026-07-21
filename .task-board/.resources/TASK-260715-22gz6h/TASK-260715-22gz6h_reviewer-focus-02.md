# Fresh review focus — client UDP association registry rework 01

Independently review the current implementation of `TASK-260715-22gz6h` after the first reviewer found an idle-timer ABA/orphan race. Do not rely on the producer handoff as proof.

Verify all original acceptance criteria and, in particular:

1. Every idle-timer arm has a monotonic epoch/token, and a stale callback cannot clear, replace, reschedule, expire, or otherwise mutate the current timer arm.
2. The deterministic race test really enforces this ordering: old sleep wakes; activity commits a replacement arm; the old actor callback runs afterward; the replacement remains the sole live sleeper.
3. Fake-clock state proves one real pending/outstanding sleeper per active association and zero after every terminal teardown path, including provider stop, cancellation, session replacement/loss, local/remote close, remote error, and expiry.
4. Generation isolation, allocation wraparound/search bounds, ID reservation through closing/expired states, exactly-once HEV/relay cleanup, and privacy-safe aggregate metrics remain intact.
5. No workaround, detached/unowned task, destination/payload history, SSH-engine coupling, or NetworkExtension dependency was introduced.

Run and record fresh evidence for the focused registry tests repeatedly, the full Swift test suite, `make relay-protocol-check`, build, format lint, diff check, board validation, and task-scoped privacy/resource checks. Route accepted work to `done`; otherwise attach an actionable verdict and route to `to-dev`.
