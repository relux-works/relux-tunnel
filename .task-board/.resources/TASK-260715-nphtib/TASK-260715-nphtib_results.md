# TASK-260715-nphtib generated-project architecture verification

Date: 2026-08-19 (Asia/Tbilisi)
Role: tester
Overall verdict: **FAIL — recoverable architecture/gate rework required**
Rework: `BUG-260819-8qf0s0`

## Environment and safety

- Source revision: `409b3b4151c9f2f7bac7392595583b3fe971e455`
- Checkout: detached local clone made with `git clone --local --no-hardlinks`; source status was clean before execution.
- Host: macOS 26.5, arm64; Xcode 26.5 (`17F42`); macOS SDK 26.5.
- Swift: 6.3.2; Mise: 2026.2.0; Tuist: 4.202.5; Go: 1.26.5; Syft: 1.48.0; Python: 3.14.4; Git: 2.50.1.
- Deployment inputs: macOS 15.0; deferred iOS input 18.0.
- Legacy input: read-only local checkout containing verified signed tag `v0.1.0` at `2557aba1c030d0643d76e0bc3b185f6d5fd172e1`.
- Safety: no command installed, opened, saved, activated, or started a VPN; no app/system extension was installed or activated. Production signing, physical Gate P0, notarization, and deferred iOS were not run by scope.
- Privacy: evidence uses task-scoped relative paths and public metadata only. A targeted generated-artifact scan found no PEM/private-key material. No unrelated local filename/path is retained here.

## Repository-owned matrix

Exact top-level command (privacy-safe variable notation):

```sh
/usr/bin/time -p make credential-free-validate LEGACY_ROOT="$LEGACY_ROOT"
```

Result: exit `0`; real `316.05 s`, user `324.32 s`, sys `85.43 s`. Per-row durations are APFS log birth-to-last-write measurements rounded to whole seconds.

| Row | Exact command | Duration | Exit/result |
| --- | --- | ---: | --- |
| Relay tool bootstrap | `./scripts/bootstrap-relay-tools.sh` | 25 s | 0 / PASS |
| Validation contract regressions | `./scripts/tests/test-credential-free-validation.sh` | <1 s | 0 / PASS |
| Deterministic double generation | `./scripts/validate-workspace-foundation.sh` | 9 s | 0 / PASS |
| macOS target builds/contracts | `./scripts/validate-macos-targets.sh` | 69 s | 0 / PASS |
| Core boundary guard | `./scripts/check-core-boundaries.sh` | 2 s | 0 / PASS |
| Swift Testing | `swift test` | 69 s | 0 / PASS |
| Swift Release build | `swift build -c release` | 25 s | 0 / PASS |
| Native packaging | `make check-native-dependencies test-native-dependencies` | 5 s | 0 / PASS |
| Relay artifacts/smoke | `env RELAY_VERSION="$MARKETING_VERSION" SOURCE_COMMIT="$SOURCE_REVISION" SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH" make relay-shell-validate` | 62 s | 0 / PASS |
| Detached legacy clone | `git clone --quiet --local --no-hardlinks "$LEGACY_ROOT" "$LEGACY_FIXTURE"` | <1 s | 0 / PASS |
| Pinned legacy checkout | `git -C "$LEGACY_FIXTURE" checkout --quiet 2557aba1c030d0643d76e0bc3b185f6d5fd172e1` | <1 s | 0 / PASS |
| Legacy preservation | `./scripts/check-legacy-preservation.sh --legacy-root "$LEGACY_FIXTURE" --workspace-root "$CLEAN_CLONE"` | 1 s | 0 / PASS |
| Legacy negative guards | `./scripts/tests/test-legacy-preservation-guard.sh --legacy-root "$LEGACY_FIXTURE"` | 7 s | 0 / PASS |
| Legacy Swift tests | `swift test --package-path "$LEGACY_FIXTURE"` | 14 s | 0 / PASS |
| Legacy Release build | `swift build -c release --package-path "$LEGACY_FIXTURE"` | 5 s | 0 / PASS |

Build subrows: `ReluxProxyMac` Debug 17 s, Release 28 s; `ReluxProxyMacTunnel` Debug 1 s, Release 14 s; target-contract tests 6 s. All used `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO`, and a generic/platform macOS destination.

## Independent result matrix

