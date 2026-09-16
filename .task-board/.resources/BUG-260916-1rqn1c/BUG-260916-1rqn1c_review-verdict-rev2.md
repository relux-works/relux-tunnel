# Independent review rev2 — changes requested

Candidate: b88bdc60b18bacdbfba6515cb42fd5bafc7c6ceb; base b3422b05226253a17676b9b84c764071fe3dbe74; PR6 head d45c85d67b78b6578b5cb0821bd2e78217124d30.

## Findings and minimal corrections

1. scripts/select-native-xcode.sh:68 uses substring matching for an exact build attestation. Independently drove the unchanged production script via its existing PATH-shim harness with `Xcode 26.5\nBuild version 17F420\n`: actual exit 0, falsely reports using Build version 17F42. Require an exact complete build value/line and add a named negative regression plus a narrowing mutant admitting this one suffix value. The older libssh2 verify_xcode_build also uses substring matching; this is pre-existing, not a new regression, and does not subsume the new selector weakness. Repair the new selector in narrow scope; no artifact/manifest changes needed.

2. scripts/tests/test_native_toolchain_alignment.py:test_workflow_selects_pinned_xcode_before_gate only searches source text. Independently changed the copied workflow command from `run: sh ./scripts/select-native-xcode.sh` to `run: echo sh ./scripts/select-native-xcode.sh`, preserving the searched token while disabling execution. Full 12-test suite still exits 0. Existing token-preserving mutant mutates the app mapping, not the workflow invocation guard. Add a token-preserving workflow execution mutant and a test that drives the workflow selection command with shims and proves selection effects (or an equivalently strict executable-command contract). Also ship narrowing mutants for the newly introduced pin-agreement, supported-build and installed-app refusal gates, currently covered by negative tests but absent from the two-entry mutant harness. No need to expand product scope or add workers.

## Identity and scope

59 of 59 staged prerequisite overlay entries match PR6 blob identities. Every candidate changed path matches worktree bytes. All candidate changed paths outside the five proposed paths equal PR6. Independently constructed prospective tree by reading PR6 into a private temporary index and replacing only the five candidate entries, including modes. This preserves every board and remaining PR entry. Prospective PR tree: 0ddf5d3269cdebb5c6381e63778f25cae1600712. Do not publish the entire old-main candidate. Exact identities follow below.

No new manifest, artifact, product, deployment-target or diagram changes relative to PR6. iOS and macOS are supported by Package.swift; this task targets the macOS hosted gate explicitly. No commits, branch operations, system xcode-select mutations, VPN or route changes performed by reviewer. All selector executions used shims.

## Validation and evidence reuse

Independently reran alignment (12 tests), both supplied mutants, the full test-credential-free-validation.sh contract suite, and candidate git diff --check: each actual exit 0, separately captured without pipelines. The unapproved-build probe and workflow bypass both return 0 and demonstrate missing protection, not passing acceptance.

Read the complete current CR rev2 validation log: all 17 stages pass, terminal [exit 0], exact_command_shard required=1 green=1 failed=0 missing=0. Reused that full credential-free gate rather than repeating exhaustive builds. Recovery report separately records native gate exit 0 and actual 17F113 verification exit 1; accepted as producer evidence, not rerun here. Rev1 failure was hardcoded macos15 contract, not mise trust metadata noise.

Production wiring is Makefile credential-free-validate -> scripts/validate-credential-free.sh:133 -> scripts/tests/test-credential-free-validation.sh -> both new suites. They are wired in rev2; workflow invocation test remains source-string-only and can be defeated as above. Two supplied mutants do fail named/full behavioral suites as claimed.

AC coverage corrected: 2 of 6 decomposed AC rows driven by executable validation: narrow selection behavior (scripts/select-native-xcode.sh through NativeToolchainAlignmentTests, incomplete strictness as finding 1) and targeted validation (credential-free contract entry, including mutant harness). Independent review, prospective composition identity, honest hosted requirements, and publication/landing are manual process/evidence bounds, not executable tests. Producer claim 4 of 6 incorrectly counts identity and prose. Counting driven does not mean accepted.

