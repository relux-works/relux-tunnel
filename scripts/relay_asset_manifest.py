#!/usr/bin/env python3
"""Generate and validate the trusted, application-bundled relay asset manifest."""

from __future__ import annotations

import argparse
from collections.abc import Callable
import ctypes
from dataclasses import dataclass
from enum import Enum
import gzip
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import struct
import sys
import tempfile
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CONTRACT = ROOT / "relay" / "asset-bundle-source-v1.json"
DEFAULT_SCHEMA = ROOT / "relay" / "asset-manifest-v1.schema.json"
DEFAULT_ARCHIVE = (
    ROOT
    / ".task-board"
    / ".resources"
    / "TASK-260715-24icoz"
    / "TASK-260715-24icoz_portable-relay-assets.tar.gz"
)
DEFAULT_BUNDLE = ROOT / ".build" / "relay" / "relay-assets-v1"
DEFAULT_SWIFT = (
    ROOT
    / "Sources"
    / "ReluxTunnelCore"
    / "RelayAssets"
    / "Generated"
    / "RelayAssetManifest+Generated.swift"
)

MANIFEST_NAME = "relux-relay-assets-v1.json"
SCHEMA_VERSION = 1
IDENTITY_SCHEMA_VERSION = 1
PROTOCOL_VERSION = 1
MAX_MANIFEST_BYTES = 64 * 1024
MAX_METADATA_BYTES = 1024 * 1024
MAX_ASSET_BYTES = 16 * 1024 * 1024
MAX_ARCHIVE_BYTES = 32 * 1024 * 1024
MAX_ARCHIVE_TRAILER_BYTES = 64 * 1024
READ_CHUNK_BYTES = 1024 * 1024
TARGETS = (
    ("darwin", "amd64"),
    ("darwin", "arm64"),
    ("linux", "amd64"),
    ("linux", "arm64"),
)
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40}$")
VERSION_PATTERN = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$")
TASK_PATTERN = re.compile(r"^TASK-[0-9]{6}-[a-z0-9]+$")
RESOURCE_PATTERN = re.compile(r"^TASK-[A-Za-z0-9_.-]+$")

SOURCE_KEYS = {
    "schemaVersion",
    "manifestSchemaVersion",
    "relayProtocolVersion",
    "relayVersion",
    "sourceCommit",
    "bundleSubdirectory",
    "buildProvenance",
    "assets",
}
SOURCE_ASSET_KEYS = {
    "os",
    "arch",
    "archivePath",
    "fileName",
    "byteSize",
    "sha256",
}
PROVENANCE_KEYS = {"kind", "taskID", "resourceName", "archiveSHA256"}
MANIFEST_KEYS = {
    "schemaVersion",
    "relayProtocolVersion",
    "buildProvenance",
    "assets",
}
MANIFEST_ASSET_KEYS = {
    "os",
    "arch",
    "fileName",
    "bundleLocation",
    "byteSize",
    "sha256",
    "relayProtocolVersion",
    "buildIdentity",
    "buildProvenanceReference",
}
IDENTITY_KEYS = {
    "schemaVersion",
    "relayProtocolVersion",
    "relayVersion",
    "sourceCommit",
    "os",
    "arch",
    "selfSha256",
}


class AssetManifestError(RuntimeError):
    pass


class BundlePublicationMode(Enum):
    INITIAL_NO_REPLACE = "initial-no-replace"
    REPLACE_EXISTING = "replace-existing"


@dataclass(frozen=True)
class BundlePublicationIntent:
    mode: BundlePublicationMode
    existing_identity: tuple[int, int] | None = None

    def __post_init__(self) -> None:
        if self.mode is BundlePublicationMode.INITIAL_NO_REPLACE:
            if self.existing_identity is not None:
                raise ValueError("initial publication cannot have an existing identity")
        elif self.existing_identity is None:
            raise ValueError("replacement publication requires an existing identity")


def stable_json(value: Any) -> bytes:
    return (
        json.dumps(value, ensure_ascii=True, separators=(",", ":"), sort_keys=True)
        + "\n"
    ).encode("ascii")


def sha256_bytes(contents: bytes) -> str:
    return hashlib.sha256(contents).hexdigest()


def sha256_stream(stream: Any) -> str:
    digest = hashlib.sha256()
    for chunk in iter(lambda: stream.read(READ_CHUNK_BYTES), b""):
        digest.update(chunk)
    return digest.hexdigest()


def close_descriptor_after_fdopen_failure(descriptor: int) -> None:
    try:
        os.close(descriptor)
    except OSError:
        # Some file-object implementations may consume the descriptor before
        # reporting an initialization failure. Either way, ownership ends here.
        pass


def sha256_file(path: Path) -> str:
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0)
    no_follow = getattr(os, "O_NOFOLLOW", None)
    if no_follow is None:
        raise AssetManifestError("trusted relay input no-follow reads are unavailable")
    descriptor: int | None = None
    try:
        descriptor = os.open(path, flags | no_follow)
        if not stat.S_ISREG(os.fstat(descriptor).st_mode):
            raise AssetManifestError("trusted relay input is not a regular file")
        try:
            stream = os.fdopen(descriptor, "rb")
        except BaseException:
            close_descriptor_after_fdopen_failure(descriptor)
            descriptor = None
            raise
        descriptor = None
        with stream:
            return sha256_stream(stream)
    except OSError as error:
        raise AssetManifestError("trusted relay input is unavailable") from error
    finally:
        if descriptor is not None:
            os.close(descriptor)


def read_bounded_descriptor(
    descriptor: int, *, label: str, maximum_size: int, expected_size: int | None = None
) -> bytes:
    try:
        status = os.fstat(descriptor)
        if not stat.S_ISREG(status.st_mode):
            raise AssetManifestError(f"{label} is not a regular file")
        if status.st_size > maximum_size:
            raise AssetManifestError(f"{label} exceeds its size limit")
        if expected_size is not None and status.st_size != expected_size:
            raise AssetManifestError(f"{label} size does not match the manifest")

        chunks: list[bytes] = []
        total = 0
        while True:
            chunk = os.read(descriptor, min(READ_CHUNK_BYTES, maximum_size + 1 - total))
            if not chunk:
                break
            total += len(chunk)
            if total > maximum_size:
                raise AssetManifestError(f"{label} exceeds its size limit")
            chunks.append(chunk)
            if total == maximum_size:
                if os.read(descriptor, 1):
                    raise AssetManifestError(f"{label} exceeds its size limit")
                break
        if expected_size is not None and total != expected_size:
            raise AssetManifestError(f"{label} size changed while reading")
        return b"".join(chunks)
    except OSError as error:
        raise AssetManifestError(f"{label} could not be read") from error


