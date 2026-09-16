# BUG-260916-20xt79 results rev2: accepted prerequisite plus full-gate evidence

Run: RUN-260916-90efd6 (developer/implementer, authorized resume with changed
prerequisite scope). No landing, no publication, no commits. Candidate is left
UNCOMMITTED in the managed Story worktree for the handoff snapshot.
Ready for independent review; composition into PR6 is a later parent-owned
delivery step, not this handoff.

## 0. Reuse statement (proportionality nudge d7b189)

- The mapper/test delta is byte-identical to rev1: `git diff` of the two
  product files diffs clean against
  `BUG-260916-20xt79_change-request_rev1.patch`; blobs
  `6fdffde1e3037d8ca7d85e3be9d6e7203c9677bf` and
  `3add91afb4d1256965a3a2defdb9718080612210` match rev1 results section 2.
- Diagnosis, fix rationale (`#if compiler(>=6.2)`), the mixed-toolchain
  limitation, and C-header/API-availability details are reused from
  `BUG-260916-20xt79_results.md` (RUN-260916-d56fa8) and the TASK-260908-34gi0y
  CI artifacts, and are not re-argued here.
- This run corroborated the key focused items fresh and adds the new
  prerequisite plus the full managed gate. Only new evidence is documented in
  full below; corroborating reruns are listed compactly in section 5.

## 1. Changed prerequisite (new in rev2, explicitly authorized)

Rev1 automatic validation failed BEFORE mapper checks: untrusted worktree
`mise.toml` plus the scheme-fixture mismatch
(`BUG-260916-20xt79_change-request_rev1-validation.log`). Both are addressed
with no other scope expansion.

a) mise trust. Inspected `mise.toml`: exactly 26 bytes,
`[tools]\ntuist = "4.202.5"\n` (sha256
`6ba6e7b342e119be5e1c9620b482dd70cda4baff6a220c7768e59938cd7f822c`),
no environment variables, templates, tasks, or `path:` pins, so trusting is
safe. Ran `mise trust ./mise.toml` (exit 0): task-scoped trust for this
worktree path only, no `--all`, no installation. `mise ls tuist` now resolves
4.202.5 from the worktree config. The trust entry lives outside the repo;
`git status` was unchanged by it. The full gate log contains zero `mise ERROR`
lines.

b) Scheme fixture. Applied ONLY the independently accepted fixture correction
from `CR-BUG-260908-shki8p` rev2 (exact patch and `review-verdict-rev2.md`
read) to `scripts/tests/test-credential-free-validation.sh`. The local
`git diff` of that file is byte-identical to the accepted fixture hunk,
including blob indices `91010e7..9c5543d`; working blob is
`9c5543db766480bf7e840661a4dfe5722cf30b8d`; exec bit preserved; the checker
script itself is unchanged. This is reuse of accepted bytes, not a new fix.
Negative cases verified through the production checker
`scripts/check-workspace-schemes.sh`: the contract script
`bash scripts/tests/test-credential-free-validation.sh` exits 0 (it exits 1
unless the valid list passes and all three invalid lists fail), and a direct
four-list probe reports valid exit 0 ("generated workspace scheme set is
exact") with missing-one-scheme, extra-scheme, and combined
missing-plus-extra each exit 1 ("does not match the active macOS graph").
That matches the accepted verdict: real declared UI test schemes in all four
sets while retaining missing, extra, and combined adversarial refusals.

c) Composition boundary. Downstream composition into PR6 MUST take only the
mapper/test pair from section 2 and MUST NOT overwrite the PR6 fixture with
this old-base file: PR6 already carries the correction plus diagnostic runner
calls (`test_macos_build_diagnostics.py` /
`test_macos_build_diagnostic_mutants.py`), per the shki8p rev2 verdict
"Prospective composition" section. The fixture change exists in this candidate
solely to satisfy the old-base managed gate.

