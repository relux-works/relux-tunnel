# TASK-260715-nphtib — generated-project architecture verification results

## Verdict

READY FOR REVIEW at authoritative revision `069e23bdbbef71be194762d275b003a40a6cfc72`.

The accepted clean-clone architecture matrix below remains authoritative for the provider graph at its parent revision `7dc73ac6e7325f86a4a178a0558619f0fc9d1490`. The only reviewer rejection was the nondeterministic harness cleanup test routed to `BUG-260819-34ikhl`. That bug is now accepted done at signed, pushed child commit `069e23b`; the focused closure verification below independently proves the deterministic test delta and confirms that it does not change production architecture or cross the build-host safety boundary.

The complete credential-free generated-project foundation matrix passed from a fresh local clone created with `git clone --local --no-hardlinks`, after trusting only that clone's checked-in `mise.toml` as required by the repository instructions. The first disposable clone was rejected by Mise as untrusted (matrix exit 2, 113.61s); it was not used as acceptance evidence. A second fresh clone was created, trusted, confirmed clean, and used for all accepted evidence.

No production signing, app/system-extension install, app/provider launch, Network Extension activation, VPN preference save, VPN tunnel start, route change, or DNS change was performed. The harness `smoke` command is a local no-op resource-lifecycle test and does not use Network Extension.

## Environment and revision

- Source revision: `7dc73ac6e7325f86a4a178a0558619f0fc9d1490`; source timestamp `1787098294`; clean source state before the accepted run.
- Legacy revision: signed tag `v0.1.0` resolved to and was detached at `2557aba1c030d0643d76e0bc3b185f6d5fd172e1` in another `--no-hardlinks` clone.
- Host: macOS 26.5 build 25F71, arm64.
- Xcode 26.5 build 17F42; macOS SDK 26.5; Swift 6.3.2; swift-format 6.3.0.
- Mise 2026.2.0; Tuist 4.202.5; Go 1.26.5 darwin/arm64; Syft 1.48.0; Git 2.50.1; Python 3.14.4; GNU Make 3.81.
- Deployment inputs: macOS 15.0; deferred iOS 18.0.
- Privacy: commands below use `<task-temp>` and `<legacy-root>` aliases; no credential values, unrelated paths, or environment dumps are retained.

## Foundation matrix

The authoritative command was:

`make credential-free-validate LEGACY_ROOT=<legacy-root>`

Result: exit 0 in 310.40s. Its repository-owned summary reported every row below PASS and explicitly reported production signing/physical P0/Developer ID/notarization/DMG and deferred iOS as NOT RUN. The durations below are from a subsequent independent row-by-row timing pass on the same accepted clone; the Swift row includes its required clean rerun after an intermittent failure.

| Row | Exact command | Exit | Duration | Result |
| --- | --- | ---: | ---: | --- |
| Relay tool bootstrap | `./scripts/bootstrap-relay-tools.sh` | 0 | 13.557s | PASS |
| Relay packaging/reproducibility/verify/smoke | `env RELAY_VERSION=0.1.0 SOURCE_COMMIT=7dc73ac6e7325f86a4a178a0558619f0fc9d1490 SOURCE_DATE_EPOCH=1787098294 make relay-shell-validate` | 0 | 76.687s | PASS |
| Entrypoint contract regressions | `./scripts/tests/test-credential-free-validation.sh` | 0 | 0.937s | PASS |
| Deterministic double generation | `./scripts/validate-workspace-foundation.sh` | 0 | 9.191s | PASS |
| macOS Debug/Release builds and contracts | `./scripts/validate-macos-targets.sh` | 0 | 82.701s | PASS |
| Core dependency boundaries | `./scripts/check-core-boundaries.sh` | 0 | 1.166s | PASS |
| Swift Testing clean rerun | `swift package clean && swift test` | 0 | 79.71s | PASS: 443 tests / 37 suites / 25 accepted known issues |
| Swift release build | `swift build -c release` | 0 | 2.091s | PASS |
| Native packaging negatives and reproduction | `make check-native-dependencies test-native-dependencies` | 0 | 4.678s | PASS |
| Legacy isolated clone | `git clone --quiet --local --no-hardlinks <legacy-root> <task-temp>/legacy-v0.1.0` | 0 | 1.087s | PASS |
| Legacy detached checkout | `git -C <task-temp>/legacy-v0.1.0 checkout --quiet 2557aba1c030d0643d76e0bc3b185f6d5fd172e1` | 0 | 0.200s | PASS |
| Legacy preservation | `./scripts/check-legacy-preservation.sh --legacy-root <task-temp>/legacy-v0.1.0 --workspace-root <task-temp>/repo` | 0 | 0.515s | PASS |
| Legacy negative guard tests | `./scripts/tests/test-legacy-preservation-guard.sh --legacy-root <task-temp>/legacy-v0.1.0` | 0 | 9.557s | PASS |
| Legacy Swift tests | `swift test --package-path <task-temp>/legacy-v0.1.0` | 0 | 14.383s | PASS |
| Legacy release build | `swift build -c release --package-path <task-temp>/legacy-v0.1.0` | 0 | 5.260s | PASS |

