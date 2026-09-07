from __future__ import annotations

import copy
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPOSITORY_ROOT / "scripts/validate-m0-production-bindings.py"
MANIFEST = (
    REPOSITORY_ROOT
    / "Configuration/TASK-260720-1qhxqa_m0-production-bindings-v1.json"
)


class M0ProductionBindingsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.resources = self.root / "resources"
        self.manifest = self.root / "bindings.json"
        self.board_state = self.root / "board-state.json"
        self.data = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self._copy_accepted_resources()
        self.write_board_state()
        self.write_manifest()

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def _copy_accepted_resources(self) -> None:
        board_dir = Path(
            os.environ.get("TASK_BOARD_DIR", REPOSITORY_ROOT / ".task-board")
        )
        source_root = Path(
            os.environ.get("TASK_BOARD_RESOURCES", board_dir / ".resources")
        )
        bindings: list[tuple[str, dict[str, object]]] = []
        runtime = self.data["runtimeContract"]
        bindings.append((runtime["taskId"], runtime))
        bindings.append((runtime["taskId"], runtime["reviewerVerdict"]))
        for item in self.data["acceptedInputs"]:
            bindings.append((item["taskId"], item["acceptedOutcome"]))
            bindings.append((item["taskId"], item["reviewerVerdict"]))
        for task_id, resource in bindings:
            source = source_root / task_id / resource["resourceName"]
            if not source.is_file():
                self.fail(f"accepted board resource unavailable: {source}")
            destination = self.resources / task_id / resource["resourceName"]
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)

    def write_manifest(self) -> None:
        self.manifest.write_text(
            json.dumps(self.data, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )

    def write_board_state(self) -> None:
        rows = []
        runtime = self.data["runtimeContract"]
        rows.append(
            {
                "id": runtime["taskId"],
                "status": "done",
                "outcomeResources": [
                    {"name": runtime["resourceName"]},
                    {"name": runtime["reviewerVerdict"]["resourceName"]},
                ],
            }
        )
        for item in self.data["acceptedInputs"]:
            rows.append(
                {
                    "id": item["taskId"],
                    "status": "done",
                    "outcomeResources": [
                        {"name": item["acceptedOutcome"]["resourceName"]},
                        {"name": item["reviewerVerdict"]["resourceName"]},
                    ],
                }
            )
        self.board_state.write_text(json.dumps(rows), encoding="utf-8")

    def run_validator(self, repository_root: Path = REPOSITORY_ROOT) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
        process = subprocess.run(
            [
                "python3",
                str(SCRIPT),
                "--manifest",
                str(self.manifest),
                "--resources-root",
                str(self.resources),
                "--repository-root",
                str(repository_root),
                "--board-state",
                str(self.board_state),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        return process, json.loads(process.stdout)

    def assert_refused(self, report: dict[str, object]) -> None:
        self.assertFalse(report["productionCompositionPermitted"])
        self.assertTrue(report["failures"])

    def copy_repository_fixture(self, name: str) -> Path:
        repository = self.root / name
        fixture_files = [
            "Project.swift",
            "Package.swift",
            "NativeDependencies/manifest.json",
            "Dependencies/ReluxLibSSH2/PATCH_MANIFEST.json",
            "Dependencies/ReluxLibSSH2/patches/0001-public-client-rekey.patch",
            "NativeDependencies/Artifacts/ReluxLibSSH2.xcframework/ios-arm64/Headers/libssh2.h",
            "NativeDependencies/Artifacts/ReluxLibSSH2.xcframework/ios-arm64_x86_64-simulator/Headers/libssh2.h",
            "NativeDependencies/Artifacts/ReluxLibSSH2.xcframework/macos-arm64_x86_64/Headers/libssh2.h",
        ]
        packet_pins = self.data["acceptedInputs"][1]["sourceOrBinaryPins"]
        fixture_files.extend(
            "NativeDependencies/Artifacts/HevSocks5Tunnel.xcframework/" + relative
            for relative in packet_pins["artifactFileSha256"]
        )
        for relative in fixture_files:
            destination = repository / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes((REPOSITORY_ROOT / relative).read_bytes())
        shutil.copytree(
            REPOSITORY_ROOT / "Dependencies/ReluxNIOSSH",
            repository / "Dependencies/ReluxNIOSSH",
            ignore=shutil.ignore_patterns(".build", ".swiftpm"),
        )
        return repository

    def test_production_entry_point_rejects_hev_artifact_byte_drift(self) -> None:
        repository = self.copy_repository_fixture("hev-artifact-byte-drift")
        path = (
            repository
            / "NativeDependencies/Artifacts/HevSocks5Tunnel.xcframework"
            / "macos-arm64_x86_64/libhev-socks5-tunnel.a"
        )
        path.write_bytes(path.read_bytes() + b"reviewer-byte-drift")

        process, report = self.run_validator(repository)

        self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
        self.assert_refused(report)
        self.assertEqual(report["failures"][0]["row"], "REPOSITORY-HEV-PIN")
        self.assertIn("artifact bytes drift", report["failures"][0]["detail"])

    def test_production_entry_point_rejects_hev_artifact_lock_drift(self) -> None:
        repository = self.copy_repository_fixture("hev-artifact-lock-drift")
        path = repository / "NativeDependencies/manifest.json"
        manifest = json.loads(path.read_text(encoding="utf-8"))
        file_pins = manifest["dependencies"]["hev-lwip"]["artifact"]["file_sha256"]
        file_pins["macos-arm64_x86_64/libhev-socks5-tunnel.a"] = "0" * 64
        path.write_text(json.dumps(manifest), encoding="utf-8")

        process, report = self.run_validator(repository)

        self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
        self.assert_refused(report)
        self.assertEqual(report["failures"][0]["row"], "REPOSITORY-HEV-PIN")
        self.assertIn("artifact lock drift", report["failures"][0]["detail"])

    def test_production_entry_point_rejects_hev_artifact_file_set_drift(self) -> None:
        for mutation in ("missing", "extra"):
            with self.subTest(mutation=mutation):
                repository = self.copy_repository_fixture(f"hev-artifact-{mutation}")
                artifact = (
                    repository
                    / "NativeDependencies/Artifacts/HevSocks5Tunnel.xcframework"
                )
                if mutation == "missing":
                    (artifact / "ios-arm64/libhev-socks5-tunnel.a").unlink()
                else:
                    (artifact / "unexpected-production-input").write_bytes(b"unexpected")

                process, report = self.run_validator(repository)

                self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
                self.assert_refused(report)
                self.assertEqual(report["failures"][0]["row"], "REPOSITORY-HEV-PIN")
                self.assertIn("artifact file set drift", report["failures"][0]["detail"])

    def test_production_entry_point_rejects_missing_malformed_or_duplicate_hev_locks(
        self,
    ) -> None:
        for mutation in ("missing", "malformed", "duplicate"):
            with self.subTest(mutation=mutation):
                repository = self.copy_repository_fixture(f"hev-lock-{mutation}")
                path = repository / "NativeDependencies/manifest.json"
                if mutation == "duplicate":
                    text = path.read_text(encoding="utf-8")
                    marker = '"file_sha256": {'
                    hev_offset = text.index('"hev-lwip": {')
                    lock_offset = text.index(marker, hev_offset)
                    path.write_text(
                        text[:lock_offset]
                        + '"file_sha256": {},\n        '
                        + text[lock_offset:],
                        encoding="utf-8",
                    )
                else:
                    manifest = json.loads(path.read_text(encoding="utf-8"))
                    artifact = manifest["dependencies"]["hev-lwip"]["artifact"]
                    if mutation == "missing":
                        del artifact["file_sha256"]
                    else:
                        artifact["file_sha256"] = []
                    path.write_text(json.dumps(manifest), encoding="utf-8")

                process, report = self.run_validator(repository)

                self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
                self.assert_refused(report)
                expected_row = (
                    "REPOSITORY-NATIVE-MANIFEST"
                    if mutation == "duplicate"
                    else "REPOSITORY-HEV-PIN"
                )
                self.assertEqual(report["failures"][0]["row"], expected_row)

    def insert_target_dependency(
        self, path: Path, target: str, dependency_expression: str
    ) -> None:
        text = path.read_text(encoding="utf-8")
        declaration = re.search(
            rf'\.target\s*\(\s*name:\s*"{re.escape(target)}"\s*,', text
        )
        self.assertIsNotNone(declaration)
        target_start = declaration.start()
        dependencies_start = text.find("dependencies: [", target_start)
        self.assertNotEqual(dependencies_start, -1)
        insertion = text.find("\n", dependencies_start) + 1
        text = text[:insertion] + f"        {dependency_expression},\n" + text[insertion:]
        path.write_text(text, encoding="utf-8")

    def test_production_entry_point_accepts_exact_current_bindings(self) -> None:
        process, report = self.run_validator()
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        self.assertTrue(report["productionCompositionPermitted"])
        self.assertEqual(report["failures"], [])

    def test_manifest_preserves_every_selected_m0_value_without_tuning(self) -> None:
        inputs = {item["kind"]: item for item in self.data["acceptedInputs"]}
        graph = inputs["generatedProjectArchitecture"]["bindings"]
        self.assertEqual(graph["providerDirectDependencies"], ["ReluxTunnelMacOSAdapter"])
        self.assertEqual(
            graph["macOSAdapterDirectDependencies"],
            ["ReluxTunnelCore", "ReluxTunnelLibSSH2Adapter", "ReluxTunnelNativeAdapter"],
        )

        packet = inputs["packetBridgeAndHEV"]["bindings"]
        self.assertEqual(
            {
                "mtu": packet["mtuBytes"],
                "send": packet["socketSendBufferRequestedBytes"],
                "receive": packet["socketReceiveBufferRequestedBytes"],
                "packets": packet["pumpPacketBudget"],
                "milliseconds": packet["pumpTimeBudgetMilliseconds"],
                "stack": packet["hevTaskStackBytes"],
                "tcp": packet["hevTCPBufferBytesPerSession"],
                "udpCopies": packet["hevUDPCopyBufferCount"],
                "sessions": packet["hevMaximumSessionCount"],
            },
            {
                "mtu": 1500,
                "send": 32768,
                "receive": 32768,
                "packets": 64,
                "milliseconds": 5,
                "stack": 24576,
                "tcp": 4096,
                "udpCopies": 2,
                "sessions": 500,
            },
        )
        self.assertTrue(packet["forkDisposition"].startswith("rejected"))

        ssh = inputs["sshEngine"]["bindings"]
        self.assertEqual(ssh["initialReceiveWindowBytes"], {
            "minimum": 32768, "maximum": 65536, "acceptedM0Value": 65536
        })
        self.assertEqual(
            ssh["rekeyProtectedBytesPerDirection"],
            {"minimum": 4096, "maximum": 5368709120},
        )
        self.assertEqual(
            ssh["rekeyElapsedMilliseconds"], {"minimum": 100, "maximum": 3600000}
        )
        self.assertEqual(ssh["rekeyCompletionTimeoutMilliseconds"], 10000)

    def test_production_entry_point_rejects_narrowed_values_and_obligations(self) -> None:
        packet = self.data["acceptedInputs"][1]
        packet["bindings"]["mtuBytes"] = 1501
        packet["bindings"]["pumpPacketBudget"] = 1
        packet["licenseAndMaintenanceObligations"][0] = "no notices required"
        self.data["compatibilityChecks"][5]["condition"] = "unchecked"
        self.write_manifest()

        process, report = self.run_validator()

        self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
        self.assert_refused(report)
        self.assertEqual(report["failures"][0]["row"], "NORMALIZED-CONTRACT")

    def test_changed_upstream_resource_cannot_silently_retain_permission(self) -> None:
        item = self.data["acceptedInputs"][1]
        path = self.resources / item["taskId"] / item["acceptedOutcome"]["resourceName"]
        path.write_text("changed accepted outcome bytes\n", encoding="utf-8")
        process, report = self.run_validator()
        self.assertEqual(process.returncode, 1)
        self.assert_refused(report)
        self.assertIn("SHA-256 mismatch", report["failures"][0]["detail"])

    def test_changed_upstream_resource_with_rebound_manifest_digest_is_rejected(self) -> None:
        item = self.data["acceptedInputs"][1]
        path = self.resources / item["taskId"] / item["acceptedOutcome"]["resourceName"]
        path.write_text("changed accepted outcome bytes\n", encoding="utf-8")
        item["acceptedOutcome"]["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        self.write_manifest()

        process, report = self.run_validator()

        self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
        self.assert_refused(report)
        self.assertEqual(report["failures"][0]["row"], "NORMALIZED-CONTRACT")

    def test_absent_evidence_is_reported_as_missing(self) -> None:
        item = self.data["acceptedInputs"][0]
        path = self.resources / item["taskId"] / item["reviewerVerdict"]["resourceName"]
        path.unlink()
        process, report = self.run_validator()
        self.assertEqual(process.returncode, 1)
        self.assert_refused(report)
        self.assertIn("accepted resource missing", report["failures"][0]["detail"])

    def test_malformed_manifest_is_unknown_not_absent(self) -> None:
        self.manifest.write_text("{not-json", encoding="utf-8")
        process, report = self.run_validator()
        self.assertEqual(process.returncode, 1)
        self.assert_refused(report)
        self.assertEqual(report["failures"][0]["row"], "UNREADABLE-OR-MALFORMED")

    def test_production_entry_point_rejects_duplicate_manifest_keys(self) -> None:
        text = self.manifest.read_text(encoding="utf-8")
        self.manifest.write_text(
            text.replace("{\n", '{\n  "schemaVersion": 999,\n', 1),
            encoding="utf-8",
        )

        process, report = self.run_validator()

        self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
        self.assert_refused(report)
        self.assertEqual(report["failures"][0]["row"], "MANIFEST-JSON")
        self.assertIn("duplicate JSON key 'schemaVersion'", report["failures"][0]["detail"])

    def test_production_entry_point_rejects_duplicate_board_state_keys(self) -> None:
        text = self.board_state.read_text(encoding="utf-8")
        self.board_state.write_text(
            text.replace('"status": "done"', '"status": "analysis", "status": "done"', 1),
            encoding="utf-8",
        )

        process, report = self.run_validator()

        self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
        self.assert_refused(report)
        self.assertEqual(report["failures"][0]["row"], "BOARD-STATE")
        self.assertIn("duplicate JSON key 'status'", report["failures"][0]["detail"])

    def test_superseded_evidence_is_rejected(self) -> None:
        self.data["acceptedInputs"][2]["supersession"] = {
            "status": "superseded",
            "supersededBy": "TASK-999999-replacement_results.md",
        }
        self.write_manifest()
        process, report = self.run_validator()
        self.assertEqual(process.returncode, 1)
        self.assert_refused(report)
        self.assertIn("stale or superseded", report["failures"][0]["detail"])

    def test_reopened_or_undeclared_board_evidence_is_rejected(self) -> None:
        board_state = json.loads(self.board_state.read_text(encoding="utf-8"))
        for mutation in ("reopened", "undeclared"):
            with self.subTest(mutation=mutation):
                candidate = copy.deepcopy(board_state)
                if mutation == "reopened":
                    candidate[1]["status"] = "analysis"
                else:
                    candidate[2]["outcomeResources"].pop()
                self.board_state.write_text(json.dumps(candidate), encoding="utf-8")
                process, report = self.run_validator()
                self.assertEqual(process.returncode, 1)
                self.assert_refused(report)
                self.assertEqual(report["failures"][0]["row"], "BOARD-STATE")

    def test_unknown_field_and_schema_version_are_rejected(self) -> None:
        for mutation in ("field", "schema"):
            with self.subTest(mutation=mutation):
                candidate = copy.deepcopy(self.data)
                if mutation == "field":
                    candidate["permitIfTwoInputsPass"] = True
                else:
                    candidate["schemaVersion"] = 2
                self.manifest.write_text(json.dumps(candidate), encoding="utf-8")
                process, report = self.run_validator()
                self.assertEqual(process.returncode, 1)
                self.assert_refused(report)

    def test_narrowed_two_of_three_gate_is_rejected(self) -> None:
        self.data["acceptedInputs"].pop()
        self.write_manifest()
        process, report = self.run_validator()
        self.assertEqual(process.returncode, 1)
        self.assert_refused(report)
        self.assertIn(report["failures"][0]["row"], {"BOARD-STATE", "INPUT-SET"})

    def test_negative_or_missing_compatibility_row_is_rejected(self) -> None:
        for mutation in ("negative", "missing"):
            with self.subTest(mutation=mutation):
                candidate = copy.deepcopy(self.data)
                if mutation == "negative":
                    candidate["compatibilityChecks"][3]["result"] = "fail"
                else:
                    candidate["compatibilityChecks"].pop()
                self.manifest.write_text(json.dumps(candidate), encoding="utf-8")
                process, report = self.run_validator()
                self.assertEqual(process.returncode, 1)
                self.assert_refused(report)

    def test_repository_pin_drift_is_rejected_at_production_entry_point(self) -> None:
        repository = self.copy_repository_fixture("repository-pin-drift")
        package = repository / "Package.swift"
        package.write_text(
            package.read_text(encoding="utf-8").replace(
                '"ReluxTunnelLibSSH2Adapter"', '"ReluxTunnelLibSSH2AdapterNarrowed"'
            ),
            encoding="utf-8",
        )
        process, report = self.run_validator(repository)
        self.assertEqual(process.returncode, 1)
        self.assert_refused(report)
        self.assertEqual(report["failures"][0]["row"], "REPOSITORY-GRAPH")

    def test_production_entry_point_rejects_selected_patch_lock_drift(self) -> None:
        repository = self.copy_repository_fixture("selected-patch-lock-drift")
        path = repository / "Dependencies/ReluxLibSSH2/PATCH_MANIFEST.json"
        manifest = json.loads(path.read_text(encoding="utf-8"))
        manifest["patches"][0]["sha256"] = "0" * 64
        path.write_text(json.dumps(manifest), encoding="utf-8")

        process, report = self.run_validator(repository)

        self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
        self.assert_refused(report)
        self.assertEqual(report["failures"][0]["row"], "REPOSITORY-SSH-PIN")

    def test_selected_ssh_integrity_bindings_cannot_be_mutated_or_removed(self) -> None:
        ssh_pins = self.data["acceptedInputs"][2]["sourceOrBinaryPins"]
        expected = {
            "libssh2CopyingSha256": "a83a4da224ebeaaaea5efb4cd1ef1ab0998c1bd719d6f70b05e1d5c491372137",
            "opensslLicenseSha256": "7d5450cb2d142651b8afa315b5f238efc805dad827d91ba367d8516bc9d49e7a",
            "opensslAcknowledgementsSha256": "58dee45791f007ced048114717f86672778fe75c551827c57e760861446ce3c3",
            "retainedReluxNIOSSHPatchSha256": "1241622deca47f05a139998a94b2ce988935bb0e288f26cf57dc71f3d23317a4",
            "retainedReluxNIOSSHLicenseSha256": "cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30",
        }
        for key, accepted_value in expected.items():
            with self.subTest(pin=key, mutation="value"):
                candidate = copy.deepcopy(self.data)
                candidate["acceptedInputs"][2]["sourceOrBinaryPins"][key] = "0" * 64
                self.manifest.write_text(json.dumps(candidate), encoding="utf-8")
                process, report = self.run_validator()
                self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
                self.assert_refused(report)
                self.assertEqual(report["failures"][0]["row"], "NORMALIZED-CONTRACT")
            with self.subTest(pin=key, mutation="missing"):
                candidate = copy.deepcopy(self.data)
                del candidate["acceptedInputs"][2]["sourceOrBinaryPins"][key]
                self.manifest.write_text(json.dumps(candidate), encoding="utf-8")
                process, report = self.run_validator()
                self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
                self.assert_refused(report)
                self.assertEqual(report["failures"][0]["row"], "NORMALIZED-CONTRACT")
            self.assertEqual(ssh_pins[key], accepted_value)

    def test_production_entry_point_rejects_selected_license_pin_drift(self) -> None:
        repository = self.copy_repository_fixture("selected-license-pin-drift")
        path = repository / "NativeDependencies/manifest.json"
        manifest = json.loads(path.read_text(encoding="utf-8"))
        manifest["dependencies"]["libssh2-openssl"]["license"]["components"][0][
            "sha256"
        ] = "0" * 64
        path.write_text(json.dumps(manifest), encoding="utf-8")

        process, report = self.run_validator(repository)

        self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
        self.assert_refused(report)
        self.assertEqual(report["failures"][0]["row"], "REPOSITORY-SSH-PIN")

    def test_production_entry_point_rejects_retained_niossh_pin_drift(self) -> None:
        repository = self.copy_repository_fixture("retained-niossh-pin-drift")
        path = repository / "Dependencies/ReluxNIOSSH/PATCH_MANIFEST.json"
        manifest = json.loads(path.read_text(encoding="utf-8"))
        manifest["upstream"]["licenseSHA256"] = "0" * 64
        path.write_text(json.dumps(manifest), encoding="utf-8")

        process, report = self.run_validator(repository)

        self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
        self.assert_refused(report)
        self.assertEqual(report["failures"][0]["row"], "REPOSITORY-SSH-PIN")

    def test_production_entry_point_rejects_retained_niossh_source_narrowing(
        self,
    ) -> None:
        repository = self.copy_repository_fixture("retained-niossh-source-narrowing")
        path = repository / "Dependencies/ReluxNIOSSH/Sources/NIOSSH/ReluxPolicies.swift"
        original = path.read_text(encoding="utf-8")
        narrowed = original.replace("32 * 1024", "1", 1)
        self.assertNotEqual(narrowed, original)
        path.write_text(narrowed, encoding="utf-8")

        process, report = self.run_validator(repository)

        self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
        self.assert_refused(report)
        self.assertEqual(report["failures"][0]["row"], "REPOSITORY-SSH-PIN")
        self.assertEqual(
            report["failures"][0]["detail"],
            "retained ReluxNIOSSH tree bytes drift",
        )

    def test_production_entry_point_rejects_selected_patch_byte_drift(self) -> None:
        repository = self.copy_repository_fixture("selected-patch-byte-drift")
        path = (
            repository
            / "Dependencies/ReluxLibSSH2/patches/0001-public-client-rekey.patch"
        )
        content = bytearray(path.read_bytes())
        self.assertTrue(content)
        content[0] ^= 1
        path.write_bytes(content)

        process, report = self.run_validator(repository)

        self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
        self.assert_refused(report)
        self.assertEqual(report["failures"][0]["row"], "REPOSITORY-SSH-PIN")

    def test_production_entry_point_rejects_one_public_header_lock_drift(self) -> None:
        repository = self.copy_repository_fixture("public-header-lock-drift")
        path = repository / "NativeDependencies/manifest.json"
        manifest = json.loads(path.read_text(encoding="utf-8"))
        file_pins = manifest["dependencies"]["libssh2-openssl"]["artifact"]["file_sha256"]
        file_pins["ios-arm64/Headers/libssh2.h"] = "0" * 64
        path.write_text(json.dumps(manifest), encoding="utf-8")

        process, report = self.run_validator(repository)

        self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
        self.assert_refused(report)
        self.assertEqual(report["failures"][0]["row"], "REPOSITORY-SSH-PIN")

    def test_production_entry_point_rejects_one_public_header_byte_drift(self) -> None:
        repository = self.copy_repository_fixture("public-header-byte-drift")
        path = (
            repository
            / "NativeDependencies/Artifacts/ReluxLibSSH2.xcframework"
            / "macos-arm64_x86_64/Headers/libssh2.h"
        )
        content = bytearray(path.read_bytes())
        self.assertTrue(content)
        content[0] ^= 1
        path.write_bytes(content)

        process, report = self.run_validator(repository)

        self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
        self.assert_refused(report)
        self.assertEqual(report["failures"][0]["row"], "REPOSITORY-SSH-PIN")

    def test_production_entry_point_rejects_missing_malformed_or_duplicate_ssh_pin_records(
        self,
    ) -> None:
        mutations = ("missing", "malformed", "duplicate")
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                repository = self.copy_repository_fixture(f"ssh-pin-{mutation}")
                path = repository / "Dependencies/ReluxLibSSH2/PATCH_MANIFEST.json"
                if mutation == "missing":
                    path.unlink()
                elif mutation == "malformed":
                    path.write_text("{not-json", encoding="utf-8")
                else:
                    text = path.read_text(encoding="utf-8")
                    path.write_text(
                        text.replace(
                            '"schema_version": 1,',
                            '"schema_version": 1, "schema_version": 1,',
                            1,
                        ),
                        encoding="utf-8",
                    )

                process, report = self.run_validator(repository)

                self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
                self.assert_refused(report)
                self.assertEqual(report["failures"][0]["row"], "REPOSITORY-SSH-PIN")

    def test_production_entry_point_rejects_extra_dependency_in_every_protected_closure(
        self,
    ) -> None:
        mutants = (
            (
                "provider",
                "Project.swift",
                "ReluxProxyMacTunnel",
                '.package(product: "ReluxTunnelCore")',
            ),
            (
                "macos-adapter",
                "Package.swift",
                "ReluxTunnelMacOSAdapter",
                '"UnauthorizedMacOSDependency"',
            ),
            (
                "native-adapter",
                "Package.swift",
                "ReluxTunnelNativeAdapter",
                '"UnauthorizedNativeDependency"',
            ),
            (
                "selected-ssh-adapter",
                "Package.swift",
                "ReluxTunnelLibSSH2Adapter",
                '"UnauthorizedSSHDependency"',
            ),
        )
        for name, relative, target, dependency in mutants:
            with self.subTest(target=name):
                repository = self.copy_repository_fixture(f"extra-{name}")
                self.insert_target_dependency(repository / relative, target, dependency)
                process, report = self.run_validator(repository)
                self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
                self.assert_refused(report)
                self.assertEqual(report["failures"][0]["row"], "REPOSITORY-GRAPH")
                self.assertIn("extra=", report["failures"][0]["detail"])

    def test_production_entry_point_rejects_duplicate_direct_dependency(self) -> None:
        repository = self.copy_repository_fixture("duplicate-provider-dependency")
        self.insert_target_dependency(
            repository / "Project.swift",
            "ReluxProxyMacTunnel",
            '.package(product: "ReluxTunnelMacOSAdapter")',
        )
        process, report = self.run_validator(repository)
        self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
        self.assert_refused(report)
        self.assertEqual(report["failures"][0]["row"], "REPOSITORY-GRAPH")
        self.assertIn("duplicate provider direct dependency", report["failures"][0]["detail"])

    def test_production_entry_point_ignores_comment_and_string_target_decoys(self) -> None:
        decoys = {
            "comment": (
                '// .target(name: "ReluxProxyMacTunnel", '
                'resources: [.folderReference(path: verifiedRelayBundleInput)], '
                'dependencies: [.package(product: "ReluxTunnelMacOSAdapter")])\n'
            ),
            "multiline-string": (
                'let targetDecoy = """\n'
                '.target(name: "ReluxProxyMacTunnel", '
                'resources: [.folderReference(path: verifiedRelayBundleInput)], '
                'dependencies: [.package(product: "ReluxTunnelMacOSAdapter")])\n'
                '"""\n'
            ),
            "raw-string": (
                'let targetDecoy = #".target(name: "ReluxProxyMacTunnel", '
                'resources: [.folderReference(path: verifiedRelayBundleInput)], '
                'dependencies: [.package(product: "ReluxTunnelMacOSAdapter")])"#\n'
            ),
        }
        for name, decoy in decoys.items():
            with self.subTest(decoy=name):
                repository = self.copy_repository_fixture(f"{name}-target-decoy")
                project = repository / "Project.swift"
                self.insert_target_dependency(
                    project,
                    "ReluxProxyMacTunnel",
                    '.package(product: "ReluxTunnelCore")',
                )
                project.write_text(decoy + project.read_text(encoding="utf-8"), encoding="utf-8")
                process, report = self.run_validator(repository)
                self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
                self.assert_refused(report)
                self.assertEqual(report["failures"][0]["row"], "REPOSITORY-GRAPH")
                self.assertIn("extra=", report["failures"][0]["detail"])

    def test_production_entry_point_rejects_ambiguous_target_declaration(self) -> None:
        repository = self.copy_repository_fixture("ambiguous-target-declaration")
        project = repository / "Project.swift"
        duplicate = (
            '.target(name: "ReluxProxyMacTunnel", '
            'resources: [.folderReference(path: verifiedRelayBundleInput)], '
            'dependencies: [.package(product: "ReluxTunnelMacOSAdapter")]),\n'
        )
        project.write_text(duplicate + project.read_text(encoding="utf-8"), encoding="utf-8")
        process, report = self.run_validator(repository)
        self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
        self.assert_refused(report)
        self.assertEqual(report["failures"][0]["row"], "REPOSITORY-GRAPH")
        self.assertIn("exactly one target declaration", report["failures"][0]["detail"])


if __name__ == "__main__":
    unittest.main()