Official runner inventory independently opened 2026-09-16: https://raw.githubusercontent.com/actions/runner-images/main/images/macos/macos-26-arm64-Readme.md lists image 20260907.0351.1, Xcode26.5 build17F42 at /Applications/Xcode_26.5.app, default26.6 build17F113. https://raw.githubusercontent.com/actions/runner-images/main/README.md supplies label architecture mapping. macos26 arm64 keeps the unchanged arm64 Mise checksum pairing. Hosted failure is reused from task toolchain-evidence: run35091586150 passes target builds/Swift tests/release then native verification rejects16F6. This diagnosis and runner/path choice are sound. Real hosted green, exact signed GitHub review and landing remain parent obligations; no hosted success asserted here.

Verdict: changes requested, route to-dev. No accept_cr for this revision. Required corrections are confined to the selector and its tests. Evidence is attached before lifecycle routing.

```json
{
  "base": "b3422b05226253a17676b9b84c764071fe3dbe74",
  "candidate": "b88bdc60b18bacdbfba6515cb42fd5bafc7c6ceb",
  "pr": "d45c85d67b78b6578b5cb0821bd2e78217124d30",
  "prospective_tree": "0ddf5d3269cdebb5c6381e63778f25cae1600712",
  "overlay_exact": 59,
  "new_paths": [
    ".github/workflows/ci.yml",
    "scripts/select-native-xcode.sh",
    "scripts/tests/test-credential-free-validation.sh",
    "scripts/tests/test_native_toolchain_alignment.py",
    "scripts/tests/test_native_toolchain_mutants.py"
  ],
  "blobs": {
    ".github/workflows/ci.yml": "205b10013422af7e43ead2a0fcd1b20ac627a4eb",
    "scripts/select-native-xcode.sh": "2489aa2dc776d5266ea68f45282b4493c356e2d6",
    "scripts/tests/test-credential-free-validation.sh": "0163045f360692a9940938d7e34b4f376cf5df03",
    "scripts/tests/test_native_toolchain_alignment.py": "d53f9a42bc9eb2a49d039ff53dae429a997b1188",
    "scripts/tests/test_native_toolchain_mutants.py": "75dc0d05a6e6dea6c3864c5c4b778919d0a4e19a"
  },
  "composition_diff": " .github/workflows/ci.yml                         |  12 +-\n scripts/select-native-xcode.sh                   |  75 ++++++++\n scripts/tests/test-credential-free-validation.sh |   7 +-\n scripts/tests/test_native_toolchain_alignment.py | 217 +++++++++++++++++++++++\n scripts/tests/test_native_toolchain_mutants.py   |  79 +++++++++\n 5 files changed, 387 insertions(+), 3 deletions(-)\n"
}
```

## alignment.log
```text
............
----------------------------------------------------------------------
Ran 12 tests in 1.656s

OK

EXIT=0

```

