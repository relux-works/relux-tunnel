"""Native toolchain alignment: hosted runner must provide the manifest-pinned Xcode.

Production entry points:
  scripts/select-native-xcode.sh (invoked by the credential-free CI job)
  .github/workflows/ci.yml (job selects the image, script selects the Xcode)

Fixtures never touch the real xcode-select/xcodebuild: every behavioral case
runs the production script with PATH shims and a fixture manifest.
"""
import contextlib
import json
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "NativeDependencies/manifest.json"
WORKFLOW = ROOT / ".github/workflows/ci.yml"
SCRIPT = ROOT / "scripts/select-native-xcode.sh"

# Independent oracle from the official GitHub runner-images inventory
# (images/macos/macos-26-arm64-Readme.md, image 20260907.0351.1):
# Xcode 26.5 build 17F42 ships at /Applications/Xcode_26.5.app on macos-26,
# whose default is Xcode 26.6 build 17F113. macos-15 tops out at Xcode 26.3
# build 17C529 with default Xcode 16.4 build 16F6, so it cannot host the pin.
EXPECTED_APP_NAME_BY_BUILD = {"17F42": "Xcode_26.5.app"}
REQUIRED_RUNS_ON = "macos-26"


def manifest_pins(manifest_path):
    manifest = json.loads(Path(manifest_path).read_text(encoding="utf-8"))
    libssh2 = manifest["dependencies"]["libssh2-openssl"]["compiler"]["xcode_build"]
    hev = manifest["dependencies"]["hev-lwip"]["rebuild"]["xcode_build"]
    return libssh2, hev


def credential_free_job_block():
    """Extract the raw YAML block of the credential-free job without pyyaml."""
    lines = WORKFLOW.read_text(encoding="utf-8").splitlines()
    begin = next(index for index, line in enumerate(lines)
                 if line == "  generated-project-credential-free:")
    end = next((index for index in range(begin + 1, len(lines))
                if lines[index] and not lines[index].startswith(" ")
                or lines[index].startswith("  ") and not lines[index].startswith("   ")),
               len(lines))
    return "\n".join(lines[begin:end])


