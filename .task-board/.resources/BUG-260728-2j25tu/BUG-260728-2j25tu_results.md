# BUG-260728-2j25tu results

## Scope and root cause
HEVUDPAssociationConnection.close published peer EOF by closing the channel before HEVUDPDatagramAdapter.connectionClosed removed the connection and released queued-byte accounting. Peer EOF therefore raced activeConnections and queue gauges. Registry cleanup could also still be pending for a locally initiated close.

## Before evidence
- Historical unmodified-tree reproduction supplied by the bug: 3 failures in roughly 24 full swift test runs on 2026-07-28. Two were staleGenerationTerminalCallbacks at the activeConnections == 0 assertion; one was relayLifecycleOutcomes at the same assertion shape.
- Task-scoped pre-fix attempt on 2026-08-11: swift test, exit 0, 426 tests in 35 suites. The low historical rate was not reproduced in this single local attempt.

## Change and audit
- Added a deterministic pending-teardown barrier. A close enters the barrier before channel.close and leaves only after adapter bookkeeping and, when notifyRegistry is true, registry.closeLocally completes.
- Added await adapter.waitForPendingTeardowns() before every adapter-internal snapshot read following receiveEOF in HEVUDPDatagramAdapterTests. This covers activeConnections, queued bytes, registry association counts, and sibling lateCallbacks/cancellations assertions.
- Serialized HEVUDPDatagramAdapterTests because repeated full-suite stress exposed blocking-socket worker starvation and real idle expiry in tests unrelated to idle behavior. Production clock defaults and adapter cancellation/generation semantics are unchanged.
- No sleep, retry, eventually assertion, or wall-clock polling was added.

## Passing validation
- git diff --check: exit 0.
- swift format lint --recursive Sources Tests Package.swift: exit 0.
- swift build: exit 0.
- swift test --filter HEVUDPDatagramAdapterTests: exit 0; 12 tests passed.
- Twenty consecutive invocations of swift test --filter HEVUDPDatagramAdapterTests/(relayLifecycleOutcomes|staleGenerationTerminalCallbacks): every run exit 0; 2 tests passed per run. Logs: /tmp/BUG-260728-2j25tu.named.HZYn5L.
- Unfiltered swift test achieved a maximum consecutive clean streak of 12 runs after the final test-fixture change. Each passed 426 tests in 35 suites. Logs: /tmp/BUG-260728-2j25tu.final3.* (runs 1-12).

## Anomalies and unresolved full-run gate
- Before suite serialization, full stress exposed an independent 10-second idle-expiry failure in replyValidationConsequences twice and a blocking-I/O hang once. Serialization removed these adapter-suite anomalies; the suite then completed in 1.7-3.0 seconds during the relevant full runs.
- Three later unfiltered gate attempts hung in the unrelated, pre-existing LibSSH integration test "caller cancellation is scoped and idle reads have no implicit timeout", after the complete HEV UDP adapter suite had passed. The latest occurrence was run 13 after 12 consecutive full passes; the adapter suite passed in 1.735 seconds before the hang.
- The unrelated LibSSH test file already contains user-owned uncommitted changes and is out of this bug's scope. Interrupted hangs each left a fresh task-created sshd fixture; only the three fixtures created by these attempts were identified by fresh task-directory/process start time and terminated. Older pre-existing fixtures were untouched.
- Therefore AC1's twenty consecutive unfiltered full swift test runs is not claimed. Exact input needed: stabilize/resolve the unrelated LibSSH hang or provide an isolated full-suite environment where it does not occur, then rerun 20 consecutive unfiltered swift test invocations. No developer handoff was run.