## 2. Exact candidate (independent-review target, 3 files)

- Base HEAD (unmoved): `b3422b05226253a17676b9b84c764071fe3dbe74`
- Branch (uncommitted, no commits made):
  `task-board/story/STORY-260916-2d5zk1`
- Worktree: `/Users/iv/Developer/relux-tunnel/.temp/STORY-260916-2d5zk1/worktree`
- `git status --short` shows exactly three modified paths, nothing else:
  - `Sources/ReluxTunnelMacOSAdapter/MacOSSSHBootstrapErrorMapper.swift`
    blob `6fdffde1e3037d8ca7d85e3be9d6e7203c9677bf` (product, composes to PR6)
  - `Tests/ReluxTunnelCoreTests/MacOSSystemKeychainCredentialResolverTests.swift`
    blob `3add91afb4d1256965a3a2defdb9718080612210` (product, composes to PR6)
  - `scripts/tests/test-credential-free-validation.sh`
    blob `9c5543db766480bf7e840661a4dfe5722cf30b8d` (old-base gate
    prerequisite only, does NOT compose to PR6)
- Scoped diff (3 files, +38/-11):

```diff
diff --git a/Sources/ReluxTunnelMacOSAdapter/MacOSSSHBootstrapErrorMapper.swift b/Sources/ReluxTunnelMacOSAdapter/MacOSSSHBootstrapErrorMapper.swift
index 5b47bd8..6fdffde 100644
--- a/Sources/ReluxTunnelMacOSAdapter/MacOSSSHBootstrapErrorMapper.swift
+++ b/Sources/ReluxTunnelMacOSAdapter/MacOSSSHBootstrapErrorMapper.swift
@@ -34,13 +34,16 @@ public enum MacOSSSHBootstrapErrorMapper {
         configurationGeneration: configurationGeneration,
         context: context
       )
-    case .wifiAware:
-      return SSHBootstrapErrorMapper.transport(
-        .unavailable,
-        stage: stage,
-        configurationGeneration: configurationGeneration,
-        context: context
-      )
+    // NWError.wifiAware exists only in the macOS 26 SDK (Swift 6.2+ toolchain).
+    #if compiler(>=6.2)
+      case .wifiAware:
+        return SSHBootstrapErrorMapper.transport(
+          .unavailable,
+          stage: stage,
+          configurationGeneration: configurationGeneration,
+          context: context
+        )
+    #endif
     @unknown default:
       return SSHBootstrapErrorMapper.transport(
         .unexpected,
diff --git a/Tests/ReluxTunnelCoreTests/MacOSSystemKeychainCredentialResolverTests.swift b/Tests/ReluxTunnelCoreTests/MacOSSystemKeychainCredentialResolverTests.swift
index 13db247..3add91a 100644
--- a/Tests/ReluxTunnelCoreTests/MacOSSystemKeychainCredentialResolverTests.swift
+++ b/Tests/ReluxTunnelCoreTests/MacOSSystemKeychainCredentialResolverTests.swift
@@ -183,6 +183,28 @@ struct MacOSSystemKeychainCredentialResolverTests {
     #expect(tls.diagnostic.retryDisposition == .terminal)
   }
 
+  // NWError.wifiAware exists only in the macOS 26 SDK (Swift 6.2+ toolchain).
+  #if compiler(>=6.2)
+    @Test("wifiAware maps to unavailable without platform values")
+    func wifiAwareBootstrapProjection() throws {
+      guard #available(macOS 26, *) else { return }
+      let context = SSHBootstrapDiagnosticContext(endpointFamily: .ipv6)
+      let error = MacOSSSHBootstrapErrorMapper.network(
+        NWError.wifiAware(987_456),
+        stage: .endpointConnect,
+        configurationGeneration: 5,
+        context: context
+      )
+
+      #expect(error.diagnostic.code == .endpointConnectFailed)
+      #expect(error.diagnostic.retryDisposition == .retryableLater)
+      #expect(error.diagnostic.context.endpointFamily == .ipv6)
+      #expect(error.diagnostic.configurationGeneration == 5)
+      let encoded = try JSONEncoder().encode(error.diagnostic)
+      #expect(!String(data: encoded, encoding: .utf8)!.contains("987456"))
+    }
+  #endif
+
   @Test("record generation digest truncation and trailing bytes fail closed")
   func strictRecordFormat() async throws {
     let reference = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
diff --git a/scripts/tests/test-credential-free-validation.sh b/scripts/tests/test-credential-free-validation.sh
index 91010e7..9c5543d 100755
--- a/scripts/tests/test-credential-free-validation.sh
+++ b/scripts/tests/test-credential-free-validation.sh
@@ -30,16 +30,18 @@ adversarial="$work_root/adversarial.log"
 
 write_list "$valid" \
   relux-relay relux-relay-protocol-test ReluxProxyMac ReluxProxyMacTunnel \
-  ReluxTunnelCore ReluxTunnelHarness
+  ReluxTunnelCore ReluxTunnelHarness ReluxProxyIOSUITests ReluxProxyMacUITests
 write_list "$missing" \
   relux-relay relux-relay-protocol-test ReluxProxyMacTunnel \
-  ReluxTunnelCore ReluxTunnelHarness
+  ReluxTunnelCore ReluxTunnelHarness ReluxProxyIOSUITests ReluxProxyMacUITests
 write_list "$unexpected" \
   relux-relay relux-relay-protocol-test ReluxProxyMac ReluxProxyMacTunnel \
-  ReluxTunnelCore ReluxTunnelHarness UnexpectedScheme
+  ReluxTunnelCore ReluxTunnelHarness ReluxProxyIOSUITests ReluxProxyMacUITests \
+  UnexpectedScheme
 write_list "$adversarial" \
   relux-relay relux-relay-protocol-test ReluxProxyMacTunnel \
-  ReluxTunnelCore ReluxTunnelHarness UnexpectedScheme
+  ReluxTunnelCore ReluxTunnelHarness ReluxProxyIOSUITests ReluxProxyMacUITests \
+  UnexpectedScheme
 
 "$repo_root/scripts/check-workspace-schemes.sh" "$valid" >/dev/null
 for invalid in "$missing" "$unexpected" "$adversarial"; do
```