## contract.log
```text
...
----------------------------------------------------------------------
Ran 3 tests in 2.867s

OK
admit-exit-1-only: behavioral suite exit 1
FFFF
======================================================================
FAIL: test_exit_one_stops_each_build_and_test_with_exact_status (__main__.MacOSBuildDiagnosticsTests.test_exit_one_stops_each_build_and_test_with_exact_status) (failing_call=1)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpwyrnovlu/scripts/tests/test_macos_build_diagnostics.py", line 65, in assert_failing_build_and_test_status
    self.assertEqual(counter.read_text().strip(), str(failing_call))
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: '5' != '1'
- 5
+ 1


======================================================================
FAIL: test_exit_one_stops_each_build_and_test_with_exact_status (__main__.MacOSBuildDiagnosticsTests.test_exit_one_stops_each_build_and_test_with_exact_status) (failing_call=2)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpwyrnovlu/scripts/tests/test_macos_build_diagnostics.py", line 65, in assert_failing_build_and_test_status
    self.assertEqual(counter.read_text().strip(), str(failing_call))
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: '5' != '2'
- 5
+ 2


======================================================================
FAIL: test_exit_one_stops_each_build_and_test_with_exact_status (__main__.MacOSBuildDiagnosticsTests.test_exit_one_stops_each_build_and_test_with_exact_status) (failing_call=3)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpwyrnovlu/scripts/tests/test_macos_build_diagnostics.py", line 65, in assert_failing_build_and_test_status
    self.assertEqual(counter.read_text().strip(), str(failing_call))
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: '5' != '3'
- 5
+ 3


======================================================================
FAIL: test_exit_one_stops_each_build_and_test_with_exact_status (__main__.MacOSBuildDiagnosticsTests.test_exit_one_stops_each_build_and_test_with_exact_status) (failing_call=4)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpwyrnovlu/scripts/tests/test_macos_build_diagnostics.py", line 65, in assert_failing_build_and_test_status
    self.assertEqual(counter.read_text().strip(), str(failing_call))
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: '5' != '4'
- 5
+ 4


----------------------------------------------------------------------
Ran 1 test in 1.871s

FAILED (failures=4)

admit-exit-65-only: behavioral suite exit 1
FFFFF
======================================================================
FAIL: test_each_failing_build_and_test_retains_status_and_context (__main__.MacOSBuildDiagnosticsTests.test_each_failing_build_and_test_retains_status_and_context) (failing_call=1)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpak8ck793/scripts/tests/test_macos_build_diagnostics.py", line 64, in assert_failing_build_and_test_status
    self.assertEqual(result.returncode, status, result.stderr)
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 1 != 65 : FAIL: xcodebuild -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMac -configuration Debug -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpxt_ud30s/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpxt_ud30s/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpxt_ud30s/.temp/TASK-260715-uyju7n/Intermediates build (exit 65; log: /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpxt_ud30s/.temp/TASK-260715-sbrrp7/credential-free-validation/logs/macos-targets/credential-free-reluxproxymac-debug-build.log)
compiler invocation 1: -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMac -configuration Debug -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpxt_ud30s/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpxt_ud30s/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpxt_ud30s/.temp/TASK-260715-uyju7n/Intermediates build
ConcreteCompile.swift:42: error: diagnostic sentinel


======================================================================
FAIL: test_each_failing_build_and_test_retains_status_and_context (__main__.MacOSBuildDiagnosticsTests.test_each_failing_build_and_test_retains_status_and_context) (failing_call=2)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpak8ck793/scripts/tests/test_macos_build_diagnostics.py", line 64, in assert_failing_build_and_test_status
    self.assertEqual(result.returncode, status, result.stderr)
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 1 != 65 : FAIL: xcodebuild -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMac -configuration Release -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpjqnsxnkg/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpjqnsxnkg/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpjqnsxnkg/.temp/TASK-260715-uyju7n/Intermediates build (exit 65; log: /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpjqnsxnkg/.temp/TASK-260715-sbrrp7/credential-free-validation/logs/macos-targets/credential-free-reluxproxymac-release-build.log)
compiler invocation 2: -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMac -configuration Release -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpjqnsxnkg/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpjqnsxnkg/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpjqnsxnkg/.temp/TASK-260715-uyju7n/Intermediates build
ConcreteCompile.swift:42: error: diagnostic sentinel


======================================================================
FAIL: test_each_failing_build_and_test_retains_status_and_context (__main__.MacOSBuildDiagnosticsTests.test_each_failing_build_and_test_retains_status_and_context) (failing_call=3)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpak8ck793/scripts/tests/test_macos_build_diagnostics.py", line 64, in assert_failing_build_and_test_status
    self.assertEqual(result.returncode, status, result.stderr)
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 1 != 65 : FAIL: xcodebuild -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMacTunnel -configuration Debug -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpanf3ugpz/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpanf3ugpz/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpanf3ugpz/.temp/TASK-260715-uyju7n/Intermediates build (exit 65; log: /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpanf3ugpz/.temp/TASK-260715-sbrrp7/credential-free-validation/logs/macos-targets/credential-free-reluxproxymactunnel-debug-build.log)
compiler invocation 3: -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMacTunnel -configuration Debug -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpanf3ugpz/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpanf3ugpz/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpanf3ugpz/.temp/TASK-260715-uyju7n/Intermediates build
ConcreteCompile.swift:42: error: diagnostic sentinel


======================================================================
FAIL: test_each_failing_build_and_test_retains_status_and_context (__main__.MacOSBuildDiagnosticsTests.test_each_failing_build_and_test_retains_status_and_context) (failing_call=4)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpak8ck793/scripts/tests/test_macos_build_diagnostics.py", line 64, in assert_failing_build_and_test_status
    self.assertEqual(result.returncode, status, result.stderr)
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 1 != 65 : FAIL: xcodebuild -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMacTunnel -configuration Release -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpbpz6x55_/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpbpz6x55_/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpbpz6x55_/.temp/TASK-260715-uyju7n/Intermediates build (exit 65; log: /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpbpz6x55_/.temp/TASK-260715-sbrrp7/credential-free-validation/logs/macos-targets/credential-free-reluxproxymactunnel-release-build.log)
compiler invocation 4: -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMacTunnel -configuration Release -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpbpz6x55_/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpbpz6x55_/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpbpz6x55_/.temp/TASK-260715-uyju7n/Intermediates build
ConcreteCompile.swift:42: error: diagnostic sentinel


======================================================================
FAIL: test_each_failing_build_and_test_retains_status_and_context (__main__.MacOSBuildDiagnosticsTests.test_each_failing_build_and_test_retains_status_and_context) (failing_call=5)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpak8ck793/scripts/tests/test_macos_build_diagnostics.py", line 64, in assert_failing_build_and_test_status
    self.assertEqual(result.returncode, status, result.stderr)
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 1 != 65 : FAIL: xcodebuild -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMac -configuration Debug -destination platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpcepgry2o/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpcepgry2o/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpcepgry2o/.temp/TASK-260715-uyju7n/Intermediates test (exit 65; log: /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpcepgry2o/.temp/TASK-260715-sbrrp7/credential-free-validation/logs/macos-targets/target-contract-tests.log)
compiler invocation 5: -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMac -configuration Debug -destination platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpcepgry2o/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpcepgry2o/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpcepgry2o/.temp/TASK-260715-uyju7n/Intermediates test
ConcreteCompile.swift:42: error: diagnostic sentinel


----------------------------------------------------------------------
Ran 1 test in 1.553s

FAILED (failures=5)

hide-exit-65-diagnostic-only: behavioral suite exit 1
FFFFF
======================================================================
FAIL: test_each_failing_build_and_test_retains_status_and_context (__main__.MacOSBuildDiagnosticsTests.test_each_failing_build_and_test_retains_status_and_context) (failing_call=1)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp776vi67z/scripts/tests/test_macos_build_diagnostics.py", line 66, in assert_failing_build_and_test_status
    self.assertIn('ConcreteCompile.swift:42: error: diagnostic sentinel', result.stderr)
    ~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 'ConcreteCompile.swift:42: error: diagnostic sentinel' not found in 'FAIL: xcodebuild -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMac -configuration Debug -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpssw7vtve/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpssw7vtve/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpssw7vtve/.temp/TASK-260715-uyju7n/Intermediates build (exit 65; log: /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpssw7vtve/.temp/TASK-260715-sbrrp7/credential-free-validation/logs/macos-targets/credential-free-reluxproxymac-debug-build.log)\n'

======================================================================
FAIL: test_each_failing_build_and_test_retains_status_and_context (__main__.MacOSBuildDiagnosticsTests.test_each_failing_build_and_test_retains_status_and_context) (failing_call=2)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp776vi67z/scripts/tests/test_macos_build_diagnostics.py", line 66, in assert_failing_build_and_test_status
    self.assertIn('ConcreteCompile.swift:42: error: diagnostic sentinel', result.stderr)
    ~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 'ConcreteCompile.swift:42: error: diagnostic sentinel' not found in 'FAIL: xcodebuild -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMac -configuration Release -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmps29ptdk9/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmps29ptdk9/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmps29ptdk9/.temp/TASK-260715-uyju7n/Intermediates build (exit 65; log: /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmps29ptdk9/.temp/TASK-260715-sbrrp7/credential-free-validation/logs/macos-targets/credential-free-reluxproxymac-release-build.log)\n'

======================================================================
FAIL: test_each_failing_build_and_test_retains_status_and_context (__main__.MacOSBuildDiagnosticsTests.test_each_failing_build_and_test_retains_status_and_context) (failing_call=3)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp776vi67z/scripts/tests/test_macos_build_diagnostics.py", line 66, in assert_failing_build_and_test_status
    self.assertIn('ConcreteCompile.swift:42: error: diagnostic sentinel', result.stderr)
    ~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 'ConcreteCompile.swift:42: error: diagnostic sentinel' not found in 'FAIL: xcodebuild -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMacTunnel -configuration Debug -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpb6219m44/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpb6219m44/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpb6219m44/.temp/TASK-260715-uyju7n/Intermediates build (exit 65; log: /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpb6219m44/.temp/TASK-260715-sbrrp7/credential-free-validation/logs/macos-targets/credential-free-reluxproxymactunnel-debug-build.log)\n'

======================================================================
FAIL: test_each_failing_build_and_test_retains_status_and_context (__main__.MacOSBuildDiagnosticsTests.test_each_failing_build_and_test_retains_status_and_context) (failing_call=4)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp776vi67z/scripts/tests/test_macos_build_diagnostics.py", line 66, in assert_failing_build_and_test_status
    self.assertIn('ConcreteCompile.swift:42: error: diagnostic sentinel', result.stderr)
    ~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 'ConcreteCompile.swift:42: error: diagnostic sentinel' not found in 'FAIL: xcodebuild -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMacTunnel -configuration Release -destination generic/platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpungcdfhy/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpungcdfhy/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpungcdfhy/.temp/TASK-260715-uyju7n/Intermediates build (exit 65; log: /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmpungcdfhy/.temp/TASK-260715-sbrrp7/credential-free-validation/logs/macos-targets/credential-free-reluxproxymactunnel-release-build.log)\n'

======================================================================
FAIL: test_each_failing_build_and_test_retains_status_and_context (__main__.MacOSBuildDiagnosticsTests.test_each_failing_build_and_test_retains_status_and_context) (failing_call=5)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp776vi67z/scripts/tests/test_macos_build_diagnostics.py", line 66, in assert_failing_build_and_test_status
    self.assertIn('ConcreteCompile.swift:42: error: diagnostic sentinel', result.stderr)
    ~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 'ConcreteCompile.swift:42: error: diagnostic sentinel' not found in 'FAIL: xcodebuild -workspace ReluxTunnel.xcworkspace -scheme ReluxProxyMac -configuration Debug -destination platform=macOS -derivedDataPath /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp3knbfn_2/.temp/TASK-260715-uyju7n/DerivedData-validation CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SYMROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp3knbfn_2/.temp/TASK-260715-uyju7n/Products OBJROOT=/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp3knbfn_2/.temp/TASK-260715-uyju7n/Intermediates test (exit 65; log: /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/tmp3knbfn_2/.temp/TASK-260715-sbrrp7/credential-free-validation/logs/macos-targets/target-contract-tests.log)\n'

----------------------------------------------------------------------
Ran 1 test in 1.345s

FAILED (failures=5)

All 3 narrowing mutants killed by production-entry behavioral tests
............
----------------------------------------------------------------------
Ran 12 tests in 1.556s

OK
baseline: behavioral suite exit 0
............
----------------------------------------------------------------------
Ran 12 tests in 1.573s

OK

admit-macos26-default-only: named test exit 1
F
======================================================================
FAIL: test_selection_rejects_macos26_default_build (__main__.NativeToolchainAlignmentTests.test_selection_rejects_macos26_default_build)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-toolchain-mutant-nqynuj5q/scripts/tests/test_native_toolchain_alignment.py", line 175, in test_selection_rejects_macos26_default_build
    self.assertNotEqual(exit_code, 0, output)
    ~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 0 == 0 : select-native-xcode: using /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-o5i5fazh/Apps/Xcode_26.5.app (Build version 17F42)


----------------------------------------------------------------------
Ran 1 test in 0.347s

FAILED (failures=1)

select-wrong-app-preserves-token: full behavioral suite exit 1
..FF........
======================================================================
FAIL: test_selection_is_idempotent_when_already_selected (__main__.NativeToolchainAlignmentTests.test_selection_is_idempotent_when_already_selected)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-toolchain-mutant-bn69q2wf/scripts/tests/test_native_toolchain_alignment.py", line 156, in test_selection_is_idempotent_when_already_selected
    self.assertNotIn("sudo xcode-select -s", calls, output)
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 'sudo xcode-select -s' unexpectedly found in 'xcode-select -p\nsudo xcode-select -s /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-j41uhspa/Apps/Xcode_26.6.app/Contents/Developer\nxcode-select -s /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-j41uhspa/Apps/Xcode_26.6.app/Contents/Developer\n' : select-native-xcode: using /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-j41uhspa/Apps/Xcode_26.6.app (Build version 17F42)


======================================================================
FAIL: test_selection_maps_manifest_pin_to_documented_app (__main__.NativeToolchainAlignmentTests.test_selection_maps_manifest_pin_to_documented_app)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-toolchain-mutant-bn69q2wf/scripts/tests/test_native_toolchain_alignment.py", line 146, in test_selection_maps_manifest_pin_to_documented_app
    self.assertEqual(selected, f"{apps_root}/{expected_name}/Contents/Developer", output)
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: '/var[43 chars]T/native-xcode-qln7pw09/Apps/Xcode_26.6.app/Contents/Developer' != '/var[43 chars]T/native-xcode-qln7pw09/Apps/Xcode_26.5.app/Contents/Developer'
- /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-qln7pw09/Apps/Xcode_26.6.app/Contents/Developer
?                                                                                      ^
+ /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-qln7pw09/Apps/Xcode_26.5.app/Contents/Developer
?                                                                                      ^
 : select-native-xcode: using /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-qln7pw09/Apps/Xcode_26.6.app (Build version 17F42)


----------------------------------------------------------------------
Ran 12 tests in 1.394s

FAILED (failures=2)

All 2 narrowing mutants killed by production-entry behavioral tests
credential-free validation contract tests passed

EXIT=0

```

