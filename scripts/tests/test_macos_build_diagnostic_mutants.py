"""Require behavioral tests to kill narrowed diagnostic/status regressions."""
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
MUTANTS = {
    'admit-exit-1-only': ('return "$command_status"',
                        '[ "$command_status" -ne 1 ] || return 0\n    return "$command_status"'),
    'admit-exit-65-only': ('return "$command_status"',
                         '[ "$command_status" -ne 65 ] || return 0\n    return "$command_status"'),
    'hide-exit-65-diagnostic-only': ('cat "$command_log" >&2',
                                   'if [ "$command_status" -ne 65 ]; then cat "$command_log" >&2; fi'),
}


def main():
    for name, (before, after) in MUTANTS.items():
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'scripts/tests').mkdir(parents=True)
            for relative in ('scripts/validate-macos-targets.sh', 'scripts/logged-command.sh',
                             'scripts/tests/test_macos_build_diagnostics.py'):
                shutil.copyfile(ROOT / relative, root / relative)
            helper = root / 'scripts/logged-command.sh'
            source = helper.read_text()
            assert source.count(before) == 1
            helper.write_text(source.replace(before, after))
            result = subprocess.run(
                ['python3', 'scripts/tests/test_macos_build_diagnostics.py',
                 ('MacOSBuildDiagnosticsTests.test_exit_one_stops_each_build_and_test_with_exact_status'
                  if name == 'admit-exit-1-only' else
                  'MacOSBuildDiagnosticsTests.test_each_failing_build_and_test_retains_status_and_context')],
                cwd=root, capture_output=True, text=True)
            print(f'{name}: behavioral suite exit {result.returncode}')
            print(result.stdout + result.stderr)
            if result.returncode != 1 or 'AssertionError' not in result.stderr:
                raise SystemExit(f'mutant survived or test infrastructure failed: {name}')
    print(f'All {len(MUTANTS)} narrowing mutants killed by production-entry behavioral tests')


if __name__ == '__main__':
    main()
