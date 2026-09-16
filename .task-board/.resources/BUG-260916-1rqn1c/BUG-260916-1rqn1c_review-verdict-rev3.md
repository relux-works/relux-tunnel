# Independent review rev3 — accepted

Verdict: accept CR-BUG-260916-1rqn1c-3 revision 3 as a local source candidate, pending separate parent publication and real hosted validation. Both rev2 findings are repaired; no remaining source defect found in this five-path slice.

## Exact composition and correction

Base b3422b05226253a17676b9b84c764071fe3dbe74; candidate c07adf4a89996b71c627860f7af7c8c392eace6e; PR6 head d45c85d67b78b6578b5cb0821bd2e78217124d30.

Independently verified all 59 staged prerequisite entries against PR6 modes/blobs, all 62 changed candidate paths against worktree bytes, and all candidate changed paths outside the five proposed paths against PR6. Constructed a private temporary index from PR6 and replaced ONLY the five candidate entries with their exact modes and blobs; all remaining entries, including board content, remain identical to PR6.

Authoritative prospective PR tree: **1c1ca7ad20e27e03f003cb3ea0bc466db45fe9e0**.
Producer report tree 008148dc2967e563f973234d3e944f51b120f456 is incorrect: it records scripts/tests/test-credential-free-validation.sh as 100644 instead of the actual candidate and PR6 executable mode 100755. Blob bytes agree. The corrected composition here supersedes that report; no source change is required. Publishing the reported tree would remove executable permission from a directly invoked contract script. Parent must use this corrected tree and must not publish the entire old-main candidate.

No manifest, artifact, product, deployment-target, diagram, or provenance change relative to PR6. Reviewed project supports Apple targets; this explicit task concerns the macOS hosted lane. Only production selector invocation is in the hosted credential-free job. Local contract tests invoke it with PATH shims; no global workstation xcode-select changes, VPN/routes, commits, branch operations, publication, root LOGBOOK writes, or nested workers performed.

## Findings closed and adversarial evidence

The selector extracts the complete Build version value and compares equality. test_selection_rejects_build_with_pin_as_prefix drives scripts/select-native-xcode.sh with 17F420 and rejects it; admit-suffix-build-only keeps the gate and admits only that extra value, and the named test fails.

The workflow execution test test_workflow_selection_command_executes_and_selects_pin extracts and executes the actual selection run command with shims and asserts its effect and attestation. workflow-selection-echo-preserves-token leaves the searched script token but bypasses execution; the full behavioral suite fails at that test. select-wrong-app-preserves-token also fails the full behavioral suite.

Other narrowing proofs: admit-macos26-default-only -> test_selection_rejects_macos26_default_build; admit-one-disagreeing-pin-pair -> test_selection_refuses_disagreeing_manifest_pins; admit-one-unmapped-build -> test_selection_refuses_unmapped_build; admit-one-missing-install -> test_selection_refuses_missing_install. All seven killed, each mutant suite exit 1 with AssertionError, baseline exit 0. The unmapped mutant reaches the build comparison with the staged decoy app; named rejection exit/message detects the weakened mapping.

Production wiring is Makefile credential-free-validate -> scripts/validate-credential-free.sh:133 -> scripts/tests/test-credential-free-validation.sh:80-81 -> both native suites. This is ongoing CI coverage. It is not a GitHub runner emulator: working-directory, if/continue-on-error and full YAML scheduling semantics are not executed by the shim harness. Runner/default-root/order checks remain source contracts, backed by manual exact workflow review and official inventory. Missing-pin negative exists; malformed JSON/type/empty-pin permutations and every external command failure are not exhaustively mutation-covered. These parsing diagnostics do not provide independent admission authority: supported-build mapping and exact final build verification remain downstream. Legacy libssh2 substring validation is unchanged and outside this slice.

## Validation

Independently reran python3 scripts/tests/test_native_toolchain_alignment.py: exit 0, 14 tests; sh scripts/tests/test-credential-free-validation.sh: exit 0, including all seven native mutants and existing diagnostic contracts; git diff --check base candidate: exit 0; sh -n scripts/select-native-xcode.sh: exit 0. Actual subprocess statuses were captured without tail pipelines. No configured dedicated lint target; syntax and whitespace checks passed.

Reused completed exact rev3 immutable CR gate resource BUG-260916-1rqn1c_change-request_rev3-validation.log: all 17 stages PASS, final [exit 0], exact_command_shard required=1 green=1 failed=0 missing=0, test_case_coverage=unknown. This includes target builds, Swift tests/release and native packaging. Did not rerun exhaustive builds. Recovery rev2 native gate exit 0 and incompatible17F113 exit1 are prior producer evidence, not independently rerun here. Rev1 gate failure was the hardcoded macos15 contract; mise trust messages were metadata noise, not its exit1 cause.

## Official evidence and bounds

