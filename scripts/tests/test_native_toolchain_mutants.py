"""Require behavioral tests to kill narrowed native-toolchain regressions.

Run: python3 scripts/tests/test_native_toolchain_mutants.py
Each mutant runs in a disposable fixture, never edits the active checkout.
Token-preserving mutants run the full behavioral suite, not only the
static contract checks.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = "scripts/select-native-xcode.sh"
WORKFLOW = ".github/workflows/ci.yml"
COPIED = (
    SCRIPT,
    "scripts/tests/test_native_toolchain_alignment.py",
    WORKFLOW,
    "NativeDependencies/manifest.json",
)
# Each entry: target file, unique anchor, weakened replacement, named tests
# (empty means the full behavioral suite). Every mutant keeps its gate and
# admits exactly one member of the class the gate must reject.
MUTANTS = {
    # Verification gate stays present; it additionally admits the macos-26
    # default build.
    "admit-macos26-default-only": (
        SCRIPT,
        'if [ "$actual_build" != "$expected_build" ]; then',
        'if [ "$actual_build" != "$expected_build" ] && [ "$actual_build" != "17F113" ]; then',
        ["NativeToolchainAlignmentTests.test_selection_rejects_macos26_default_build"],
    ),
    # Verification gate stays present; it additionally admits exactly the
    # suffix-extended build 17F420.
    "admit-suffix-build-only": (
        SCRIPT,
        'if [ "$actual_build" != "$expected_build" ]; then',
        'if [ "$actual_build" != "$expected_build" ] && [ "$actual_build" != "17F420" ]; then',
        ["NativeToolchainAlignmentTests.test_selection_rejects_build_with_pin_as_prefix"],
    ),
    # The 17F42 token is preserved everywhere; only the selected app changes.
    "select-wrong-app-preserves-token": (
        SCRIPT,
        '17F42) xcode_app="$xcode_root/Xcode_26.5.app" ;;',
        '17F42) xcode_app="$xcode_root/Xcode_26.6.app" ;;',
        [],
    ),
    # The workflow still names the selection script, but the job step no
    # longer executes it; the executable-command test must catch the bypass.
    "workflow-selection-echo-preserves-token": (
        WORKFLOW,
        "run: sh ./scripts/select-native-xcode.sh",
        "run: echo sh ./scripts/select-native-xcode.sh",
        [],
    ),
    # Pin-agreement gate stays present; it additionally admits exactly the
    # disagreeing pair 17F42/17C529.
    "admit-one-disagreeing-pin-pair": (
        SCRIPT,
        "if libssh2 != hev:",
        'if libssh2 != hev and (libssh2, hev) != ("17F42", "17C529"):',
        ["NativeToolchainAlignmentTests.test_selection_refuses_disagreeing_manifest_pins"],
    ),
    # Supported-build mapping stays present; it additionally admits exactly
    # the unmapped build 17C529. The decoy app is already staged, so the kill
    # proves mapping-gate admission rather than tripping the install gate.
    "admit-one-unmapped-build": (
        SCRIPT,
        '''  *)
    echo "select-native-xcode: no supported hosted Xcode''',
        '''  17C529) xcode_app="$xcode_root/Xcode_26.6.app" ;;
  *)
    echo "select-native-xcode: no supported hosted Xcode''',
        ["NativeToolchainAlignmentTests.test_selection_refuses_unmapped_build"],
    ),
    # Installed-app gate stays present; it additionally admits exactly the
    # missing Xcode_26.5.app install.
    "admit-one-missing-install": (
        SCRIPT,
        'if [ ! -d "$xcode_app" ]; then',
        'if [ ! -d "$xcode_app" ] && [ "$xcode_app" != "$xcode_root/Xcode_26.5.app" ]; then',
        ["NativeToolchainAlignmentTests.test_selection_refuses_missing_install"],
    ),
}


def stage(root):
    for relative in COPIED:
        target = root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / relative, target)


def run_suite(root, extra):
    return subprocess.run(
        ["python3", "scripts/tests/test_native_toolchain_alignment.py", *extra],
        cwd=root, capture_output=True, text=True)


def main():
    with tempfile.TemporaryDirectory(prefix="native-toolchain-baseline-") as directory:
        root = Path(directory)
        stage(root)
        baseline = run_suite(root, [])
        print(f"baseline: behavioral suite exit {baseline.returncode}")
        print(baseline.stdout + baseline.stderr)
        if baseline.returncode != 0:
            raise SystemExit("mutant proof failed: baseline is not green")
    for name, (target, before, after, extra) in MUTANTS.items():
        with tempfile.TemporaryDirectory(prefix="native-toolchain-mutant-") as directory:
            root = Path(directory)
            stage(root)
            mutated = root / target
            source = mutated.read_text()
            assert source.count(before) == 1, f"mutant anchor is not unique: {name}"
            mutated.write_text(source.replace(before, after))
            result = run_suite(root, extra)
            scope = "named test" if extra else "full behavioral suite"
            print(f"{name}: {scope} exit {result.returncode}")
            print(result.stdout + result.stderr)
            if result.returncode == 0 or "AssertionError" not in result.stderr:
                raise SystemExit(f"mutant survived or test infrastructure failed: {name}")
    print(f"All {len(MUTANTS)} narrowing mutants killed by production-entry behavioral tests")


if __name__ == "__main__":
    main()
