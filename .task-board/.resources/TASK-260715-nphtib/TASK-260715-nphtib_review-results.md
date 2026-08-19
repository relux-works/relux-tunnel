# TASK-260715-nphtib — independent reviewer results

## Verdict

CHANGES REQUESTED at revision `7dc73ac6e7325f86a4a178a0558619f0fc9d1490`. Architecture, generation, build, linkage, relay, legacy, lint, coverage, and safety gates pass. Deterministic Swift Testing is not proved because the same revision has a real recorded warm-cache `swift test` failure in `HarnessTests.cancellationCleanup`, the scheduler-count polling implementation is unchanged, and BUG-260819-34ikhl has no completed rework.

## Independent clean environment

- Fresh local source clone: `git clone --quiet --local --no-hardlinks <source> <review-root>/repo`; detached checkout at the authoritative revision; exit 0.
- Fresh legacy clone: `git clone --quiet --local --no-hardlinks <legacy-source> <review-root>/legacy-v0.1.0`; detached checkout `2557aba1c030d0643d76e0bc3b185f6d5fd172e1`; exit 0.
- Source was clean before and after applicable gates. Public environment: macOS 26.5 arm64; Xcode 26.5 build 17F42; macOS SDK 26.5; Swift 6.3.2; Mise 2026.2.0; Tuist 4.202.5; Go 1.26.5; Syft 1.48.0.
- Privacy: `<source>`, `<legacy-source>`, and `<review-root>` replace local paths. No credentials, environment dump, unrelated filename, or secret material is attached.

## Result matrix

| Gate | Exact command | Exit | Duration/result |
| --- | --- | ---: | --- |
| Full repository entrypoint | `make credential-free-validate LEGACY_ROOT=<review-root>/legacy-v0.1.0` | 0 | 417.04s; all 15 applicable rows PASS |
| Strict Swift formatting | `git ls-files *.swift :!.task-board/** \| xargs swift format lint --strict --parallel` | 0 | 2.72s |
| Coverage suite | `swift test --enable-code-coverage` | 0 | 75.64s; 443 tests, 37 suites, 25 accepted known issues |
| Product Sources coverage | `jq` aggregation over Swift codecov JSON | 0 | lines 19,481/21,655 = 89.96%; functions 2,322/2,591 = 89.62%; regions 6,573/7,998 = 82.18% |
| Targeted flaky-test stress | 50 sequential `swift test --filter cancellationCleanup` invocations | 0 | 50/50 pass in 75s |
| Second deterministic generation | `./scripts/validate-workspace-foundation.sh` | 0 | 11.46s; manifests identical |
| Generation manifest compare | `diff -u generation-01.sha256 generation-02.sha256` | 0 | both SHA-256 `d5c5fd2899750f5b9e90de096e2b0552df22384a5ecbea793c0f19df630b7fc6` |
| Exact graph enumeration | `xcodebuild -workspace ReluxTunnel.xcworkspace -list -json` and project list | 0 | six workspace schemes; four application targets; Debug/Release only; deferred iOS absent |
| Actual Release provider graph | `scripts/check-generated-provider-graph.py` with generated PBX project and nested Release provider bundle | 0 | graph and relay resource contract PASS |
| Release provider inspection | `lipo`, `nm`, `otool -L`, PlistBuddy, and nested-bundle count | 0 | x86_64+arm64; one nested extension; adapter/HEV/libssh2 symbols present; fixture/loader symbols absent; system-only dylibs |
| Actual nested relay checksums | `shasum -a 256 -c relux-relay-SHA256SUMS` in the nested Release resource | 0 | notice, four executables, four SBOMs, and manifest all OK |
| Staged relay verifier | `scripts/relay_release.py verify ... --output .build/relay/apple-bundle-input` | 0 | PASS |
| Focused architecture DOT | `dot -Tdot diagrams/TASK-260715-32umrc_target-dependency-plan.dot -o /dev/null` | 0 | parses; consumer-to-dependency direction matches ADR |
| Board validation, clean clone and working board | `task-board validate` | 0 / 0 | no issues |

The producer outcome `TASK-260715-nphtib_results.md` retains exact per-row commands and durations for the accepted clean producer matrix; this reviewer independently reran the full entrypoint and the gates above.

## Architecture and artifact findings

Workspace schemes are exactly `relux-relay`, `relux-relay-protocol-test`, `ReluxProxyMac`, `ReluxProxyMacTunnel`, `ReluxTunnelCore`, and `ReluxTunnelHarness`. Generated application targets are exactly `ReluxProxyMac`, `ReluxProxyMacTests`, `ReluxProxyMacTunnel`, and `ReluxProxyMacTunnelTests`; configurations are exactly Debug and Release. All four deferred iOS target names are absent.

The provider directly consumes `ReluxTunnelMacOSAdapter` and verified relay resources. Its universal Release binary contains macOS-adapter, HEV, and libssh2 production symbols; contains no `CReluxNativeFixture`, `relux_native_fixture`, or forbidden dynamic-loader symbol; and dynamically links only system frameworks/libraries. Bundle IDs, exactly-one embedding, no `_CodeSignature`, and no local signing overlay all match the credential-free ADR lane. Relay checksums and the provider-graph verifier pass against the actual nested bundle.

One reviewer-authored `otool` filter initially exited 92 because it treated the fat-binary architecture header as a dependency. A corrected path-only filter exited 0 and proved system-only linkage. A direct `relay_release.py verify` attempt on the nested bundle printed its intended `output paths must remain under .build/relay` refusal; the supported staged verifier then exited 0, while the actual nested bundle was independently covered by checksum verification and `check-generated-provider-graph.py` exit 0. These are reviewer diagnostic-command corrections, not product failures.

## Deterministic-test rejection

Prior same-revision evidence records `swift test` exit 1 after 75.684s: `HarnessTests.cancellationCleanup` threw `TimedOut()` at `HarnessTests.swift:140`. The authoritative clean matrix, this review coverage suite, and 50 targeted repeats pass, but the failing revision still implements `waitUntil` as only 10,000 scheduler yields. No code change eliminates or bounds the demonstrated scheduling race, and BUG-260819-34ikhl remains backlog with all rework checklist items false. Passing samples cannot establish determinism after an actual unchanged-revision failure.

Required rework is concrete: complete BUG-260819-34ikhl by reproducing under repetition/load, replacing the scheduler-count wait without weakening resource-cleanup assertions, and attaching repeated clean full-suite plus coverage evidence. Then rerun this complete matrix from a fresh clone.

## Build-host safety

No production signing, app/system-extension installation, app/provider launch, NetworkExtension preference save, VPN start/stop, route mutation, or DNS mutation was invoked. Physical Gate P0, notarization, DMG, and deferred iOS were NOT RUN by scope. The harness smoke remains a local no-op resource-lifecycle test and does not activate a VPN.