## diff-check.log
```text

EXIT=0

```

## mutants.log
```text
baseline: behavioral suite exit 0
............
----------------------------------------------------------------------
Ran 12 tests in 1.654s

OK

admit-macos26-default-only: named test exit 1
F
======================================================================
FAIL: test_selection_rejects_macos26_default_build (__main__.NativeToolchainAlignmentTests.test_selection_rejects_macos26_default_build)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-toolchain-mutant-v17bgqo5/scripts/tests/test_native_toolchain_alignment.py", line 175, in test_selection_rejects_macos26_default_build
    self.assertNotEqual(exit_code, 0, output)
    ~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 0 == 0 : select-native-xcode: using /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-69oddter/Apps/Xcode_26.5.app (Build version 17F42)


----------------------------------------------------------------------
Ran 1 test in 0.400s

FAILED (failures=1)

select-wrong-app-preserves-token: full behavioral suite exit 1
..FF........
======================================================================
FAIL: test_selection_is_idempotent_when_already_selected (__main__.NativeToolchainAlignmentTests.test_selection_is_idempotent_when_already_selected)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-toolchain-mutant-5w0r14gq/scripts/tests/test_native_toolchain_alignment.py", line 156, in test_selection_is_idempotent_when_already_selected
    self.assertNotIn("sudo xcode-select -s", calls, output)
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: 'sudo xcode-select -s' unexpectedly found in 'xcode-select -p\nsudo xcode-select -s /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-_bb5ioea/Apps/Xcode_26.6.app/Contents/Developer\nxcode-select -s /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-_bb5ioea/Apps/Xcode_26.6.app/Contents/Developer\n' : select-native-xcode: using /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-_bb5ioea/Apps/Xcode_26.6.app (Build version 17F42)


======================================================================
FAIL: test_selection_maps_manifest_pin_to_documented_app (__main__.NativeToolchainAlignmentTests.test_selection_maps_manifest_pin_to_documented_app)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/private/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-toolchain-mutant-5w0r14gq/scripts/tests/test_native_toolchain_alignment.py", line 146, in test_selection_maps_manifest_pin_to_documented_app
    self.assertEqual(selected, f"{apps_root}/{expected_name}/Contents/Developer", output)
    ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError: '/var[43 chars]T/native-xcode-zdt2e1hj/Apps/Xcode_26.6.app/Contents/Developer' != '/var[43 chars]T/native-xcode-zdt2e1hj/Apps/Xcode_26.5.app/Contents/Developer'
- /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-zdt2e1hj/Apps/Xcode_26.6.app/Contents/Developer
?                                                                                      ^
+ /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-zdt2e1hj/Apps/Xcode_26.5.app/Contents/Developer
?                                                                                      ^
 : select-native-xcode: using /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-zdt2e1hj/Apps/Xcode_26.6.app (Build version 17F42)


----------------------------------------------------------------------
Ran 12 tests in 1.414s

FAILED (failures=2)

All 2 narrowing mutants killed by production-entry behavioral tests

EXIT=0

```

## readiness.log
```text
git version 2.50.1 (Apple Git-155)
Python 3.14.7
task-board version dev

```

## strict-prefix-probe.log
```text
(0, 'select-native-xcode: using /var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-ir41an5a/Apps/Xcode_26.5.app (Build version 17F42)\n', 'xcode-select -p\n', '/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-ir41an5a/Apps/Xcode_26.5.app/Contents/Developer', '/var/folders/cz/jqbthtks55zbkpcdkfyk4bl80000gp/T/native-xcode-ir41an5a/Apps')
```

## workflow-bypass.log
```text
............
----------------------------------------------------------------------
Ran 12 tests in 1.690s

OK

EXIT=0

```
