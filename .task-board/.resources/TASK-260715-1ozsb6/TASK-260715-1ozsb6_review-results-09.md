# TASK-260715-1ozsb6 reviewer result — round 9

Verdict: CHANGES REQUESTED. Route to to-dev.

The round-8 reserved teardown capacity fixes the submitted saturation defect: the focused saturation regression passes and socket close is no longer admitted through the ordinary 64-slot registry. Pinning, extension safety, deferred-state disclosure, macOS provider/harness linkage, format, boundary checks, and builds are otherwise healthy.

## Blocking lifecycle finding

Teardown still does not deterministically return owned tasks to baseline. performTearDown waits for a reserved timeout race only until its first child resolves, while LibSSH2TimeoutRace removes itself only after both children finish. ownedResourceSnapshot awaits teardownTask but does not drain teardownAsyncOperations and includes that registry in automaticTasks. Independent full-suite runs observed the residual count after teardown returned.

A second branch makes this permanent for a connected transport whose socket close consumes the transportClose deadline: automatic tasks are non-empty, but the join branch at LibSSH2Transport.swift:2096-2104 is skipped when remainingDuration is nil. Their stored references are never cleared; state later becomes closed, and subsequent close returns immediately. Snapshot lines 907-913 continue counting those references and the reserved registry. This violates AC 2 and AC 5 deterministic teardown and baseline restoration.

Required rework: make teardown completion reconcile cooperative reserved races before exposing completion, retain genuinely non-cooperative work visibly until it retires, and guarantee automatic-task references clear even when socket close exhausts the deadline. Add a connected-session regression with active automatic tasks and a cancellation-ignoring socket close that consumes the close deadline; prove bounded close, exact-once socket close, safe late completion, repeated close safety, and eventual zero ownership. Stabilize the existing full-suite lifecycle tests.

## Independent validation

- swift test --filter saturatedOrdinaryOperationsCannotSkipSocketClose: exit 0 — 1 test / 1 suite.
- swift test --filter LibSSH2: exit 1 — 40 tests / 3 suites; nonCooperativeUploadSourceTimeout failed at LibSSH2AdapterIntegrationTests.swift:512. The same test reran alone with exit 0, showing order/concurrency sensitivity rather than a stable green gate.
- make validate-core: exit 2 — 374 tests / 31 suites; repeatedHandshakeCleanup iteration 1 observed automaticTasks = 1 rather than 0 at LibSSH2BridgeTests.swift:211.
- make validate-libssh2: exit 0.
- make test-libssh2-source-gates: exit 0.
- make native-apple-matrix: exit 0 — arm64/x86_64 macOS provider and harness release targets built and linked.
- swift-format lint --recursive --strict Package.swift Sources Tests: exit 0.
- swift build: exit 0.
- git diff --check: exit 0.
- task-board validate: exit 0 with the known STORY-260715-lkshfz aggregate mismatch while this task is reviewing.
- Attachment SHA-256 values match: contract 207b5834794202a5a3c051b248b80ddeaab0888399a9e39dd4b65274c57bddf7; inputs fec044ef6b854a21318027399eaaa59e6862a653be8106d2c644141cbbed488c.

Reviewer scratch evidence: .temp/TASK-260715-1ozsb6/reviewer-validation-09.md