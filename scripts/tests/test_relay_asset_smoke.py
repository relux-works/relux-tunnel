#!/usr/bin/env python3
"""Deterministic tests for the portable relay runtime-boundary gate."""

from __future__ import annotations

import json
import os
import stat
import struct
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path
from unittest import mock

SCRIPT_DIR = Path(__file__).resolve().parents[1]
ROOT = SCRIPT_DIR.parent
sys.path.insert(0, str(SCRIPT_DIR))

import relay_asset_smoke  # noqa: E402
import relay_release  # noqa: E402


class RelayAssetSmokeTests(unittest.TestCase):
    def make_gate(
        self,
        root: Path,
        *,
        target: str | None = None,
        runner_kind: str = "native",
        require_native: bool = False,
        emulator: list[str] | None = None,
    ) -> relay_asset_smoke.SmokeGate:
        return relay_asset_smoke.SmokeGate(
            target=target or relay_asset_smoke.normalized_host_target(),
            runner_kind=runner_kind,
            runner_name="deterministic-test-runner",
            runner_owner="TASK-260715-36gq4m",
            evidence_path=root / "evidence.json",
            emulator=emulator,
            require_native=require_native,
        )

    @staticmethod
    def target_bytes(target: dict[str, str]) -> bytes:
        data = bytearray(64)
        if target["os"] == "linux":
            data[:6] = b"\x7fELF\x02\x01"
            struct.pack_into("<H", data, 18, 62 if target["arch"] == "amd64" else 183)
        else:
            data[:4] = b"\xcf\xfa\xed\xfe"
            struct.pack_into(
                "<I",
                data,
                4,
                0x01000007 if target["arch"] == "amd64" else 0x0100000C,
            )
        return bytes(data)

    def write_release_fixture(self, root: Path) -> Path:
        for target in relay_release.TARGETS:
            filename = relay_release.target_filename(target)
            executable = root / filename
            executable.write_bytes(self.target_bytes(target))
            executable.chmod(0o755)
            (root / f"{filename}.spdx.json").write_text("{}\n", encoding="utf-8")
        manifest = relay_release.build_manifest(
            "1.2.3-test.1",
            "0123456789abcdef0123456789abcdef01234567",
            root,
        )
        manifest_path = root / relay_release.MANIFEST_NAME
        manifest_path.write_bytes(relay_release.stable_json(manifest))
        return manifest_path

    def write_runtime_fixture(self, root: Path, fault: str = "") -> Path:
        target = relay_asset_smoke.normalized_host_target()
        os_name, architecture = target.split("/", 1)
        fixture = root / "fixture-relay.py"
        fixture.write_text(
            textwrap.dedent(
                f"""\
                #!{sys.executable}
                import hashlib, json, os, select, signal, subprocess, sys

                fault = {fault!r}
                signal.signal(signal.SIGTERM, lambda *_: sys.exit(130))
                arguments = sys.argv[1:]
                if arguments == ["--identity", "--protocol", "1"]:
                    digest = hashlib.sha256(open(sys.argv[0], "rb").read()).hexdigest()
                    value = {{
                        "schemaVersion": 1,
                        "relayProtocolVersion": 1,
                        "relayVersion": "1.2.3-test.1",
                        "sourceCommit": "0123456789abcdef0123456789abcdef01234567",
                        "os": {os_name!r},
                        "arch": {architecture!r},
                        "selfSha256": digest,
                    }}
                    sys.stdout.write(json.dumps(value, separators=(",", ":")) + "\\n")
                    if fault == "identity":
                        sys.stderr.write("relux-relay: identity rejected\\n")
                    raise SystemExit(0)
                if arguments == ["--stdio", "--protocol", "1"]:
                    hello = sys.stdin.buffer.read(12)
                    if hello[:4] != b"RLXR":
                        sys.stdout.buffer.write(b"RLXR\\x00\\x01\\x00\\x02" + b"\\x00" * 8)
                        sys.stdout.buffer.flush()
                        sys.stderr.write("relux-relay: protocol rejected\\n")
                        raise SystemExit(65)
                    sys.stdout.buffer.write(b"RLXR\\x00\\x01" + b"\\x00" * 6 + b"\\x00\\x00\\x10\\x00")
                    if fault == "stdout":
                        sys.stdout.buffer.write(b"payload-contamination")
                    if fault == "stderr":
                        sys.stderr.write("secret.example payload\\n")
                    if fault == "file":
                        os.chmod(os.getcwd(), 0o755)
                        open("runtime-residue", "wb").write(b"forbidden")
                    if fault == "external-file":
                        open(os.environ["RELUX_SMOKE_EXTERNAL_WRITE_PROBE"], "wb").write(b"forbidden")
                    if fault == "detached":
                        subprocess.Popen(
                            [
                                sys.executable,
                                "-c",
                                "import os,time; time.sleep(.2); open(os.environ['RELUX_SMOKE_EXTERNAL_WRITE_PROBE'],'wb').write(b'x'); time.sleep(30)",
                                "relux-smoke-detached-fixture",
                            ],
                            start_new_session=True,
                        )
                    sys.stdout.buffer.flush()
                    sys.stderr.flush()
                    readable, _, _ = select.select([sys.stdin.buffer], [], [], 0.15)
                    if fault == "child" and not readable:
                        subprocess.Popen(["/bin/sleep", "30"])
                    sys.stdin.buffer.read()
                    raise SystemExit(0)
                if fault == "unsupported" and arguments[0:1] == ["--daemon"]:
                    raise SystemExit(0)
                sys.stderr.write("relux-relay: unsupported invocation\\n")
                raise SystemExit(64)
                """
            ),
            encoding="utf-8",
        )
        fixture.chmod(0o755)
        return fixture

    def test_all_four_asset_formats_and_manifest_bindings(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            release = Path(temporary)
            manifest_path = self.write_release_fixture(release)
            for target in relay_release.TARGETS:
                target_name = f"{target['os']}/{target['arch']}"
                gate = self.make_gate(release, target=target_name)
                manifest = gate.validate_asset(
                    release / relay_release.target_filename(target), manifest_path
                )
                self.assertEqual(manifest["relayProtocolVersion"], 1)
                self.assertEqual(
                    gate.report["artifact"]["canonicalTarget"],
                    target["canonicalTarget"],
                )

    def test_manifest_size_hash_architecture_and_symlink_tampering_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            release = Path(temporary)
            manifest_path = self.write_release_fixture(release)
            target = relay_release.TARGETS[0]
            target_name = f"{target['os']}/{target['arch']}"
            executable = release / relay_release.target_filename(target)

            original = executable.read_bytes()
            executable.write_bytes(original + b"tampered")
            with self.assertRaisesRegex(
                relay_asset_smoke.GateFailure, "asset_manifest"
            ):
                self.make_gate(release, target=target_name).validate_asset(
                    executable, manifest_path
                )

            executable.write_bytes(original)
            changed = bytearray(original)
            changed[4] ^= 1
            executable.write_bytes(changed)
            changed_manifest = relay_release.build_manifest(
                "1.2.3-test.1",
                "0123456789abcdef0123456789abcdef01234567",
                release,
            )
            manifest_path.write_bytes(relay_release.stable_json(changed_manifest))
            with self.assertRaisesRegex(
                relay_asset_smoke.GateFailure, "architecture_mismatch"
            ):
                self.make_gate(release, target=target_name).validate_asset(
                    executable, manifest_path
                )

            executable.unlink()
            executable.symlink_to(
                release / relay_release.target_filename(relay_release.TARGETS[1])
            )
            with self.assertRaises(relay_asset_smoke.GateFailure):
                self.make_gate(release, target=target_name).validate_asset(
                    executable, manifest_path
                )

            executable.unlink()
            executable.write_bytes(b"")
            executable.chmod(0o755)
            with self.assertRaises(relay_asset_smoke.GateFailure):
                self.make_gate(release, target=target_name).validate_asset(
                    executable, manifest_path
                )

            executable.write_bytes(original)
            executable.chmod(0o644)
            manifest_path.write_bytes(
                relay_release.stable_json(
                    relay_release.build_manifest(
                        "1.2.3-test.1",
                        "0123456789abcdef0123456789abcdef01234567",
                        release,
                    )
                )
            )
            with self.assertRaises(relay_asset_smoke.GateFailure):
                self.make_gate(release, target=target_name).validate_asset(
                    executable, manifest_path
                )

    def test_runtime_boundary_passes_with_clean_fixture(self) -> None:
        if os.geteuid() == 0:
            self.skipTest("runtime contract intentionally rejects root")
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            executable = self.write_runtime_fixture(root)
            gate = self.make_gate(root)
            gate.validate_runner()
            with (
                mock.patch.object(
                    relay_asset_smoke.relay_release,
                    "verify_identity_against_manifest",
                ),
                mock.patch.object(
                    relay_asset_smoke, "process_sockets", return_value=[]
                ),
                mock.patch.object(
                    relay_asset_smoke, "direct_children", return_value=[]
                ),
            ):
                gate.exercise_runtime(executable, root / "manifest.json")
            check_names = {check["name"] for check in gate.report["checks"]}
            self.assertTrue(
                {
                    "identity-and-self-hash",
                    "stdio-eof-and-stdout-framing",
                    "stderr-redaction",
                    "unsupported-daemon",
                    "unsupported-listener",
                    "unsupported-payload",
                    "unsupported-version",
                    "no-child-processes",
                    "no-listeners-or-sockets",
                    "signal-exit",
                    "runtime-cleanup",
                }.issubset(check_names)
            )
            self.assertFalse(any(root.glob("runtime-*")))

    def test_signal_exit_is_repeatably_termination_owned(self) -> None:
        if os.geteuid() == 0:
            self.skipTest("runtime contract intentionally rejects root")
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            executable = self.write_runtime_fixture(root)
            gate = self.make_gate(root)
            working = root / "cwd"
            home = root / "home"
            temporary_dir = root / "tmp"
            for directory in (working, home, temporary_dir):
                directory.mkdir()
            environment = gate.runtime_environment(home, temporary_dir)
            with (
                mock.patch.object(
                    relay_asset_smoke, "process_sockets", return_value=[]
                ),
                mock.patch.object(
                    relay_asset_smoke, "direct_children", return_value=[]
                ),
            ):
                for _ in range(8):
                    gate.signal_smoke(executable, working, environment)
            exits = [
                check["exitCode"]
                for check in gate.report["checks"]
                if check["name"] == "signal-exit"
            ]
            self.assertEqual(exits, [130] * 8)

    def test_stdout_stderr_and_unsupported_contamination_fail_closed(self) -> None:
        if os.geteuid() == 0:
            self.skipTest("runtime contract intentionally rejects root")
        for fault, expected in (
            ("stdout", "stdio-eof-and-stdout-framing_contract_mismatch"),
            ("stderr", "stdio-eof-and-stdout-framing_contract_mismatch"),
            ("unsupported", "unsupported-daemon_contract_mismatch"),
        ):
            with self.subTest(fault=fault), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                executable = self.write_runtime_fixture(root, fault)
                gate = self.make_gate(root)
                with (
                    mock.patch.object(
                        relay_asset_smoke.relay_release,
                        "verify_identity_against_manifest",
                    ),
                    mock.patch.object(
                        relay_asset_smoke, "process_sockets", return_value=[]
                    ),
                    mock.patch.object(
                        relay_asset_smoke, "direct_children", return_value=[]
                    ),
                    self.assertRaisesRegex(relay_asset_smoke.GateFailure, expected),
                ):
                    gate.exercise_runtime(executable, root / "manifest.json")
                self.assertFalse(any(root.glob("runtime-*")))

    def test_runtime_file_and_cleanup_failures_are_detected(self) -> None:
        if os.geteuid() == 0:
            self.skipTest("runtime contract intentionally rejects root")
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            executable = self.write_runtime_fixture(root, "file")
            gate = self.make_gate(root)
            with (
                mock.patch.object(
                    relay_asset_smoke.relay_release,
                    "verify_identity_against_manifest",
                ),
                mock.patch.object(
                    relay_asset_smoke, "process_sockets", return_value=[]
                ),
                mock.patch.object(
                    relay_asset_smoke, "direct_children", return_value=[]
                ),
                self.assertRaisesRegex(
                    relay_asset_smoke.GateFailure,
                    "stdio-eof-and-stdout-framing_contract_mismatch",
                ),
            ):
                gate.exercise_runtime(executable, root / "manifest.json")

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            executable = self.write_runtime_fixture(root)
            gate = self.make_gate(root)
            with (
                mock.patch.object(
                    relay_asset_smoke.relay_release,
                    "verify_identity_against_manifest",
                ),
                mock.patch.object(
                    relay_asset_smoke, "process_sockets", return_value=[]
                ),
                mock.patch.object(
                    relay_asset_smoke, "direct_children", return_value=[]
                ),
                mock.patch.object(
                    relay_asset_smoke.shutil,
                    "rmtree",
                    side_effect=OSError("injected cleanup failure"),
                ),
                self.assertRaisesRegex(
                    relay_asset_smoke.GateFailure, "runtime_cleanup_failed"
                ),
            ):
                gate.exercise_runtime(executable, root / "manifest.json")

    def test_child_and_socket_observers_are_red_gates(self) -> None:
        if os.geteuid() == 0:
            self.skipTest("runtime contract intentionally rejects root")
        for observer, expected in (
            ("direct_children", "child_process_detected"),
            ("process_sockets", "runtime_socket_detected"),
        ):
            with (
                self.subTest(observer=observer),
                tempfile.TemporaryDirectory() as temporary,
            ):
                root = Path(temporary)
                executable = self.write_runtime_fixture(root)
                gate = self.make_gate(root)
                children = [999] if observer == "direct_children" else []
                sockets = ["socket"] if observer == "process_sockets" else []
                with (
                    mock.patch.object(
                        relay_asset_smoke.relay_release,
                        "verify_identity_against_manifest",
                    ),
                    mock.patch.object(
                        relay_asset_smoke, "direct_children", return_value=children
                    ),
                    mock.patch.object(
                        relay_asset_smoke, "process_sockets", return_value=sockets
                    ),
                    self.assertRaisesRegex(relay_asset_smoke.GateFailure, expected),
                ):
                    gate.exercise_runtime(executable, root / "manifest.json")

    def test_detached_descendant_and_external_write_are_contained(self) -> None:
        if os.geteuid() == 0:
            self.skipTest("runtime contract intentionally rejects root")
        for fault in ("detached", "external-file"):
            with self.subTest(fault=fault), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                executable = self.write_runtime_fixture(root, fault)
                gate = self.make_gate(root)
                with (
                    mock.patch.object(
                        relay_asset_smoke.relay_release,
                        "verify_identity_against_manifest",
                    ),
                    self.assertRaisesRegex(
                        relay_asset_smoke.GateFailure,
                        "stdio-eof-and-stdout-framing_contract_mismatch",
                    ),
                ):
                    gate.exercise_runtime(executable, root / "manifest.json")
                self.assertFalse(any(root.glob("runtime-*-outside-write")))
                process_table = subprocess.run(
                    ["/bin/ps", "-Ao", "command="],
                    check=True,
                    stdout=subprocess.PIPE,
                    text=True,
                    env={"PATH": "/usr/bin:/bin", "LC_ALL": "C", "LANG": "C"},
                ).stdout
                self.assertNotIn("relux-smoke-detached-fixture", process_table)
                failed = next(
                    check
                    for check in gate.report["checks"]
                    if check["name"] == "stdio-eof-and-stdout-framing"
                    and check["status"] == "fail"
                )
                self.assertTrue(failed["processStarted"])
                self.assertIsNotNone(failed["exitCode"])

    def test_subprocess_failures_preserve_exit_code_and_check_record(self) -> None:
        if os.geteuid() == 0:
            self.skipTest("runtime contract intentionally rejects root")
        for fault, check_name, expected_exit in (
            ("stdout", "stdio-eof-and-stdout-framing", 0),
            ("identity", "identity-and-self-hash", 0),
        ):
            with self.subTest(fault=fault), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                executable = self.write_runtime_fixture(root, fault)
                gate = self.make_gate(root)
                with (
                    mock.patch.object(
                        relay_asset_smoke.relay_release,
                        "verify_identity_against_manifest",
                    ),
                    self.assertRaises(relay_asset_smoke.GateFailure),
                ):
                    gate.exercise_runtime(executable, root / "manifest.json")
                failed = next(
                    check
                    for check in gate.report["checks"]
                    if check["name"] == check_name and check["status"] == "fail"
                )
                self.assertEqual(failed["exitCode"], expected_exit)
                self.assertTrue(failed["processStarted"])

    def test_native_and_emulated_reports_are_path_free_and_bounded(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            private_path = "/Users/reviewer/private/secret-relay"
            invalid = relay_asset_smoke.SmokeGate(
                target=relay_asset_smoke.normalized_host_target(),
                runner_kind="emulated",
                runner_name=private_path,
                runner_owner="TASK-260715-36gq4m",
                evidence_path=root / "invalid.json",
                emulator=[private_path, "x" * 200],
            )
            with self.assertRaisesRegex(
                relay_asset_smoke.GateFailure, "runner_metadata_invalid"
            ):
                invalid.validate_runner()
            invalid.finish("fail", private_path)
            invalid_text = (root / "invalid.json").read_text(encoding="utf-8")
            self.assertNotIn(private_path, invalid_text)
            self.assertLessEqual(
                len(invalid_text.encode()), relay_asset_smoke.MAX_REPORT_BYTES
            )
            self.assertEqual(
                json.loads(invalid_text)["errorCode"], "internal_gate_failure"
            )

            native = self.make_gate(root)
            native.evidence_path = root / "native.json"
            native.record(
                "identity-and-self-hash",
                native.started,
                "pass",
                0,
                [private_path, "--identity", "--protocol", "1"],
                True,
            )
            native.finish("pass")
            native_text = (root / "native.json").read_text(encoding="utf-8")
            self.assertNotIn(private_path, native_text)
            self.assertEqual(
                json.loads(native_text)["checks"][0]["command"],
                ["relay", "--identity", "--protocol", "1"],
            )

            emulated = self.make_gate(
                root,
                runner_kind="emulated",
                emulator=[private_path, "-x86_64"],
            )
            command = [
                private_path,
                "-x86_64",
                "/tmp/private/executable",
                "--identity",
                "--protocol",
                "1",
            ]
            emulated.record(
                "identity-and-self-hash",
                emulated.started,
                "pass",
                0,
                command,
                True,
            )
            emulated.finish("pass")
            emulated_text = (root / "evidence.json").read_text(encoding="utf-8")
            report = json.loads(emulated_text)
            self.assertNotIn(private_path, emulated_text)
            self.assertNotIn("/tmp/private", emulated_text)
            self.assertEqual(
                report["checks"][0]["command"],
                ["emulator", "relay", "--identity", "--protocol", "1"],
            )
            self.assertLessEqual(
                len(emulated_text.encode()), relay_asset_smoke.MAX_REPORT_BYTES
            )

            oversized = self.make_gate(root)
            oversized.evidence_path = root / "oversized.json"
            oversized.report["injected"] = "x" * (
                relay_asset_smoke.MAX_REPORT_BYTES * 2
            )
            oversized.finish("pass")
            bounded = json.loads((root / "oversized.json").read_text(encoding="utf-8"))
            self.assertEqual(bounded["status"], "fail")
            self.assertEqual(bounded["errorCode"], "report_size_limit_exceeded")

    def test_linux_containment_builds_landlock_and_seccomp_filters(self) -> None:
        class FakeFunction:
            def __init__(self, results: list[int]):
                self.results = iter(results)
                self.calls: list[tuple[object, ...]] = []
                self.restype = None

            def __call__(self, *arguments: object) -> int:
                self.calls.append(arguments)
                return next(self.results)

        class FakeLibc:
            def __init__(self) -> None:
                self.syscall = FakeFunction([6, 9, 0])
                self.prctl = FakeFunction([0, 0])

        for architecture in ("x86_64", "aarch64"):
            with self.subTest(architecture=architecture):
                fake = FakeLibc()
                with (
                    mock.patch.object(
                        relay_asset_smoke.ctypes, "CDLL", return_value=fake
                    ),
                    mock.patch.object(
                        relay_asset_smoke.platform,
                        "machine",
                        return_value=architecture,
                    ),
                    mock.patch.object(relay_asset_smoke.os, "close") as close,
                ):
                    relay_asset_smoke._linux_containment_preexec()
                self.assertEqual(len(fake.syscall.calls), 3)
                self.assertEqual(len(fake.prctl.calls), 2)
                close.assert_called_once_with(9)

        with (
            mock.patch.object(relay_asset_smoke.sys, "platform", "unsupported"),
            self.assertRaisesRegex(
                relay_asset_smoke.GateFailure, "runtime_containment_unsupported"
            ),
        ):
            relay_asset_smoke.contained_process_options(["relay"])

    def test_missing_native_runner_is_explicit_red_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            gate = self.make_gate(
                root,
                runner_kind="emulated",
                require_native=True,
                emulator=["arch", "-x86_64"],
            )
            with self.assertRaisesRegex(
                relay_asset_smoke.GateFailure, "required_native_runner_missing"
            ):
                gate.validate_runner()
            gate.finish("fail", "required_native_runner_missing")
            report = json.loads((root / "evidence.json").read_text(encoding="utf-8"))
            self.assertFalse(report["nativeEvidence"]["satisfied"])
            self.assertEqual(report["nativeEvidence"]["owner"], "TASK-260715-36gq4m")
            self.assertNotIn(str(root), json.dumps(report))

    def test_runner_identity_privilege_and_emulator_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with (
                mock.patch.object(relay_asset_smoke.os, "geteuid", return_value=0),
                self.assertRaisesRegex(
                    relay_asset_smoke.GateFailure, "privileged_runner_forbidden"
                ),
            ):
                self.make_gate(root).validate_runner()

            foreign = "linux/amd64"
            if foreign == relay_asset_smoke.normalized_host_target():
                foreign = "darwin/arm64"
            with self.assertRaisesRegex(
                relay_asset_smoke.GateFailure, "native_runner_identity_mismatch"
            ):
                self.make_gate(root, target=foreign).validate_runner()

            with self.assertRaisesRegex(
                relay_asset_smoke.GateFailure, "emulator_command_required"
            ):
                self.make_gate(root, runner_kind="emulated").validate_runner()

    def test_process_and_socket_observers_exercise_host_implementation(self) -> None:
        process = subprocess.Popen(["/bin/sleep", "5"], start_new_session=True)
        try:
            self.assertIn(process.pid, relay_asset_smoke.direct_children(os.getpid()))
            self.assertEqual(relay_asset_smoke.process_sockets(process.pid), [])
            self.assertFalse(relay_asset_smoke.no_process(process.pid))
        finally:
            relay_asset_smoke.terminate_process_group(process)
        self.assertTrue(relay_asset_smoke.no_process(process.pid))
        relay_asset_smoke.terminate_process_group(process)

    def test_run_gate_writes_pass_and_privacy_safe_failure_reports(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            arguments = mock.Mock(
                target=relay_asset_smoke.normalized_host_target(),
                runner_kind="native",
                runner_name="unit-runner",
                runner_owner="TASK-260715-36gq4m",
                evidence=str(root / "pass.json"),
                emulator=[],
                require_native=True,
                executable=str(root / "relay"),
                manifest=str(root / "manifest.json"),
            )
            with (
                mock.patch.object(relay_asset_smoke.SmokeGate, "validate_asset"),
                mock.patch.object(relay_asset_smoke.SmokeGate, "exercise_runtime"),
            ):
                self.assertEqual(relay_asset_smoke.run_gate(arguments), 0)
            passed = json.loads((root / "pass.json").read_text(encoding="utf-8"))
            self.assertEqual(passed["status"], "pass")

            arguments.evidence = str(root / "fail.json")
            with mock.patch.object(
                relay_asset_smoke.SmokeGate,
                "validate_asset",
                side_effect=relay_asset_smoke.GateFailure("manifest_fixture_failure"),
            ):
                self.assertEqual(relay_asset_smoke.run_gate(arguments), 1)
            failed_text = (root / "fail.json").read_text(encoding="utf-8")
            failed = json.loads(failed_text)
            self.assertEqual(failed["errorCode"], "manifest_fixture_failure")
            self.assertNotIn(str(root), failed_text)

    def test_parser_preserves_explicit_emulation_identity(self) -> None:
        arguments = relay_asset_smoke.parser().parse_args(
            [
                "--target",
                "darwin/amd64",
                "--runner-kind",
                "emulated",
                "--runner-name",
                "local-rosetta",
                "--runner-owner",
                "TASK-260715-36gq4m",
                "--emulator=arch",
                "--emulator=-x86_64",
                "--manifest",
                "manifest.json",
                "--executable",
                "relux-relay-darwin-amd64",
                "--evidence",
                "report.json",
            ]
        )
        self.assertEqual(arguments.runner_kind, "emulated")
        self.assertEqual(arguments.emulator, ["arch", "-x86_64"])

    def test_ci_declares_four_native_rows_and_retains_exact_outputs(self) -> None:
        workflow = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
        for literal in (
            "target: darwin/amd64",
            "target: darwin/arm64",
            "target: linux/amd64",
            "target: linux/arm64",
            "runner: macos-15-intel",
            "runner: macos-15",
            "runner: ubuntu-24.04",
            "runner: ubuntu-24.04-arm",
            "python3 -W error::ResourceWarning -m unittest scripts/tests/test_relay_asset_smoke.py",
            "python3 scripts/relay_asset_smoke.py",
            "--require-native",
            "runtime-evidence-${{ matrix.slug }}-${{ github.run_id }}",
            "relux-relay-${{ matrix.slug }}",
        ):
            self.assertIn(literal, workflow)
        self.assertIn("fail-fast: false", workflow)


if __name__ == "__main__":
    unittest.main()