def open_regular_path(
    path: Path,
    label: str,
    *,
    maximum_size: int,
    expected_size: int | None = None,
) -> tuple[int, os.stat_result]:
    no_follow = getattr(os, "O_NOFOLLOW", None)
    if no_follow is None:
        raise AssetManifestError("trusted relay input no-follow reads are unavailable")
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | no_follow
    descriptor: int | None = None
    try:
        descriptor = os.open(path, flags)
        status = os.fstat(descriptor)
    except OSError as error:
        if descriptor is not None:
            os.close(descriptor)
        raise AssetManifestError(f"{label} is missing or unsafe") from error
    if not stat.S_ISREG(status.st_mode):
        os.close(descriptor)
        raise AssetManifestError(f"{label} is not a regular file")
    if status.st_size > maximum_size:
        os.close(descriptor)
        raise AssetManifestError(f"{label} exceeds its size limit")
    if expected_size is not None and status.st_size != expected_size:
        os.close(descriptor)
        raise AssetManifestError(f"{label} size does not match the manifest")
    return descriptor, status


def read_regular_file(
    path: Path,
    label: str,
    *,
    maximum_size: int,
    expected_size: int | None = None,
) -> tuple[bytes, os.stat_result]:
    descriptor, status = open_regular_path(
        path,
        label,
        maximum_size=maximum_size,
        expected_size=expected_size,
    )
    try:
        contents = read_bounded_descriptor(
            descriptor,
            label=label,
            maximum_size=maximum_size,
            expected_size=expected_size,
        )
    except OSError as error:
        raise AssetManifestError(f"{label} could not be read") from error
    finally:
        os.close(descriptor)
    return contents, status