Additional gates:

- `swift format lint --strict --parallel` over tracked product/manifests/tests Swift files excluding `.task-board/**`: exit 0, 2.38s.
- `swift test --enable-code-coverage`: exit 0, 64.24s; 443 tests / 37 suites passed with 25 expected known issues.
- Product `Sources/` coverage across 46 files: lines 19,482/21,655 = 89.97%; functions 2,322/2,591 = 89.62%; regions 6,567/7,998 = 82.11%.
- `task-board validate`: exit 0, 0.27s, no issues.
- `swift run --skip-build ReluxTunnelHarness smoke --configuration-json <privacy-labelled-noop-document>`: exit 0, 1.02s; status succeeded, profile reference redacted, temporary directory/socket/task cleanup succeeded, and gauges proved HEV/libssh2 linkage.

## Exact generated graph and ADR comparison

Workspace-visible schemes are exactly:

1. `relux-relay`
2. `relux-relay-protocol-test`
3. `ReluxProxyMac`
4. `ReluxProxyMacTunnel`
5. `ReluxTunnelCore`
6. `ReluxTunnelHarness`

Generated application targets are exactly `ReluxProxyMac`, `ReluxProxyMacTests`, `ReluxProxyMacTunnel`, and `ReluxProxyMacTunnelTests`. Generated configurations are exactly `Debug` and `Release`. `ReluxProxyIOS`, `ReluxProxyIOSTunnel`, `ReluxProxyIOSTests`, and `ReluxProxyIOSTunnelTests` are absent from the generated targets and workspace-visible schemes, matching accepted ADR-024/ADR-027 and ADR-029.

`scripts/check-generated-provider-graph.py` passed against `Project.swift`, `Package.swift`, the generated provider-owned PBX build phases, the staged relay root, and the actual Release provider bundle. It proves the accepted consumer-to-dependency direction:

- Provider directly consumes only `ReluxTunnelMacOSAdapter` plus the verified relay folder resource.
- `ReluxTunnelMacOSAdapter` consumes exactly Core, `ReluxTunnelLibSSH2Adapter`, and `ReluxTunnelNativeAdapter`.
- `ReluxTunnelNativeAdapter` consumes exactly Core and `HevSocks5Tunnel`.
- `CReluxNativeFixture` is restricted to test evidence and absent from the generated production project/provider binary.

Two clean-generation SHA-256 manifests were byte-identical (`cmp` exit 0), each with digest `d5c5fd2899750f5b9e90de096e2b0552df22384a5ecbea793c0f19df630b7fc6` across 11 generated files. `Package.swift` and tracked source state remained unchanged by generation.

## Release bundle, static/native linkage, and relay evidence

- Release host bundle ID: `works.relux.tunnel.mac`; exactly one nested system extension with bundle ID `works.relux.tunnel.mac.tunnel` at the ADR path.
- Actual Release provider binary architectures: `x86_64 arm64` (universal).
- Production symbol evidence: 249 HEV text symbols and 28 libssh2 text symbols, plus `ReluxTunnelMacOSAdapter` Swift symbols.
- Forbidden `_NSAddImage`, `_NSCreateObjectFileImageFromFile`, `_dladdr`, `_dlclose`, `_dlopen`, `_dlsym`, `relux_native_fixture`, and `CReluxNativeFixture` symbols: absent.
- Dynamic linkage contains only `/System/Library/Frameworks/*` and `/usr/lib/*`; no bundled or third-party dylib.
- `_CodeSignature` and `Configuration/Signing.local.xcconfig`: absent, as required for the unsigned lane.
- No complete embedded PEM private-key payload was present. A broad marker-only probe found libssh2's literal OpenSSH parser delimiter; a complete-payload check correctly distinguished this non-secret format marker from key material and passed.
- The nested provider relay resource contains exactly four executable OS/architecture artifacts, four SPDX SBOMs, the manifest, canonical checksum file, and notice. `shasum -a 256 -c relux-relay-SHA256SUMS` passed every entry.
- Manifest schema/protocol versions are 1/1. Artifact SHA-256 values: Darwin amd64 `8ae943c5ee6e4bac6934081eb7388f8504840f441709a28653da96a61eb0bed0`; Darwin arm64 `bbfe79ff550dc3f09ab795b0870f0703151e4f3b6c3c8c19a28eaa635a291d64`; Linux amd64 `012818980e94ff69f159620650902823e6174c5e99aa72c6cdba7ee70e9f0484`; Linux arm64 `22fce3f64b2e114f76ad5fb6bcc2442c4611e7812b8e547f6ae8595b9e85808d`.