Production call site for all mapping rows:
`MacOSSSHBootstrapErrorMapper.network(_:stage:configurationGeneration:context:)`.
Production call site for the fixture gate:
`scripts/check-workspace-schemes.sh` (unchanged).

## 3. AC coverage: 3 of 5 rows driven, 2 declared bounds

Rows unchanged from rev1; row 4 is strengthened by the full gate.

1. Declared older SDK compiles the mapper -- BOUND (hosted proof pending).
   No Xcode 16.4 toolchain exists locally (only Xcode 26.5/26.6). Local
   simulation attached instead, see section 5 items 7-9.
2. Current SDK retains intended wifiAware mapping -- DRIVEN by committed test
   `wifiAwareBootstrapProjection` through `MacOSSSHBootstrapErrorMapper.network`.
   Asserts `.endpointConnectFailed`, `.retryableLater`, context passthrough,
   generation passthrough, and platform-code absence from the JSON projection.
3. Preserved mappings and safe fallback -- DRIVEN by committed test
   `networkFrameworkBootstrapProjection` through the same entry point.
   posix/dns/tls expectations unchanged; the tls branch exercises the same
   `.unexpected` cause path as `@unknown default`. Direct stimulation of
   `@unknown default` is impossible on the current SDK (no further NWError
   case exists); the default arm is verified present by the diff in section 2.
4. Focused checks pass with local-vs-hosted distinction -- DRIVEN/SATISFIED.
   Full gate 15/15 PASS plus 18 plus 10 focused tests green locally
   (section 5); toolchain table in section 4 distinguishes local results from
   unavailable hosted proof.