def load_json(path: Path, label: str) -> tuple[dict[str, Any], bytes]:
    try:
        encoded, _ = read_regular_file(path, label, maximum_size=MAX_METADATA_BYTES)
        value = json.loads(encoded.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise AssetManifestError(f"{label} is not valid JSON") from error
    if not isinstance(value, dict):
        raise AssetManifestError(f"{label} must be an object")
    return value, encoded


def validate_provenance(value: Any) -> dict[str, str]:
    if not isinstance(value, dict) or set(value) != PROVENANCE_KEYS:
        raise AssetManifestError("build provenance field set changed")
    if (
        value.get("kind") != "taskBoardResource"
        or not isinstance(value.get("taskID"), str)
        or TASK_PATTERN.fullmatch(value["taskID"]) is None
        or not isinstance(value.get("resourceName"), str)
        or RESOURCE_PATTERN.fullmatch(value["resourceName"]) is None
        or not isinstance(value.get("archiveSHA256"), str)
        or SHA256_PATTERN.fullmatch(value["archiveSHA256"]) is None
    ):
        raise AssetManifestError("build provenance value is invalid")
    return value


def canonical_file_name(os_name: str, architecture: str) -> str:
    return f"relux-relay-{os_name}-{architecture}"


def canonical_archive_path(os_name: str, architecture: str) -> str:
    return f"{os_name}-{architecture}/{canonical_file_name(os_name, architecture)}"


def load_source_contract(path: Path = DEFAULT_CONTRACT) -> dict[str, Any]:
    contract, _ = load_json(path, "relay asset source contract")
    if set(contract) != SOURCE_KEYS:
        raise AssetManifestError("relay asset source contract field set changed")
    if (
        contract.get("schemaVersion") != 1
        or contract.get("manifestSchemaVersion") != SCHEMA_VERSION
        or contract.get("relayProtocolVersion") != PROTOCOL_VERSION
    ):
        raise AssetManifestError("relay asset source contract version mismatch")
    if (
        not isinstance(contract.get("relayVersion"), str)
        or VERSION_PATTERN.fullmatch(contract["relayVersion"]) is None
        or not isinstance(contract.get("sourceCommit"), str)
        or COMMIT_PATTERN.fullmatch(contract["sourceCommit"]) is None
        or contract.get("bundleSubdirectory") != "relay-assets-v1"
    ):
        raise AssetManifestError("relay asset source build identity is invalid")
    validate_provenance(contract.get("buildProvenance"))

    assets = contract.get("assets")
    if not isinstance(assets, list) or len(assets) != len(TARGETS):
        raise AssetManifestError("relay asset source must contain exactly four assets")
    tuples: set[tuple[str, str]] = set()
    names: set[str] = set()
    paths: set[str] = set()
    for index, (asset, expected_target) in enumerate(zip(assets, TARGETS, strict=True)):
        if not isinstance(asset, dict) or set(asset) != SOURCE_ASSET_KEYS:
            raise AssetManifestError("relay asset source entry field set changed")
        target = (asset.get("os"), asset.get("arch"))
        if target != expected_target or target in tuples:
            raise AssetManifestError(
                "relay asset source target order or uniqueness changed"
            )
        os_name, architecture = expected_target
        expected_name = canonical_file_name(os_name, architecture)
        expected_path = canonical_archive_path(os_name, architecture)
        if (
            asset.get("fileName") != expected_name
            or asset.get("archivePath") != expected_path
        ):
            raise AssetManifestError(
                f"relay asset source name is not canonical at index {index}"
            )
        if (
            type(asset.get("byteSize")) is not int
            or asset["byteSize"] <= 0
            or asset["byteSize"] > MAX_ASSET_BYTES
            or not isinstance(asset.get("sha256"), str)
            or SHA256_PATTERN.fullmatch(asset["sha256"]) is None
        ):
            raise AssetManifestError(
                f"relay asset source digest is invalid: {expected_name}"
            )
        tuples.add(target)
        names.add(expected_name)
        paths.add(expected_path)
    if len(tuples) != 4 or len(names) != 4 or len(paths) != 4:
        raise AssetManifestError("relay asset source contains a duplicate asset")
    return contract


def verify_schema(path: Path = DEFAULT_SCHEMA) -> None:
    schema, _ = load_json(path, "relay asset manifest schema")
    if (
        schema.get("type") != "object"
        or schema.get("additionalProperties") is not False
        or set(schema.get("required", [])) != MANIFEST_KEYS
        or set(schema.get("properties", {})) != MANIFEST_KEYS
        or schema["properties"]["schemaVersion"].get("const") != SCHEMA_VERSION
        or schema["properties"]["relayProtocolVersion"].get("const") != PROTOCOL_VERSION
    ):
        raise AssetManifestError("relay asset manifest schema root contract changed")
    definitions = schema.get("$defs")
    if not isinstance(definitions, dict) or set(definitions) != {
        "asset",
        "buildIdentity",
        "buildProvenance",
    }:
        raise AssetManifestError("relay asset manifest schema definitions changed")
    expected = {
        "asset": MANIFEST_ASSET_KEYS,
        "buildIdentity": IDENTITY_KEYS,
        "buildProvenance": PROVENANCE_KEYS,
    }
    for name, keys in expected.items():
        definition = definitions[name]
        if (
            definition.get("type") != "object"
            or definition.get("additionalProperties") is not False
            or set(definition.get("required", [])) != keys
            or set(definition.get("properties", {})) != keys
        ):
            raise AssetManifestError(
                f"relay asset manifest schema {name} contract changed"
            )


def verify_binary_header(contents: bytes, os_name: str, architecture: str) -> None:
    if os_name == "darwin":
        if len(contents) < 8 or contents[:4] != b"\xcf\xfa\xed\xfe":
            raise AssetManifestError(
                "relay asset has an unparseable Darwin executable header"
            )
        machine = struct.unpack_from("<I", contents, 4)[0]
        expected = 0x01000007 if architecture == "amd64" else 0x0100000C
    else:
        if (
            len(contents) < 20
            or contents[:4] != b"\x7fELF"
            or contents[4] != 2
            or contents[5] != 1
        ):
            raise AssetManifestError(
                "relay asset has an unparseable Linux executable header"
            )
        machine = struct.unpack_from("<H", contents, 18)[0]
        expected = 62 if architecture == "amd64" else 183
    if machine != expected:
        raise AssetManifestError(
            "relay asset executable platform does not match its tuple"
        )


def verify_embedded_identity(contents: bytes, contract: dict[str, Any]) -> None:
    commit = contract["sourceCommit"].encode("ascii")
    version = ("Xb" + contract["relayVersion"]).encode("ascii")
    if contents.count(commit) != 1 or version not in contents:
        raise AssetManifestError("relay asset embedded build identity mismatch")


def parse_tar_number(field: bytes, label: str) -> int:
    encoded = field.rstrip(b"\0 ").lstrip(b" ")
    if not encoded or any(byte not in b"01234567" for byte in encoded):
        raise AssetManifestError(f"trusted relay archive {label} is invalid")
    return int(encoded, 8)


def read_exact_stream(stream: Any, size: int, label: str) -> bytes:
    chunks: list[bytes] = []
    remaining = size
    while remaining:
        chunk = stream.read(min(remaining, READ_CHUNK_BYTES))
        if not chunk:
            raise AssetManifestError(f"trusted relay archive {label} is truncated")
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def validate_archive_trailer(stream: Any) -> None:
    chunks: list[bytes] = []
    total = 0
    while True:
        chunk = stream.read(
            min(READ_CHUNK_BYTES, MAX_ARCHIVE_TRAILER_BYTES + 1 - total)
        )
        if not chunk:
            break
        chunks.append(chunk)
        total += len(chunk)
        if total > MAX_ARCHIVE_TRAILER_BYTES:
            raise AssetManifestError(
                "trusted relay archive metadata exceeds its size limit"
            )
    trailer = b"".join(chunks)
    if len(trailer) < 1024 or any(trailer):
        raise AssetManifestError("trusted relay archive trailer is invalid")


def parse_ustar_assets(stream: Any, contract: dict[str, Any]) -> list[bytes]:
    contents_by_target: list[bytes] = []
    for asset in contract["assets"]:
        header = read_exact_stream(stream, 512, "header")
        if header == bytes(512):
            raise AssetManifestError("trusted relay archive is missing an asset")
        stored_checksum = parse_tar_number(header[148:156], "header checksum")
        computed_checksum = sum(header[:148]) + (8 * ord(" ")) + sum(header[156:])
        if stored_checksum != computed_checksum:
            raise AssetManifestError("trusted relay archive header checksum mismatch")
        if header[257:263] != b"ustar\0" or header[156:157] not in {b"0", b"\0"}:
            raise AssetManifestError("trusted relay archive contains unsafe metadata")
        try:
            name = header[:100].split(b"\0", 1)[0].decode("ascii")
            prefix = header[345:500].split(b"\0", 1)[0].decode("ascii")
        except UnicodeDecodeError as error:
            raise AssetManifestError(
                "trusted relay archive member name is invalid"
            ) from error
        if prefix:
            name = f"{prefix}/{name}"
        member_size = parse_tar_number(header[124:136], "member size")
        member_mode = parse_tar_number(header[100:108], "member mode")
        if (
            name != asset["archivePath"]
            or member_size != asset["byteSize"]
            or member_mode != 0o755
        ):
            raise AssetManifestError(
                "trusted relay archive member set, order, or metadata changed"
            )
        contents = read_exact_stream(stream, member_size, "asset")
        padding_size = (-member_size) % 512
        if padding_size and read_exact_stream(stream, padding_size, "padding") != bytes(
            padding_size
        ):
            raise AssetManifestError("trusted relay archive padding is invalid")
        if sha256_bytes(contents) != asset["sha256"]:
            raise AssetManifestError("trusted relay archive asset checksum mismatch")
        verify_binary_header(contents, asset["os"], asset["arch"])
        verify_embedded_identity(contents, contract)
        contents_by_target.append(contents)

    validate_archive_trailer(stream)
    return contents_by_target


def read_archive_assets(archive: Path, contract: dict[str, Any]) -> list[bytes]:
    provenance = validate_provenance(contract["buildProvenance"])
    descriptor: int | None
    descriptor, _ = open_regular_path(
        archive,
        "trusted relay archive",
        maximum_size=MAX_ARCHIVE_BYTES,
    )
    try:
        try:
            archive_stream = os.fdopen(descriptor, "rb")
        except BaseException:
            close_descriptor_after_fdopen_failure(descriptor)
            descriptor = None
            raise
        descriptor = None
        with archive_stream:
            if sha256_stream(archive_stream) != provenance["archiveSHA256"]:
                raise AssetManifestError("trusted relay archive checksum mismatch")
            archive_stream.seek(0)
            with gzip.GzipFile(fileobj=archive_stream, mode="rb") as decompressed:
                return parse_ustar_assets(decompressed, contract)
    except (EOFError, gzip.BadGzipFile, OSError) as error:
        raise AssetManifestError("trusted relay archive is unparseable") from error
    finally:
        if descriptor is not None:
            os.close(descriptor)


def build_manifest(contract: dict[str, Any], contents: list[bytes]) -> dict[str, Any]:
    assets: list[dict[str, Any]] = []
    for source, binary in zip(contract["assets"], contents, strict=True):
        digest = sha256_bytes(binary)
        identity = {
            "schemaVersion": IDENTITY_SCHEMA_VERSION,
            "relayProtocolVersion": contract["relayProtocolVersion"],
            "relayVersion": contract["relayVersion"],
            "sourceCommit": contract["sourceCommit"],
            "os": source["os"],
            "arch": source["arch"],
            "selfSha256": digest,
        }
        assets.append(
            {
                "os": source["os"],
                "arch": source["arch"],
                "fileName": source["fileName"],
                "bundleLocation": f"{contract['bundleSubdirectory']}/{source['fileName']}",
                "byteSize": len(binary),
                "sha256": digest,
                "relayProtocolVersion": contract["relayProtocolVersion"],
                "buildIdentity": identity,
                "buildProvenanceReference": "#/buildProvenance",
            }
        )
    return {
        "schemaVersion": contract["manifestSchemaVersion"],
        "relayProtocolVersion": contract["relayProtocolVersion"],
        "buildProvenance": contract["buildProvenance"],
        "assets": assets,
    }


def validate_manifest(manifest: dict[str, Any], contract: dict[str, Any]) -> None:
    if set(manifest) != MANIFEST_KEYS:
        raise AssetManifestError("relay asset manifest field set changed")
    if (
        manifest.get("schemaVersion") != SCHEMA_VERSION
        or manifest.get("relayProtocolVersion") != PROTOCOL_VERSION
    ):
        raise AssetManifestError("relay asset manifest version mismatch")
    if (
        validate_provenance(manifest.get("buildProvenance"))
        != contract["buildProvenance"]
    ):
        raise AssetManifestError("relay asset manifest provenance mismatch")
    assets = manifest.get("assets")
    if not isinstance(assets, list) or len(assets) != len(TARGETS):
        raise AssetManifestError(
            "relay asset manifest must contain exactly four assets"
        )
    tuples: set[tuple[str, str]] = set()
    names: set[str] = set()
    locations: set[str] = set()
    for asset, source, expected_target in zip(
        assets, contract["assets"], TARGETS, strict=True
    ):
        if not isinstance(asset, dict) or set(asset) != MANIFEST_ASSET_KEYS:
            raise AssetManifestError("relay asset manifest entry field set changed")
        target = (asset.get("os"), asset.get("arch"))
        if target != expected_target or target in tuples:
            raise AssetManifestError(
                "relay asset manifest target order or uniqueness changed"
            )
        expected_location = f"{contract['bundleSubdirectory']}/{source['fileName']}"
        if (
            asset.get("fileName") != source["fileName"]
            or asset.get("bundleLocation") != expected_location
            or asset.get("byteSize") != source["byteSize"]
            or asset.get("sha256") != source["sha256"]
            or asset.get("relayProtocolVersion") != PROTOCOL_VERSION
            or asset.get("buildProvenanceReference") != "#/buildProvenance"
        ):
            raise AssetManifestError(
                "relay asset manifest entry does not match trusted source"
            )
        identity = asset.get("buildIdentity")
        expected_identity = {
            "schemaVersion": IDENTITY_SCHEMA_VERSION,
            "relayProtocolVersion": PROTOCOL_VERSION,
            "relayVersion": contract["relayVersion"],
            "sourceCommit": contract["sourceCommit"],
            "os": source["os"],
            "arch": source["arch"],
            "selfSha256": source["sha256"],
        }
        if not isinstance(identity, dict) or set(identity) != IDENTITY_KEYS:
            raise AssetManifestError(
                "relay asset manifest build identity field set changed"
            )
        if identity != expected_identity:
            raise AssetManifestError("relay asset manifest build identity mismatch")
        tuples.add(target)
        names.add(asset["fileName"])
        locations.add(asset["bundleLocation"])
    if len(tuples) != 4 or len(names) != 4 or len(locations) != 4:
        raise AssetManifestError("relay asset manifest contains duplicate assets")


def open_bundle_directory(bundle: Path) -> int:
    no_follow = getattr(os, "O_NOFOLLOW", None)
    directory_flag = getattr(os, "O_DIRECTORY", None)
    if no_follow is None or directory_flag is None:
        raise AssetManifestError(
            "trusted relay directory no-follow opens are unavailable"
        )
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | no_follow | directory_flag
    descriptor: int | None = None
    try:
        descriptor = os.open(bundle, flags)
        status = os.fstat(descriptor)
    except OSError as error:
        if descriptor is not None:
            os.close(descriptor)
        raise AssetManifestError("relay asset bundle is missing or unsafe") from error
    if not stat.S_ISDIR(status.st_mode):
        os.close(descriptor)
        raise AssetManifestError("relay asset bundle is missing or unsafe")
    return descriptor


def open_bundle_directory_at(
    parent_descriptor: int, name: str, label: str
) -> tuple[int, os.stat_result]:
    if not name or name in {".", ".."} or PurePosixPath(name).name != name:
        raise AssetManifestError(f"{label} name is unsafe")
    no_follow = getattr(os, "O_NOFOLLOW", None)
    directory_flag = getattr(os, "O_DIRECTORY", None)
    if no_follow is None or directory_flag is None:
        raise AssetManifestError(
            "trusted relay directory no-follow opens are unavailable"
        )
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | no_follow | directory_flag
    descriptor: int | None = None
    try:
        descriptor = os.open(name, flags, dir_fd=parent_descriptor)
        status = os.fstat(descriptor)
    except OSError as error:
        if descriptor is not None:
            os.close(descriptor)
        raise AssetManifestError(f"{label} is missing or unsafe") from error
    if not stat.S_ISDIR(status.st_mode) or stat.S_ISLNK(status.st_mode):
        os.close(descriptor)
        raise AssetManifestError(f"{label} is missing or unsafe")
    return descriptor, status


def entry_status_at(parent_descriptor: int, name: str, label: str) -> os.stat_result:
    if not name or name in {".", ".."} or PurePosixPath(name).name != name:
        raise AssetManifestError(f"{label} name is unsafe")
    try:
        return os.stat(name, dir_fd=parent_descriptor, follow_symlinks=False)
    except OSError as error:
        raise AssetManifestError(f"{label} is unavailable") from error


def directory_identity_at(
    parent_descriptor: int, name: str, label: str
) -> tuple[int, int]:
    status = entry_status_at(parent_descriptor, name, label)
    if not stat.S_ISDIR(status.st_mode) or stat.S_ISLNK(status.st_mode):
        raise AssetManifestError(f"{label} is not a safe directory")
    return status.st_dev, status.st_ino


def require_directory_identity_at(
    parent_descriptor: int,
    name: str,
    expected_identity: tuple[int, int],
    label: str,
) -> None:
    if directory_identity_at(parent_descriptor, name, label) != expected_identity:
        raise AssetManifestError(f"{label} identity changed")


def observe_bundle_publication_intent(
    parent_descriptor: int, destination_name: str
) -> BundlePublicationIntent:
    if (
        not destination_name
        or destination_name in {".", ".."}
        or PurePosixPath(destination_name).name != destination_name
    ):
        raise AssetManifestError("relay asset bundle destination name is unsafe")
    try:
        status = os.stat(
            destination_name,
            dir_fd=parent_descriptor,
            follow_symlinks=False,
        )
    except FileNotFoundError:
        return BundlePublicationIntent(BundlePublicationMode.INITIAL_NO_REPLACE)
    except OSError as error:
        raise AssetManifestError(
            "relay asset bundle destination is unavailable"
        ) from error
    if not stat.S_ISDIR(status.st_mode) or stat.S_ISLNK(status.st_mode):
        raise AssetManifestError("relay asset bundle destination is unsafe")
    return BundlePublicationIntent(
        BundlePublicationMode.REPLACE_EXISTING,
        (status.st_dev, status.st_ino),
    )


def open_regular_at(
    directory_descriptor: int,
    name: str,
    label: str,
    *,
    maximum_size: int,
    expected_size: int | None = None,
) -> tuple[int, os.stat_result]:
    if not name or name in {".", ".."} or PurePosixPath(name).name != name:
        raise AssetManifestError(f"{label} name is unsafe")
    no_follow = getattr(os, "O_NOFOLLOW", None)
    if no_follow is None:
        raise AssetManifestError("trusted relay input no-follow reads are unavailable")
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0) | no_follow
    descriptor: int | None = None
    try:
        descriptor = os.open(name, flags, dir_fd=directory_descriptor)
        status = os.fstat(descriptor)
    except OSError as error:
        if descriptor is not None:
            os.close(descriptor)
        raise AssetManifestError(f"{label} is missing or unsafe") from error
    if not stat.S_ISREG(status.st_mode):
        os.close(descriptor)
        raise AssetManifestError(f"{label} is not a regular file")
    if status.st_size > maximum_size:
        os.close(descriptor)
        raise AssetManifestError(f"{label} exceeds its size limit")
    if expected_size is not None and status.st_size != expected_size:
        os.close(descriptor)
        raise AssetManifestError(f"{label} size does not match the manifest")
    return descriptor, status


