# TASK-260715-3cv3r4 rework-02 outcome

## Result

Ready for independent review. The remaining review-02 lifecycle-accounting finding is closed without changing the accepted product seams or the fake-only/no-network boundary.

## Rework-02 closure

- `FixtureLifecycleRegistry` is independently owned and shared by every transport across all 16 bounded repetitions. Its monotonically issued concrete tokens make prior-iteration leaks remain visible.
- Task, connection, and observer lifetime starts register tokens. Host-policy, credential-provider, and authentication/sign callbacks each use balanced callback-token scopes on return and throw.
- Cleanup releases tokens; it never assigns lifecycle counters to zero. Double release records a Swift Testing issue.
- A deterministic gated host-policy operation observes one live task, connection, observer, and callback. The same registry returns to its original zero baseline after success, every seven rejecting `SSHHostKeyDecision` cases, an injected thrown policy, and cancellation.
- Accepted paths retain connection/observer tokens until explicit close. Rejected, thrown, and cancelled paths reach neither credential lookup nor authentication/channel work and release all registered resources.
- Previously accepted coverage remains intact: all nine host decisions traverse the candidate-neutral transport seam; fixture Keychain queries cannot reach the live matcher; invalid profiles stop at the real `TunnelRuntimeCoordinator` boundary; redaction scans remain clean.

## Test matrix

| Command | Exit | Result |
| --- | ---: | --- |
| `swift test --filter SSHContractSeamFixtureTests` (initial compile) | 1 | Missing explicit `return` in the new async snapshot; corrected immediately. |
| `swift test --filter SSHContractSeamFixtureTests` | 0 | 3 tests passed, including 16 bounded shared-registry iterations. |
| `swift test --enable-code-coverage --filter '(SSHProfileSnapshotLoaderTests|MacOSSystemKeychainCredentialResolverTests|ApprovedHostIdentityPolicyTests|SSHBootstrapErrorMappingTests|SSHContractSeamFixtureTests|TunnelRuntimeCoordinatorTests.invalidProfilesStopBeforeDownstreamBoundaries)'` | 0 | 53 tests in 6 suites passed. |
| Three `--skip-build` repetitions each of `MacOSSystemKeychainCredentialResolverTests`, `SSHContractSeamFixtureTests`, and `SSHBootstrapErrorMappingTests` | 0 | 9/9 invocations passed. |
| `xcrun llvm-cov report ...` for five affected production files | 0 | 87.75% lines; 87.04% functions. |
| `swift format lint --recursive Sources Tests Package.swift` | 0 | Clean. |
| `./scripts/check-core-boundaries.sh` | 0 | Valid. |
| `git diff --check` | 0 | Clean. |
| Captured-log prohibited-data, test live-Security, public fixture seam, test live-network, and self-reset-counter scans | 0 | Wrapper verified underlying `rg` exit 1/no matches for every prohibited pattern. |
| Production Security API inventory | 0 | Only injected/default `SecItemCopyMatching` references and the private system-domain resolver remain. |
| `task-board validate` | 0 | Reports one dependency-gated parent aggregate anomaly: `STORY-260715-2wjwuf` remains `to-dev` while this child is `development`. Direct parent promotion returned `ok:false` because unfinished blocker `STORY-260715-1y04r0` gates it. |

## Coverage

| Scope | Line coverage | Function coverage |
| --- | ---: | ---: |
| Five affected production files | 87.75% | 87.04% |
| `SSHProfileSnapshot.swift` | 90.94% | 92.08% |
| `ApprovedHostIdentityPolicy.swift` | 85.14% | 70.73% |
| `SSHBootstrapDiagnostics.swift` | 86.13% | 88.57% |
| `MacOSSystemKeychainCredentialResolver.swift` | 85.33% | 88.06% |
| `MacOSSSHBootstrapErrorMapper.swift` | 86.52% | 100.00% |

## Evidence logs

- `.temp/TASK-260715-3cv3r4/rework-02-transport-tests-01.log` (expected corrected compile failure)
- `.temp/TASK-260715-3cv3r4/rework-02-transport-tests-02.log`
- `.temp/TASK-260715-3cv3r4/rework-02-focused-coverage-01.log`
- `.temp/TASK-260715-3cv3r4/rework-02-repeated-cleanup-redaction-01.log`
- `.temp/TASK-260715-3cv3r4/rework-02-coverage-report-01.log`
- `.temp/TASK-260715-3cv3r4/rework-02-format-lint-01.log`
- `.temp/TASK-260715-3cv3r4/rework-02-core-boundaries-01.log`
- `.temp/TASK-260715-3cv3r4/rework-02-diff-check-final.log`
- `.temp/TASK-260715-3cv3r4/rework-02-prohibited-live-scans-01.log`
- `.temp/TASK-260715-3cv3r4/rework-02-production-security-inventory.log`
- `.temp/TASK-260715-3cv3r4/rework-02-task-board-validate-03.log`
- `.temp/TASK-260715-3cv3r4/rework-02-parent-status-fix-01.log`

## Safety and residual risk

No real Keychain, SSH/network, NetworkExtension provider, VPN configuration, route, DNS, interface, or packet-filter operation ran. Repository-wide and opt-in SSH integration tests were intentionally not run because the binding task brief prohibits network activity; the focused SwiftPM matrix builds the shared test bundle and exercises all task-owned behavior.
