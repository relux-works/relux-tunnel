# TASK-260715-1ozsb6 reviewer result — round 10

Verdict: CHANGES REQUESTED. Route to to-dev.

The round-9 teardown change is present and the new connected cancellation-ignoring socket-close regression passes inside the isolated integration suite. Packaging, pinned-source validation, extension-safe macOS linkage, explicit M3-deferred states, lint, and builds remain healthy. However, AC 2, AC 5, and the Tests green/reproducibility gates remain red.

## Blocking lifecycle/test finding

The developer's exact claimed gate, swift test --filter LibSSH2, is still not reproducible. Two reviewer invocations failed to complete (one remained idle for more than five minutes and one for more than two minutes; both were terminated and their orphaned reviewer-owned processes were cleaned up). After suite isolation and relinking, the exact command completed with exit 1: nonCooperativeUploadSourceTimeout failed at Tests/ReluxTunnelLibSSH2AdapterTests/LibSSH2AdapterIntegrationTests.swift:512 because the post-timeout ownedResourceSnapshot().automaticTasks did not equal baseline.automaticTasks + 1.

This is the same order/concurrency-sensitive ownership failure recorded in round 9. The source explicitly remains unreleased at that assertion, so exactly one non-cooperative upload task should remain owned while cooperative upload/read/reset work has retired. The observed mismatch means task ownership accounting/retirement is still nondeterministic, or the regression does not synchronize the state it claims. Either way, repeated connect/cancel/upload lifecycle evidence is not green and baseline restoration cannot be accepted.

Required rework: diagnose the actual count/state at the failed assertion; make cooperative timeout children and channel cleanup deterministically reconcile before the public upload result is observed while retaining the one genuinely non-cooperative source task; make the test synchronize on the intended ownership state rather than timing; and pass the exact combined swift test --filter LibSSH2 gate repeatedly without hangs or order-sensitive failures. Preserve the new connected non-cooperative socket-close coverage.

## Independent validation

- swift test --filter LibSSH2: two invocations did not terminate and were reviewer-terminated; later exact invocation exit 1, 40 passed / 1 failed at line 512.
- swift test --filter LibSSH2BridgeTests: exit 0, 18 tests.
- swift test --filter LibSSH2AdapterIntegrationTests: exit 0, 19 tests.
- swift test --filter ReluxTunnelLibSSH2AdapterTests: exit 0, 37 tests; this isolation confirms the failure is order/concurrency-sensitive rather than a stable green gate.
- make validate-core: exit 0, 375 tests / 31 suites plus boundary checks and build.
- make validate-libssh2: exit 0.
- make test-libssh2-source-gates: exit 0.
- make native-apple-matrix: exit 0; arm64/x86_64 macOS provider and harness release targets link the pinned extension-safe graph.
- swift-format lint --recursive --strict Package.swift Sources Tests: exit 0.
- swift build: exit 0.
- git diff --check: exit 0.
- task-board validate: exit 0 with the known STORY-260715-lkshfz aggregate mismatch while this task is reviewing.
- Attachment SHA-256 values match: contract 207b5834794202a5a3c051b248b80ddeaab0888399a9e39dd4b65274c57bddf7; inputs fec044ef6b854a21318027399eaaa59e6862a653be8106d2c644141cbbed488c.

The four M3-deferred semantics remain explicit unsupported/notReported states traceable to TASK-260728-3cveay; they are not a rejection reason.