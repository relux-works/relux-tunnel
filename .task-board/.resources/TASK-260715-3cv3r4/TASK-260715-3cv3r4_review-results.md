# TASK-260715-3cv3r4 independent review outcome

## Verdict

Changes requested. The implementation is fake-only and the focused gates pass, but acceptance criteria 3 and 5 plus required adversarial seam evidence are incomplete.

## Material findings

1. Pre-auth ordering is not covered on every rejected outcome. Tests/ReluxTunnelCoreTests/SSHTransportContractTests.swift:711-725 injects only ChangedHostPolicy. The other rejecting decisions defined in Sources/ReluxTunnelCore/SSHContracts.swift:398-404 — trustRequired, rejectRevoked, rejectAlgorithm, rejectHostMismatch, rejectMalformed, and rejectPolicy — are unit-tested as decisions but are not driven through the transport seam to prove zero credential lookup, signing/authentication, and channel calls for each path. Add a table-driven transport test for every accepted and rejected decision.
2. The bounded repetition test does not measure all required retained resources. ConformanceResourceSnapshot at Tests/ReluxTunnelCoreTests/SSHTransportContractTests.swift:893-899 contains only tasks, channels, sockets, descriptors, and bufferedBytes. It has no connection, observer, or callback counts, while AC5 and the execution brief explicitly require no retained connection, observer, or callback growth. Add deterministic counters/registries and compare one baseline across bounded repetitions, including cancellation/rejection cleanup.
3. The inert fixture handle is structurally guarded but lacks the required behavioral regression. Sources/ReluxTunnelMacOSAdapter/MacOSSystemKeychainCredentialResolver.swift:279-283 guards fixture handles before SecItemCopyMatching, and the fixture initializer is internal rather than public. However, no test passes a synthetic query through LiveMacOSSystemKeychainSecurityClient and proves the live matcher is never invoked. Add an injectable matcher or equivalent spy-backed seam and assert zero live Security API calls; retain exact one-item query isolation and no fallback/enumeration.
4. The invalid-profile downstream proof at Tests/ReluxTunnelCoreTests/SSHProfileSnapshotLoaderTests.swift:300-329 uses a test-local captureThenAccess helper whose only behavior is to call counters after decode. It does not exercise an existing product/SPM composition boundary with injected Keychain and network fakes. Replace or supplement it with the narrow real orchestration seam so every invalid profile class stops before both injected dependencies.

## Independent safe validation

| Command | Exit | Result |
| --- | ---: | --- |
| swift test --enable-code-coverage --filter focused-five-suite-regex | 0 | 51 tests in 5 suites passed |
| Three repetitions each of MacOSSystemKeychainCredentialResolverTests, SSHContractSeamFixtureTests, and SSHBootstrapErrorMappingTests | 0 | 9 of 9 invocations passed |
| xcrun llvm-cov report | 0 | Affected line coverage: 83.18% to 90.94% |
| swift format lint --recursive Sources Tests Package.swift | 0 | Clean |
| ./scripts/check-core-boundaries.sh | 0 | Valid |
| git diff --check | 0 | Clean |
| rg live Security APIs in Keychain test source | 1 | Expected: no matches |
| rg prohibited sentinels in captured review logs | 1 | Expected: no matches |

Review logs are under .temp/TASK-260715-3cv3r4-review/. No real Keychain, network connection, NetworkExtension runtime, VPN, route, DNS, interface, or packet-filter operation was run.

## Required rework

Add the missing table-driven ordering paths, retained connection/observer/callback measurements, spy-backed live-client rejection proof, and product-boundary invalid-profile test. Re-run the same focused coverage, repeated cleanup/redaction matrix, format, boundary, diff, and prohibited-data scans.