from __future__ import annotations

import copy
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import struct
import tarfile
import tempfile
import unittest
from unittest import mock

from scripts import relay_asset_manifest as manifest_tool


COMMIT = "1" * 40
VERSION = "1.2.3"


def synthetic_binary(os_name: str, architecture: str) -> bytes:
    if os_name == "darwin":
        machine = 0x01000007 if architecture == "amd64" else 0x0100000C
        header = b"\xcf\xfa\xed\xfe" + struct.pack("<I", machine)
    else:
        header_bytes = bytearray(20)
        header_bytes[:6] = b"\x7fELF\x02\x01"
        struct.pack_into("<H", header_bytes, 18, 62 if architecture == "amd64" else 183)
        header = bytes(header_bytes)
    return (
        header
        + b"\0Xb"
        + VERSION.encode("ascii")
        + b"\0"
        + COMMIT.encode("ascii")
        + b"\0fixture"
    )


class RelayAssetManifestTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="relay-asset-manifest.")
        self.root = Path(self.temporary.name)
        self.assets = {
            target: synthetic_binary(*target) for target in manifest_tool.TARGETS
        }
        self.archive = self.root / "assets.tar.gz"
        self.write_archive()
        self.contract = self.make_contract()
        self.contract_path = self.root / "source.json"
        self.write_contract()

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def write_archive(
        self,
        *,
        names: list[str] | None = None,
        contents: list[bytes] | None = None,
        modes: list[int] | None = None,
    ) -> None:
        canonical_names = [
            manifest_tool.canonical_archive_path(*target)
            for target in manifest_tool.TARGETS
        ]
        payloads = [self.assets[target] for target in manifest_tool.TARGETS]
        names = canonical_names if names is None else names
        contents = payloads if contents is None else contents
        modes = [0o755] * len(names) if modes is None else modes
        tar_buffer = io.BytesIO()
        with tarfile.open(
            fileobj=tar_buffer, mode="w", format=tarfile.USTAR_FORMAT
        ) as archive:
            for name, content, mode in zip(names, contents, modes, strict=True):
                member = tarfile.TarInfo(name)
                member.size = len(content)
                member.mode = mode
                member.mtime = 0
                archive.addfile(member, io.BytesIO(content))
        with self.archive.open("wb") as destination:
            with gzip.GzipFile(fileobj=destination, mode="wb", mtime=0) as compressed:
                compressed.write(tar_buffer.getvalue())

    def write_pax_archive(self) -> None:
        tar_buffer = io.BytesIO()
        with tarfile.open(
            fileobj=tar_buffer, mode="w", format=tarfile.PAX_FORMAT
        ) as archive:
            for index, target in enumerate(manifest_tool.TARGETS):
                content = self.assets[target]
                member = tarfile.TarInfo(manifest_tool.canonical_archive_path(*target))
                member.size = len(content)
                member.mode = 0o755
                member.mtime = 0
                if index == 0:
                    member.pax_headers = {
                        "comment": "x" * (manifest_tool.MAX_ARCHIVE_TRAILER_BYTES + 1)
                    }
                archive.addfile(member, io.BytesIO(content))
        with self.archive.open("wb") as destination:
            with gzip.GzipFile(fileobj=destination, mode="wb", mtime=0) as compressed:
                compressed.write(tar_buffer.getvalue())

    def make_contract(self) -> dict[str, object]:
        return {
            "schemaVersion": 1,
            "manifestSchemaVersion": 1,
            "relayProtocolVersion": 1,
            "relayVersion": VERSION,
            "sourceCommit": COMMIT,
            "bundleSubdirectory": "relay-assets-v1",
            "buildProvenance": {
                "kind": "taskBoardResource",
                "taskID": "TASK-260715-fixture",
                "resourceName": "TASK-260715-fixture_assets.tar.gz",
                "archiveSHA256": manifest_tool.sha256_file(self.archive),
            },
            "assets": [
                {
                    "os": os_name,
                    "arch": architecture,
                    "archivePath": manifest_tool.canonical_archive_path(
                        os_name, architecture
                    ),
                    "fileName": manifest_tool.canonical_file_name(
                        os_name, architecture
                    ),
                    "byteSize": len(self.assets[(os_name, architecture)]),
                    "sha256": hashlib.sha256(
                        self.assets[(os_name, architecture)]
                    ).hexdigest(),
                }
                for os_name, architecture in manifest_tool.TARGETS
            ],
        }

    def write_contract(self) -> None:
        self.contract_path.write_text(json.dumps(self.contract), encoding="utf-8")

    def refresh_archive_digest(self) -> None:
        self.contract["buildProvenance"]["archiveSHA256"] = manifest_tool.sha256_file(
            self.archive
        )
        self.write_contract()

    def loaded_contract(self) -> dict[str, object]:
        return manifest_tool.load_source_contract(self.contract_path)

    def generated_bundle(self, name: str = "relay-assets-v1") -> Path:
        bundle = self.root / name
        manifest_tool.generate_bundle(self.archive, bundle, self.loaded_contract())
        return bundle

    def rewrite_manifest(self, bundle: Path, mutate) -> None:
        path = bundle / manifest_tool.MANIFEST_NAME
        value = json.loads(path.read_text(encoding="utf-8"))
        mutate(value)
        path.write_bytes(manifest_tool.stable_json(value))

    def test_valid_bundle_is_exact_and_deterministic(self) -> None:
        contract = self.loaded_contract()
        first = self.generated_bundle("first")
        second = self.generated_bundle("second")
        first_manifest = manifest_tool.validate_bundle(first, contract)
        second_manifest = manifest_tool.validate_bundle(second, contract)

        self.assertEqual(first_manifest, second_manifest)
        self.assertEqual(
            (first / manifest_tool.MANIFEST_NAME).read_bytes(),
            (second / manifest_tool.MANIFEST_NAME).read_bytes(),
        )
        self.assertEqual(
            manifest_tool.render_swift(first_manifest),
            manifest_tool.render_swift(second_manifest),
        )
        self.assertEqual(
            [(entry["os"], entry["arch"]) for entry in first_manifest["assets"]],
            list(manifest_tool.TARGETS),
        )
        for entry, target in zip(
            first_manifest["assets"], manifest_tool.TARGETS, strict=True
        ):
            expected = self.assets[target]
            self.assertEqual(entry["byteSize"], len(expected))
            self.assertEqual(entry["sha256"], hashlib.sha256(expected).hexdigest())
            self.assertEqual(entry["buildIdentity"]["selfSha256"], entry["sha256"])

    def test_bundle_rejects_missing_extra_renamed_zero_length_and_tampering(
        self,
    ) -> None:
        cases = {
            "missing": lambda bundle: (
                bundle / manifest_tool.canonical_file_name("linux", "arm64")
            ).unlink(),
            "extra": lambda bundle: (bundle / "unexpected").write_bytes(b"extra"),
            "renamed": lambda bundle: (
                bundle / manifest_tool.canonical_file_name("linux", "arm64")
            ).rename(bundle / "renamed-relay"),
            "zero": lambda bundle: (
                bundle / manifest_tool.canonical_file_name("linux", "arm64")
            ).write_bytes(b""),
            "tampered": lambda bundle: (
                bundle / manifest_tool.canonical_file_name("linux", "arm64")
            ).write_bytes(b"tampered"),
        }
        contract = self.loaded_contract()
        pristine = self.generated_bundle("pristine")
        for name, mutate in cases.items():
            with self.subTest(name=name):
                bundle = self.root / f"bundle-{name}"
                shutil.copytree(pristine, bundle)
                mutate(bundle)
                with self.assertRaises(manifest_tool.AssetManifestError):
                    manifest_tool.validate_bundle(bundle, contract)

    def test_bundle_rejects_oversized_manifest_before_json_allocation(self) -> None:
        bundle = self.generated_bundle()
        contract = self.loaded_contract()
        manifest_path = bundle / manifest_tool.MANIFEST_NAME
        with manifest_path.open("r+b") as stream:
            stream.truncate(manifest_tool.MAX_MANIFEST_BYTES + 1)

        with mock.patch.object(manifest_tool.json, "loads") as loads:
            with self.assertRaises(manifest_tool.AssetManifestError):
                manifest_tool.validate_bundle(bundle, contract)
        loads.assert_not_called()

    def test_bundle_rejects_oversized_asset_before_content_read(self) -> None:
        bundle = self.generated_bundle()
        contract = self.loaded_contract()
        asset_path = bundle / manifest_tool.canonical_file_name("darwin", "amd64")
        with asset_path.open("r+b") as stream:
            stream.truncate(manifest_tool.MAX_ASSET_BYTES + 1)

        with mock.patch.object(
            manifest_tool, "validate_asset_descriptor"
        ) as validate_asset:
            with self.assertRaises(manifest_tool.AssetManifestError):
                manifest_tool.validate_bundle(bundle, contract)
        validate_asset.assert_not_called()

    def test_bundle_rejects_manifest_asset_and_root_symlinks(self) -> None:
        contract = self.loaded_contract()
        pristine = self.generated_bundle("pristine")

        manifest_bundle = self.root / "manifest-symlink"
        shutil.copytree(pristine, manifest_bundle)
        manifest_path = manifest_bundle / manifest_tool.MANIFEST_NAME
        manifest_target = self.root / "manifest-target.json"
        shutil.copy2(manifest_path, manifest_target)
        manifest_path.unlink()
        manifest_path.symlink_to(manifest_target)
        with self.assertRaises(manifest_tool.AssetManifestError):
            manifest_tool.validate_bundle(manifest_bundle, contract)

        asset_bundle = self.root / "asset-symlink"
        shutil.copytree(pristine, asset_bundle)
        asset_path = asset_bundle / manifest_tool.canonical_file_name("darwin", "amd64")
        asset_target = self.root / "asset-target"
        shutil.copy2(asset_path, asset_target)
        asset_path.unlink()
        asset_path.symlink_to(asset_target)
        with self.assertRaises(manifest_tool.AssetManifestError):
            manifest_tool.validate_bundle(asset_bundle, contract)

        bundle_symlink = self.root / "bundle-symlink"
        bundle_symlink.symlink_to(pristine, target_is_directory=True)
        with self.assertRaises(manifest_tool.AssetManifestError):
            manifest_tool.validate_bundle(bundle_symlink, contract)
        with self.assertRaises(manifest_tool.AssetManifestError):
            manifest_tool.generate_bundle(self.archive, bundle_symlink, contract)

    def test_asset_symlink_replacement_race_fails_closed(self) -> None:
        bundle = self.generated_bundle()
        contract = self.loaded_contract()
        asset_name = manifest_tool.canonical_file_name("darwin", "amd64")
        asset_path = bundle / asset_name
        original_path = self.root / "original-raced-asset"
        symlink_target = self.root / "raced-symlink-target"
        shutil.copy2(asset_path, symlink_target)
        real_open = manifest_tool.os.open
        replaced = False

        def replacing_open(path, flags, *args, **kwargs):
            nonlocal replaced
            if path == asset_name and kwargs.get("dir_fd") is not None and not replaced:
                replaced = True
                asset_path.rename(original_path)
                asset_path.symlink_to(symlink_target)
            return real_open(path, flags, *args, **kwargs)

        with mock.patch.object(manifest_tool.os, "open", side_effect=replacing_open):
            with self.assertRaises(manifest_tool.AssetManifestError):
                manifest_tool.validate_bundle(bundle, contract)
        self.assertTrue(replaced)

    def test_streaming_identity_validation_handles_chunk_boundaries(self) -> None:
        bundle = self.generated_bundle()
        with mock.patch.object(manifest_tool, "READ_CHUNK_BYTES", 7):
            manifest_tool.validate_bundle(bundle, self.loaded_contract())

    def test_manifest_rejects_schema_protocol_duplicate_identity_and_unparseable(
        self,
    ) -> None:
        contract = self.loaded_contract()
        mutations = {
            "schema": lambda value: value.__setitem__("schemaVersion", 2),
            "protocol": lambda value: value.__setitem__("relayProtocolVersion", 2),
            "entry-protocol": lambda value: value["assets"][0].__setitem__(
                "relayProtocolVersion", 2
            ),
            "duplicate": lambda value: value["assets"].__setitem__(
                1, copy.deepcopy(value["assets"][0])
            ),
            "identity": lambda value: value["assets"][0]["buildIdentity"].__setitem__(
                "sourceCommit", "2" * 40
            ),
            "stale": lambda value: value["assets"][0].__setitem__(
                "byteSize", value["assets"][0]["byteSize"] + 1
            ),
        }
        pristine = self.generated_bundle("pristine")
        for name, mutate in mutations.items():
            with self.subTest(name=name):
                bundle = self.root / f"manifest-{name}"
                shutil.copytree(pristine, bundle)
                self.rewrite_manifest(bundle, mutate)
                with self.assertRaises(manifest_tool.AssetManifestError):
                    manifest_tool.validate_bundle(bundle, contract)

        unparseable = self.root / "manifest-unparseable"
        shutil.copytree(pristine, unparseable)
        (unparseable / manifest_tool.MANIFEST_NAME).write_bytes(b"not-json")
        with self.assertRaises(manifest_tool.AssetManifestError):
            manifest_tool.validate_bundle(unparseable, contract)

    def test_archive_rejects_missing_extra_renamed_duplicate_zero_and_mismatched_assets(
        self,
    ) -> None:
        canonical_names = [
            manifest_tool.canonical_archive_path(*target)
            for target in manifest_tool.TARGETS
        ]
        payloads = [self.assets[target] for target in manifest_tool.TARGETS]
        fixtures = {
            "missing": (canonical_names[:-1], payloads[:-1], None),
            "extra": (canonical_names + ["extra"], payloads + [b"extra"], None),
            "renamed": ([*canonical_names[:-1], "renamed"], payloads, None),
            "path-traversal": (
                [*canonical_names[:-1], "../relux-relay-linux-arm64"],
                payloads,
                None,
            ),
            "duplicate": (
                [canonical_names[0], canonical_names[0], *canonical_names[2:]],
                payloads,
                None,
            ),
            "zero": (canonical_names, [*payloads[:-1], b""], None),
            "non-executable": (canonical_names, payloads, [0o755, 0o755, 0o755, 0o644]),
            "mismatched-platform": (
                canonical_names,
                [payloads[1], *payloads[1:]],
                None,
            ),
        }
        for name, (names, contents, modes) in fixtures.items():
            with self.subTest(name=name):
                self.write_archive(names=names, contents=contents, modes=modes)
                self.refresh_archive_digest()
                with self.assertRaises(manifest_tool.AssetManifestError):
                    manifest_tool.read_archive_assets(
                        self.archive, self.loaded_contract()
                    )

    def test_archive_hash_and_parse_hold_one_no_follow_descriptor(self) -> None:
        malicious = self.root / "malicious.tar.gz"
        original = self.root / "held-original.tar.gz"
        self.write_archive(
            contents=[
                self.assets[manifest_tool.TARGETS[0]] + b"tampered",
                *[self.assets[target] for target in manifest_tool.TARGETS[1:]],
            ]
        )
        self.archive.rename(malicious)
        self.write_archive()
        contract = self.make_contract()
        real_sha256_stream = manifest_tool.sha256_stream
        replaced = False

        def replace_path_after_hash(stream) -> str:
            nonlocal replaced
            digest = real_sha256_stream(stream)
            self.archive.rename(original)
            self.archive.symlink_to(malicious)
            replaced = True
            return digest

        with mock.patch.object(
            manifest_tool, "sha256_stream", side_effect=replace_path_after_hash
        ):
            contents = manifest_tool.read_archive_assets(self.archive, contract)

        self.assertTrue(replaced)
        self.assertTrue(self.archive.is_symlink())
        self.assertEqual(
            contents,
            [self.assets[target] for target in manifest_tool.TARGETS],
        )
        with self.assertRaises(manifest_tool.AssetManifestError):
            manifest_tool.read_archive_assets(self.archive, contract)

    def test_archive_rejects_oversize_and_hostile_metadata_before_allocation(
        self,
    ) -> None:
        with self.archive.open("r+b") as stream:
            stream.truncate(manifest_tool.MAX_ARCHIVE_BYTES + 1)
        with mock.patch.object(manifest_tool, "sha256_stream") as sha256_stream:
            with self.assertRaises(manifest_tool.AssetManifestError):
                manifest_tool.read_archive_assets(self.archive, self.contract)
        sha256_stream.assert_not_called()

        self.write_pax_archive()
        self.refresh_archive_digest()
        requested_sizes: list[int] = []
        real_read_exact = manifest_tool.read_exact_stream

        def track_read_size(stream, size: int, label: str) -> bytes:
            requested_sizes.append(size)
            return real_read_exact(stream, size, label)

        with mock.patch.object(
            manifest_tool, "read_exact_stream", side_effect=track_read_size
        ):
            with self.assertRaises(manifest_tool.AssetManifestError):
                manifest_tool.read_archive_assets(self.archive, self.loaded_contract())
        self.assertEqual(requested_sizes, [512])

    def test_fdopen_failures_close_owned_descriptors(self) -> None:
        real_open = manifest_tool.os.open
        opened: list[int] = []

        def track_open(*args, **kwargs) -> int:
            descriptor = real_open(*args, **kwargs)
            opened.append(descriptor)
            return descriptor

        with mock.patch.object(manifest_tool.os, "open", side_effect=track_open):
            with mock.patch.object(
                manifest_tool.os, "fdopen", side_effect=OSError("injected fdopen")
            ):
                with self.assertRaises(manifest_tool.AssetManifestError):
                    manifest_tool.sha256_file(self.archive)
        self.assertEqual(len(opened), 1)
        with self.assertRaises(OSError):
            os.fstat(opened[0])

        opened.clear()
        with mock.patch.object(manifest_tool.os, "open", side_effect=track_open):
            with mock.patch.object(
                manifest_tool.os, "fdopen", side_effect=OSError("injected fdopen")
            ):
                with self.assertRaises(manifest_tool.AssetManifestError):
                    manifest_tool.read_archive_assets(self.archive, self.contract)
        self.assertEqual(len(opened), 1)
        with self.assertRaises(OSError):
            os.fstat(opened[0])

        directory_descriptor = real_open(
            self.root, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0)
        )
        opened.clear()
        try:
            with mock.patch.object(manifest_tool.os, "open", side_effect=track_open):
                with mock.patch.object(
                    manifest_tool.os,
                    "fdopen",
                    side_effect=OSError("injected fdopen"),
                ):
                    with self.assertRaises(manifest_tool.AssetManifestError):
                        manifest_tool.write_new_file_at(
                            directory_descriptor, "fdopen-failure", b"data", 0o600
                        )
        finally:
            os.close(directory_descriptor)
        self.assertEqual(len(opened), 1)
        with self.assertRaises(OSError):
            os.fstat(opened[0])

    def test_source_contract_rejects_stale_hash_protocol_and_schema(self) -> None:
        mutations = {
            "hash": lambda value: value["assets"][0].__setitem__("sha256", "0" * 64),
            "protocol": lambda value: value.__setitem__("relayProtocolVersion", 2),
            "schema": lambda value: value.__setitem__("manifestSchemaVersion", 2),
        }
        for name, mutate in mutations.items():
            with self.subTest(name=name):
                value = copy.deepcopy(self.make_contract())
                mutate(value)
                self.contract_path.write_text(json.dumps(value), encoding="utf-8")
                if name == "hash":
                    contract = manifest_tool.load_source_contract(self.contract_path)
                    with self.assertRaises(manifest_tool.AssetManifestError):
                        manifest_tool.read_archive_assets(self.archive, contract)
                else:
                    with self.assertRaises(manifest_tool.AssetManifestError):
                        manifest_tool.load_source_contract(self.contract_path)

        self.write_archive(
            contents=[
                self.assets[manifest_tool.TARGETS[0]] + b"tampered",
                *[self.assets[target] for target in manifest_tool.TARGETS[1:]],
            ]
        )
        contract = self.make_contract()
        contract["buildProvenance"]["archiveSHA256"] = "0" * 64
        with self.assertRaises(manifest_tool.AssetManifestError):
            manifest_tool.read_archive_assets(self.archive, contract)

    def test_schema_and_generated_swift_drift_fail_closed(self) -> None:
        schema = json.loads(manifest_tool.DEFAULT_SCHEMA.read_text(encoding="utf-8"))
        schema["properties"]["schemaVersion"]["const"] = 2
        schema_path = self.root / "schema.json"
        schema_path.write_text(json.dumps(schema), encoding="utf-8")
        with self.assertRaises(manifest_tool.AssetManifestError):
            manifest_tool.verify_schema(schema_path)

        contract = self.loaded_contract()
        bundle = self.generated_bundle()
        manifest = manifest_tool.validate_bundle(bundle, contract)
        swift = self.root / "Generated.swift"
        swift.write_bytes(manifest_tool.render_swift(manifest) + b"// stale\n")
        with self.assertRaises(manifest_tool.AssetManifestError):
            manifest_tool.verify_swift(swift, manifest)

    def test_generation_recovers_stale_bundle_with_atomic_replacement(self) -> None:
        bundle = self.generated_bundle()
        stale_identity = manifest_tool.directory_identity(bundle, "fixture bundle")
        stale_asset = bundle / manifest_tool.canonical_file_name("linux", "arm64")
        stale_asset.unlink()

        manifest_tool.generate_bundle(self.archive, bundle, self.loaded_contract())

        self.assertNotEqual(
            manifest_tool.directory_identity(bundle, "fixture bundle"),
            stale_identity,
        )
        manifest_tool.validate_bundle(bundle, self.loaded_contract())
        self.assertEqual(list(bundle.parent.glob(f".{bundle.name}.staging-*")), [])

    def test_generation_cleans_staging_after_interruption(self) -> None:
        bundle = self.root / "interrupted"

        def interrupt(event: str, _: Path) -> None:
            if event == "before_publish":
                raise KeyboardInterrupt("injected interruption")

        with self.assertRaises(KeyboardInterrupt):
            manifest_tool.generate_bundle(
                self.archive,
                bundle,
                self.loaded_contract(),
                event_hook=interrupt,
            )

        self.assertFalse(bundle.exists())
        self.assertEqual(list(bundle.parent.glob(f".{bundle.name}.staging-*")), [])

    def test_initial_publication_race_preserves_foreign_destination(self) -> None:
        bundle = self.root / "raced-destination"
        marker = bundle / "foreign-marker"
        foreign_identity: tuple[int, int] | None = None

        def create_foreign_destination(event: str, path: Path) -> None:
            nonlocal foreign_identity
            if event == "before_initial_publish":
                path.mkdir()
                marker.write_text("preserve", encoding="utf-8")
                foreign_identity = manifest_tool.directory_identity(
                    path, "foreign fixture"
                )

        with self.assertRaises(manifest_tool.AssetManifestError):
            manifest_tool.generate_bundle(
                self.archive,
                bundle,
                self.loaded_contract(),
                event_hook=create_foreign_destination,
            )

        self.assertIsNotNone(foreign_identity)
        self.assertEqual(
            manifest_tool.directory_identity(bundle, "foreign fixture"),
            foreign_identity,
        )
        self.assertEqual(marker.read_text(encoding="utf-8"), "preserve")
        self.assertEqual(list(bundle.parent.glob(f".{bundle.name}.staging-*")), [])

    def test_initial_observation_race_preserves_foreign_destination(self) -> None:
        bundle = self.root / "initial-observation-raced-destination"
        marker = bundle / "foreign-marker"
        foreign_identity: tuple[int, int] | None = None

        def create_foreign_destination(event: str, path: Path) -> None:
            nonlocal foreign_identity
            if event == "after_initial_destination_observation":
                path.mkdir()
                marker.write_bytes(b"preserve exact bytes")
                foreign_identity = manifest_tool.directory_identity(
                    path, "foreign fixture"
                )

        with self.assertRaises(manifest_tool.AssetManifestError):
            manifest_tool.generate_bundle(
                self.archive,
                bundle,
                self.loaded_contract(),
                event_hook=create_foreign_destination,
            )

        self.assertIsNotNone(foreign_identity)
        self.assertEqual(
            manifest_tool.directory_identity(bundle, "foreign fixture"),
            foreign_identity,
        )
        self.assertEqual(marker.read_bytes(), b"preserve exact bytes")
        self.assertEqual(list(bundle.parent.glob(f".{bundle.name}.staging-*")), [])

    def test_pre_publish_race_preserves_foreign_destination(self) -> None:
        bundle = self.root / "pre-publish-raced-destination"
        marker = bundle / "foreign-marker"
        foreign_identity: tuple[int, int] | None = None

        def create_foreign_destination(event: str, _: Path) -> None:
            nonlocal foreign_identity
            if event == "before_publish":
                bundle.mkdir()
                marker.write_text("preserve", encoding="utf-8")
                foreign_identity = manifest_tool.directory_identity(
                    bundle, "foreign fixture"
                )

        with self.assertRaises(manifest_tool.AssetManifestError):
            manifest_tool.generate_bundle(
                self.archive,
                bundle,
                self.loaded_contract(),
                event_hook=create_foreign_destination,
            )

        self.assertIsNotNone(foreign_identity)
        self.assertEqual(
            manifest_tool.directory_identity(bundle, "foreign fixture"),
            foreign_identity,
        )
        self.assertEqual(marker.read_text(encoding="utf-8"), "preserve")
        self.assertEqual(list(bundle.parent.glob(f".{bundle.name}.staging-*")), [])

    def assert_existing_destination_race_preserves_foreign_destination(
        self, event_name: str
    ) -> None:
        bundle = self.generated_bundle(f"existing-{event_name.replace('_', '-')}")
        stale_marker = bundle / "stale-marker"
        stale_marker.write_bytes(b"stale directory A")
        (bundle / manifest_tool.MANIFEST_NAME).unlink()
        stale_identity = manifest_tool.directory_identity(bundle, "stale fixture")
        displaced = bundle.with_name(f"{bundle.name}-displaced")
        foreign_marker = bundle / "foreign-marker"
        foreign_identity: tuple[int, int] | None = None

        def replace_destination(event: str, _: Path) -> None:
            nonlocal foreign_identity
            if event == event_name:
                bundle.rename(displaced)
                bundle.mkdir()
                foreign_marker.write_bytes(b"preserve exact foreign bytes")
                foreign_identity = manifest_tool.directory_identity(
                    bundle, "foreign fixture"
                )

        with self.assertRaises(manifest_tool.AssetManifestError):
            manifest_tool.generate_bundle(
                self.archive,
                bundle,
                self.loaded_contract(),
                event_hook=replace_destination,
            )

        self.assertIsNotNone(foreign_identity)
        self.assertEqual(
            manifest_tool.directory_identity(bundle, "foreign fixture"),
            foreign_identity,
        )
        self.assertEqual(foreign_marker.read_bytes(), b"preserve exact foreign bytes")
        self.assertEqual(
            manifest_tool.directory_identity(displaced, "displaced stale fixture"),
            stale_identity,
        )
        self.assertEqual(
            (displaced / stale_marker.name).read_bytes(), b"stale directory A"
        )
        self.assertEqual(list(bundle.parent.glob(f".{bundle.name}.staging-*")), [])

    def test_existing_destination_race_after_observation_fails_closed(self) -> None:
        self.assert_existing_destination_race_preserves_foreign_destination(
            "after_initial_destination_observation"
        )

    def test_existing_destination_race_before_publish_fails_closed(self) -> None:
        self.assert_existing_destination_race_preserves_foreign_destination(
            "before_publish"
        )

    def test_existing_destination_race_before_exchange_is_rolled_back(self) -> None:
        self.assert_existing_destination_race_preserves_foreign_destination(
            "before_exchange"
        )

    def test_cleanup_refuses_replaced_staging_path(self) -> None:
        staging = self.root / ".relay-assets-v1.staging-owned"
        staging.mkdir()
        identity = manifest_tool.directory_identity(staging, "fixture staging")
        staging.rmdir()
        victim = self.root / "victim"
        victim.mkdir()
        marker = victim / "preserve"
        marker.write_text("owned elsewhere", encoding="utf-8")
        staging.symlink_to(victim, target_is_directory=True)

        with self.assertRaises(manifest_tool.AssetManifestError):
            manifest_tool.remove_owned_directory(staging, identity)

        self.assertEqual(marker.read_text(encoding="utf-8"), "owned elsewhere")
        self.assertTrue(staging.is_symlink())

    def test_cleanup_removes_owned_bundle_tree(self) -> None:
        staging = self.generated_bundle("cleanup-owned")
        identity = manifest_tool.directory_identity(staging, "fixture staging")

        manifest_tool.remove_owned_directory(staging, identity)

        self.assertFalse(staging.exists())

    def test_cleanup_race_preserves_foreign_staging_directory(self) -> None:
        bundle = self.generated_bundle("cleanup-race")
        (bundle / manifest_tool.MANIFEST_NAME).write_bytes(b"stale")
        stale_identity = manifest_tool.directory_identity(bundle, "stale fixture")
        displaced = bundle.with_name(f"{bundle.name}-displaced-cleanup")
        foreign_marker = self.root / "foreign-marker-placeholder"
        foreign_identity: tuple[int, int] | None = None
        real_remove_entries = manifest_tool.remove_owned_bundle_entries
        race_injected = False

        def replace_checked_directory(directory_descriptor: int) -> None:
            nonlocal foreign_identity, foreign_marker, race_injected
            race_injected = True
            staging_matches = list(bundle.parent.glob(f".{bundle.name}.staging-*"))
            self.assertEqual(len(staging_matches), 1)
            checked_staging = staging_matches[0]
            checked_staging.rename(displaced)
            checked_staging.mkdir()
            foreign_marker = checked_staging / "foreign-marker"
            foreign_marker.write_bytes(b"preserve exact foreign bytes")
            foreign_identity = manifest_tool.directory_identity(
                checked_staging, "foreign fixture"
            )
            real_remove_entries(directory_descriptor)

        with mock.patch.object(
            manifest_tool,
            "remove_owned_bundle_entries",
            side_effect=replace_checked_directory,
        ):
            with self.assertRaises(manifest_tool.AssetManifestError):
                manifest_tool.generate_bundle(
                    self.archive,
                    bundle,
                    self.loaded_contract(),
                )

        self.assertTrue(race_injected)
        self.assertIsNotNone(foreign_identity)
        foreign_staging = foreign_marker.parent
        self.assertEqual(
            manifest_tool.directory_identity(foreign_staging, "foreign fixture"),
            foreign_identity,
        )
        self.assertEqual(foreign_marker.read_bytes(), b"preserve exact foreign bytes")
        self.assertEqual(
            manifest_tool.directory_identity(displaced, "displaced stale fixture"),
            stale_identity,
        )
        self.assertEqual(list(displaced.iterdir()), [])
        manifest_tool.validate_bundle(bundle, self.loaded_contract())

    def test_generation_keeps_valid_replacement_after_exchange_interruption(
        self,
    ) -> None:
        bundle = self.generated_bundle()
        (bundle / manifest_tool.MANIFEST_NAME).write_bytes(b"partial")

        def interrupt(event: str, _: Path) -> None:
            if event == "after_exchange":
                raise KeyboardInterrupt("injected interruption")

        with self.assertRaises(KeyboardInterrupt):
            manifest_tool.generate_bundle(
                self.archive,
                bundle,
                self.loaded_contract(),
                event_hook=interrupt,
            )

        manifest_tool.validate_bundle(bundle, self.loaded_contract())
        self.assertEqual(list(bundle.parent.glob(f".{bundle.name}.staging-*")), [])


if __name__ == "__main__":
    unittest.main()
