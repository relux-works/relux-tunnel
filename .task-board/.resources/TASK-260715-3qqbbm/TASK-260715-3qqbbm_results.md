# TASK-260715-3qqbbm migration-isolation evidence

## Result

Ready for review. The accepted M0 legacy baseline from
`TASK-260715-14lk3y` is reviewer-accepted (`done`), and every direct M1
dependency consumed by this task is also `done`.

The generated M1 runtime remains a separate product lane. It does not replace,
mutate, import into, or publish through the legacy `ReluxProxy` SwiftPM app or
its v0.1.0 release path.

## Delivered

- `scripts/check-migration-isolation.py` is a fail-closed production CLI. It
  verifies all 14 files in `config/legacy-v0.1.0.sha256`, exact legacy and
  generated target graphs, bundle/executable/product identities, defaults and
  Keychain namespaces, launch behavior, release entry points, generated PBX
  identities, and optional Debug/Release product trees. An unreadable required
  input is an error, never inferred absence.
- `scripts/tests/test-migration-isolation-guard.sh` drives the production CLI
  and rejects eight named shapes: generated cross-link, legacy cross-link,
  bundle-ID collision, legacy defaults-key reuse, Keychain namespace collision,
  release-script substitution, built-product collision, and the valid baseline.
- `scripts/validate-credential-free.sh` is the production integration call site.
  It now runs the source/generated-product gate and the negative suite after the
  generated host/provider matrix.
- `Makefile` exposes `check-migration-isolation` and
  `test-migration-isolation`; `README.md` documents commands and outputs.
- `docs/migration-isolation.md` records the complete comparison boundary and
  points the exhaustive legacy file inventory to the byte-pinned manifest.
- `LOGBOOK.md` records the boundary, gate, negative evidence, and deferred
  ownership.

The machine-readable comparison is attached separately as
`TASK-260715-3qqbbm_migration-isolation-report.json`. It records 14 pinned legacy
files, exact generated host dependencies
`ReluxProxyMacTunnel / ReluxAppleUITestShared / ReluxTunnelCore`, sole provider
dependency `ReluxTunnelMacOSAdapter`, both Debug/Release product identities, and
zero collisions.

## Preserved boundary

| Surface | Legacy lane | Generated M1 lane |
| --- | --- | --- |
| Package/product | SwiftPM `ReluxProxy`; `ReluxProxyTests` | SwiftPM `ReluxTunnel`; Tuist `ReluxProxyMac` and `ReluxProxyMacTunnel` |
| Runtime dependencies | No `ReluxTunnelCore`, native adapter, HEV, libssh2, or generated target dependency | Host uses the provider/Core; provider uses only `ReluxTunnelMacOSAdapter` |
| App/provider artifacts | `dist/ReluxProxy.app`; no provider | `ReluxProxyMac.app`; `works.relux.tunnel.mac.tunnel.systemextension` |
| Bundle/executable identities | `works.relux.proxy`; `ReluxProxy` | `works.relux.tunnel.mac`; `ReluxProxyMac`; provider `works.relux.tunnel.mac.tunnel` |
| Defaults | Standard domain `works.relux.proxy`; `sshHost`, `sshAccount`, `localPort` | Standard domain `works.relux.tunnel.mac`; no reuse of those three keys |
| Keychain | No v0.1.0 product Keychain namespace | `works.relux.tunnel.credential.v1`; deferred iOS group remains distinct |
| Launch | SwiftUI `MenuBarExtra`; no product LaunchAgent | Accessory host plus NetworkExtension system-extension mode; no M1 LaunchAgent |
| Release | `make app`, `make dmg`, legacy packaging scripts and workflow; `ReluxProxy-v*` and `ReluxProxy.dmg` | No generated application release entry or legacy artifact name in M1 |

## Negative evidence

Production call site: `scripts/validate-credential-free.sh` step
`migration-isolation` -> `scripts/check-migration-isolation.py:main`.

The final eight-row CLI suite exited `0`; every invalid fixture was refused for
its named reason. The release boundary was then narrowed, not deleted: only the
`ReluxProxy.dmg` marker was temporarily removed from the production CLI. The
suite exited `2` (`make` wrapper; test script exit `1`) because
`release-script-substitution` was admitted, while the other mutation rows
remained green. Restoring the exact marker returned the final suite to exit `0`.

Evidence:

- `.temp/TASK-260715-3qqbbm/release-marker-narrowing-mutant-expected-failure-final-01.log`
- `.temp/TASK-260715-3qqbbm/migration-isolation-negative-restored-final-01.log`

## Verification