def count_new_matches(window: bytes, previous_tail_size: int, pattern: bytes) -> int:
    count = 0
    start = 0
    while True:
        match = window.find(pattern, start)
        if match < 0:
            return count
        if match + len(pattern) > previous_tail_size:
            count += 1
        start = match + 1


def validate_asset_descriptor(
    descriptor: int,
    status: os.stat_result,
    asset: dict[str, Any],
    source: dict[str, Any],
    contract: dict[str, Any],
) -> None:
    if stat.S_IMODE(status.st_mode) != 0o755:
        raise AssetManifestError("relay asset has an unsafe mode")

    commit = contract["sourceCommit"].encode("ascii")
    version = ("Xb" + contract["relayVersion"]).encode("ascii")
    maximum_pattern_size = max(len(commit), len(version))
    tail = b""
    header = bytearray()
    commit_count = 0
    version_seen = False
    total = 0
    digest = hashlib.sha256()

    try:
        while True:
            chunk = os.read(descriptor, READ_CHUNK_BYTES)
            if not chunk:
                break
            total += len(chunk)
            if total > asset["byteSize"]:
                raise AssetManifestError("relay asset grew while reading")
            digest.update(chunk)
            if len(header) < 20:
                header.extend(chunk[: 20 - len(header)])
            window = tail + chunk
            commit_count += count_new_matches(window, len(tail), commit)
            if not version_seen:
                version_seen = count_new_matches(window, len(tail), version) > 0
            tail = window[-(maximum_pattern_size - 1) :]
    except OSError as error:
        raise AssetManifestError("relay asset could not be read") from error

    if total != asset["byteSize"]:
        raise AssetManifestError("relay asset size changed while reading")
    if digest.hexdigest() != asset["sha256"]:
        raise AssetManifestError("relay asset bytes do not match the manifest")
    verify_binary_header(bytes(header), source["os"], source["arch"])
    if commit_count != 1 or not version_seen:
        raise AssetManifestError("relay asset embedded build identity mismatch")


