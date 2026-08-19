# Rework 01: terminal readiness state

The independent reviewer requested changes after accepting the normal-path evidence.

Finding: `ResourceRecorder.waitUntilStarted()` stores a non-throwing continuation resumed only by `record(directory:socket:)`. If `ResourceCommand` fails before publication (directory creation, marker write, socket creation/bind, or managed-task registration), `HarnessApplication.run` can complete with `commandFailed` while the test remains suspended forever. Task cancellation also cannot release that waiter.

Required rework:

1. Preserve actor-atomic check/register and explicit readiness synchronization.
2. Model readiness as a terminal event that completes every waiter exactly once on ready, startup failure/completion-before-ready, and cancellation.
3. Make waiter cancellation race-safe, including cancellation before registration; prove no stored waiter or continuation leak remains.
4. Add deterministic regression coverage that injects a command failure before readiness publication and proves the wait/test terminates with the expected diagnostic rather than hanging.
5. Preserve exit 143, empty output, removed directory/socket, and exactly-one managed-task cancellation on the signal success path.
6. Run focused normal/failure/cancellation stress, clean full suite, coverage, format, boundaries, diff and board validation. The previously completed full credential-free gate need not be repeated unless this rework touches production or validation sources.

Do not add arbitrary sleeps, blind retries, timeout inflation, or weaker assertions. This Mac remains build-only: no signing, installation, app/provider launch, VPN preferences or activation, routes, or DNS changes.
