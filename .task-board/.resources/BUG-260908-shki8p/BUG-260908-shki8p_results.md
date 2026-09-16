# BUG-260908-shki8p source candidate

Ready for independent source review; NOT delivered and NOT hosted-green.
Base: b3422b05226253a17676b9b84c764071fe3dbe74. Changes remain uncommitted on the managed Story branch, as required. Parent owns signed composition, PR publication, exact-head review, hosted checks and landing.

## Proven cause and repair

Original failure remains run 34167625590 / job 101881722247, exit 65. Diagnostic propagation exposed the compiler failure in run 34172537905 / job 101895476744 at PR6 head 018c9d9672767fd02f42fb4ab4f2dfe3800646b8. Inspected the actual downloaded build log at control-root .temp/deadline-20260908/ci-generated-artifact-02/logs/macos-targets/credential-free-reluxproxymac-debug-build.log, lines 701 onward. ReluxProxyMac Debug generic macOS build, ReluxTunnelCore target; Xcode 16.4 and Swift 6.1.2 (confirmed downloaded environment.log line 6). Error at TunnelRuntimeCoordinator.swift:687:24: non-sendable result type T cannot be sent from nonisolated context in call to parameter operation. Compiler note at line 681 explicitly requests T: Sendable. Repeated architecture invocations are the same defect.

Changed only mapped<T> to mapped<T: Sendable>. All five existing result contracts satisfy it: RuntimeConfigurationSnapshot explicitly conforms, and SSHBootstrapSession, TCPConsumer, DNSConsumer and M1PacketPlaneSession inherit Sendable through TunnelRuntimeHealthProviding. No isolation suppression, unchecked conformance, toolchain change, cancellation logic change, or VPN activity.

Expanded existing Swift Testing callerCancellation(point:) from DNS-only to all five mapped acquisitions. Existing orderedStartupAndStop drives successful returns and resource usage; partialStartRollback exercises failure mapping. Production path: TunnelRuntimeCoordinator.start -> runStartup -> mapped -> map, followed by cancellation classification and cleanup.

## Coverage and bounds

1 of 5 AC rows driven by named tests through production (source candidate; tests are not yet committed because managed producer commits are forbidden):
1. Diagnose real hosted source/target/toolchain/error: artifact evidence above, not a unit-test claim.
2. Repair with positive/negative tests: orderedStartupAndStop, partialStartRollback(point:), callerCancellation(point:), cancellationRollback(point:), production start -> runStartup -> mapped/map. All 5 of 5 mapped acquisition call sites driven by cancellation cases: configurationSource.loadValidatedSnapshot, sshBootstrap.authenticate, tcpFactory.prepare, dnsFactory.prepareSafeDNS, packetPlaneFactory.prepare.
3. Publish independently reviewed signed fix: pending parent delivery, no claim.
4. Previously failing hosted job and all required PR checks green on exact signed head: pending parent delivery, no claim. Local Swift 6.3.2 accepts the original source, so a local pass does not establish Swift 6.1 compatibility. Existing hosted generated-project build is the required minimum-toolchain compile regression check.
5. Preserve initial failures and uncertainty: original artifacts unchanged; this resource records diagnostic provenance and remaining uncertainty. Not a unit-test claim.

No new runtime gate or source-text inspection gate was introduced. Negative cancellation guarantee was additionally attacked with a narrowing mutant: in production map, change `if error is CancellationError` to `if error is CancellationError, fallback.domain != .configuration`. Gate remains active for all other stages and retains the CancellationError token. Running the behavioral suite `swift test --filter TunnelRuntimeCoordinatorTests/callerCancellation` exits 1: duringConfiguration receives startupFailed(configuration_invalid) instead of CancellationError and reaches the wrong terminal state. The other four mapped cases pass. Restored the exact pre-mutant file from a copy and verified cmp exit 0. Mutant source is not in candidate.

## Commands rerun in this worker

Local Xcode 26.5 / Swift 6.3.2, arm64 macOS. This is the requested failing platform, despite the package also supporting iOS.
- Baseline `swift test --filter TunnelRuntimeCoordinatorTests`: exit 0, 22 tests.
- First ad hoc typecheck with incomplete source globs: exit 1, omitted generated nested RelayProtocolV1 source. Replaced with recursive rg enumeration; this is a probe failure, not a product error.
- Baseline and fixed `swiftc -typecheck -swift-version 6 -module-name ReluxTunnelCore $(rg --files Sources/ReluxTunnelCore -g '*.swift')`: both exit 0. Local newer compiler cannot reproduce old diagnostic.
- Fixed `swift test --filter TunnelRuntimeCoordinatorTests`: exit 0, 22 tests including five cancellation cases.
- Narrowing mutant behavioral run above: exit 1 as required, two assertions fail for configuration cancellation.
- After restoration `swift test --filter ReluxTunnelCoreTests`: exit 0, 357 tests in 31 suites.
- `swift format lint --strict Sources/ReluxTunnelCore/TunnelRuntimeCoordinator.swift Tests/ReluxTunnelCoreTests/TunnelRuntimeCoordinatorTests.swift`: exit 0, before and after mutant restoration.
- `git diff --check`: exit 0.

Logs are retained in the Story worktree .temp/BUG-260908-shki8p and attached with task-scoped resource names. Source delta is exactly two files (generic constraint and expanded cancellation test). No local generated-app xcodebuild or new hosted run was executed by this worker. Earlier hosted diagnostic provenance is accepted from the supplied parent evidence and directly checked against the downloaded compiler/environment logs; no previous green evidence is substituted for the outstanding hosted gate.

## Delivery gate

Checklist row 1 remains unchecked because it explicitly requires real hosted green before completion. Independent source candidate review must precede publication. Do not convert this source handoff into accepted completion or waive the hosted requirement. If task-board handoff refuses the unchecked delivery row, parent must resolve the source-review versus delivery-checklist lifecycle conflict without falsely checking it.

## Actual handoff result

`task-board handoff BUG-260908-shki8p --role developer` exited 1: `cannot hand off BUG-260908-shki8p: unchecked checklist items [1] (...) : handoff evidence missing`. Checklist items 2–11 are checked against source evidence / explicitly stated bounds; item 1 remains unchecked. Status stays development; no CR was published by this attempt. This is a concrete lifecycle conflict: source review must precede publication, while the producer handoff requires the post-publication hosted gate. Parent must route source review/delivery using the supported board lifecycle; do not falsify the hosted checklist or mark this task complete. Source is ready for review, but the role handoff was refused.

Artifact upload note: attaching the empty successful lint log was refused with `content or path is required`; the strict lint command exit 0 is recorded here instead. Other listed test, mutant, compiler excerpt and readiness logs were attached successfully. Initial malformed resource syntax and two unknown schema probes were corrected using the documented task-board API; no board files were edited directly.
