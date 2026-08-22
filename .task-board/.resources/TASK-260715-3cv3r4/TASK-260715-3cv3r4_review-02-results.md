# TASK-260715-3cv3r4 independent review 02 outcome

## Verdict

Changes requested. Rework findings 1, 3, and 4 are closed, and all focused safe gates pass. Rework finding 2 remains material because connection/observer/callback cleanup accounting is self-fulfilling rather than an independent retained-resource measurement, so acceptance criterion 5 is not evidenced.

## Material finding

1. `Tests/ReluxTunnelCoreTests/SSHTransportContractTests.swift:1260-1263` stores lifecycle counts as local integer fields on each newly created `FixtureTransport`. `connect` assigns task/connection/observer counts directly at lines 1292-1294, and the catch block force-resets every count at lines 1353-1357. There is no observer registration/token or independently owned connection/callback registry; the observer count represents no concrete fixture resource. The repeated test at lines 682-757 creates fresh transports and compares each transport's own counters to a literal zero baseline, so retained objects from prior iterations cannot accumulate into the measured baseline. This makes the cleanup assertion pass by construction and does not satisfy the review-02 requirement to reject self-fulfilling counters.

Required correction: measure lifecycle state in one independently owned fixture registry shared across all bounded iterations. Register concrete connection and observer tokens when their fixture lifetimes begin, scope actual callback registrations with balanced teardown (including thrown/cancelled paths), and have the registry—not `FixtureTransport.catch`—report the stable baseline. Prove observable non-zero transitions during gated cancellation and restoration after success, every rejection class, and cancellation without resetting registry counts as cleanup compensation. Update the LOGBOOK verification claim accordingly.

## Closed rework checks

- All nine production `SSHHostKeyDecision` cases are enumerated and traversed through `FixtureTransport`. Both accepted cases record `hostPolicy -> credentialLookup -> authentication`; all seven rejected cases record only `hostPolicy`, with zero authentication and channel/open requests.
- `MacOSSystemKeychainHandle.init(fixtureIdentity:)`, the handle type, `ItemMatcher`, and matcher injection are non-public. `LiveMacOSSystemKeychainSecurityClient.copyMatching` rejects a fixture handle before its injected matcher; the spy test observes zero calls. Production live queries retain one exact search-list item and `kSecMatchLimitOne`, with no fallback or enumeration.
- Invalid generation, noncanonical host, unsupported schema, and prohibited secret fields traverse the real `TunnelRuntimeCoordinator` startup sequence through the injected `ConfigurationSnapshotSource`. Loading fails before the injected `SSHBootstrap`; because that product boundary owns downstream credential/network work, both remain untouched. The valid control reaches bootstrap and cleanup. The test-local adapter is composition around the real coordinator, not a replacement for its ordering.
- No public fixture/live-network surface or test-source live Security API was found. No real Keychain, network, provider, VPN, route, DNS, interface, or packet-filter operation ran.

## Independent validation matrix

| Command | Exit | Result |
| --- | ---: | --- |
| `swift test --enable-code-coverage --filter '(SSHProfileSnapshotLoaderTests|MacOSSystemKeychainCredentialResolverTests|ApprovedHostIdentityPolicyTests|SSHBootstrapErrorMappingTests|SSHContractSeamFixtureTests|TunnelRuntimeCoordinatorTests.invalidProfilesStopBeforeDownstreamBoundaries)'` | 0 | 53 tests in 6 suites passed (final rerun also exit 0) |
| Three repetitions each of `MacOSSystemKeychainCredentialResolverTests`, `SSHContractSeamFixtureTests`, and `SSHBootstrapErrorMappingTests` | 0 | 9/9 invocations passed |
| `xcrun llvm-cov report ...` for five affected production files | 0 | 87.75% lines; 87.04% functions |
| Initial `xcrun llvm-cov report ...` after non-coverage rebuild | 1 | Expected stale-profile mismatch; regenerated coverage and final report passed |
| `swift format lint --recursive Sources Tests Package.swift` | 0 | Clean |
| `./scripts/check-core-boundaries.sh` | 0 | Valid |
| `git diff --check` | 0 | Clean |
| Captured-log prohibited-data scan | 0 | Wrapper confirms underlying `rg` exit 1/no matches |
| Test-source live-Security API scan | 0 | Wrapper confirms underlying `rg` exit 1/no matches |
| Public fixture/matcher surface scan | 0 | Wrapper confirms underlying `rg` exit 1/no matches |
| Production Security API inventory | 0 | Only injected/default `SecItemCopyMatching` references and private system-domain resolver remain |

Affected-file coverage: `SSHProfileSnapshot.swift` 90.94% lines, `ApprovedHostIdentityPolicy.swift` 85.14%, `SSHBootstrapDiagnostics.swift` 86.13%, `MacOSSystemKeychainCredentialResolver.swift` 85.33%, and `MacOSSSHBootstrapErrorMapper.swift` 86.52%.

## Evidence logs

- `.temp/TASK-260715-3cv3r4/review-02-focused-coverage-final.log`
- `.temp/TASK-260715-3cv3r4/review-02-repeated-cleanup-redaction.log`
- `.temp/TASK-260715-3cv3r4/review-02-coverage-report-final.log`
- `.temp/TASK-260715-3cv3r4/review-02-format-lint.log`
- `.temp/TASK-260715-3cv3r4/review-02-core-boundaries.log`
- `.temp/TASK-260715-3cv3r4/review-02-diff-check.log`
- `.temp/TASK-260715-3cv3r4/review-02-prohibited-data-scan.log`
- `.temp/TASK-260715-3cv3r4/review-02-live-security-test-scan.log`
- `.temp/TASK-260715-3cv3r4/review-02-public-seam-scan.log`
- `.temp/TASK-260715-3cv3r4/review-02-production-security-scan.log`

## Residual scope

Repository-wide tests and opt-in loopback/real-host SSH integration were intentionally not run because the binding brief prohibits network activity. The focused SwiftPM build compiles the shared test bundle and covers the task-owned behavior.