5. Independent reviewer accepts exact candidate before PR6 composition --
   BOUND (pending; this handoff requests it).

Gate analysis: the mapper change is a total classification (every NWError
input maps to some projection; nothing is refused, gated, or attested), so
the negative-gate and narrowing-mutant obligations have no mapper target.
Sensitivity is still proven by a weakening mutant (section 5 item 6), and the
existing hostile-redaction suite passes unchanged inside the green suites.
The scheme fixture gate (production call site above) ships missing, extra,
and combined negative cases, each verified refused in section 1b. No
source-text-inspecting gate exists, so the token-preserving-mutant clause is
not applicable.

## 4. Toolchain evidence (local results are NOT hosted proof)

Local (personally rerun in this session):

- `Apple Swift version 6.3.2 (swiftlang-6.3.2.1.108 clang-2100.1.1.101)`,
  target `arm64-apple-macosx28.0`, toolchain `Xcode_26_5.app`
- `Xcode 26.5, Build version 17F42`
- SDK `MacOSX26.5.sdk`, DisplayName `macOS 26.5`
  (`DEVELOPER_DIR=/Applications/Xcode_26_5.app/Contents/Developer`)
- `sw_vers` product version `27.0`, arch `arm64`
- `swift-format 602.0.0`, `tuist 4.202.5` via worktree mise config

Hosted (from the attached CI log, not reproduced as a toolchain):

- `/Applications/Xcode_16.4.app`, `MacOSX15.5.sdk`, `-swift-version 6`, run
  `35048178384`, exact error
  `MacOSSSHBootstrapErrorMapper.swift:37:11: type 'NWError' has no member 'wifiAware'`.

Nothing in this outcome claims hosted green. Full PR6 green and landing remain
a later delivery task.

## 5. Validation log

New evidence in this session (primary):

1. Exact rev1 gate command
   `LEGACY_ROOT="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/../relux-proxy" make credential-free-validate`
   exit 0. All 15 steps PASS: relay-tool-bootstrap, relay-packaging,
   validation-contract-tests (previously failing), deterministic-generation,
   macos-target-builds-and-contracts, core-boundaries, swift-testing,
   swift-release-build, native-packaging, legacy-clone, legacy-checkout,
   legacy-preservation, legacy-guard-tests, legacy-swift-test,
   legacy-swift-release-build; plus the two standing NOT RUN lines
   (credential-gated release steps; deferred iOS targets). Raw log attached as
   `BUG-260916-20xt79_gate-rev2.log`.
2. Gate `swift-testing` step: `Test run with 495 tests in 40 suites passed
   ... with 25 known issues` (25 known issues match the shki8p accepted
   baseline; count is 495 vs 494 there because this candidate adds the
   wifiAware test).
3. Fixture contract script exit 0; direct four-list checker probe:
   valid exit 0, missing exit 1, extra exit 1, combined exit 1, all as
   expected (section 1b).
4. `mise trust ./mise.toml` exit 0; zero `mise ERROR` lines in the gate log.

Corroborating reruns in this session (compact; consistent with d56fa8):

5. `swift build --target ReluxTunnelMacOSAdapter` exit 0;
   `swift-format lint` on both Swift files exit 0; `git diff --check` exit 0;
   `sh -n` on the fixture exit 0.
6. `swift test --filter MacOSSystemKeychainCredentialResolverTests` exit 0,
   18/18 pass including `wifiAware maps to unavailable without platform
   values`; `swift test --filter SSHBootstrapErrorMappingTests` exit 0,
   10/10 pass.
7. Weakening mutant (sensitivity, then reverted): production wifiAware cause
   `.unavailable` changed to `.unexpected`; mapper suite exits 1 with exactly
   one failure, `retryDisposition .terminal == .retryableLater` in the named
   wifiAware test. File restored; sha256 and `git diff`-vs-rev1.patch
   verified byte-identical.