## Failure routing and anomalies

- Resolved prerequisite diagnostic: a first disposable clean clone failed because its checked-in Mise config had not yet been trusted (exit 2, 113.61s). The accepted run used a second fresh clone after `mise trust <task-temp>/repo/mise.toml`, as documented by the repository.
- Scope diagnostic: a broad Swift-format probe included historical `.task-board` Swift evidence and exited 1 in 3.29s. The relevant tracked product/manifests/tests scope then passed strict lint. No product lint failure exists.
- Real intermittent regression: a warm-cache `swift test` timing row exited 1 in 75.684s because `ReluxTunnelHarness` test `signal cancellation uses signal exit code and cleans all resources` threw `TimedOut()` at `HarnessTests.swift:140`. It is routed to `BUG-260819-34ikhl` with reproduction evidence and rework checklist. The authoritative clean matrix, coverage run, and subsequent `swift package clean && swift test` all pass; no architecture failure remains hidden.
- The anomaly and final accepted evidence are recorded in `LOGBOOK.md` under the 2026-08-19 TASK-260715-nphtib entry.

## Scope exclusions and safety attestation

NOT RUN by design: production signing, physical Gate P0, Developer ID archive, notarization, DMG publication, every iOS build/target, real-host SSH opt-in, app/system-extension install, application/provider launch, VPN preference save, VPN start/stop, route mutation, and DNS mutation. No command in this verification requested or performed those actions.

## Focused deterministic-harness closure at `069e23b`

Executed independently in the project working copy on 2026-08-19, following the task's focused resume instruction. The earlier producer and reviewer clean-clone matrices were reused because the accepted child commit changes no production source or generated-project input. A full credential-free matrix was intentionally not repeated.

| Gate | Exact command | Exit | Duration/result |
| --- | --- | ---: | --- |
| Signed pushed revision | `git verify-commit 069e23bdbbef71be194762d275b003a40a6cfc72 && git merge-base --is-ancestor 069e23bdbbef71be194762d275b003a40a6cfc72 origin/main && git rev-parse origin/main` | 0 | Valid ECDSA signature; `origin/main` is exactly `069e23b` |
| Scoped commit integrity | `git diff --check 7dc73ac6e7325f86a4a178a0558619f0fc9d1490..069e23bdbbef71be194762d275b003a40a6cfc72` plus scoped name/status and commit-stat inspection | 0 | Only `Tests/ReluxTunnelHarnessTests/HarnessTests.swift` changed in code scope; remaining changes are logbook/board evidence |
| Focused clean harness suite | `swift package clean && swift test --filter ReluxTunnelHarness` | 0 | 23.93s; 13 tests in one suite passed, including 50 signal-cleanup, 50 startup-failure, and 50 pre-registration cancellation cases |
| Strict Swift formatting | `swift format lint --recursive --strict Sources Tests App Probes Package.swift Project.swift Workspace.swift Tuist.swift` | 0 | 2.32s |
| Core dependency boundaries | `make check-core-boundaries` | 0 | 0.57s; valid |
| Working/scoped diff checks | `git diff --check && git diff --check 7dc73ac6e7325f86a4a178a0558619f0fc9d1490..069e23bdbbef71be194762d275b003a40a6cfc72` | 0 | clean |
| Build-host safety delta audit | exact changed-path equality plus forbidden lifecycle/network/signing token scan over the harness-test diff | 0 | No production source, signing, installation, launch, VPN preference/tunnel, route, or DNS operation added |
| Board validation before outcome update | `task-board validate` | 0 | Board valid; no issues |

`BUG-260819-34ikhl` is `done` with all checklist items complete. Its accepted producer/reviewer evidence records three clean full-suite passes (446 tests), an independent clean full-suite pass, producer and reviewer clean coverage passes, focused CPU-load stress, strict formatting, boundaries, diff, and board validation. Combined with the two previously attached clean-clone architecture matrices, every task AC and DoD gate is proven without invoking a real VPN or any installation/activation path.
