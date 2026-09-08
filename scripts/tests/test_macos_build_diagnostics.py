"""Behavioral diagnostics tests; fixtures never launch Xcode or activate a VPN."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class MacOSBuildDiagnosticsTests(unittest.TestCase):
    def test_successful_child_retains_both_streams(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / 'child.log'
            result = subprocess.run(
                ['sh', '-c', '. "$1"; run_logged_command "$2" sh -c '
                 '\'echo compiler-output; echo compiler-warning >&2\'',
                 'test', str(ROOT / 'scripts/logged-command.sh'), str(log)],
                capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(log.read_text(), 'compiler-output\ncompiler-warning\n')

    def test_each_failing_build_and_test_retains_status_and_context(self):
        self.assert_failing_build_and_test_status(65)

    def test_exit_one_stops_each_build_and_test_with_exact_status(self):
        self.assert_failing_build_and_test_status(1)

    def assert_failing_build_and_test_status(self, status):
        # Four unsigned builds followed by the target-contract test invocation.
        for failing_call in range(1, 6):
            with self.subTest(failing_call=failing_call), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                scripts = root / 'scripts'
                scripts.mkdir()
                for name in ('validate-macos-targets.sh', 'logged-command.sh'):
                    shutil.copyfile(ROOT / 'scripts' / name, scripts / name)
                generate = scripts / 'generate-workspace.sh'
                generate.write_text('#!/bin/sh\nexit 0\n')
                generate.chmod(0o755)
                binary = root / 'bin'
                binary.mkdir()
                xcodebuild = binary / 'xcodebuild'
                xcodebuild.write_text('''#!/bin/sh
count=0
[ ! -f "$COUNTER" ] || count=$(cat "$COUNTER")
count=$((count + 1))
echo "$count" > "$COUNTER"
echo "compiler invocation $count: $*"
if [ "$count" -eq "$FAIL_CALL" ]; then
  echo 'ConcreteCompile.swift:42: error: diagnostic sentinel' >&2
  exit "$FAIL_STATUS"
fi
''')
                xcodebuild.chmod(0o755)
                counter = root / 'counter'
                result = subprocess.run(
                    ['sh', str(scripts / 'validate-macos-targets.sh')],
                    env={**os.environ, 'PATH': f'{binary}:/usr/bin:/bin',
                         'COUNTER': str(counter), 'FAIL_CALL': str(failing_call),
                         'FAIL_STATUS': str(status)},
                    capture_output=True, text=True)
                self.assertEqual(result.returncode, status, result.stderr)
                self.assertEqual(counter.read_text().strip(), str(failing_call))
                self.assertIn('ConcreteCompile.swift:42: error: diagnostic sentinel', result.stderr)
                self.assertIn(f'exit {status}', result.stderr)
                logs = root / '.temp/TASK-260715-sbrrp7/credential-free-validation/logs/macos-targets'
                self.assertEqual(len(list(logs.glob('*.log'))), failing_call)
                self.assertTrue(any('diagnostic sentinel' in log.read_text()
                                    for log in logs.glob('*.log')))


if __name__ == '__main__':
    unittest.main()
