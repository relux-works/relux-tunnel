# TASK-260715-1ozsb6 reviewer result — round 6

Verdict: CHANGES REQUESTED. Route to to-dev.

The round-5 socket-failure, keepalive/KEX, bounded-admission, task-join, and channel-pointer fixes are present. Packaging, focused tests, full tests, lint, source gates, and Apple builds are green. AC 2 and AC 5 remain unsatisfied because the generic timeout adapter is not bounded for an injected dependency that ignores task cancellation.

## Blocking finding

`withTimeout` cancels the losing task group at `Sources/ReluxTunnelLibSSH2Adapter/LibSSH2Transport.swift:2291`, then drains every child at line 2292 before returning the already-selected timeout/cancellation result. The helper wraps resolution, TCP connect, host policy, credential lookup, upload, socket progress, and gate waits. In the upload path, `upload` wraps `performUpload` at lines 530-535 and `performUpload` awaits the caller-supplied `SSHUploadSource.read` at line 549. A source or injected connect dependency that ignores cancellation therefore keeps the public operation suspended beyond its configured deadline; concurrent close can also wait for that work instead of completing under `transportClose`, and owned tasks cannot be proven back at baseline.

The existing timeout fixtures do not exercise this condition. `SuspendedUploadSource.read` and `SuspendedResolver.resolve` use cancellation-aware `Task.sleep` (`Tests/ReluxTunnelLibSSH2AdapterTests/LibSSH2AdapterIntegrationTests.swift:1036-1040` and `Tests/ReluxTunnelLibSSH2AdapterTests/LibSSH2BridgeTests.swift:458-462`), so cancellation immediately drains the task group and makes the current tests green.

Required rework: use bounded caller detachment plus explicit owned-task/cancellation lifecycle for every injected async seam, or provide another contract-valid mechanism that guarantees the operation deadline and transport-close deadline without abandoning adapter-owned tasks. Add a deterministic dependency that ignores task cancellation until an explicit release, prove the operation returns at its deadline before release, then prove close/release reconciles the task/resource baseline. Cover upload and at least one pre-session connect seam.

## Reviewer validation

- `swift test --filter LibSSH2AdapterIntegrationTests`: exit 0; 17 tests / 1 suite.
- `swift test --filter LibSSH2`: exit 0; 35 tests / 3 suites.
- `make validate-core`: exit 0; 369 tests / 31 suites plus build and boundary checks.
- `make validate-libssh2`: exit 0.
- `make test-libssh2-source-gates`: exit 0.
- `make native-apple-matrix`: exit 0; arm64/x86_64 macOS provider and harness production targets and linked harness evidence passed.
- `swift format lint --recursive --strict Package.swift Sources Tests`: exit 0.
- `git diff --check`: exit 0.
- `task-board validate`: exit 0 while reporting the existing `PARENT_STATUS_MISMATCH` for `STORY-260715-lkshfz`.

The four M3-deferred semantics remain explicit `unsupported` or `notReported` states traceable to `TASK-260728-3cveay`; they are not the reason for rejection. The named adapter boundary and macOS-only dependency graph fit the project architecture, so no architecture diagram change is required.