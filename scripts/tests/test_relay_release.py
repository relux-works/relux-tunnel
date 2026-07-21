#!/usr/bin/env python3

import importlib.util
import io
import json
import os
from pathlib import Path
import struct
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

    def write_go_archive(self, path: Path) -> dict[str, bytes]:
        files = {
            "go/bin/go": b"verified-go-fixture",
            "go/src/runtime/proc.go": b"package runtime\n",
            "go/src/archive/tar/common.go": b"package tar\n",
        }
        directories = {
            "go",
            "go/bin",
            "go/src",
            "go/src/runtime",
            "go/src/archive",
            "go/src/archive/tar",
        }
        with tarfile.open(path, "w:gz") as bundle:
            for name in sorted(
                directories, key=lambda value: (value.count("/"), value)
            ):
                info = tarfile.TarInfo(name)
                info.type = tarfile.DIRTYPE
                info.mode = 0o755
                bundle.addfile(info)
            for name, contents in sorted(files.items()):
                info = tarfile.TarInfo(name)
                info.size = len(contents)
                info.mode = 0o755 if name == "go/bin/go" else 0o644
                bundle.addfile(info, io.BytesIO(contents))
        return files

    def install_go_fixture(self, directory: Path, archive: Path) -> None:
        with tarfile.open(archive, "r:gz") as bundle:
            bundle.extractall(directory, filter="data")

    def write_raw_archive(
        self, path: Path, members: list[tuple[tarfile.TarInfo, bytes | None]]
    ) -> None:
        with tarfile.open(path, "w:gz") as bundle:
            for info, contents in members:
                bundle.addfile(info, None if contents is None else io.BytesIO(contents))

    def write_elf_fixture(
        self,
        path: Path,
        machine: int,
        program_types: list[int],
        section_names: list[str] | None = None,
    ) -> None:
        header = bytearray(64)
        header[:6] = b"\x7fELF\x02\x01"
        struct.pack_into("<H", header, 18, machine)
        struct.pack_into("<Q", header, 32, 64)
        struct.pack_into("<HH", header, 54, 56, len(program_types))
        programs = bytearray(56 * len(program_types))
        for index, program_type in enumerate(program_types):
            struct.pack_into("<I", programs, index * 56, program_type)
        if not section_names:
            path.write_bytes(header + programs)
            return
        names = bytearray(b"\0.shstrtab\0")
        name_offsets = []
        for name in section_names:
            name_offsets.append(len(names))
            names.extend(name.encode("ascii") + b"\0")
        section_offset = len(header) + len(programs)
        section_count = 2 + len(section_names)
        names_offset = section_offset + section_count * 64
        struct.pack_into("<Q", header, 40, section_offset)
        struct.pack_into("<HHH", header, 58, 64, section_count, 1)
        sections = bytearray(section_count * 64)
        struct.pack_into("<I", sections, 64, 1)
        struct.pack_into("<QQ", sections, 64 + 24, names_offset, len(names))
        for index, name_offset in enumerate(name_offsets, start=2):
            struct.pack_into("<I", sections, index * 64, name_offset)
        path.write_bytes(header + programs + sections + names)

    def macho_dylib_command(self, name: str) -> bytes:
        encoded = name.encode("ascii") + b"\0"
        size = (24 + len(encoded) + 7) & ~7
        return (
            struct.pack("<IIIIII", 0xC, size, 24, 0, 0, 0)
            + encoded
            + bytes(size - 24 - len(encoded))
        )

    def write_macho_fixture(
        self,
        path: Path,
        cpu_type: int,
        minimum: int = 0x000C0000,
        debug_section: bool = False,
    ) -> None:
        commands = [
            self.macho_dylib_command("/usr/lib/libSystem.B.dylib"),
            self.macho_dylib_command("/usr/lib/libresolv.9.dylib"),
            struct.pack("<IIIIII", 0x32, 24, 1, minimum, 0x000C0000, 0),
        ]
        if debug_section:
            commands.append(
                struct.pack(
                    "<II16sQQQQIIII",
                    0x19,
                    152,
                    b"__DWARF\0",
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    1,
                    0,
                )
                + struct.pack(
                    "<16s16sQQIIIIIIII",
                    b"__debug_info\0",
                    b"__DWARF\0",
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                )
            )
        header = struct.pack(
            "<IIIIIIII",
            0xFEEDFACF,
            cpu_type,
            0,
            2,
            len(commands),
            sum(map(len, commands)),
            0,
            0,
        )
        path.write_bytes(header + b"".join(commands))

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

    def test_portable_aggregate_inspects_only_after_all_builds(self) -> None:
        makefile = (relay_release.ROOT / "Makefile").read_text(encoding="utf-8")
        self.assertIn(
            "relay-portable-assets: relay-toolchain-build-all\n"
            "\t$(MAKE) relay-toolchain-inspect-assets\n",
            makefile,
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
            ("1.2.3-" + "x" * relay_release.MAX_RELAY_VERSION_BYTES, valid_commit),
            ("0.1.0", "ABCDEF" * 6 + "ABCD"),
            ("0.1.0", "host-specific-source"),
        ):
            with self.assertRaises(relay_release.ReleaseError):
                relay_release.validate_release_inputs(version, commit)
        self.assertEqual(relay_release.validate_source_date_epoch("0"), "0")
        self.assertEqual(
            relay_release.validate_source_date_epoch("1721491200"), "1721491200"
        )
        for invalid in ("", "-1", "+1", "01", "latest"):
            with self.assertRaises(relay_release.ReleaseError):
                relay_release.validate_source_date_epoch(invalid)

    def test_toolchain_manifest_pins_module_compiler_linker_targets_and_licenses(
        self,
    ) -> None:
        manifest = relay_release.verify_toolchain_manifest()
        self.assertEqual(manifest["compiler"]["version"], "go1.26.5")
        self.assertEqual(manifest["compiler"]["linker"], "Go internal linker")
        self.assertEqual(manifest["compiler"]["sdk"], "none")
        self.assertEqual(manifest["compiler"]["sysroot"], "none")
        self.assertEqual(len(manifest["targets"]), 4)
        self.assertEqual(
            manifest["ci"]["checkoutAction"], relay_release.CHECKOUT_ACTION
        )
        self.assertEqual(
            [fixture["target"] for fixture in manifest["ci"]["nativeRuntimeFixtures"]],
            ["linux/amd64", "linux/arm64"],
        )
        self.assertEqual(
            {dependency["license"] for dependency in manifest["dependencies"]},
            {"BSD-3-Clause", "MIT"},
        )

    def test_toolchain_manifest_rejects_linker_pin_drift(self) -> None:
        manifest = json.loads(
            relay_release.TOOLCHAIN_MANIFEST_PATH.read_text(encoding="utf-8")
        )
        manifest["compiler"]["linker"] = "workstation linker"
        with tempfile.TemporaryDirectory() as temporary:
            altered = Path(temporary) / relay_release.TOOLCHAIN_MANIFEST_NAME
            altered.write_bytes(relay_release.stable_json(manifest))
            with mock.patch.object(relay_release, "TOOLCHAIN_MANIFEST_PATH", altered):
                with self.assertRaisesRegex(
                    relay_release.ReleaseError, "compiler/linker pin drift"
                ):
                    relay_release.verify_toolchain_manifest()

    def test_toolchain_manifest_rejects_cache_isolation_policy_drift(self) -> None:
        manifest = json.loads(
            relay_release.TOOLCHAIN_MANIFEST_PATH.read_text(encoding="utf-8")
        )
        manifest["build"]["cachePolicy"] = "incremental caches may be global"
        with tempfile.TemporaryDirectory() as temporary:
            altered = Path(temporary) / relay_release.TOOLCHAIN_MANIFEST_NAME
            altered.write_bytes(relay_release.stable_json(manifest))
            with mock.patch.object(relay_release, "TOOLCHAIN_MANIFEST_PATH", altered):
                with self.assertRaisesRegex(
                    relay_release.ReleaseError,
                    "toolchain manifest build environment drift",
                ):
                    relay_release.verify_toolchain_manifest()

    def test_checkout_action_pin_must_match_manifest_and_workflow(self) -> None:
        workflow = relay_release.CI_WORKFLOW_PATH.read_text(encoding="utf-8")
        with tempfile.TemporaryDirectory() as temporary:
            altered = Path(temporary) / "ci.yml"
            altered.write_text(
                workflow.replace(
                    relay_release.CHECKOUT_ACTION,
                    "actions/checkout@1111111111111111111111111111111111111111",
                ),
                encoding="utf-8",
            )
            with mock.patch.object(relay_release, "CI_WORKFLOW_PATH", altered):
                with self.assertRaisesRegex(
                    relay_release.ReleaseError,
                    "CI workflow checkout action pin drift",
                ):
                    relay_release.verify_toolchain_manifest()

    def test_checkout_revision_must_match_source_commit(self) -> None:
        completed = mock.Mock(stdout="0123456789abcdef0123456789abcdef01234567\n")
        with mock.patch.object(relay_release, "run_checked", return_value=completed):
            relay_release.verify_checkout_revision(
                "0123456789abcdef0123456789abcdef01234567"
            )
            with self.assertRaisesRegex(relay_release.ReleaseError, "checkout HEAD"):
                relay_release.verify_checkout_revision(
                    "fedcba9876543210fedcba9876543210fedcba98"
                )

    def test_sanitized_environment_is_offline_and_credential_isolated(self) -> None:
        relay_release.BUILD_ROOT.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=relay_release.BUILD_ROOT) as temporary:
            sandbox = Path(temporary)
            with mock.patch.dict(
                os.environ,
                {
                    "HOME": "/workstation/home",
                    "SSH_AUTH_SOCK": "/workstation/agent.sock",
                    "GOPROXY": "https://proxy.invalid",
                    "AWS_SECRET_ACCESS_KEY": "secret",
                },
                clear=True,
            ):
                environment = relay_release.sanitized_environment(
                    "local",
                    relay_release.TARGETS[2],
                    sandbox=sandbox,
                    source_date_epoch="1721491200",
                )
            self.assertEqual(environment["HOME"], str(sandbox / "home"))
            self.assertEqual(environment["GOPROXY"], "off")
            self.assertEqual(environment["GOVCS"], "off")
            self.assertEqual(environment["SOURCE_DATE_EPOCH"], "1721491200")
            self.assertNotIn("SSH_AUTH_SOCK", environment)
            self.assertNotIn("AWS_SECRET_ACCESS_KEY", environment)
            self.assertNotIn("/workstation", json.dumps(environment))

    def test_build_sandbox_rejects_symlink_and_non_directory_roots(self) -> None:
        relay_release.BUILD_ROOT.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(
            dir=relay_release.BUILD_ROOT
        ) as temporary, tempfile.TemporaryDirectory() as external:
            directory = Path(temporary)
            symlinked = directory / "symlinked-workspace"
            symlinked.symlink_to(external, target_is_directory=True)
            regular_file = directory / "file-workspace"
            regular_file.write_text("not a directory\n", encoding="utf-8")

            for cache_mode in ("clean", "incremental"):
                with self.subTest(kind="symlink", cache_mode=cache_mode):
                    with self.assertRaises(relay_release.ReleaseError) as raised:
                        relay_release.prepare_build_sandbox(symlinked, cache_mode)
                    self.assertEqual(
                        str(raised.exception),
                        "build sandbox root must not be a symbolic link",
                    )
                with self.subTest(kind="file", cache_mode=cache_mode):
                    with self.assertRaises(relay_release.ReleaseError) as raised:
                        relay_release.prepare_build_sandbox(regular_file, cache_mode)
                    self.assertEqual(
                        str(raised.exception),
                        "build sandbox root must be a directory",
                    )

            with self.assertRaises(relay_release.ReleaseError) as raised:
                relay_release.sanitized_environment("local", sandbox=symlinked)
            self.assertEqual(
                str(raised.exception),
                "build sandbox root must not be a symbolic link",
            )
            with self.assertRaises(relay_release.ReleaseError) as raised:
                relay_release.sanitized_environment("local", sandbox=regular_file)
            self.assertEqual(
                str(raised.exception),
                "build sandbox root must be a directory",
            )

    def test_sanitized_environment_rejects_every_symlinked_child(self) -> None:
        relay_release.BUILD_ROOT.mkdir(parents=True, exist_ok=True)
        child_names = {
            "HOME": "home",
            "TMPDIR": "tmp",
            "GOCACHE": "go-build-cache",
            "GOMODCACHE": "go-module-cache",
            "GOPATH": "go-path",
        }
        for variable, child_name in child_names.items():
            with self.subTest(variable=variable), tempfile.TemporaryDirectory(
                dir=relay_release.BUILD_ROOT
            ) as temporary, tempfile.TemporaryDirectory() as external:
                sandbox = Path(temporary) / "workspace"
                sandbox.mkdir()
                (sandbox / child_name).symlink_to(external, target_is_directory=True)
                with self.assertRaises(relay_release.ReleaseError) as raised:
                    relay_release.sanitized_environment("local", sandbox=sandbox)
                self.assertEqual(
                    str(raised.exception),
                    f"build sandbox {variable} must not be a symbolic link",
                )

    def test_sanitized_environment_rejects_non_directory_child(self) -> None:
        relay_release.BUILD_ROOT.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=relay_release.BUILD_ROOT) as temporary:
            sandbox = Path(temporary) / "workspace"
            sandbox.mkdir()
            (sandbox / "tmp").write_text("not a directory\n", encoding="utf-8")
            with self.assertRaises(relay_release.ReleaseError) as raised:
                relay_release.sanitized_environment("local", sandbox=sandbox)
            self.assertEqual(
                str(raised.exception),
                "build sandbox TMPDIR must be a directory",
            )

    def test_isolated_child_must_resolve_below_sandbox(self) -> None:
        relay_release.BUILD_ROOT.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(
            dir=relay_release.BUILD_ROOT
        ) as temporary, tempfile.TemporaryDirectory() as external:
            sandbox = Path(temporary)
            with self.assertRaises(relay_release.ReleaseError) as raised:
                relay_release.resolve_isolated_child(
                    Path(external), sandbox.resolve(strict=True), "build sandbox HOME"
                )
            self.assertEqual(
                str(raised.exception),
                "build sandbox HOME escapes build sandbox root",
            )

    def test_clean_recreates_and_incremental_reuses_only_safe_sandbox(self) -> None:
        relay_release.BUILD_ROOT.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=relay_release.BUILD_ROOT) as temporary:
            sandbox = Path(temporary) / "workspace"
            relay_release.prepare_build_sandbox(sandbox, "incremental")
            environment = relay_release.sanitized_environment("local", sandbox=sandbox)
            marker = Path(environment["GOCACHE"]) / "incremental-marker"
            marker.write_text("preserved\n", encoding="utf-8")

            relay_release.prepare_build_sandbox(sandbox, "incremental")
            self.assertTrue(marker.is_file())

            relay_release.prepare_build_sandbox(sandbox, "clean")
            self.assertTrue(sandbox.is_dir())
            self.assertFalse(marker.exists())

    def test_linkage_contract_rejects_dynamic_linux_and_wrong_macos_floor(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            linux = directory / "relay-linux"
            self.write_elf_fixture(linux, 62, [1])
            relay_release.verify_binary_format(linux, relay_release.TARGETS[2])
            relay_release.verify_linkage_contract(linux, relay_release.TARGETS[2])
            self.write_elf_fixture(linux, 62, [1, 3])
            with self.assertRaisesRegex(
                relay_release.ReleaseError, "PT_DYNAMIC or PT_INTERP"
            ):
                relay_release.verify_linkage_contract(linux, relay_release.TARGETS[2])

            darwin = directory / "relay-darwin"
            self.write_macho_fixture(darwin, 0x0100000C)
            relay_release.verify_binary_format(darwin, relay_release.TARGETS[1])
            relay_release.verify_linkage_contract(darwin, relay_release.TARGETS[1])
            self.write_macho_fixture(darwin, 0x0100000C, minimum=0x000B0000)
            with self.assertRaisesRegex(
                relay_release.ReleaseError, "minimum OS or SDK"
            ):
                relay_release.verify_linkage_contract(darwin, relay_release.TARGETS[1])

    def test_debug_symbol_contract_rejects_elf_and_macho_dwarf(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            linux = directory / "relay-linux"
            self.write_elf_fixture(linux, 62, [1], [".gopclntab"])
            relay_release.verify_debug_symbol_contract(linux, relay_release.TARGETS[2])
            self.write_elf_fixture(linux, 62, [1], [".debug_info"])
            with self.assertRaisesRegex(relay_release.ReleaseError, "debug symbols"):
                relay_release.verify_debug_symbol_contract(
                    linux, relay_release.TARGETS[2]
                )

            darwin = directory / "relay-darwin"
            self.write_macho_fixture(darwin, 0x0100000C)
            relay_release.verify_debug_symbol_contract(darwin, relay_release.TARGETS[1])
            self.write_macho_fixture(darwin, 0x0100000C, debug_section=True)
            with self.assertRaisesRegex(relay_release.ReleaseError, "debug symbols"):
                relay_release.verify_debug_symbol_contract(
                    darwin, relay_release.TARGETS[1]
                )

    def write_portable_asset_fixture(self, root: Path) -> None:
        for target in relay_release.TARGETS:
            directory = root / relay_release.target_directory(target)
            directory.mkdir(parents=True)
            binary = directory / relay_release.target_filename(target)
            if target["os"] == "linux":
                machine = 62 if target["arch"] == "amd64" else 183
                self.write_elf_fixture(binary, machine, [1])
            else:
                cpu_type = 0x01000007 if target["arch"] == "amd64" else 0x0100000C
                self.write_macho_fixture(binary, cpu_type)
            binary.chmod(0o755)

    def test_portable_asset_report_is_exact_budgeted_and_path_free(self) -> None:
        relay_version = "0.1.0"
        source_commit = "0123456789abcdef0123456789abcdef01234567"
        manifest = relay_release.verify_toolchain_manifest()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "portable"
            root.mkdir()
            self.write_portable_asset_fixture(root)
            with mock.patch.object(relay_release, "verify_go_build_info"):
                report = relay_release.portable_asset_report(
                    root,
                    relay_version,
                    source_commit,
                    "1784563200",
                    1_000_000,
                    "go",
                    "local",
                    manifest,
                )
            self.assertEqual(report["schemaVersion"], 1)
            self.assertEqual(report["relayProtocolVersion"], 1)
            self.assertEqual(report["buildMode"], "release")
            self.assertEqual(len(report["artifacts"]), 4)
            self.assertEqual(
                [artifact["filename"] for artifact in report["artifacts"]],
                [
                    "relux-relay-darwin-amd64",
                    "relux-relay-darwin-arm64",
                    "relux-relay-linux-amd64",
                    "relux-relay-linux-arm64",
                ],
            )
            self.assertTrue(report["withinBundleBudget"])
            self.assertEqual(
                report["remainingBudgetBytes"],
                report["bundleBudgetBytes"] - report["totalAssetSizeBytes"],
            )
            encoded = relay_release.stable_json(report).decode("utf-8")
            self.assertNotIn(str(root), encoded)
            self.assertNotIn(str(Path.home()), encoded)
            self.assertTrue(
                all(
                    artifact["debugSymbolDisposition"].startswith("stripped")
                    for artifact in report["artifacts"]
                )
            )

            with mock.patch.object(relay_release, "verify_go_build_info"):
                over_budget = relay_release.portable_asset_report(
                    root,
                    relay_version,
                    source_commit,
                    "1784563200",
                    1,
                    "go",
                    "local",
                    manifest,
                )
            self.assertFalse(over_budget["withinBundleBudget"])
            self.assertLess(over_budget["remainingBudgetBytes"], 0)

            extra = root / "linux-amd64" / "undeclared-executable"
            extra.write_bytes(b"extra")
            extra.chmod(0o755)
            with mock.patch.object(relay_release, "verify_go_build_info"):
                with self.assertRaisesRegex(
                    relay_release.ReleaseError, "not canonical"
                ):
                    relay_release.portable_asset_report(
                        root,
                        relay_version,
                        source_commit,
                        "1784563200",
                        1_000_000,
                        "go",
                        "local",
                        manifest,
                    )

    def test_inspect_assets_retains_measured_over_budget_report(self) -> None:
        relay_release.BUILD_ROOT.mkdir(parents=True, exist_ok=True)
        manifest = relay_release.verify_toolchain_manifest()
        with tempfile.TemporaryDirectory(dir=relay_release.BUILD_ROOT) as temporary:
            fixture = Path(temporary)
            portable_root = fixture / "portable"
            portable_root.mkdir()
            self.write_portable_asset_fixture(portable_root)
            report_path = fixture / "portable-assets-v1.json"
            arguments = mock.Mock(
                go="go",
                go_toolchain="local",
                relay_version="0.1.0",
                source_commit="0123456789abcdef0123456789abcdef01234567",
                source_date_epoch="1784563200",
                bundle_budget_bytes=1,
                portable_root=str(portable_root),
                report=str(report_path),
                require_clean=False,
            )
            with (
                mock.patch.object(relay_release, "verify_checkout_revision"),
                mock.patch.object(
                    relay_release,
                    "verify_toolchain_manifest",
                    return_value=manifest,
                ),
                mock.patch.object(relay_release, "verify_go_module_policy"),
                mock.patch.object(relay_release, "verify_go_toolchain"),
                mock.patch.object(relay_release, "verify_go_build_info"),
                self.assertRaisesRegex(
                    relay_release.ReleaseError, "exceed bundle budget"
                ),
            ):
                relay_release.inspect_portable_assets(arguments)
            retained = json.loads(report_path.read_text(encoding="utf-8"))
            self.assertFalse(retained["withinBundleBudget"])
            self.assertEqual(len(retained["artifacts"]), 4)

    def test_output_paths_cannot_escape_build_root(self) -> None:
        accepted = relay_release.validate_output_path(Path(".build/relay/test-output"))
        self.assertEqual(accepted, relay_release.BUILD_ROOT / "test-output")
        absolute_outside = Path(Path.cwd().anchor) / "privacy-test-output"
        for rejected in (
            Path("."),
            Path(".build/relay"),
            Path("../outside"),
            absolute_outside,
        ):
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
        other_platform = (
            "linux/amd64" if valid_platform != "linux/amd64" else "darwin/arm64"
        )
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            for name, identity in (
                ("older", f"go1.26.4 {valid_platform}"),
                ("newer", f"go1.26.6 {valid_platform}"),
                ("wrong-platform", f"{relay_release.GO_VERSION} {other_platform}"),
            ):
                with self.subTest(name=name):
                    executable = self.write_executable(
                        directory, name, f"go version {identity}\n"
                    )
                    with self.assertRaises(relay_release.ReleaseError):
                        relay_release.verify_go_toolchain(str(executable), "local")
            with self.assertRaisesRegex(relay_release.ReleaseError, "not found"):
                relay_release.verify_go_toolchain(
                    str(directory / "missing-go"), "local"
                )

    def test_go_archive_checksum_provenance_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            archive = directory / "go-fixture.tar.gz"
            self.write_go_archive(archive)
            self.install_go_fixture(directory, archive)
            installed = directory / "go" / "bin" / "go"
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
                    relay_release.stable_json(
                        relay_release.provenance_document("go", "darwin/arm64")
                    )
                )
                relay_release.verify_archive_provenance(
                    directory,
                    "go",
                    "darwin/arm64",
                    (("go/bin/go", installed),),
                )
                archive.write_bytes(archive.read_bytes() + b"tamper")
                with self.assertRaisesRegex(
                    relay_release.ReleaseError, "archive checksum"
                ):
                    relay_release.verify_archive_provenance(
                        directory,
                        "go",
                        "darwin/arm64",
                        (("go/bin/go", installed),),
                    )

    def replace_runtime_with_symlink(self, root: Path) -> None:
        runtime = root / "go/src/runtime/proc.go"
        runtime.unlink()
        runtime.symlink_to(root / "go/src/archive/tar/common.go")

    def test_go_tree_provenance_rejects_every_installed_tree_drift(self) -> None:
        cases = {
            "runtime-content": (
                "installed Go tree differs from archive: content mismatch go/src/runtime/proc.go",
                lambda root: (root / "go/src/runtime/proc.go").write_text(
                    "package substituted\n", encoding="utf-8"
                ),
            ),
            "stdlib-content": (
                "installed Go tree differs from archive: content mismatch go/src/archive/tar/common.go",
                lambda root: (root / "go/src/archive/tar/common.go").write_text(
                    "package substituted\n", encoding="utf-8"
                ),
            ),
            "deleted": (
                "installed Go tree differs from archive: missing path go/src/runtime/proc.go",
                lambda root: (root / "go/src/runtime/proc.go").unlink(),
            ),
            "added": (
                "installed Go tree differs from archive: unexpected path go/src/unapproved.go",
                lambda root: (root / "go/src/unapproved.go").write_text(
                    "package unapproved\n", encoding="utf-8"
                ),
            ),
            "mode": (
                "installed Go tree differs from archive: mode mismatch go/src/runtime/proc.go",
                lambda root: (root / "go/src/runtime/proc.go").chmod(0o755),
            ),
            "symlink": (
                "installed Go tree is unsafe: unsupported file type go/src/runtime/proc.go",
                self.replace_runtime_with_symlink,
            ),
        }
        for name, (diagnostic, mutate) in cases.items():
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temporary:
                directory = Path(temporary)
                archive = directory / "go-fixture.tar.gz"
                self.write_go_archive(archive)
                self.install_go_fixture(directory, archive)
                mutate(directory)
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
                        relay_release.stable_json(
                            relay_release.provenance_document("go", "darwin/arm64")
                        )
                    )
                    with self.assertRaises(relay_release.ReleaseError) as raised:
                        relay_release.verify_archive_provenance(
                            directory,
                            "go",
                            "darwin/arm64",
                            (("go/bin/go", directory / "go/bin/go"),),
                        )
                    self.assertEqual(str(raised.exception), diagnostic)

    def test_go_archive_rejects_duplicate_traversal_links_and_devices(self) -> None:
        def regular(name: str) -> tuple[tarfile.TarInfo, bytes]:
            info = tarfile.TarInfo(name)
            info.mode = 0o644
            info.size = 1
            return info, b"x"

        def directory(name: str) -> tuple[tarfile.TarInfo, None]:
            info = tarfile.TarInfo(name)
            info.type = tarfile.DIRTYPE
            info.mode = 0o755
            return info, None

        symlink = tarfile.TarInfo("go/link")
        symlink.type = tarfile.SYMTYPE
        symlink.linkname = "/tmp/outside"
        symlink.mode = 0o777
        device = tarfile.TarInfo("go/device")
        device.type = tarfile.CHRTYPE
        device.mode = 0o600
        cases = {
            "duplicate": (
                [directory("go"), regular("go/file"), regular("go/file")],
                "Go release archive layout is unsafe: duplicate path go/file",
            ),
            "traversal": (
                [regular("go/../escape")],
                "Go release archive layout is unsafe: non-canonical path go/../escape",
            ),
            "symlink": (
                [directory("go"), (symlink, None)],
                "Go release archive layout is unsafe: unsupported member type go/link",
            ),
            "device": (
                [directory("go"), (device, None)],
                "Go release archive layout is unsafe: unsupported member type go/device",
            ),
        }
        for name, (members, diagnostic) in cases.items():
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temporary:
                archive = Path(temporary) / "unsafe.tar.gz"
                self.write_raw_archive(archive, members)
                with tarfile.open(archive, "r:gz") as bundle:
                    with self.assertRaises(relay_release.ReleaseError) as raised:
                        relay_release.go_archive_tree(bundle)
                    self.assertEqual(str(raised.exception), diagnostic)

    def test_go_build_metadata_enforces_architecture_baseline(self) -> None:
        for target in relay_release.TARGETS:
            with self.subTest(target=target["canonicalTarget"]):
                settings = {
                    "GOOS": target["os"],
                    "GOARCH": target["arch"],
                    "CGO_ENABLED": "0",
                    "-trimpath": "true",
                    target["architectureVariable"]: target["architectureValue"],
                }
                valid = f"fixture: {relay_release.GO_VERSION}\n" + "".join(
                    f"\tbuild\t{key}={value}\n" for key, value in settings.items()
                )
                with mock.patch.object(
                    relay_release,
                    "run_checked",
                    return_value=mock.Mock(stdout=valid),
                ):
                    relay_release.verify_go_build_info(
                        "go", "local", Path("fixture"), target
                    )
                wrong = valid.replace(
                    f"{target['architectureVariable']}={target['architectureValue']}",
                    f"{target['architectureVariable']}=unapproved",
                )
                with mock.patch.object(
                    relay_release,
                    "run_checked",
                    return_value=mock.Mock(stdout=wrong),
                ):
                    with self.assertRaisesRegex(
                        relay_release.ReleaseError, "unexpected Go build metadata"
                    ):
                        relay_release.verify_go_build_info(
                            "go", "local", Path("fixture"), target
                        )

    def test_syft_identity_rejects_wrong_commit_platform_and_missing_fields(
        self,
    ) -> None:
        valid_platform = relay_release.host_platform()
        other_platform = (
            "linux/amd64" if valid_platform != "linux/amd64" else "darwin/arm64"
        )
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
                "wrong-commit": base.format(
                    commit="wrong-unapproved-build", platform=valid_platform
                ),
                "wrong-platform": base.format(
                    commit=relay_release.SYFT_COMMIT, platform=other_platform
                ),
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
                    relay_release.stable_json(
                        relay_release.provenance_document("syft", "darwin/arm64")
                    )
                )
                relay_release.verify_archive_provenance(
                    directory,
                    "syft",
                    "darwin/arm64",
                    (("syft", installed),),
                )
                archive_bytes = archive.read_bytes()
                archive.write_bytes(archive_bytes + b"tamper")
                with self.assertRaisesRegex(
                    relay_release.ReleaseError, "archive checksum"
                ):
                    relay_release.verify_archive_provenance(
                        directory,
                        "syft",
                        "darwin/arm64",
                        (("syft", installed),),
                    )
                archive.write_bytes(archive_bytes)
                installed.write_bytes(b"substituted-syft")
                with self.assertRaisesRegex(
                    relay_release.ReleaseError, "differs from archive"
                ):
                    relay_release.verify_archive_provenance(
                        directory,
                        "syft",
                        "darwin/arm64",
                        (("syft", installed),),
                    )

    def test_provenance_contract_pins_all_supported_archives_without_host_paths(
        self,
    ) -> None:
        for tool, contracts in (
            ("go", relay_release.GO_ARCHIVES),
            ("syft", relay_release.SYFT_ARCHIVES),
        ):
            self.assertEqual(
                set(contracts),
                {"darwin/amd64", "darwin/arm64", "linux/amd64", "linux/arm64"},
            )
            for tool_platform in contracts:
                document = relay_release.provenance_document(tool, tool_platform)
                self.assertRegex(document["sha256"], r"^[0-9a-f]{64}$")
                self.assertNotIn(
                    str(Path.home()),
                    relay_release.stable_json(document).decode("utf-8"),
                )

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
        self.assertTrue(
            all(set(artifact) == artifact_keys for artifact in manifest["artifacts"])
        )
        encoded = relay_release.stable_json(manifest).decode("utf-8")
        self.assertNotIn(str(Path.home()), encoded)
        self.assertEqual(json.loads(encoded), manifest)

    def test_identity_preflight_binds_manifest_target_size_hash_and_bytes(self) -> None:
        relay_version = "1.2.3-test.1"
        source_commit = "0123456789abcdef0123456789abcdef01234567"
        target_name = "darwin/arm64"
        target_index = 1

        with tempfile.TemporaryDirectory() as temporary:
            fixture = Path(temporary)
            release = fixture / "copied-release"
            release.mkdir()
            for index, target in enumerate(relay_release.TARGETS, start=1):
                filename = relay_release.target_filename(target)
                (release / filename).write_bytes(
                    f"copied executable fixture {index}".encode("ascii")
                )
                (release / f"{filename}.spdx.json").write_text("{}\n", encoding="utf-8")

            manifest = relay_release.build_manifest(
                relay_version, source_commit, release
            )
            manifest_path = fixture / relay_release.MANIFEST_NAME
            manifest_path.write_bytes(relay_release.stable_json(manifest))
            selected_artifact = manifest["artifacts"][target_index]
            selected_copy = fixture / "selected-executable-copy"
            selected_copy.write_bytes(
                (release / selected_artifact["filename"]).read_bytes()
            )

            def identity_output(self_sha256: str) -> bytes:
                identity = {
                    "schemaVersion": 1,
                    "relayProtocolVersion": 1,
                    "relayVersion": relay_version,
                    "sourceCommit": source_commit,
                    "os": "darwin",
                    "arch": "arm64",
                    "selfSha256": self_sha256,
                }
                return (json.dumps(identity, separators=(",", ":")) + "\n").encode(
                    "ascii"
                )

            canonical_identity = identity_output(selected_artifact["sha256"])
            relay_release.verify_identity_against_manifest(
                canonical_identity, manifest_path, selected_copy, target_name
            )

            identity_path = fixture / "canonical-identity.json"
            identity_path.write_bytes(canonical_identity)
            with mock.patch(
                "sys.argv",
                [
                    str(SCRIPT),
                    "verify-identity",
                    "--target",
                    target_name,
                    "--manifest",
                    str(manifest_path),
                    "--executable",
                    str(selected_copy),
                    "--identity-output",
                    str(identity_path),
                ],
            ), mock.patch("sys.stderr", new_callable=io.StringIO) as diagnostics:
                self.assertEqual(relay_release.main(), 0)
                self.assertEqual(diagnostics.getvalue(), "")

            with self.subTest("identity self hash mismatch"):
                with self.assertRaisesRegex(
                    relay_release.ReleaseError, "identity output mismatch"
                ):
                    relay_release.verify_identity_against_manifest(
                        identity_output("0" * 64),
                        manifest_path,
                        selected_copy,
                        target_name,
                    )

            with self.subTest("manifest size mismatch"):
                altered = json.loads(json.dumps(manifest))
                altered["artifacts"][target_index]["size"] += 1
                altered_manifest = fixture / "size-mismatch-manifest.json"
                altered_manifest.write_bytes(relay_release.stable_json(altered))
                with self.assertRaisesRegex(
                    relay_release.ReleaseError, "executable size mismatch"
                ):
                    relay_release.verify_identity_against_manifest(
                        canonical_identity,
                        altered_manifest,
                        selected_copy,
                        target_name,
                    )

            with self.subTest("manifest target tuple mismatch"):
                altered = json.loads(json.dumps(manifest))
                altered["artifacts"][target_index][
                    "canonicalTarget"
                ] = "x86_64-apple-darwin"
                altered_manifest = fixture / "target-mismatch-manifest.json"
                altered_manifest.write_bytes(relay_release.stable_json(altered))
                with self.assertRaisesRegex(
                    relay_release.ReleaseError, "manifest target mismatch"
                ):
                    relay_release.verify_identity_against_manifest(
                        canonical_identity,
                        altered_manifest,
                        selected_copy,
                        target_name,
                    )

            with self.subTest("manifest self hash mismatch"):
                altered = json.loads(json.dumps(manifest))
                altered["artifacts"][target_index]["sha256"] = "f" * 64
                altered_manifest = fixture / "hash-mismatch-manifest.json"
                altered_manifest.write_bytes(relay_release.stable_json(altered))
                with self.assertRaisesRegex(
                    relay_release.ReleaseError, "executable checksum mismatch"
                ):
                    relay_release.verify_identity_against_manifest(
                        canonical_identity,
                        altered_manifest,
                        selected_copy,
                        target_name,
                    )

            with self.subTest("selected executable bytes tampered"):
                tampered_copy = fixture / "tampered-executable-copy"
                tampered = bytearray(selected_copy.read_bytes())
                tampered[-1] ^= 1
                tampered_copy.write_bytes(tampered)
                with self.assertRaisesRegex(
                    relay_release.ReleaseError, "executable checksum mismatch"
                ):
                    relay_release.verify_identity_against_manifest(
                        canonical_identity,
                        manifest_path,
                        tampered_copy,
                        target_name,
                    )

            with self.subTest("selected executable symlink rejected"):
                symlink_copy = fixture / "symlink-executable-copy"
                symlink_copy.symlink_to(selected_copy)
                with self.assertRaisesRegex(
                    relay_release.ReleaseError, "executable is unavailable"
                ):
                    relay_release.verify_identity_against_manifest(
                        canonical_identity,
                        manifest_path,
                        symlink_copy,
                        target_name,
                    )

            with self.subTest("extra identity stdout"):
                with self.assertRaisesRegex(
                    relay_release.ReleaseError, "output framing mismatch"
                ):
                    relay_release.verify_identity_against_manifest(
                        canonical_identity + b"extra\n",
                        manifest_path,
                        selected_copy,
                        target_name,
                    )

            with self.subTest("CLI mismatch is stable and privacy safe"):
                mismatch_path = fixture / "mismatched-identity.json"
                mismatch_path.write_bytes(identity_output("0" * 64))
                with mock.patch(
                    "sys.argv",
                    [
                        str(SCRIPT),
                        "verify-identity",
                        "--target",
                        target_name,
                        "--manifest",
                        str(manifest_path),
                        "--executable",
                        str(selected_copy),
                        "--identity-output",
                        str(mismatch_path),
                    ],
                ), mock.patch("sys.stderr", new_callable=io.StringIO) as diagnostics:
                    self.assertEqual(relay_release.main(), 1)
                    self.assertEqual(
                        diagnostics.getvalue(),
                        "relay-release: relay identity output mismatch\n",
                    )
                    self.assertNotIn(str(fixture), diagnostics.getvalue())


if __name__ == "__main__":
    unittest.main()