def write_shim(path, body):
    path.write_text(body, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


@contextlib.contextmanager
def selection_fixture(selected_name, xcodebuild_output, fixture_manifest_text,
                      install_app=True):
    """Stage PATH shims, a fixture manifest, and a fake install tree.

    Yields a namespace with the shimmed env plus fixture paths; the caller
    chooses which production command to drive inside it.
    """
    with tempfile.TemporaryDirectory(prefix="native-xcode-") as directory:
        root = Path(directory)
        bin_dir = root / "bin"
        bin_dir.mkdir()
        apps_root = root / "Apps"
        apps_root.mkdir()
        if install_app:
            # Stage the pinned app plus the macos-26 default as a decoy, so a
            # mutant selecting the wrong app fails on the recorded path.
            (apps_root / "Xcode_26.5.app").mkdir()
            (apps_root / "Xcode_26.6.app").mkdir()
        selected_file = root / "selected"
        selected_file.write_text(f"{apps_root}/{selected_name}/Contents/Developer",
                                 encoding="utf-8")
        call_log = root / "calls.log"
        call_log.write_text("", encoding="utf-8")
        write_shim(bin_dir / "xcode-select",
                   '#!/bin/sh\n'
                   'echo "xcode-select $*" >> "$CALL_LOG"\n'
                   'if [ "$1" = "-p" ]; then cat "$SELECTED_FILE"; '
                   'elif [ "$1" = "-s" ]; then printf "%s" "$2" > "$SELECTED_FILE"; '
                   'else exit 9; fi\n')
        write_shim(bin_dir / "xcodebuild", '#!/bin/sh\nprintf "%s" "$XCODEBUILD_OUTPUT"\n')
        write_shim(bin_dir / "sudo", '#!/bin/sh\necho "sudo $*" >> "$CALL_LOG"\nexec "$@"\n')
        manifest_file = root / "manifest.json"
        manifest_file.write_text(fixture_manifest_text, encoding="utf-8")
        yield SimpleNamespace(
            env={**os.environ, "PATH": f"{bin_dir}:/usr/bin:/bin",
                 "CALL_LOG": str(call_log), "SELECTED_FILE": str(selected_file),
                 "XCODEBUILD_OUTPUT": xcodebuild_output,
                 "RELUX_NATIVE_MANIFEST": str(manifest_file),
                 "RELUX_XCODE_ROOT": str(apps_root)},
            call_log=call_log, selected_file=selected_file, apps_root=apps_root,
            manifest_file=manifest_file)


def run_selection_script(fixture_manifest, selected_name, xcodebuild_output,
                         install_app=True):
    """Run the production script with shims and a staged install tree.

    Returns (exit, stdout+stderr, calls, selected path, staged app root).
    selected_name is an Xcode app bundle name inside the staged root.
    """
    with selection_fixture(selected_name, xcodebuild_output, fixture_manifest,
                           install_app) as fixture:
        result = subprocess.run(
            ["sh", str(SCRIPT)],
            env=fixture.env,
            capture_output=True, text=True)
        return (result.returncode, result.stdout + result.stderr,
                fixture.call_log.read_text(encoding="utf-8"),
                fixture.selected_file.read_text(encoding="utf-8"),
                str(fixture.apps_root))


def fixture_manifest(libssh2_pin, hev_pin=...):
    hev = libssh2_pin if hev_pin is ... else hev_pin
    return json.dumps({"dependencies": {
        "libssh2-openssl": {"compiler": {"xcode_build": libssh2_pin}},
        "hev-lwip": {"rebuild": {"xcode_build": hev}}}})


class NativeToolchainAlignmentTests(unittest.TestCase):
    def test_manifest_pins_agree_on_single_toolchain(self):
        libssh2, hev = manifest_pins(MANIFEST)
        self.assertTrue(libssh2, "libssh2 pin is empty")
        self.assertEqual(hev, libssh2,
                         "native dependencies pin different Xcode builds; "
                         "hosted selection is undefined until they agree")

    def test_workflow_runs_credential_free_job_on_macos26(self):
        block = credential_free_job_block()
        self.assertIn(f"runs-on: {REQUIRED_RUNS_ON}", block,
                      "credential-free job must run on macos-26: macos-15 ships "
                      "at most Xcode 26.3 (17C529) and cannot provide the pinned 17F42")
        self.assertNotIn("runs-on: macos-15\n", block + "\n")

    def test_workflow_selects_pinned_xcode_before_gate(self):
        block = credential_free_job_block()
        self.assertIn("scripts/select-native-xcode.sh", block,
                      "credential-free job must select the pinned Xcode explicitly: "
                      "the macos-26 default (Xcode 26.6, 17F113) is not the pin")
        select = block.index("scripts/select-native-xcode.sh")
        gate = block.index("make credential-free-validate")
        self.assertLess(select, gate, "Xcode selection must precede the credential-free gate")

    def test_workflow_selection_command_executes_and_selects_pin(self):
        # Source text alone cannot tell `sh ./scripts/...` from
        # `echo sh ./scripts/...`: extract the exact job command and drive it
        # with shims, proving it selects the pinned Xcode.
        block = credential_free_job_block()
        commands = [line.split("run:", 1)[1].strip()
                    for line in block.splitlines()
                    if "run:" in line and "select-native-xcode.sh" in line]
        self.assertEqual(len(commands), 1,
                         "credential-free job must invoke the selection "
                         f"script exactly once: {commands!r}")
        libssh2, _ = manifest_pins(MANIFEST)
        expected_name = EXPECTED_APP_NAME_BY_BUILD[libssh2]
        with selection_fixture(
                "Xcode_26.6.app",
                f"Xcode 26.5\nBuild version {libssh2}\n",
                fixture_manifest(libssh2)) as fixture:
            result = subprocess.run(
                ["sh", "-c", commands[0]],
                cwd=ROOT, env=fixture.env,
                capture_output=True, text=True)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertEqual(
                fixture.selected_file.read_text(encoding="utf-8"),
                f"{fixture.apps_root}/{expected_name}/Contents/Developer",
                output)
            self.assertIn(f"(Build version {libssh2})", output)

    def test_selection_defaults_to_applications_root(self):
        self.assertIn("xcode_root=${RELUX_XCODE_ROOT:-/Applications}", SCRIPT.read_text(),
                      "hosted runners install Xcode under /Applications; the test-only "
                      "override must never change the production default")

    def test_selection_maps_manifest_pin_to_documented_app(self):
        libssh2, _ = manifest_pins(MANIFEST)
        expected_name = EXPECTED_APP_NAME_BY_BUILD[libssh2]
        exit_code, output, _, selected, apps_root = run_selection_script(
            fixture_manifest(libssh2),
            "Xcode_26.6.app",
            f"Xcode 26.5\nBuild version {libssh2}\n")
        self.assertEqual(exit_code, 0, output)
        self.assertEqual(selected, f"{apps_root}/{expected_name}/Contents/Developer", output)

    def test_selection_is_idempotent_when_already_selected(self):
        libssh2, _ = manifest_pins(MANIFEST)
        expected_name = EXPECTED_APP_NAME_BY_BUILD[libssh2]
        exit_code, output, calls, _, _ = run_selection_script(
            fixture_manifest(libssh2),
            expected_name,
            f"Xcode 26.5\nBuild version {libssh2}\n")
        self.assertEqual(exit_code, 0, output)
        self.assertNotIn("sudo xcode-select -s", calls, output)

    def test_selection_rejects_xcode16_default(self):
        # Mirrors hosted run35091586150: macos-15 default Xcode 16.4 (16F6).
        libssh2, _ = manifest_pins(MANIFEST)
        exit_code, output, _, _, _ = run_selection_script(
            fixture_manifest(libssh2),
            "Xcode_16.4.app",
            "Xcode 16.4\nBuild version 16F6\n")
        self.assertNotEqual(exit_code, 0, output)
        self.assertIn("mismatch", output)

    def test_selection_rejects_macos26_default_build(self):
        # macos-26 default Xcode 26.6 (17F113) is close to but not the pin.
        libssh2, _ = manifest_pins(MANIFEST)
        exit_code, output, _, _, _ = run_selection_script(
            fixture_manifest(libssh2),
            "Xcode_26.6.app",
            "Xcode 26.6\nBuild version 17F113\n")
        self.assertNotEqual(exit_code, 0, output)
        self.assertIn("mismatch", output)

    def test_selection_rejects_build_with_pin_as_prefix(self):
        # The pin must match the complete build value: 17F420 starts with
        # 17F42 but is a different build and must not be attested as the pin.
        libssh2, _ = manifest_pins(MANIFEST)
        exit_code, output, _, _, _ = run_selection_script(
            fixture_manifest(libssh2),
            "Xcode_26.5.app",
            "Xcode 26.5\nBuild version 17F420\n")
        self.assertNotEqual(exit_code, 0, output)
        self.assertIn("mismatch", output)

    def test_selection_refuses_missing_install(self):
        exit_code, output, _, _, _ = run_selection_script(
            fixture_manifest("17F42"),
            "Xcode_26.5.app",
            "Xcode 26.5\nBuild version 17F42\n",
            install_app=False)
        self.assertEqual(exit_code, 2, output)
        self.assertIn("not installed", output)

    def test_selection_refuses_disagreeing_manifest_pins(self):
        exit_code, output, _, _, _ = run_selection_script(
            fixture_manifest("17F42", "17C529"),
            "Xcode_26.5.app",
            "Xcode 26.5\nBuild version 17F42\n")
        self.assertEqual(exit_code, 2, output)
        self.assertIn("17F42", output)
        self.assertIn("17C529", output)

    def test_selection_refuses_unmapped_build(self):
        # Xcode 26.3 (17C529) exists on runners but never produced the artifacts.
        exit_code, output, _, _, _ = run_selection_script(
            fixture_manifest("17C529"),
            "Xcode_26.3.app",
            "Xcode 26.3\nBuild version 17C529\n")
        self.assertEqual(exit_code, 2, output)
        self.assertIn("17C529", output)

    def test_selection_refuses_missing_pin(self):
        fixture = json.dumps({"dependencies": {
            "libssh2-openssl": {"compiler": {"xcode_build": "17F42"}},
            "hev-lwip": {"rebuild": {}}}})
        exit_code, output, _, _, _ = run_selection_script(
            fixture,
            "Xcode_26.5.app",
            "Xcode 26.5\nBuild version 17F42\n")
        self.assertEqual(exit_code, 2, output)


if __name__ == "__main__":
    unittest.main()