Independently opened official runner inventory on 2026-09-16: https://raw.githubusercontent.com/actions/runner-images/main/images/macos/macos-26-arm64-Readme.md image20260907.0351.1 lists Xcode26.5 build17F42 at /Applications/Xcode_26.5.app and default26.6 build17F113. https://raw.githubusercontent.com/actions/runner-images/main/README.md documents macos-26 arm64. Existing arm64 Mise checksum remains byte-identical to PR6. Therefore moving to macos-26 and explicitly selecting the installed pinned build is supported and proportionate; artifact provenance remains unchanged. Inventory is mutable, and the selector refuses missing or mismatched future images.

Reused primary hosted incident captured in BUG-260916-1rqn1c_toolchain-evidence.md: run35091586150 on PR6 passes target builds/Swift tests/release, then native-packaging rejects actual16F6 against expected17F42. This review does not claim a fresh hosted run. Parent must publish the exact corrected prospective composition with signed commits, obtain real GitHub review/checks for that exact head, and land only after required checks pass. Local green does not substitute for hosted green. Signing, physical Gate P0, notarization and release publication remain downstream bounds stated by the gate.

AC coverage: **2 of 6 AC rows driven** by executable validation: (1) narrow selection behavior via scripts/select-native-xcode.sh and the extracted .github/workflows/ci.yml command, named NativeToolchainAlignmentTests; (4) targeted validation via scripts/tests/test-credential-free-validation.sh and test_native_toolchain_mutants.py. (2) independent review, (3) prospective composition identity, (5) honest hosted requirements, and (6) publication/landing separation are manual process/evidence bounds, not executable tests. New tests are captured in immutable CR tree and remain uncommitted under the managed Story contract; parent owns signed delivery.

## Independently computed identities

