# TASK-260715-2d3g5e tester handoff

## Result

Ready for review. The named parameterized Swift Testing suite runs the same M0, M3-deferred, and cancellation inventory with candidate selection as data.

- libssh2 production adapter: all 9 M0 gate rows, all 15 cancellation/timeout rows, and all four explicit deferred-state semantics pass.
- ReluxNIOSSH: 25 explicit unavailable/red known-issue rows because the repository has no production `SSHTransport` adapter target. This matches the 2026-08-18 owner-approved ADR-014/ADR-027 board realignment forbidding new ReluxNIOSSH adapter/fork work unless libssh2 is invalidated.
- M3 exact-value ownership remains `TASK-260728-3cveay`.

## Rework delivered

- Added a real libssh2/OpenSSH privacy test that injects host, user, endpoint, fingerprint, credential, command, path, stream, and payload sentinels.
- Captured and proved non-empty public error, logger-event, observer-event, metric-update, and snapshot surfaces, then asserted every sentinel is absent from their combined public representation.
- Wired the production privacy test into the common `privacySafeErrors` gate.
- Made channel-open, exec-startup, and keepalive task-baseline assertions wait for actual owned-task registry retirement.
- Made the 64-operation pressure cap deterministic with an injected frozen clock and a non-terminating `cat` channel, preventing timeout or process exit from racing the cap assertion.

## Test inventory

- 3 named parameterized tests expand to 50 candidate cases: 18 M0, 2 M3-deferred, and 30 cancellation cases.
- M0 inventory: Apple integration/injection; approved algorithms and host-before-auth; direct/exec/upload/isolation; bounded buffers/backpressure/windows; client and server rekey; keepalive scheduling/failure; lifecycle baselines; privacy-safe errors; mandatory metrics.
- Deferred inventory: receive credit, RFC open reasons, exact exec exit metadata, and deep rekey/keepalive observability.
- Cancellation inventory: resolution, connect, initial KEX, host decision, credential lookup, authentication, channel open, read, write, EOF, exec, upload, rekey, keepalive, and close.

## Final verification

- `swift test --filter productionPublicDiagnosticsExcludePrivacySentinels`: exit 0; 1 test passed.
- `swift test --filter channelOpenCancellationRestoresBaseline` repeated 3 times: exit 0 each time.
- `swift test --filter channelOperationPressureIsBounded` repeated 3 times: exit 0 each time.
- `swift test --filter SSHTransportConformanceTests`: exit 0; 50 cases, 25 explicit ReluxNIOSSH known issues.
- `swift test --enable-code-coverage`: exit 0; 442 tests in 37 suites, 25 explicit ReluxNIOSSH known issues.
- Fresh reset-on-any-failure `swift test --skip-build` streak: 20/20 consecutive unfiltered runs exited 0; each passed 442 tests in 37 suites with only the 25 explicit ReluxNIOSSH known issues, including historical failure positions 13 and 17.
- Affected adapter coverage (`LibSSH2Bridge.swift`, `LibSSH2Channels.swift`, `LibSSH2Transport.swift`): 83.36% regions, 94.61% functions, 92.14% lines.
- `swift format lint --recursive Sources Tests Package.swift`: exit 0.
- `./scripts/check-core-boundaries.sh`: exit 0.
- `git diff --check`: exit 0.

## Findings

- Immediate task-count snapshots raced cleanup task retirement even after operation completion; the corrected tests synchronize on the owned-operation registry before comparing baselines.
- The former `sleep 30` pressure fixture allowed the 10-second exec-exit deadline to reset the channel before the 65th cap assertion. A frozen clock plus `cat` makes admission pressure the only terminating condition.
- The privacy gate initially used the short local username as a sentinel, which collided with ordinary reflected type text. A unique rejected-auth username now exercises the user privacy path without false positives.
- An earlier output-suppressed aggregate streak reset at run 8 with exit 1 but did not retain the failing assertion; the immediate unsuppressed rerun passed, and the subsequent failure-line-capturing 20-run streak completed without a reset.