def validate_bundle_descriptor(
    directory_descriptor: int, contract: dict[str, Any]
) -> dict[str, Any]:
    try:
        entries = os.listdir(directory_descriptor)
    except OSError as error:
        raise AssetManifestError("relay asset bundle is unavailable") from error
    expected_files = {MANIFEST_NAME} | {
        source["fileName"] for source in contract["assets"]
    }
    actual_files = set(entries)
    if actual_files != expected_files or len(entries) != len(expected_files):
        raise AssetManifestError(
            "relay asset bundle has missing, renamed, or extra resources"
        )

    manifest_descriptor, _ = open_regular_at(
        directory_descriptor,
        MANIFEST_NAME,
        "relay asset manifest",
        maximum_size=MAX_MANIFEST_BYTES,
    )
    try:
        encoded = read_bounded_descriptor(
            manifest_descriptor,
            label="relay asset manifest",
            maximum_size=MAX_MANIFEST_BYTES,
        )
    finally:
        os.close(manifest_descriptor)
    try:
        manifest = json.loads(encoded.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise AssetManifestError("relay asset manifest is not valid JSON") from error
    if not isinstance(manifest, dict):
        raise AssetManifestError("relay asset manifest must be an object")
    if encoded != stable_json(manifest):
        raise AssetManifestError(
            "relay asset manifest is not canonical deterministic JSON"
        )
    validate_manifest(manifest, contract)
    for asset, source in zip(manifest["assets"], contract["assets"], strict=True):
        asset_descriptor, status = open_regular_at(
            directory_descriptor,
            source["fileName"],
            "relay asset",
            maximum_size=MAX_ASSET_BYTES,
            expected_size=asset["byteSize"],
        )
        try:
            validate_asset_descriptor(asset_descriptor, status, asset, source, contract)
        finally:
            os.close(asset_descriptor)
    return manifest


def validate_bundle(bundle: Path, contract: dict[str, Any]) -> dict[str, Any]:
    directory_descriptor = open_bundle_directory(bundle)
    try:
        return validate_bundle_descriptor(directory_descriptor, contract)
    finally:
        os.close(directory_descriptor)


def swift_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=True)