| Gate | Result | Evidence |
| --- | --- | --- |
| M0 source/identity/release guard plus new source isolation gate | exit `0` | `migration-isolation-source-01.log` |
| Final source/PBX/Debug+Release product isolation report | exit `0`; 14 pinned files; zero collisions | `migration-isolation-products-restored-final-01.log`, `migration-isolation-report.json` |
| Final migration-isolation negative suite | exit `0`; baseline plus 7 rejected mutations | `migration-isolation-negative-restored-final-01.log` |
| Release-marker narrowing mutant | expected exit `2`; named substitution admitted | `release-marker-narrowing-mutant-expected-failure-final-01.log` |
| Clean legacy SwiftPM test | exit `0`; 4 tests, 0 failures | `legacy-swift-test-01.log` |
| Clean legacy release build | exit `0` | `legacy-swift-release-build-01.log` |
| Legacy ad-hoc universal app + DMG | exit `0`; `x86_64 arm64`; codesign and DMG checksum valid | `legacy-make-dmg-01.log`, `legacy-app-archs-01.log`, `legacy-codesign-verify-01.log`, `legacy-dmg-verify-01.log` |
| Existing legacy mutation guard | exit `0`; baseline plus 7 rejected mutations | `legacy-guard-negative-02.log` |
| Clean generated host/provider Debug builds | exit `0` for both schemes | `generated-debug-reluxproxymac-01.log`, `generated-debug-reluxproxymactunnel-01.log` |
| Clean generated host/provider Release builds | exit `0` for both schemes | `generated-release-reluxproxymac-01.log`, `generated-release-reluxproxymactunnel-01.log` |
| Existing unsigned macOS matrix, target tests, entitlements, linkage, graph | exit `0` | `existing-macos-target-validation-01.log` |
| Existing provider-graph adversarial suite | exit `0` | `existing-provider-graph-negative-01.log` |
| Clean M1 harness build and focused runtime/ownership suites | exit `0`; 20 tests | `generated-swiftpm-harness-build-01.log`, `generated-swiftpm-m1-harness-test-01.log`, `generated-swiftpm-m1-composition-test-01.log`, `generated-swiftpm-macos-ownership-test-01.log`, `generated-swiftpm-harness-ownership-test-01.log` |
| Existing M1 runtime harness command/fixture manifest | exit `0`; 6 tests and 7 fixture rows | `m1-runtime-harness-command-01.log` |
| Full SwiftPM suite rerun with observed terminal exit | exit `0`; 514 tests / 44 suites; 25 known unavailable-ReluxNIOSSH issues | `generated-swiftpm-full-test-02.log` |
| Core import/dependency boundary | exit `0` | `core-boundaries-01.log` |
| Python/shell lint and syntax plus diff whitespace | all exit `0` | `black-check-final-01.log`, `shellcheck-restored-final-01.log` |
| SwiftPM package/product and dependency projections | both exit `0` | `generated-package-describe.json`, `generated-package-dependencies.json` |

## Anomalies and safety

- The first negative-suite invocation stopped before tests because the new shell
  file lacked executable mode (make exit `2`, child exit `126`). The mode was
  fixed and all later suites reached terminal exit.
- Two initial negative fixtures exposed test bugs (Perl interpolation and
  rejection ordering); both were corrected before evidence was accepted.
- The first optional PBX/product gate exited `1` because it looked for a bundle
  identifier that PBX serialization does not contain. It now validates the
  serialized target/product identity and separately reads exact built bundle
  identifiers. This preserves unknown-versus-absence semantics.
- One parallel wrapper lost two terminal transport exit codes. Both gates were
  rerun sequentially: full SwiftPM exit `0`, legacy negative suite exit `0`.
- `task-board validate` returned process exit `0` while reporting the
  pre-existing owning Story mismatch (`backlog` stored versus child aggregate
  `development`). The task itself remains `development` with 10/10 checklist
  items complete; parent normalization is orchestrator-owned and the validation
  output is retained without calling it clean.
- Tuist retained its existing variable-based `PRODUCT_NAME` warning, and the
  Release host retained the existing missing App Category warning. Both builds
  exited `0`; neither warning is an identity collision.
- No production signing, notarization, publication, app/provider process launch,
  system-extension installation, VPN start, live Keychain access, SSH network
  connection, route mutation, or DNS mutation was performed. Legacy packaging
  used only ad-hoc signing inside the task clone.

## Future ownership

- M4 `TASK-260715-35nc5m` owns coexistence/replacement/retirement and any user or
  defaults import behavior.
- M5 `TASK-260715-1tzaed` owns macOS release identity, entitlement, packaging,
  and data-migration decisions after the M4 outcome.

No user/data migration or release substitution is implemented here.
