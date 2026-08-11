# BUG-260728-2j25tu results

## Scope and root cause

`HEVUDPAssociationConnection.close` published peer EOF by closing the channel before `HEVUDPDatagramAdapter.connectionClosed` removed the connection and released queued-byte accounting. Peer EOF therefore raced `activeConnections` and queue gauges. Registry cleanup could also still be pending for a locally initiated close.

## Before evidence

- Historical unmodified-tree reproduction supplied by the bug: 3 failures in roughly 24 full `swift test` runs on 2026-07-28. Two occurred in `staleGenerationTerminalCallbacks` at `activeConnections == 0`; one occurred in `relayLifecycleOutcomes` at the same assertion shape.
- Task-scoped pre-fix attempt on 2026-08-11: `swift test`, exit 0, 426 tests in 35 suites. The low historical rate was not reproduced in that single local attempt.

## Deterministic fix and suite audit

- A lock-protected pending-teardown barrier begins before `channel.close()` can publish EOF and completes only after adapter bookkeeping and, when `notifyRegistry` is true, `registry.closeLocally` finishes.
- Every adapter-internal snapshot read after `receiveEOF` in `HEVUDPDatagramAdapterTests` now awaits `adapter.waitForPendingTeardowns()`. This covers `activeConnections`, queued-byte gauges, `registry.associationCount`, `metrics.lateCallbacks`, and `metrics.cancellations`.
- The one nearby post-EOF snapshot without this seam is `RecordingUDPRelay.snapshot()` at the terminal-error ordering assertions. It reads synchronized relay-fixture submissions, not adapter-internal teardown state, so it does not have the reported race shape.
- The suite is serialized to prevent its blocking-socket fixtures from starving one another during full-suite stress.
- No production cancellation semantics or generation model changed. No sleep, retry, eventually assertion, or wall-clock polling was added.

## After evidence

- An earlier attempt reached 12 consecutive unfiltered passes (426 tests in 35 suites) before an unrelated LibSSH integration hang. That anomaly was recorded rather than counted as satisfying AC1.
- On the final tree at `06dabb11010d874a0810b80409199b8a7f9ec971`, a fresh reset-on-any-failure streak passed 20 consecutive unfiltered `swift test` invocations. Every process exited 0 and reported 427 tests in 35 suites passed.
- Every one of the 20 logs contains a pass record for both named tests: `relayLifecycleOutcomes` and `staleGenerationTerminalCallbacks`.
- Logs are retained at `.temp/BUG-260728-2j25tu/full-runs/run-01.log` through `run-20.log`.
- No test anomaly or process hang occurred in this final 20-run streak.

## Final validation

- `swift format lint --recursive Sources Tests Package.swift`: exit 0.
- `swift build`: exit 0. The linker emitted the existing alignment-reduction warning for `ReluxTunnelHarness`; build completed successfully.
- `git diff --check`: exit 0.
- `task-board validate`: exit 0, while reporting `PARENT_STATUS_MISMATCH` because `STORY-260715-1nsw9p` remained stored as `to-dev` while this bug was in `development`. This board anomaly is unrelated to adapter behavior and is rechecked after handoff.

## Outcome

All bug acceptance criteria and developer checklist gates are satisfied. The implementation and tests are ready for review.