def render_swift(manifest: dict[str, Any]) -> bytes:
    provenance = manifest["buildProvenance"]
    lines = [
        "// Generated by scripts/relay_asset_manifest.py; do not edit.",
        "",
        "import Foundation",
        "",
        "extension RelayAssetCatalog {",
        f"  static let generatedSchemaVersion = {manifest['schemaVersion']}",
        f"  static let generatedProtocolVersion = {manifest['relayProtocolVersion']}",
        "",
        "  static let generatedBuildProvenance = RelayAssetBuildProvenance(",
        f"    kind: {swift_string(provenance['kind'])},",
        f"    taskID: {swift_string(provenance['taskID'])},",
        f"    resourceName: {swift_string(provenance['resourceName'])},",
        f"    archiveSHA256: {swift_string(provenance['archiveSHA256'])})",
        "",
        "  static let generatedAssets: [RelayBundledAsset] = [",
    ]
    for asset in manifest["assets"]:
        identity = asset["buildIdentity"]
        byte_size = f"{asset['byteSize']:,}".replace(",", "_")
        lines.extend(
            [
                "    RelayBundledAsset(",
                "      platform: RelayRemotePlatform(",
                f"        operatingSystem: .{asset['os']},",
                f"        architecture: .{asset['arch']}),",
                f"      fileName: {swift_string(asset['fileName'])},",
                f"      bundleLocation: {swift_string(asset['bundleLocation'])},",
                f"      byteSize: {byte_size},",
                f"      sha256: {swift_string(asset['sha256'])},",
                f"      relayProtocolVersion: {asset['relayProtocolVersion']},",
                "      buildIdentity: RelayAssetBuildIdentity(",
                f"        schemaVersion: {identity['schemaVersion']},",
                f"        relayProtocolVersion: {identity['relayProtocolVersion']},",
                f"        relayVersion: {swift_string(identity['relayVersion'])},",
                f"        sourceCommit: {swift_string(identity['sourceCommit'])},",
                f"        operatingSystem: .{identity['os']},",
                f"        architecture: .{identity['arch']},",
                f"        selfSHA256: {swift_string(identity['selfSha256'])}),",
                f"      buildProvenanceReference: {swift_string(asset['buildProvenanceReference'])}),",
            ]
        )
    lines.extend(["  ]", "}", ""])
    return "\n".join(lines).encode("utf-8")


def write_new_file_at(
    directory_descriptor: int, name: str, contents: bytes, mode: int
) -> None:
    if not name or name in {".", ".."} or PurePosixPath(name).name != name:
        raise AssetManifestError("relay asset output name is unsafe")
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_CLOEXEC", 0)
    no_follow = getattr(os, "O_NOFOLLOW", None)
    if no_follow is None:
        raise AssetManifestError(
            "trusted relay output no-follow writes are unavailable"
        )
    descriptor: int | None = None
    try:
        descriptor = os.open(name, flags | no_follow, mode, dir_fd=directory_descriptor)
        os.fchmod(descriptor, mode)
        try:
            stream = os.fdopen(descriptor, "wb")
        except BaseException:
            close_descriptor_after_fdopen_failure(descriptor)
            descriptor = None
            raise
        descriptor = None
        with stream:
            stream.write(contents)
            stream.flush()
            os.fsync(stream.fileno())
    except FileExistsError as error:
        raise AssetManifestError("relay asset output already exists") from error
    except OSError as error:
        raise AssetManifestError("relay asset output could not be written") from error
    finally:
        if descriptor is not None:
            os.close(descriptor)


def directory_identity(path: Path, label: str) -> tuple[int, int]:
    try:
        status = os.lstat(path)
    except OSError as error:
        raise AssetManifestError(f"{label} is unavailable") from error
    if not stat.S_ISDIR(status.st_mode) or stat.S_ISLNK(status.st_mode):
        raise AssetManifestError(f"{label} is not a safe directory")
    return status.st_dev, status.st_ino