```json
{
  "base": "b3422b05226253a17676b9b84c764071fe3dbe74",
  "candidate": "c07adf4a89996b71c627860f7af7c8c392eace6e",
  "pr": "d45c85d67b78b6578b5cb0821bd2e78217124d30",
  "prospective_tree": "1c1ca7ad20e27e03f003cb3ea0bc466db45fe9e0",
  "overlay_exact": 59,
  "changed_paths_verified": 62,
  "entries": {
    ".github/workflows/ci.yml": "100644 blob 205b10013422af7e43ead2a0fcd1b20ac627a4eb",
    "scripts/select-native-xcode.sh": "100755 blob 0575eaddec932b6f100ca5e60431a30061ce324f",
    "scripts/tests/test-credential-free-validation.sh": "100755 blob 0163045f360692a9940938d7e34b4f376cf5df03",
    "scripts/tests/test_native_toolchain_alignment.py": "100644 blob 22d2c1edfac56a717b67c2220c1548c568139fdc",
    "scripts/tests/test_native_toolchain_mutants.py": "100644 blob 0d67c482239e0b52db1f50168bdfb04aee07ee76"
  },
  "overlay_inventory": {
    ".github/workflows/ci.yml": "100644 blob 740e64f93cc34a3e55e5141502fe58012f0973a2",
    "Configuration/TASK-260720-1qhxqa_m0-production-bindings-v1.json": "100644 blob d3e2bf3214d77e8bc6d3593120b3c3cc803df105",
    "Fixtures/M1Runtime/TASK-260715-m8bi8i_authentication-failure-v1.json": "100644 blob 791d5fbd5ddd492b40fbdf2daf9659fe89223cd1",
    "Fixtures/M1Runtime/TASK-260715-m8bi8i_dns-failure-v1.json": "100644 blob 96005751e01a9e8af5d5f27e32756a50efb513d6",
    "Fixtures/M1Runtime/TASK-260715-m8bi8i_fixture-manifest-v1.json": "100644 blob 27a0e8f65e971c5769fa2ebea5a682b340ff74bf",
    "Fixtures/M1Runtime/TASK-260715-m8bi8i_mid-session-dns-failure-v1.json": "100644 blob 626c80b4a15d66ea4b5453ac5a5d26a82acf7b5b",
    "Fixtures/M1Runtime/TASK-260715-m8bi8i_mid-session-ssh-failure-v1.json": "100644 blob 33bebb0304e36b3f83fac92ab00667ae5583b562",
    "Fixtures/M1Runtime/TASK-260715-m8bi8i_packet-failure-v1.json": "100644 blob 5eef34394c987d2904ffe49c6255fcfe5811c4c5",
    "Fixtures/M1Runtime/TASK-260715-m8bi8i_route-apply-failure-v1.json": "100644 blob e17348a91c3cf581e70f9f84d5ac783c81eeb981",
    "Fixtures/M1Runtime/TASK-260715-m8bi8i_success-v1.json": "100644 blob e31fd9a963d8c8c1c867a1ef281e27de36d99dae",
    "LOGBOOK.md": "100644 blob 67cb07aa51d5d69354027909cbf63d6228ec54c5",
    "Makefile": "100644 blob b7056d651d51d799a4743030e986a3b2cd65a8ff",
    "README.md": "100644 blob c4f3fe208673add04bc6e658edc2b32289019793",
    "Sources/ReluxSnapshotDiffSupport/SnapshotDiff.swift": "100644 blob 963888b71e5ffbe62fa2429869815e9972e0da18",
    "Sources/ReluxTunnelCore/M1RuntimeComposition.swift": "100644 blob b4d52003bfe1bbc1ce7bc2c554f7c536f858a0ed",
    "Sources/ReluxTunnelCore/TunnelRuntimeCoordinator.swift": "100644 blob 6b843d123626f9cb084c49a0b7eafe79cd814d95",
    "Sources/ReluxTunnelHarnessSupport/HarnessContracts.swift": "100644 blob 2ae0999d7b23000ec33d2b5c51df587350570ec4",
    "Sources/ReluxTunnelHarnessSupport/HarnessRuntime.swift": "100644 blob 048df07620df868a0858ad76ae385eb747c21bfa",
    "Sources/ReluxTunnelHarnessSupport/M1RuntimeCommand.swift": "100644 blob d868eb7be3849c8aa0da84a0423de6c5476ebb38",
    "Sources/ReluxTunnelHarnessSupport/SmokeCommand.swift": "100644 blob d0a727971c41c23fea8f15d6b642abdc49347f4d",
    "Sources/ReluxTunnelMacOSAdapter/MacOSProductionDependencyFactory.swift": "100644 blob c72daa9400362a7d6a4b696c30a3af499ad507c5",
    "Sources/ReluxTunnelMacOSAdapter/MacOSProductionSSHBootstrap.swift": "100644 blob 458ebe1b9336703517b4a25c31d1b1253c883146",
    "Sources/ReluxTunnelMacOSAdapter/MacOSSSHBootstrapErrorMapper.swift": "100644 blob 6fdffde1e3037d8ca7d85e3be9d6e7203c9677bf",
    "Sources/ReluxTunnelNativeAdapter/HEVSOCKSBoundary.swift": "100644 blob 090a2334488168a079cd8075703a07f83bfa2a24",
    "Tests/ReluxSnapshotDiffSupportTests/SnapshotDiffSupportTests.swift": "100644 blob 3291cb4ea1fcd8db1a79c13d3670a182b77e37a9",
    "Tests/ReluxTunnelCoreTests/M1RuntimeCompositionTests.swift": "100644 blob 59db917ba96326b686074ff3efcebef91c766b69",
    "Tests/ReluxTunnelCoreTests/MacOSProductionRuntimeOwnershipTests.swift": "100644 blob 120410fe7f993e1f6e5820417cf85295b7f76574",
    "Tests/ReluxTunnelCoreTests/MacOSSystemKeychainCredentialResolverTests.swift": "100644 blob 3add91afb4d1256965a3a2defdb9718080612210",
    "Tests/ReluxTunnelCoreTests/TunnelRuntimeCoordinatorTests.swift": "100644 blob c0cc562d79bf8eb2ded4d3b8d4ff5c08accf5999",
    "Tests/ReluxTunnelHarnessTests/DeterministicSessionFactoryTests.swift": "100644 blob 4e801d91128ba5125305f557e0ae7937001332f0",
    "Tests/ReluxTunnelHarnessTests/M1RuntimeHarnessTests.swift": "100644 blob 329f629863d06c30b149c1a6a779adf363bd5e62",
    "diagrams/TASK-260715-2rcvr0_m1-runtime-lifecycle.puml": "100644 blob 5e573b029ed979e6db9407943ccfef51b98e07ce",
    "diagrams/artefacts/TASK-260715-2rcvr0_m1-runtime-lifecycle.svg": "100644 blob 221a49f763d31cb6768bf37b63c59a0b4add9fad",
    "diagrams/artefacts/TASK-260715-2rcvr0_m1-runtime-lifecycle_001.svg": "100644 blob 432a21350ea6ba240ff00399ea5cbe52ff395056",
    "diagrams/artefacts/TASK-260715-2rcvr0_m1-runtime-lifecycle_002.svg": "100644 blob 013c461f06455327a8f078af80b3a210cebedf67",
    "diagrams/artefacts/TASK-260715-2rcvr0_m1-runtime-lifecycle_003.svg": "100644 blob 78fab5445866839dbb34e1e11e4b78178644d4e1",
    "docs/TASK-260720-1qhxqa_m0-production-bindings.md": "100644 blob ba68769e3805f41b2e5009de64b5df20b96b00b8",
    "docs/core-adapter-boundaries.md": "100644 blob dd740e52a841e91b82c5e2cb9c23d8aa50d39bdf",
    "docs/generated-workspace-foundation.md": "100644 blob a4948d21b143c51187b16ac8b85a6cdf9f3cc6bd",
    "docs/m1-runtime-ownership-and-operations.md": "100644 blob 12a54af07d14dde90823cbdc0c41a0178b46bff9",
    "docs/migration-isolation.md": "100644 blob c76c4d2512035517110f674e0c2b3fce255d495e",
    "scripts/check-core-boundaries.sh": "100755 blob 4e7422fe54884c2ef3c305a5ff327bd2114b3bc9",
    "scripts/check-migration-isolation.py": "100755 blob 725ab2e8f758cd7131cb4a6f3ec6ead98e838f53",
    "scripts/check_board_structure.py": "100644 blob ff742bb42db1ad33fdb84ebca239ecc1e24642a6",
    "scripts/logged-command.sh": "100644 blob 5024443a47b718af2f6a7f0eea3337250d80ac53",
    "scripts/relay_supply_chain.py": "100644 blob 020aeb3d7be5eef84e504769a5bf4621e72e965d",
    "scripts/tests/test-credential-free-validation.sh": "100755 blob 156fc56167320226ec6f07fb4bd12d0d35e1d320",
    "scripts/tests/test-migration-isolation-guard.sh": "100755 blob d45c1bcd62b47f9eb7044ae21eaa269ebd6b51e1",
    "scripts/tests/test_check_board_structure.py": "100644 blob 885c0d42171b8170243e4ab5e44e882b5ae2b7ec",
    "scripts/tests/test_m0_production_bindings.py": "100644 blob 63da8feee257809d3125c72dab5bc9d2028b9ac8",
    "scripts/tests/test_macos_build_diagnostic_mutants.py": "100644 blob 08b30dda0c85e7854a017299b44275a8a5e5f606",
    "scripts/tests/test_macos_build_diagnostics.py": "100644 blob ac4592987f8bc49da055fd3694fb4ec45e861a55",
    "scripts/tests/test_pr6_boundary_mutants.py": "100644 blob 8557d72650a6998d303bf7d8ba214eb230667fca",
    "scripts/tests/test_relay_supply_chain.py": "100644 blob a4de3ef766b23b83781b0987393d97577b60a03d",
    "scripts/validate-credential-free.sh": "100755 blob f3635a2de2c669d9411721dc7b72675fe9f6bd49",
    "scripts/validate-m0-production-bindings.py": "100644 blob affd649bd0d435d999085a5544811d520b7f23ce",
    "scripts/validate-m1-runtime-harness.py": "100644 blob ed5eb0f725f762150fc698d8d2d2f2feddb4e8bb",
    "scripts/validate-macos-targets.sh": "100755 blob f58001d97eff1eef712634d8bc2265e4741ccd5c",
    "task-board.config.json": "100644 blob d7bba702bde16b1e9aef2ccee446ba1ef09b60a3"
  },
  "composition_diff": ".github/workflows/ci.yml                         |  12 +-\n scripts/select-native-xcode.sh                   |  76 +++++++\n scripts/tests/test-credential-free-validation.sh |   7 +-\n scripts/tests/test_native_toolchain_alignment.py | 276 +++++++++++++++++++++++\n scripts/tests/test_native_toolchain_mutants.py   | 128 +++++++++++\n 5 files changed, 496 insertions(+), 3 deletions(-)"
}
```

