#!/usr/bin/env python3

import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "relay_release.py"
SPEC = importlib.util.spec_from_file_location("relay_release", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
relay_release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(relay_release)


class RelayReleaseTests(unittest.TestCase):
    def write_executable(self, directory: Path, name: str, output: str) -> Path:
        executable = directory / name
        escaped = output.replace("'", "'\\''")
        executable.write_text(f"#!/bin/sh\nprintf '%s' '{escaped}'\n", encoding="utf-8")
        executable.chmod(0o755)
        return executable

    def write_archive(self, path: Path, members: dict[str, bytes]) -> None:
        with tarfile.open(path, "w:gz") as bundle:
            for name, contents in members.items():
                info = tarfile.TarInfo(name)
                info.size = len(contents)
                info.mode = 0o755
                bundle.addfile(info, io.BytesIO(contents))

    def test_target_matrix_and_names_are_canonical(self) -> None:
        identities = [
            (target["os"], target["arch"], target["canonicalTarget"])
            for target in relay_release.TARGETS
        ]
        self.assertEqual(
            identities,
            [
                ("darwin", "amd64", "x86_64-apple-darwin"),
                ("darwin", "arm64", "aarch64-apple-darwin"),
                ("linux", "amd64", "x86_64-unknown-linux"),
                ("linux", "arm64", "aarch64-unknown-linux"),
            ],
        )
        self.assertEqual(
            [relay_release.target_filename(target) for target in relay_release.TARGETS],
            [
                "relux-relay-darwin-amd64",
                "relux-relay-darwin-arm64",
                "relux-relay-linux-amd64",
                "relux-relay-linux-arm64",
            ],
        )

    def test_release_inputs_fail_closed(self) -> None:
        valid_commit = "0123456789abcdef0123456789abcdef01234567"
        relay_release.validate_release_inputs("0.1.0", valid_commit)
        for version, commit in (
            ("latest", valid_commit),
            ("0.1.0", "ABCDEF" * 6 + "ABCD"),
            ("0.1.0", "host-specific-source"),
        ):
            with self.assertRaises(relay_release.ReleaseError):
                relay_release.validate_release_inputs(version, commit)

    def test_output_paths_cannot_escape_build_root(self) -> None:
        accepted = relay_release.validate_output_path(Path(".build/relay/test-output"))
        self.assertEqual(accepted, relay_release.BUILD_ROOT / "test-output")
        absolute_outside = Path(Path.cwd().anchor) / "privacy-test-output"
        for rejected in (Path("."), Path(".build/relay"), Path("../outside"), absolute_outside):
            with self.assertRaises(relay_release.ReleaseError):
                relay_release.validate_output_path(rejected)

    def test_relative_tool_path_resolves_from_repository(self) -> None:
        self.assertEqual(
            relay_release.resolve_tool_command(".temp/tools/syft"),
            str((relay_release.ROOT / ".temp/tools/syft").resolve()),
        )
        self.assertEqual(relay_release.resolve_tool_command("go"), "go")

    def test_release_go_rejects_auto_toolchain_selection(self) -> None:
        with self.assertRaisesRegex(relay_release.ReleaseError, "GOTOOLCHAIN=local"):
            relay_release.verify_go_toolchain("go", "go1.26.5", require_provenance=True)

    def test_go_identity_rejects_missing_version_and_platform_drift(self) -> None:
        valid_platform = relay_release.host_platform()
        other_platform = "linux/amd64" if valid_platform != "linux/amd64" else "darwin/arm64"
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            for name, identity in (
                ("older", f"go1.26.4 {valid_platform}"),
                ("newer", f"go1.26.6 {valid_platform}"),
                ("wrong-platform", f"{relay_release.GO_VERSION} {other_platform}"),
            ):
                with self.subTest(name=name):
                    executable = self.write_executable(directory, name, f"go version {identity}\n")
                    with self.assertRaises(relay_release.ReleaseError):
                        relay_release.verify_go_toolchain(str(executable), "local")
            with self.assertRaisesRegex(relay_release.ReleaseError, "not found"):
                relay_release.verify_go_toolchain(str(directory / "missing-go"), "local")

    def test_go_archive_checksum_provenance_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            archive = directory / "go-fixture.tar.gz"
            installed = directory / "go" / "bin" / "go"
            installed.parent.mkdir(parents=True)
            installed.write_bytes(b"verified-go-fixture")
            self.write_archive(archive, {"go/bin/go": installed.read_bytes()})
            contract = {
                "artifact": archive.name,
                "sha256": relay_release.sha256(archive),
            }
            with mock.patch.dict(
                relay_release.GO_ARCHIVES,
                {"darwin/arm64": contract},
                clear=True,
            ):
                (directory / relay_release.PROVENANCE_NAME).write_bytes(
                    relay_release.stable_json(relay_release.provenance_document("go", "darwin/arm64"))
                )
                relay_release.verify_archive_provenance(
                    directory,
                    "go",
                    "darwin/arm64",
                    (("go/bin/go", installed),),
                )
                archive.write_bytes(archive.read_bytes() + b"tamper")
                with self.assertRaisesRegex(relay_release.ReleaseError, "archive checksum"):
                    relay_release.verify_archive_provenance(
                        directory,
                        "go",
                        "darwin/arm64",
                        (("go/bin/go", installed),),
                    )

    def test_syft_identity_rejects_wrong_commit_platform_and_missing_fields(self) -> None:
        valid_platform = relay_release.host_platform()
        other_platform = "linux/amd64" if valid_platform != "linux/amd64" else "darwin/arm64"
        base = (
            "Application: syft\n"
            f"Version: {relay_release.SYFT_VERSION}\n"
            "GitCommit: {commit}\n"
            f"GitDescription: v{relay_release.SYFT_VERSION}\n"
            "Platform: {platform}\n"
        )
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            cases = {
                "wrong-commit": base.format(commit="wrong-unapproved-build", platform=valid_platform),
                "wrong-platform": base.format(commit=relay_release.SYFT_COMMIT, platform=other_platform),
                "version-only": f"Version: {relay_release.SYFT_VERSION}\n",
            }
            for name, output in cases.items():
                with self.subTest(name=name):
                    executable = self.write_executable(directory, name, output)
                    with self.assertRaises(relay_release.ReleaseError):
                        relay_release.verify_syft_toolchain(str(executable))

    def test_syft_archive_checksum_and_installed_bytes_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            archive = directory / "syft-fixture.tar.gz"
            installed = directory / "syft"
            installed.write_bytes(b"verified-syft-fixture")
            self.write_archive(archive, {"syft": installed.read_bytes()})
            contract = {
                "artifact": archive.name,
                "sha256": relay_release.sha256(archive),
            }
            with mock.patch.dict(
                relay_release.SYFT_ARCHIVES,
                {"darwin/arm64": contract},
                clear=True,
            ):
                (directory / relay_release.PROVENANCE_NAME).write_bytes(
                    relay_release.stable_json(relay_release.provenance_document("syft", "darwin/arm64"))
                )
                relay_release.verify_archive_provenance(
                    directory,
                    "syft",
                    "darwin/arm64",
                    (("syft", installed),),
                )
                archive_bytes = archive.read_bytes()
                archive.write_bytes(archive_bytes + b"tamper")
                with self.assertRaisesRegex(relay_release.ReleaseError, "archive checksum"):
                    relay_release.verify_archive_provenance(
                        directory,
                        "syft",
                        "darwin/arm64",
                        (("syft", installed),),
                    )
                archive.write_bytes(archive_bytes)
                installed.write_bytes(b"substituted-syft")
                with self.assertRaisesRegex(relay_release.ReleaseError, "differs from archive"):
                    relay_release.verify_archive_provenance(
                        directory,
                        "syft",
                        "darwin/arm64",
                        (("syft", installed),),
                    )

    def test_provenance_contract_pins_all_supported_archives_without_host_paths(self) -> None:
        for tool, contracts in (("go", relay_release.GO_ARCHIVES), ("syft", relay_release.SYFT_ARCHIVES)):
            self.assertEqual(
                set(contracts),
                {"darwin/amd64", "darwin/arm64", "linux/amd64", "linux/arm64"},
            )
            for tool_platform in contracts:
                document = relay_release.provenance_document(tool, tool_platform)
                self.assertRegex(document["sha256"], r"^[0-9a-f]{64}$")
                self.assertNotIn(str(Path.home()), relay_release.stable_json(document).decode("utf-8"))

    def test_manifest_field_names_are_stable_and_path_free(self) -> None:
        relay_release.verify_manifest_schema()
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            for index, target in enumerate(relay_release.TARGETS, start=1):
                filename = relay_release.target_filename(target)
                (output / filename).write_bytes(bytes([index]))
                (output / f"{filename}.spdx.json").write_text("{}\n", encoding="utf-8")
            manifest = relay_release.build_manifest(
                "0.1.0",
                "0123456789abcdef0123456789abcdef01234567",
                output,
            )
        top_keys, toolchain_keys, artifact_keys = relay_release.expected_manifest_keys()
        self.assertEqual(set(manifest), top_keys)
        self.assertEqual(set(manifest["toolchain"]), toolchain_keys)
        self.assertTrue(all(set(artifact) == artifact_keys for artifact in manifest["artifacts"]))
        encoded = relay_release.stable_json(manifest).decode("utf-8")
        self.assertNotIn(str(Path.home()), encoded)
        self.assertEqual(json.loads(encoded), manifest)


if __name__ == "__main__":
    unittest.main()