def remove_owned_bundle_entries(directory_descriptor: int) -> None:
    allowed_names = {
        MANIFEST_NAME,
        *(canonical_file_name(*target) for target in TARGETS),
    }
    seen: set[str] = set()
    try:
        with os.scandir(directory_descriptor) as entries:
            for entry in entries:
                name = entry.name
                if (
                    name in seen
                    or name not in allowed_names
                    or len(seen) >= len(allowed_names)
                ):
                    raise AssetManifestError(
                        "relay asset staging contains an unsupported entry"
                    )
                status = os.stat(
                    name,
                    dir_fd=directory_descriptor,
                    follow_symlinks=False,
                )
                if not stat.S_ISREG(status.st_mode) or stat.S_ISLNK(status.st_mode):
                    raise AssetManifestError(
                        "relay asset staging contains an unsafe entry"
                    )
                os.unlink(name, dir_fd=directory_descriptor)
                seen.add(name)
    except OSError as error:
        raise AssetManifestError("relay asset staging cleanup failed") from error


def remove_owned_directory_at(
    parent_descriptor: int,
    name: str,
    identity: tuple[int, int],
    *,
    missing_ok: bool = False,
) -> None:
    directory_descriptor: int | None = None
    try:
        if missing_ok:
            try:
                os.stat(name, dir_fd=parent_descriptor, follow_symlinks=False)
            except FileNotFoundError:
                return
            except OSError as error:
                raise AssetManifestError(
                    "relay asset staging cleanup failed"
                ) from error
        directory_descriptor, status = open_bundle_directory_at(
            parent_descriptor,
            name,
            "relay asset staging directory",
        )
        if (status.st_dev, status.st_ino) != identity:
            raise AssetManifestError(
                "relay asset staging ownership changed; refusing unsafe cleanup"
            )
        remove_owned_bundle_entries(directory_descriptor)
        require_directory_identity_at(
            parent_descriptor,
            name,
            identity,
            "relay asset staging directory",
        )
        try:
            os.rmdir(name, dir_fd=parent_descriptor)
        except OSError as error:
            raise AssetManifestError("relay asset staging cleanup failed") from error
    finally:
        if directory_descriptor is not None:
            os.close(directory_descriptor)


def remove_owned_directory(
    path: Path,
    identity: tuple[int, int],
    *,
    missing_ok: bool = False,
) -> None:
    parent_descriptor = open_bundle_directory(path.parent)
    try:
        remove_owned_directory_at(
            parent_descriptor,
            path.name,
            identity,
            missing_ok=missing_ok,
        )
    finally:
        os.close(parent_descriptor)


def atomic_rename_at(
    directory_descriptor: int,
    source_name: str,
    destination_name: str,
    *,
    exchange: bool,
) -> None:
    for name in (source_name, destination_name):
        if not name or name in {".", ".."} or PurePosixPath(name).name != name:
            raise AssetManifestError("relay asset publication name is unsafe")
    library = ctypes.CDLL(None, use_errno=True)
    source_bytes = os.fsencode(source_name)
    destination_bytes = os.fsencode(destination_name)
    if sys.platform == "darwin":
        function = library.renameatx_np
        function.argtypes = [
            ctypes.c_int,
            ctypes.c_char_p,
            ctypes.c_int,
            ctypes.c_char_p,
            ctypes.c_uint,
        ]
        function.restype = ctypes.c_int
        flag = 0x00000002 if exchange else 0x00000004
        result = function(
            directory_descriptor,
            source_bytes,
            directory_descriptor,
            destination_bytes,
            flag,
        )
    elif sys.platform.startswith("linux"):
        function = library.renameat2
        function.argtypes = [
            ctypes.c_int,
            ctypes.c_char_p,
            ctypes.c_int,
            ctypes.c_char_p,
            ctypes.c_uint,
        ]
        function.restype = ctypes.c_int
        flag = 0x00000002 if exchange else 0x00000001
        result = function(
            directory_descriptor,
            source_bytes,
            directory_descriptor,
            destination_bytes,
            flag,
        )
    else:
        raise AssetManifestError(
            "atomic relay asset directory replacement is unavailable"
        )
    if result != 0:
        error_number = ctypes.get_errno()
        operation = "replacement" if exchange else "initial publication"
        raise AssetManifestError(
            f"atomic relay asset directory {operation} failed"
        ) from OSError(error_number, os.strerror(error_number))


def publish_staged_bundle(
    staging: Path,
    bundle: Path,
    event_hook: Callable[[str, Path], None] | None,
    *,
    publication_intent: BundlePublicationIntent,
) -> None:
    parent = bundle.parent
    if staging.parent != parent:
        raise AssetManifestError("relay asset staging directory is not a sibling")
    parent_descriptor = open_bundle_directory(parent)
    try:
        if publication_intent.mode is BundlePublicationMode.INITIAL_NO_REPLACE:
            if event_hook is not None:
                event_hook("before_initial_publish", bundle)
            atomic_rename_at(
                parent_descriptor, staging.name, bundle.name, exchange=False
            )
            os.fsync(parent_descriptor)
            if event_hook is not None:
                event_hook("after_publish", bundle)
            return

        expected_identity = publication_intent.existing_identity
        if expected_identity is None:
            raise AssetManifestError("relay asset publication intent is invalid")
        staged_identity = directory_identity_at(
            parent_descriptor, staging.name, "relay asset staging directory"
        )
        require_directory_identity_at(
            parent_descriptor,
            bundle.name,
            expected_identity,
            "relay asset bundle destination",
        )
        if event_hook is not None:
            event_hook("before_exchange", bundle)
        atomic_rename_at(parent_descriptor, staging.name, bundle.name, exchange=True)
        displaced_status = entry_status_at(
            parent_descriptor, staging.name, "displaced relay asset bundle"
        )
        displaced_identity = (displaced_status.st_dev, displaced_status.st_ino)
        if (
            not stat.S_ISDIR(displaced_status.st_mode)
            or stat.S_ISLNK(displaced_status.st_mode)
            or displaced_identity != expected_identity
        ):
            try:
                atomic_rename_at(
                    parent_descriptor, staging.name, bundle.name, exchange=True
                )
                os.fsync(parent_descriptor)
                require_directory_identity_at(
                    parent_descriptor,
                    staging.name,
                    staged_identity,
                    "relay asset staging directory",
                )
                restored_status = entry_status_at(
                    parent_descriptor,
                    bundle.name,
                    "restored relay asset bundle destination",
                )
                if (
                    restored_status.st_dev,
                    restored_status.st_ino,
                ) != displaced_identity:
                    raise AssetManifestError(
                        "foreign relay asset bundle restoration identity changed"
                    )
            except AssetManifestError as error:
                raise AssetManifestError(
                    "relay asset bundle destination changed during atomic exchange "
                    "and could not be restored"
                ) from error
            raise AssetManifestError(
                "relay asset bundle destination changed during atomic exchange"
            )
        try:
            os.fsync(parent_descriptor)
            if event_hook is not None:
                event_hook("after_exchange", bundle)
        finally:
            remove_owned_directory_at(
                parent_descriptor,
                staging.name,
                displaced_identity,
            )
            os.fsync(parent_descriptor)
    finally:
        os.close(parent_descriptor)