8. Old-SDK diagnosis: `swift build --target ReluxTunnelMacOSAdapter --sdk
   .../MacOSX15.2.sdk` with the fix active exits 1 with the exact hosted
   error `type 'NWError' has no member 'wifiAware'` (new-compiler plus
   old-SDK mix; expected limitation reused from rev1 results, reproduced as
   diagnosis proof, not a supported configuration).
9. Forced-guard simulation: both `#if compiler(>=6.2)` temporarily forced to
   `#if compiler(>=99)`; build against `MacOSX15.2.sdk` exits 0; suite
   executes 17 tests green with 0 wifiAware mentions (test correctly
   compiled out). Both files restored afterward; blobs and
   `git diff`-vs-rev1.patch verified byte-identical. Honest bound: a full
   `swift test --sdk .../MacOSX15.2.sdk` execution is not runnable in this
   mixed environment because Xcode 26.5's own `Testing.swiftinterface` fails
   against the 15.2 Swift module (`no type named 'SendableMetatype'`) while
   building unrelated test targets -- a pre-existing harness/SDK mix issue,
   not a mapper failure. So the guard-false code shape was compiled against
   15.2 and executed 17-green on the current SDK; d56fa8's simulation claim
   stands as its own evidence.
10. SDK presence re-verified by grep: `wifiAware` occurs 0 times in the 15.2
    `Network.swiftinterface` (arm64e-apple-macos) and once in the 26.5 one:
    `@available(macOS 26.0, ...) case wifiAware(Swift.Int32)` (line 597).

Accepted from already-attached evidence without rerun: hosted CI failure
lines and PR6 head/tree/signature facts from `TASK-260908-34gi0y_results.md`
and `TASK-260908-34gi0y_ci-35048178384-failed-job.log`, and the C-header
`nw_error_domain_wifi_aware` / `WiFiAware.framework` stub details from rev1
results section 1. Everything else above was rerun in this session.

## 6. Scope and safety preservation

- Touched only the mapper, its directly relevant compatibility test, and the
  explicitly authorized accepted fixture prerequisite. No VPN operations,
  routes, tooling edits, gate relaxation, unrelated fixes, or publication.
- No commits on the managed Story branch; root `main` and managed refs
  unmoved; HEAD still `b3422b0`.
- The mise trust entry lives in the user trust store outside the repo; the
  repo diff is unaffected by it.
- No control-root LOGBOOK write per the review brief (control-root additions
  stay in the preserved patch/stash); worktree LOGBOOK untouched to keep the
  candidate minimal. Findings live in this outcome artifact instead.
- Human signing identity/key untouched; no signing operations performed.
- No foreign state touched: `git status` shows only the three intended files.
- Directives observed at safe checkpoints: proportionality nudge d7b189
  (this document follows it) and progress request 661c8e (answered via task
  note and this outcome).
- Build cache inventory: worktree `.build` preserved (not deleted) for
  reviewer re-runs of the exact candidate; fully regenerable via the commands
  in section 5. Gate logs and the legacy fixture under worktree `.temp/`
  are ignored build outputs, regenerable by rerunning the gate. My scratch
  logs live in `/tmp` (outside the repo). No shared caches touched.

## 7. Handoff state

Ready for review (handed off to review). The independent reviewer must verify
the exact 3-file candidate in section 2 (base, branch, blobs, uncommitted
status) and the composition boundary in section 1c before any composition of
the mapper/test pair into PR6. Reviewer re-runs: the two `swift test --filter`
commands and `swift-format lint` from section 5, the fixture contract script,
and the full gate command from section 5 item 1 on the snapshotted worktree;
plus hosted Xcode 16.4 CI for the declared-SDK proof this local session
cannot supply. Exact composed-head platform review and signed landing remain
parent-owned and mandatory before landing.
