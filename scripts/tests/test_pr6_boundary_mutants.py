"""Behavioral narrowing mutants for BUG-260908-7c5iv4; no network or VPN use.

Run: python3 scripts/tests/test_pr6_boundary_mutants.py
Each mutant runs in a disposable fixture, never edits the active checkout, and
must fail its named regression test. Swift tests exercise the production source.
"""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def run(command, root, expected, diagnostic):
    result = subprocess.run(command, cwd=root, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=240)
    print("COMMAND:", " ".join(command), "EXIT:", result.returncode)
    print(result.stdout)
    if (result.returncode == 0) != (expected == 0) or diagnostic not in result.stdout:
        raise SystemExit("mutant proof failed: unexpected exit or missing named diagnostic")


def main():
    with tempfile.TemporaryDirectory(prefix="pr6-boundary-mutants-") as temporary:
        root = Path(temporary)
        for relative in (
            "scripts/check_board_structure.py", "scripts/relay_supply_chain.py",
            "scripts/tests/test_check_board_structure.py",
            "scripts/tests/test_relay_supply_chain.py", "relay/supply-chain-source-v1.json",
            "Sources/ReluxSnapshotDiffSupport/SnapshotDiff.swift",
        ):
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        board = root / "scripts/check_board_structure.py"
        original = board.read_text()
        command = [sys.executable, "-m", "unittest", "-v",
                   "scripts.tests.test_check_board_structure.BoardStructureTests.test_unknown_hidden_directory_is_not_exempt"]
        run(command, root, 0, "OK")
        board.write_text(original.replace('(".resources", ".activity")',
                                          '(".resources", ".activity", ".hidden")'))
        run(command, root, 1, "FAIL: test_unknown_hidden_directory_is_not_exempt")
        board.write_text(original)
        scanner = root / "scripts/relay_supply_chain.py"
        original = scanner.read_text()
        command = [sys.executable, "-m", "unittest", "-v",
                   "scripts.tests.test_relay_supply_chain.RelaySupplyChainTests.test_snapshot_support_network_mutants_preserve_file_tokens_and_fail"]
        run(command, root, 0, "OK")
        scanner.write_text(original.replace("if explicit_local_url:",
                                            'if explicit_local_url or token_is(tokens, index + 2, "referenceURL"):'))
        run(command, root, 1, "FAIL: test_snapshot_support_network_mutants_preserve_file_tokens_and_fail")
        scanner.write_text(original)

        package = root / "snapshot"
        source = package / "Sources/ReluxSnapshotDiffSupport/SnapshotDiff.swift"
        test = package / "Tests/ReluxSnapshotDiffSupportTests/SnapshotDiffSupportTests.swift"
        for target, relative in ((source, "Sources/ReluxSnapshotDiffSupport/SnapshotDiff.swift"),
                                 (test, "Tests/ReluxSnapshotDiffSupportTests/SnapshotDiffSupportTests.swift")):
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
        (package / "Package.swift").write_text('''// swift-tools-version: 6.1
import PackageDescription
let package = Package(name: "SnapshotBoundaryProof", platforms: [.macOS(.v15)], targets: [
  .target(name: "ReluxSnapshotDiffSupport"),
  .testTarget(name: "ReluxSnapshotDiffSupportTests", dependencies: ["ReluxSnapshotDiffSupport"]),
])
''')
        command = ["swift", "test", "--package-path", str(package)]
        run(command, root, 0, "Test run with 3 tests")
        # Keep isFileURL and the refusal; admit only HTTP from the forbidden schemes.
        source.write_text(source.read_text().replace("guard url.isFileURL else",
                                                     'guard url.isFileURL || url.scheme == "http" else'))
        run(command, root, 1, "expected nonFileURL before I/O")
    print("All three narrowing mutants killed by named behavioral regressions.")


if __name__ == "__main__":
    main()
