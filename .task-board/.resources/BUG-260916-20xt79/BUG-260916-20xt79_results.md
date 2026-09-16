# BUG-260916-20xt79 results: SDK-compatible NWError wifiAware mapping repair

Run: RUN-260916-d56fa8 (developer/implementer). No landing, no publication, no commits.
Candidate is left UNCOMMITTED in the managed Story worktree for handoff snapshot.
Ready for independent review; composition into PR6 is a later delivery step, not this handoff.

## 1. Diagnosis

Hosted run 35048178384 (PR6 head a46e2ba) fails only in
`Sources/ReluxTunnelMacOSAdapter/MacOSSSHBootstrapErrorMapper.swift:37` with
`error: type NWError has no member wifiAware` on declared Xcode 16.4 /
Swift 6.1 / MacOSX15.5.sdk. File blob 5b47bd80 is identical on protected main
b3422b0 and PR6 a46e2ba, so the defect predates the Sendable fix.

SDK evidence collected locally in this run:

- New SDK MacOSX26.5.sdk: `Network.swiftinterface` declares
  `case wifiAware(Swift.Int32)` with `@available(macOS 26.0, ...)`; C header
  `error.h` declares `nw_error_domain_wifi_aware = 4` with
  `API_AVAILABLE(macos(26.0), ...)`; `WiFiAware.framework` stub is present.
- Old SDK MacOSX15.2.sdk (CommandLineTools proxy for hosted 15.5):
  `Network.swiftinterface` declares only `posix/dns/tls`; C header declares
  only domains 0-3; no `WiFiAware.framework` entry at all.
- Therefore `.wifiAware` cannot be referenced when compiling against the
  declared older SDK. A runtime `#available` check does not help: the symbol
  does not exist at compile time. The repair must be compile-time conditional.

Fix choice: guard the single `case .wifiAware` (and only it) with
`#if compiler(>=6.2)`. Rationale:

- Hosted toolchain is Swift 6.1 (guard false, case omitted, `@unknown default`
  keeps the switch exhaustive). Local toolchain is Swift 6.3.2 (guard true,
  intended `.unavailable` mapping retained).
- `compiler` (toolchain version) is used instead of `swift` (language mode)
  because the package builds in Swift 6 language mode on both toolchains; a
  `swift(>=6.2)` check would be false everywhere.
- The 6.2 threshold follows the availability annotation: wifiAware arrived in
  the macOS 26 SDK, first shipped with Xcode 26 / Swift 6.2. Verified present
  in 6.3.2, absent in 6.1-era SDK 15.x.
- Deleting the case was rejected: on current SDK wifiAware would fall through
  to `@unknown default` (`.unexpected`, terminal) instead of the intended
  `.unavailable` (retryableLater). The conditional keeps both behaviors.
- Known limitation, stated honestly: the guard is toolchain-based, so a mixed
  new-compiler plus old-SDK invocation still references the case and fails.
  That mix is outside the declared matched pairs (Xcode 16.4 plus SDK 15.5,
  Xcode 26.x plus SDK 26.x). Reproduced below as diagnosis proof, not as a
  supported configuration.

## 2. Exact candidate (independent-review target)

- Base HEAD (unmoved): `b3422b05226253a17676b9b84c764071fe3dbe74`
- Branch (uncommitted, no commits made):
  `task-board/story/STORY-260916-2d5zk1`
- Worktree: `/Users/iv/Developer/relux-tunnel/.temp/STORY-260916-2d5zk1/worktree`
- `git status --short` shows exactly two modified paths, nothing else:
  - `Sources/ReluxTunnelMacOSAdapter/MacOSSSHBootstrapErrorMapper.swift`
    blob `6fdffde1e3037d8ca7d85e3be9d6e7203c9677bf`
  - `Tests/ReluxTunnelCoreTests/MacOSSystemKeychainCredentialResolverTests.swift`
    blob `3add91afb4d1256965a3a2defdb9718080612210`
