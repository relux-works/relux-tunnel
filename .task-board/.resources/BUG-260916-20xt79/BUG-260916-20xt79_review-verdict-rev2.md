# Independent review: ACCEPT CR-BUG-260916-20xt79-2 revision 2

Reviewer run RUN-260916-a0c567. No blocking source findings. Acceptance authorizes composition only; it does not establish hosted compatibility or approve a future signed commit.

## Identity and scope

Base b3422b05226253a17676b9b84c764071fe3dbe74; candidate tree 3568b4ac4bd92974d7cfc29575a1375ee90b3703. Patch SHA-256 ed833a297ee91ca234d54db0c07471db5f3e758678a5d267ab65259873168142 independently verified. All three working paths equal the candidate; HEAD remains the base. The fixture blob is identical to accepted shki8p rev2 tree aa1d81492840c92a285bafcf4306f5c291c017ca. Reviewed that verdict and the authorized prerequisite boundary. No product edits, commits, managed-ref changes, publication, VPN, route changes, installations, or LOGBOOK writes performed.

## Assessment and bounds

The compiler conditional omits only the unavailable enum case on Swift 6.1 and preserves the current-SDK unavailable/retryableLater classification. POSIX, DNS, TLS and unknown-default arms are unchanged. Associated platform values are discarded, with context and generation retained. Runtime availability would not solve a missing SDK declaration. The compiler version is a proxy for matched Apple toolchain/SDK pairs, not an SDK capability test: Swift >=6.2 with an older SDK still fails. This documented mix is outside the declared matched pairs and is acceptable for this narrow repair. Xcode 16.4/Swift 6.1/macOS SDK 15.5 remains unexecuted here. Forced compiler-guard simulation is not real Swift 6.1 proof.

Coverage: **2 of 5 AC rows driven by named candidate tests**, with explicit bounds below (process artifacts are not executable-test coverage):
1. Older SDK compilation: bound; actual hosted Xcode 16.4 build still required.
2. Current mapping: wifiAwareBootstrapProjection calls MacOSSSHBootstrapErrorMapper.network; checks retry, category, context, generation and absence of the raw code in JSON.
3. Existing mappings: networkFrameworkBootstrapProjection calls the same production entry with POSIX/DNS/TLS; SSHBootstrapErrorMappingTests covers taxonomy and hostile redaction. Unknown-default arm is unchanged but not directly stimulated; TLS exercises the same unexpected cause, not the unknown enum arm itself.
4. Focused checks and environment distinction: command evidence below, not a test of process compliance.
5. Independent acceptance before composition: this verdict/accept_cr, not a unit test.
Tests are in the immutable candidate and intentionally uncommitted per managed handoff policy; no nonexistent test commit is claimed.

No new authorization/refusal/source-text gate is introduced by the classifier. Reused producer rev2 behavioral sensitivity evidence: changing only wifiAware unavailable to unexpected caused the named wifiAware test to fail on terminal versus retryableLater, exit 1; restored candidate passes. This is classification sensitivity, not a claim of a new gate narrowing proof. Unchanged scheme checker is independently exercised by the fixture contract: valid list passes; missing ReluxProxyMac, extra UnexpectedScheme, and combined missing/extra lists must fail through scripts/check-workspace-schemes.sh. Its exact-set gate is unchanged; no newly shipped gate or source-text gate requires new mutation coverage in this delta.

## Verification personally rerun

- swift test --filter 'MacOSSystemKeychainCredentialResolverTests|SSHBootstrapErrorMappingTests': exit 0, 28 tests / 2 suites, including wifiAware and hostile-redaction tests.
- swift-format lint --strict on both changed Swift files: exit 0.
- bash scripts/tests/test-credential-free-validation.sh: exit 0; runs the three negative cases described above.
- git diff --check base candidate: exit 0.
- Candidate/working-file and accepted-prerequisite comparisons: empty diffs, exit 0.

Local Apple Swift 6.3.2 (swiftlang-6.3.2.1.108), Xcode 26.5 build 17F42, explicitly resolved macOS SDK 26.5 at /Applications/Xcode_26_5.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.5.sdk. Initial unqualified xcrun --show-sdk-version failed resolving a stale CommandLineTools SDK path; explicit xcrun --sdk macosx --show-sdk-version succeeded with 26.5. No configuration changed to conceal this failure.

Reused, not rerun: exact rev2 managed validation log (final [exit 0], one of one command shards green); its Swift test log reports 495 tests / 40 suites with 25 known issues. Full gate was not run a third time. Producer mutation, old-SDK diagnosis and forced-guard simulation are accepted as explicitly bounded prior evidence, not personally rerun results. Existing hosted failure remains preserved; no hosted green is claimed.

## Prospective PR6 composition

Fresh git fetch origin refs/pull/6/head returned a46e2ba351a81e42f2907805b4cda2c313af7bd1. Applied only mapper/test patch via a scratch Git index: check and application exit 0. Resulting prospective tree **b383baa86274d4ace8294b6a0f9ec1d45ddc6198**. Exactly two changed paths versus fetched PR6, +32/-7; both resulting blobs equal the reviewed candidate. Every other PR tree entry is preserved, including the fixture and its test_macos_build_diagnostics.py / test_macos_build_diagnostic_mutants.py calls. Do not copy the old-base fixture onto PR6.

This is tree review only. Parent must reverify current PR input, compose via the authorized producer, and require real hosted Xcode 16.4 CI plus actual platform review of the exact signed composed head before landing.

Reviewer checklist accepted within these stated bounds. Rejection-routing row is not applicable because verdict is acceptance. Route via accept_cr to integrating, never done here. Worktree .build (1.7G) remains preserved; it is regenerable and safely disposable after parent no longer needs validation reuse. Review scratch .temp/review-20xt79 is likewise disposable after attached evidence is retained. Foreign state and control-root LOGBOOK preservation remain untouched.