| Requirement | Evidence | Verdict |
| --- | --- | --- |
| Clean isolated revision | Detached no-hardlink clone; clean source status; exact revision above | PASS |
| Deterministic generation | Two clean generations; 11 normalized files each; both hash-list SHA-256 `d2da12f9f1f921237b9ad14a9a397c28cdc30e55cb7189abf25b43f5118619e1`; no tracked drift | PASS |
| Exact workspace schemes | `ReluxProxyMac`, `ReluxProxyMacTunnel`, `ReluxTunnelCore`, `ReluxTunnelHarness`, `relux-relay`, `relux-relay-protocol-test` only | PASS |
| Exact generated Xcode targets/configurations | `ReluxProxyMac`, `ReluxProxyMacTests`, `ReluxProxyMacTunnel`, `ReluxProxyMacTunnelTests`; Debug and Release only; all four deferred iOS targets absent | PASS |
| Accepted dependency/resource direction | Accepted ADR §3.1 requires provider → `ReluxTunnelMacOSAdapter` plus verified relay resources. Generated `Project.swift` declares provider → `ReluxTunnelCore` only; Release provider has no adapter/native symbol and no relay payload. Existing logbook notes this was deferred, but there is no accepted exception to this task's exact-graph criterion. | **FAIL** |
| Unsigned macOS builds/tests | Host and provider Debug/Release builds pass; target-contract tests pass | PASS |
| Swift Testing/harness lifecycle | 443 tests in 37 suites pass; 25 existing declared known-issue rows are limited to the unavailable ReluxNIOSSH adapter. Harness suites and repeated cleanup/lifecycle baselines pass. | PASS |
| Coverage | `swift test --enable-code-coverage` exits 0 in 70.81 s; 93.30% lines, 91.44% functions, 85.67% regions overall | PASS (>80%) |
| Lint | `swift format lint --strict --parallel --recursive Sources Tests App Package.swift Project.swift Workspace.swift Tuist.swift` exits 0 in 2.28 s; relay gate also runs `gofmt` checks and pinned `go vet ./...` | PASS |
| Native/static policy | macOS slices for `HevSocks5Tunnel`, `ReluxLibSSH2`, and evidence-only `ReluxNativeFixture` are static universal `arm64+x86_64`; checksum, byte-identical fixture rebuild, notices, architecture and extension-safety negative gates pass | PASS |
| Nested bundle/linkage | Exactly one system extension is embedded at the accepted path; Release provider is universal `arm64+x86_64`, has only Apple system dynamic dependencies, and has no runtime-loading symbols | PASS for foundation embedding; production adapter/resource edge fails above |
| Relay artifacts | Four Darwin/Linux amd64/arm64 binaries, manifest, checksums, SPDX SBOMs, offline tests/vet, executable-byte reproducibility comparison, format/linkage/strip/minimum-OS verification and smoke all pass | PASS |
| Legacy coexistence | Signed pinned v0.1.0 detached fixture, preservation/negative guards, Swift tests and Release build pass | PASS |
| Secret material | Targeted artifact/log scan finds no private-key PEM; credential-free settings remain unsigned and no signing overlay is generated | PASS |
| Local VPN prohibition | Only generation/build/test/static inspection commands executed; no install/open/save/activate/start command | PASS |

## Evidence locations

All paths are relative to the detached clone and ignored/task-scoped:

- `.temp/TASK-260715-sbrrp7/credential-free-validation/{environment.log,summary.log,logs/}`
- `.temp/TASK-260715-2btjwm/{generation-01.sha256,generation-02.sha256,xcodebuild-list.log,xcodebuild-project-list.log}`
- `.temp/TASK-260715-uyju7n/` (four build logs, target tests, build settings, nested products, provider linkage/symbol reports)
- `.build/relay/apple-bundle-input/` and `.build/relay/repro/` (relay manifests, binaries, SBOMs, reproducibility inputs)
- `.temp/TASK-260715-nphtib-swift-format.log`
- `.temp/TASK-260715-nphtib-swift-coverage.log`
- `.build/arm64-apple-macosx/debug/codecov/ReluxTunnel.json`

## Disposition

The repository-owned matrix is green, but architecture acceptance is not. `BUG-260819-8qf0s0` owns the missing provider adapter/relay-resource edges and a validator regression that must fail on their absence. `TASK-260715-nphtib` is linked to that bug and remains in development. Per AC6, pass and tester handoff require accepted rework followed by a fresh clean-clone rerun; no handoff command was run in this attempt.