- Scoped diff (2 files, +32/-7):

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
```

Production call site for all mapping rows:
`MacOSSSHBootstrapErrorMapper.network(_:stage:configurationGeneration:context:)`.

## 3. AC coverage: 3 of 5 rows driven, 2 declared bounds

1. Declared older SDK compiles the mapper -- BOUND (hosted proof pending).
   No Xcode 16.4 toolchain exists locally (only Xcode 26.5/26.6). Local
   simulation attached instead, see section 5 items 5-6.
2. Current SDK retains intended wifiAware mapping -- DRIVEN by committed test
   `wifiAwareBootstrapProjection` through `MacOSSSHBootstrapErrorMapper.network`.
   Asserts `.endpointConnectFailed`, `.retryableLater`, context passthrough,
   generation passthrough, and platform-code absence from the JSON projection.
3. Preserved mappings and safe fallback -- DRIVEN by committed test
   `networkFrameworkBootstrapProjection` through the same entry point.
   posix/dns/tls expectations unchanged (10 assertions, all pass); the tls
   branch exercises the same `.unexpected` cause path as `@unknown default`.
   Direct stimulation of `@unknown default` is impossible on the current SDK
   (no further NWError case exists to trigger it); the default arm is verified
   present by the attached diff.
4. Focused checks pass with local-vs-hosted distinction -- DRIVEN/SATISFIED.
   18 plus 10 tests green locally (section 5); toolchain table in section 4
   distinguishes local results from unavailable hosted proof.
5. Independent reviewer accepts exact candidate before PR6 composition --
   BOUND (pending; this handoff requests it).

Gate analysis: this change is a total classification (every NWError input maps
to some projection; nothing is refused, gated, or attested), so the
negative-gate and narrowing-mutant obligations have no target. Sensitivity is
still proven by a weakening mutant (section 5 item 4), and the existing
hostile-redaction suite (`hostileTextAndProhibitedDataRedaction`, prohibited
values never projected) passes unchanged. No source-text-inspecting gate
exists, so the token-preserving-mutant clause is not applicable.

## 4. Toolchain evidence (local results are NOT hosted proof)

Local (personally rerun in this session):

- `Apple Swift version 6.3.2 (swiftlang-6.3.2.1.108 clang-2100.1.1.101)`,
  target `arm64-apple-macosx28.0`
- `Xcode 26.5, Build version 17F42`
- SDK `MacOSX26.5.sdk`, SDK version `26.5`
- `sw_vers` product version `27.0`, arch `arm64`

Hosted (from attached CI log, not reproduced as a toolchain):

- `/Applications/Xcode_16.4.app`, `MacOSX15.5.sdk`, target
  `arm64-apple-macos15.0`, `-swift-version 6`, job `104642534222`,
  run `35048178384`, exact error
  `MacOSSSHBootstrapErrorMapper.swift:37:11: type NWError has no member wifiAware`.

Nothing in this outcome claims hosted green. Full PR6 green and landing remain
a later delivery task.

## 5. Validation log (all commands rerun by this run unless noted)

1. Baseline before fix: `swift build --target ReluxTunnelMacOSAdapter` exit 0
   (one pre-existing `SecKeychainCopyDomainDefault` deprecation warning, also
   present in the hosted log; untouched).
2. After fix: same build exit 0; `swift-format lint` on both changed files
   exit 0 with zero warnings (formatter-conformant `#if` indentation applied);
   `git diff --check` exit 0.
3. `swift test --filter MacOSSystemKeychainCredentialResolverTests` exit 0:
   18 tests in 1 suite pass, including new
   `wifiAware maps to unavailable without platform values`.
4. Weakening mutant (sensitivity, then reverted): production wifiAware cause
   `.unavailable` changed to `.unexpected`; same suite exits 1 with exactly
   one failure, `retryDisposition .terminal == .retryableLater`. Mutant killed
   by the named new test. File restored; final diff verified byte-identical.
5. Old-SDK diagnosis: `swift build --target ReluxTunnelMacOSAdapter --sdk
   .../MacOSX15.2.sdk` with the fix active exits 1 with the exact hosted
   error `type NWError has no member wifiAware` (new-compiler plus old-SDK
   mix; expected limitation documented in section 1).
6. Old-toolchain simulation: both `#if compiler(>=6.2)` temporarily forced to
   `#if compiler(>=99)`; build against `MacOSX15.2.sdk` exits 0; test suite
   exits 0 with 17 tests (wifiAware test correctly omitted, no compile
   error). Both files restored afterward; `git diff --stat` confirms the exact
   2-file candidate.
7. `swift test --filter SSHBootstrapErrorMappingTests` exit 0: 10 tests pass
   (golden taxonomy, redaction, terminal/transient classes unchanged).
8. Final state re-verified after restore: build exit 0, lint exit 0,
   diff-check exit 0, 18-test suite exit 0, 10-test suite exit 0.

Accepted from already-attached evidence without rerun: hosted CI failure
lines and PR6 head/tree/signature facts from
`TASK-260908-34gi0y_results.md` and
`TASK-260908-34gi0y_ci-35048178384-failed-job.log`. Everything else above was
rerun in this session.

## 6. Scope and safety preservation

- Touched only the mapper and its directly relevant compatibility test.
  No VPN operations, routes, tooling edits, gate relaxation, unrelated fixes,
  or publication.
- No commits on the managed Story branch; root `main` and managed refs
  unmoved; HEAD still `b3422b0`.
- No control-root LOGBOOK write per active directive; findings live in this
  outcome artifact instead. Worktree LOGBOOK untouched to keep the candidate
  minimal.
- Human signing identity/key untouched; no signing operations performed.
- No foreign state touched: `git status` shows only the two intended files.
- Build cache inventory per directive: worktree `.build` is 493M from focused
  `swift build`/`swift test` runs. Preserved (not deleted); useful for
  reviewer re-runs of the exact candidate, fully regenerable via the commands
  in section 5. No other caches created; no shared caches touched.
- Directives polled at a safe checkpoint: observed the LOGBOOK/cache nudge
  and the progress-report request. Progress: finding is the macOS-26-only
  NWError case (section 1); validation is complete per section 5; expected
  handoff is ready-for-review with hosted proof pending (section 7).

## 7. Handoff state

Ready for review (handed off to review). Independent reviewer must verify the
exact 2-file candidate in section 2 (base, branch, blobs, uncommitted status)
before any composition into PR6. Reviewer re-runs: the two `swift test
--filter` commands and `swift-format lint` from section 5 on the snapshotted
worktree, plus hosted Xcode 16.4 CI for the declared-SDK proof this local
session cannot supply.