def generate_bundle(
    archive: Path,
    bundle: Path,
    contract: dict[str, Any],
    *,
    event_hook: Callable[[str, Path], None] | None = None,
) -> dict[str, Any]:
    contents = read_archive_assets(archive, contract)
    manifest = build_manifest(contract, contents)
    validate_manifest(manifest, contract)

    parent = bundle.parent
    try:
        parent.mkdir(parents=True, mode=0o755, exist_ok=True)
    except OSError as error:
        raise AssetManifestError("relay asset bundle parent is unavailable") from error
    directory_identity(parent, "relay asset bundle parent")
    parent_descriptor = open_bundle_directory(parent)
    try:
        publication_intent = observe_bundle_publication_intent(
            parent_descriptor, bundle.name
        )
    finally:
        os.close(parent_descriptor)
    if event_hook is not None:
        event_hook("after_initial_destination_observation", bundle)

    if publication_intent.mode is BundlePublicationMode.REPLACE_EXISTING:
        expected_identity = publication_intent.existing_identity
        if expected_identity is None:
            raise AssetManifestError("relay asset publication intent is invalid")
        existing: dict[str, Any] | None = None
        existing_is_valid = False
        parent_descriptor = open_bundle_directory(parent)
        try:
            existing_descriptor, existing_status = open_bundle_directory_at(
                parent_descriptor,
                bundle.name,
                "observed relay asset bundle destination",
            )
            try:
                if (
                    existing_status.st_dev,
                    existing_status.st_ino,
                ) != expected_identity:
                    raise AssetManifestError(
                        "observed relay asset bundle destination identity changed"
                    )
                try:
                    existing = validate_bundle_descriptor(existing_descriptor, contract)
                except AssetManifestError:
                    pass
                else:
                    existing_is_valid = True
            finally:
                os.close(existing_descriptor)
            if existing_is_valid:
                require_directory_identity_at(
                    parent_descriptor,
                    bundle.name,
                    expected_identity,
                    "observed relay asset bundle destination",
                )
        finally:
            os.close(parent_descriptor)
        if existing_is_valid:
            if existing != manifest:
                raise AssetManifestError("existing relay asset bundle is stale")
            return manifest

    try:
        staging = Path(tempfile.mkdtemp(prefix=f".{bundle.name}.staging-", dir=parent))
    except OSError as error:
        raise AssetManifestError(
            "relay asset staging directory creation failed"
        ) from error
    staging_identity = directory_identity(staging, "relay asset staging directory")
    try:
        staging_descriptor = open_bundle_directory(staging)
        try:
            for source, binary in zip(contract["assets"], contents, strict=True):
                write_new_file_at(staging_descriptor, source["fileName"], binary, 0o755)
                if event_hook is not None:
                    event_hook("after_asset_write", staging)
            write_new_file_at(
                staging_descriptor, MANIFEST_NAME, stable_json(manifest), 0o644
            )
            os.fsync(staging_descriptor)
        finally:
            os.close(staging_descriptor)
        validate_bundle(staging, contract)
        try:
            os.chmod(staging, 0o755, follow_symlinks=False)
        except OSError as error:
            raise AssetManifestError(
                "relay asset staging mode update failed"
            ) from error
        if event_hook is not None:
            event_hook("before_publish", staging)
        publish_staged_bundle(
            staging,
            bundle,
            event_hook,
            publication_intent=publication_intent,
        )
    except BaseException:
        remove_owned_directory(staging, staging_identity, missing_ok=True)
        raise
    validate_bundle(bundle, contract)
    return manifest


def verify_swift(path: Path, manifest: dict[str, Any]) -> None:
    expected = render_swift(manifest)
    actual, _ = read_regular_file(
        path,
        "generated Swift relay asset lookup",
        maximum_size=MAX_METADATA_BYTES,
    )
    if actual != expected:
        raise AssetManifestError("generated Swift relay asset lookup is stale")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command", choices=("generate", "validate", "check", "render-swift")
    )
    parser.add_argument("--contract", type=Path, default=DEFAULT_CONTRACT)
    parser.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA)
    parser.add_argument("--archive", type=Path, default=DEFAULT_ARCHIVE)
    parser.add_argument("--bundle", type=Path, default=DEFAULT_BUNDLE)
    parser.add_argument("--swift-output", type=Path, default=DEFAULT_SWIFT)
    return parser.parse_args()


def main() -> int:
    arguments = parse_args()
    try:
        verify_schema(arguments.schema)
        contract = load_source_contract(arguments.contract)
        if arguments.command == "generate":
            manifest = generate_bundle(arguments.archive, arguments.bundle, contract)
            verify_swift(arguments.swift_output, manifest)
        elif arguments.command == "validate":
            validate_bundle(arguments.bundle, contract)
        elif arguments.command == "check":
            archive_contents = read_archive_assets(arguments.archive, contract)
            expected = build_manifest(contract, archive_contents)
            actual = validate_bundle(arguments.bundle, contract)
            if actual != expected:
                raise AssetManifestError("relay asset bundle regeneration drift")
            verify_swift(arguments.swift_output, expected)
        else:
            contents = read_archive_assets(arguments.archive, contract)
            sys.stdout.buffer.write(render_swift(build_manifest(contract, contents)))
    except AssetManifestError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    if arguments.command != "render-swift":
        print(f"relay asset manifest {arguments.command} passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