## readiness.log
```text
git version 2.50.1 (Apple Git-155)
Python 3.14.7
task-board version dev

```

## alignment.log
```text
..............
----------------------------------------------------------------------
Ran 14 tests in 2.670s

OK

EXIT=0

```

## contract.log
```text
...
----------------------------------------------------------------------
Ran 3 tests in 3.054s

OK
admit-exit-1-only: behavioral suite exit 1
FFFF
======================================================================
FAIL: test_exit_one_stops_each_build_and_test_with_exact_status (__main__.MacOSBuildDiagnosticsTests.test_exit_one_stops_each_build_and_test_with_exact_status) (failing_call=1)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp0a4s3qse/scripts/tests/test_macos_build_diagnostics.py", line 65, in assert_failing_build_and_test_status
    self.assertEqual(counter.read_text().strip(), str(failing_call))
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: '5' != '1'
- 5
+ 1


======================================================================
FAIL: test_exit_one_stops_each_build_and_test_with_exact_status (__main__.MacOSBuildDiagnosticsTests.test_exit_one_stops_each_build_and_test_with_exact_status) (failing_call=2)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp0a4s3qse/scripts/tests/test_macos_build_diagnostics.py", line 65, in assert_failing_build_and_test_status
    self.assertEqual(counter.read_text().strip(), str(failing_call))
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: '5' != '2'
- 5
+ 2


======================================================================
FAIL: test_exit_one_stops_each_build_and_test_with_exact_status (__main__.MacOSBuildDiagnosticsTests.test_exit_one_stops_each_build_and_test_with_exact_status) (failing_call=3)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp0a4s3qse/scripts/tests/test_macos_build_diagnostics.py", line 65, in assert_failing_build_and_test_status
    self.assertEqual(counter.read_text().strip(), str(failing_call))
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: '5' != '3'
- 5
+ 3


======================================================================
FAIL: test_exit_one_stops_each_build_and_test_with_exact_status (__main__.MacOSBuildDiagnosticsTests.test_exit_one_stops_each_build_and_test_with_exact_status) (failing_call=4)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp0a4s3qse/scripts/tests/test_macos_build_diagnostics.py", line 65, in assert_failing_build_and_test_status
    self.assertEqual(counter.read_text().strip(), str(failing_call))
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: '5' != '4'
- 5
+ 4


----------------------------------------------------------------------
Ran 1 test in 1.746s

FAILED (failures=4)

admit-exit-65-only: behavioral suite exit 1
FFFFF
======================================================================
FAIL: test_each_failing_build_and_test_retains_status_and_context (__main__.MacOSBuildDiagnosticsTests.test_each_failing_build_and_test_retains_status_and_context) (failing_call=1)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpu2_qt5uv/scripts/tests/test_macos_build_diagnostics.py", line 64, in assert_failing_build_and_test_status
    self.assertEqual(result.returncode, status, result.stderr)
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 1 != 65 : FAIL: xcodebuild -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMac -configuration Debug -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpwytjid05/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpwytjid05/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpwytjid05/.temp/TASK-260715-uyju7n/Intermediates build (exit 65; log: /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpwytjid05/.temp/TASK-260715-sbrrp7/credential-free-validation/logs/macos-targets/credential-free-reluxproxymac-debug-build.log)
compiler invocation 1: -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMac -configuration Debug -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpwytjid05/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpwytjid05/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpwytjid05/.temp/TASK-260715-uyju7n/Intermediates build
ConcreteCompile.swift:42: error: diagnostic sentinel


======================================================================
FAIL: test_each_failing_build_and_test_retains_status_and_context (__main__.MacOSBuildDiagnosticsTests.test_each_failing_build_and_test_retains_status_and_context) (failing_call=2)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpu2_qt5uv/scripts/tests/test_macos_build_diagnostics.py", line 64, in assert_failing_build_and_test_status
    self.assertEqual(result.returncode, status, result.stderr)
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 1 != 65 : FAIL: xcodebuild -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMac -configuration Release -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpf0hwg1ly/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpf0hwg1ly/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpf0hwg1ly/.temp/TASK-260715-uyju7n/Intermediates build (exit 65; log: /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpf0hwg1ly/.temp/TASK-260715-sbrrp7/credential-free-validation/logs/macos-targets/credential-free-reluxproxymac-release-build.log)
compiler invocation 2: -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMac -configuration Release -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpf0hwg1ly/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpf0hwg1ly/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpf0hwg1ly/.temp/TASK-260715-uyju7n/Intermediates build
ConcreteCompile.swift:42: error: diagnostic sentinel


======================================================================
FAIL: test_each_failing_build_and_test_retains_status_and_context (__main__.MacOSBuildDiagnosticsTests.test_each_failing_build_and_test_retains_status_and_context) (failing_call=3)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpu2_qt5uv/scripts/tests/test_macos_build_diagnostics.py", line 64, in assert_failing_build_and_test_status
    self.assertEqual(result.returncode, status, result.stderr)
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 1 != 65 : FAIL: xcodebuild -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMacTunnel -configuration Debug -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpvij2wq19/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpvij2wq19/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpvij2wq19/.temp/TASK-260715-uyju7n/Intermediates build (exit 65; log: /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpvij2wq19/.temp/TASK-260715-sbrrp7/credential-free-validation/logs/macos-targets/credential-free-reluxproxymactunnel-debug-build.log)
compiler invocation 3: -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMacTunnel -configuration Debug -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpvij2wq19/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpvij2wq19/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpvij2wq19/.temp/TASK-260715-uyju7n/Intermediates build
ConcreteCompile.swift:42: error: diagnostic sentinel


======================================================================
FAIL: test_each_failing_build_and_test_retains_status_and_context (__main__.MacOSBuildDiagnosticsTests.test_each_failing_build_and_test_retains_status_and_context) (failing_call=4)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpu2_qt5uv/scripts/tests/test_macos_build_diagnostics.py", line 64, in assert_failing_build_and_test_status
    self.assertEqual(result.returncode, status, result.stderr)
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 1 != 65 : FAIL: xcodebuild -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMacTunnel -configuration Release -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp1h3a5aoo/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp1h3a5aoo/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp1h3a5aoo/.temp/TASK-260715-uyju7n/Intermediates build (exit 65; log: /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp1h3a5aoo/.temp/TASK-260715-sbrrp7/credential-free-validation/logs/macos-targets/credential-free-reluxproxymactunnel-release-build.log)
compiler invocation 4: -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMacTunnel -configuration Release -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp1h3a5aoo/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp1h3a5aoo/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp1h3a5aoo/.temp/TASK-260715-uyju7n/Intermediates build
ConcreteCompile.swift:42: error: diagnostic sentinel


======================================================================
FAIL: test_each_failing_build_and_test_retains_status_and_context (__main__.MacOSBuildDiagnosticsTests.test_each_failing_build_and_test_retains_status_and_context) (failing_call=5)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpu2_qt5uv/scripts/tests/test_macos_build_diagnostics.py", line 64, in assert_failing_build_and_test_status
    self.assertEqual(result.returncode, status, result.stderr)
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 1 != 65 : FAIL: xcodebuild -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMac -configuration Debug -destination platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp50m70afg/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp50m70afg/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp50m70afg/.temp/TASK-260715-uyju7n/Intermediates test (exit 65; log: /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp50m70afg/.temp/TASK-260715-sbrrp7/credential-free-validation/logs/macos-targets/target-contract-tests.log)
compiler invocation 5: -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMac -configuration Debug -destination platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp50m70afg/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp50m70afg/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp50m70afg/.temp/TASK-260715-uyju7n/Intermediates test
ConcreteCompile.swift:42: error: diagnostic sentinel


----------------------------------------------------------------------
Ran 1 test in 2.328s

FAILED (failures=5)

hide-exit-65-diagnostic-only: behavioral suite exit 1
FFFFF
======================================================================
FAIL: test_each_failing_build_and_test_retains_status_and_context (__main__.MacOSBuildDiagnosticsTests.test_each_failing_build_and_test_retains_status_and_context) (failing_call=1)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp34rwu97h/scripts/tests/test_macos_build_diagnostics.py", line 66, in assert_failing_build_and_test_status
    self.assertIn('ConcreteCompile.swift:42: error: diagnostic sentinel', result.stderr)
    ~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 'ConcreteCompile.swift:42: error: diagnostic sentinel' not found in 'FAIL: xcodebuild -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMac -configuration Debug -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpcl2jj1hq/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpcl2jj1hq/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpcl2jj1hq/.temp/TASK-260715-uyju7n/Intermediates build (exit 65; log: /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpcl2jj1hq/.temp/TASK-260715-sbrrp7/credential-free-validation/logs/macos-targets/credential-free-reluxproxymac-debug-build.log)\n'

======================================================================
FAIL: test_each_failing_build_and_test_retains_status_and_context (__main__.MacOSBuildDiagnosticsTests.test_each_failing_build_and_test_retains_status_and_context) (failing_call=2)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp34rwu97h/scripts/tests/test_macos_build_diagnostics.py", line 66, in assert_failing_build_and_test_status
    self.assertIn('ConcreteCompile.swift:42: error: diagnostic sentinel', result.stderr)
    ~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 'ConcreteCompile.swift:42: error: diagnostic sentinel' not found in 'FAIL: xcodebuild -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMac -configuration Release -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpawi7xw3b/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpawi7xw3b/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpawi7xw3b/.temp/TASK-260715-uyju7n/Intermediates build (exit 65; log: /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpawi7xw3b/.temp/TASK-260715-sbrrp7/credential-free-validation/logs/macos-targets/credential-free-reluxproxymac-release-build.log)\n'

======================================================================
FAIL: test_each_failing_build_and_test_retains_status_and_context (__main__.MacOSBuildDiagnosticsTests.test_each_failing_build_and_test_retains_status_and_context) (failing_call=3)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp34rwu97h/scripts/tests/test_macos_build_diagnostics.py", line 66, in assert_failing_build_and_test_status
    self.assertIn('ConcreteCompile.swift:42: error: diagnostic sentinel', result.stderr)
    ~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 'ConcreteCompile.swift:42: error: diagnostic sentinel' not found in 'FAIL: xcodebuild -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMacTunnel -configuration Debug -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpf_k80sha/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpf_k80sha/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpf_k80sha/.temp/TASK-260715-uyju7n/Intermediates build (exit 65; log: /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpf_k80sha/.temp/TASK-260715-sbrrp7/credential-free-validation/logs/macos-targets/credential-free-reluxproxymactunnel-debug-build.log)\n'

======================================================================
FAIL: test_each_failing_build_and_test_retains_status_and_context (__main__.MacOSBuildDiagnosticsTests.test_each_failing_build_and_test_retains_status_and_context) (failing_call=4)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp34rwu97h/scripts/tests/test_macos_build_diagnostics.py", line 66, in assert_failing_build_and_test_status
    self.assertIn('ConcreteCompile.swift:42: error: diagnostic sentinel', result.stderr)
    ~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 'ConcreteCompile.swift:42: error: diagnostic sentinel' not found in 'FAIL: xcodebuild -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMacTunnel -configuration Release -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpm3av2w7g/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpm3av2w7g/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpm3av2w7g/.temp/TASK-260715-uyju7n/Intermediates build (exit 65; log: /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpm3av2w7g/.temp/TASK-260715-sbrrp7/credential-free-validation/logs/macos-targets/credential-free-reluxproxymactunnel-release-build.log)\n'

======================================================================
FAIL: test_each_failing_build_and_test_retains_status_and_context (__main__.MacOSBuildDiagnosticsTests.test_each_failing_build_and_test_retains_status_and_context) (failing_call=5)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp34rwu97h/scripts/tests/test_macos_build_diagnostics.py", line 66, in assert_failing_build_and_test_status
    self.assertIn('ConcreteCompile.swift:42: error: diagnostic sentinel', result.stderr)
    ~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 'ConcreteCompile.swift:42: error: diagnostic sentinel' not found in 'FAIL: xcodebuild -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMac -configuration Debug -destination platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpjq5j68g4/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpjq5j68g4/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpjq5j68g4/.temp/TASK-260715-uyju7n/Intermediates test (exit 65; log: /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpjq5j68g4/.temp/TASK-260715-sbrrp7/credential-free-validation/logs/macos-targets/target-contract-tests.log)\n'

----------------------------------------------------------------------
Ran 1 test in 1.621s

FAILED (failures=5)

All 3 narrowing mutants killed by production-entry behavioral tests
..............
----------------------------------------------------------------------
Ran 14 tests in 3.501s

OK
baseline: behavioral suite exit 0
..............
----------------------------------------------------------------------
Ran 14 tests in 2.366s

OK

admit-macos26-default-only: named test exit 1
F
======================================================================
FAIL: test_selection_rejects_macos26_default_build (__main__.NativeToolchainAlignmentTests.test_selection_rejects_macos26_default_build)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-toolchain-mutant-vayac_mb/scripts/tests/test_native_toolchain_alignment.py", line 223, in test_selection_rejects_macos26_default_build
    self.assertNotEqual(exit_code, 0, output)
    ~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 0 == 0 : select-native-xcode: using /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-6ptuyu8j/Apps/Xcode_26.5.app (Build version 17F42)


----------------------------------------------------------------------
Ran 1 test in 0.432s

FAILED (failures=1)

admit-suffix-build-only: named test exit 1
F
======================================================================
FAIL: test_selection_rejects_build_with_pin_as_prefix (__main__.NativeToolchainAlignmentTests.test_selection_rejects_build_with_pin_as_prefix)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-toolchain-mutant-udcs7ssx/scripts/tests/test_native_toolchain_alignment.py", line 234, in test_selection_rejects_build_with_pin_as_prefix
    self.assertNotEqual(exit_code, 0, output)
    ~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 0 == 0 : select-native-xcode: using /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-1grbsg6h/Apps/Xcode_26.5.app (Build version 17F42)


----------------------------------------------------------------------
Ran 1 test in 0.278s

FAILED (failures=1)

select-wrong-app-preserves-token: full behavioral suite exit 1
..FF........F.
======================================================================
FAIL: test_selection_is_idempotent_when_already_selected (__main__.NativeToolchainAlignmentTests.test_selection_is_idempotent_when_already_selected)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-toolchain-mutant-a9gw2t3q/scripts/tests/test_native_toolchain_alignment.py", line 204, in test_selection_is_idempotent_when_already_selected
    self.assertNotIn("sudo xcode-select -s", calls, output)
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 'sudo xcode-select -s' unexpectedly found in 'xcode-select -p\nsudo xcode-select -s /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-5cij8m5b/Apps/Xcode_26.6.app/Contents/Developer\nxcode-select -s /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-5cij8m5b/Apps/Xcode_26.6.app/Contents/Developer\n' : select-native-xcode: using /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-5cij8m5b/Apps/Xcode_26.6.app (Build version 17F42)


======================================================================
FAIL: test_selection_maps_manifest_pin_to_documented_app (__main__.NativeToolchainAlignmentTests.test_selection_maps_manifest_pin_to_documented_app)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-toolchain-mutant-a9gw2t3q/scripts/tests/test_native_toolchain_alignment.py", line 194, in test_selection_maps_manifest_pin_to_documented_app
    self.assertEqual(selected, f"{apps_root}/{expected_name}/Contents/Developer", output)
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: '/var[43 chars]T/native-xcode-1btkuisd/Apps/Xcode_26.6.app/Contents/Developer' != '/var[43 chars]T/native-xcode-1btkuisd/Apps/Xcode_26.5.app/Contents/Developer'
- /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-1btkuisd/Apps/Xcode_26.6.app/Contents/Developer
?                                                                                      ^
+ /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-1btkuisd/Apps/Xcode_26.5.app/Contents/Developer
?                                                                                      ^
 : select-native-xcode: using /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-1btkuisd/Apps/Xcode_26.6.app (Build version 17F42)


======================================================================
FAIL: test_workflow_selection_command_executes_and_selects_pin (__main__.NativeToolchainAlignmentTests.test_workflow_selection_command_executes_and_selects_pin)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-toolchain-mutant-a9gw2t3q/scripts/tests/test_native_toolchain_alignment.py", line 175, in test_workflow_selection_command_executes_and_selects_pin
    self.assertEqual(
    ~~~~~~~~~~~~~~~~^
        fixture.selected_file.read_text(encoding="utf-8"),
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        f"{fixture.apps_root}/{expected_name}/Contents/Developer",
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        output)
        ^^^^^^^
AssertionError: '/var[43 chars]T/native-xcode-0he6qbu0/Apps/Xcode_26.6.app/Contents/Developer' != '/var[43 chars]T/native-xcode-0he6qbu0/Apps/Xcode_26.5.app/Contents/Developer'
- /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-0he6qbu0/Apps/Xcode_26.6.app/Contents/Developer
?                                                                                      ^
+ /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-0he6qbu0/Apps/Xcode_26.5.app/Contents/Developer
?                                                                                      ^
 : select-native-xcode: using /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-0he6qbu0/Apps/Xcode_26.6.app (Build version 17F42)


----------------------------------------------------------------------
Ran 14 tests in 2.321s

FAILED (failures=3)

workflow-selection-echo-preserves-token: full behavioral suite exit 1
............F.
======================================================================
FAIL: test_workflow_selection_command_executes_and_selects_pin (__main__.NativeToolchainAlignmentTests.test_workflow_selection_command_executes_and_selects_pin)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-toolchain-mutant-dfdba2_6/scripts/tests/test_native_toolchain_alignment.py", line 175, in test_workflow_selection_command_executes_and_selects_pin
    self.assertEqual(
    ~~~~~~~~~~~~~~~~^
        fixture.selected_file.read_text(encoding="utf-8"),
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        f"{fixture.apps_root}/{expected_name}/Contents/Developer",
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        output)
        ^^^^^^^
AssertionError: '/var[43 chars]T/native-xcode-dblh9tf0/Apps/Xcode_26.6.app/Contents/Developer' != '/var[43 chars]T/native-xcode-dblh9tf0/Apps/Xcode_26.5.app/Contents/Developer'
- /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-dblh9tf0/Apps/Xcode_26.6.app/Contents/Developer
?                                                                                      ^
+ /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-dblh9tf0/Apps/Xcode_26.5.app/Contents/Developer
?                                                                                      ^
 : sh ./scripts/select-native-xcode.sh


----------------------------------------------------------------------
Ran 14 tests in 2.308s

FAILED (failures=1)

admit-one-disagreeing-pin-pair: named test exit 1
F
======================================================================
FAIL: test_selection_refuses_disagreeing_manifest_pins (__main__.NativeToolchainAlignmentTests.test_selection_refuses_disagreeing_manifest_pins)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-toolchain-mutant-ptw96txz/scripts/tests/test_native_toolchain_alignment.py", line 251, in test_selection_refuses_disagreeing_manifest_pins
    self.assertEqual(exit_code, 2, output)
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 0 != 2 : select-native-xcode: using /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-hqz4qz4d/Apps/Xcode_26.5.app (Build version 17F42)


----------------------------------------------------------------------
Ran 1 test in 0.270s

FAILED (failures=1)

admit-one-unmapped-build: named test exit 1
F
======================================================================
FAIL: test_selection_refuses_unmapped_build (__main__.NativeToolchainAlignmentTests.test_selection_refuses_unmapped_build)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-toolchain-mutant-xl2ovk8x/scripts/tests/test_native_toolchain_alignment.py", line 261, in test_selection_refuses_unmapped_build
    self.assertEqual(exit_code, 2, output)
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 0 != 2 : select-native-xcode: using /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-mmdh4kao/Apps/Xcode_26.6.app (Build version 17C529)


----------------------------------------------------------------------
Ran 1 test in 0.434s

FAILED (failures=1)

admit-one-missing-install: named test exit 1
F
======================================================================
FAIL: test_selection_refuses_missing_install (__main__.NativeToolchainAlignmentTests.test_selection_refuses_missing_install)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-toolchain-mutant-ol8rzqxr/scripts/tests/test_native_toolchain_alignment.py", line 243, in test_selection_refuses_missing_install
    self.assertEqual(exit_code, 2, output)
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 0 != 2 : select-native-xcode: using /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-9wud8kq7/Apps/Xcode_26.5.app (Build version 17F42)


----------------------------------------------------------------------
Ran 1 test in 0.325s

FAILED (failures=1)

All 7 narrowing mutants killed by production-entry behavioral tests
credential-free validation contract tests passed

EXIT=0

```

## diff-check.log
```text

EXIT=0

```
