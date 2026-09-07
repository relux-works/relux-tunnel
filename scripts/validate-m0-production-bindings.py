#!/usr/bin/env python3
"""Fail-closed validator for the accepted M0 production binding manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


EXPECTED_TASKS = {
    "TASK-260715-nphtib",
    "TASK-260715-2jatnd",
    "TASK-260715-1gjxer",
}
EXPECTED_KINDS = {
    "generatedProjectArchitecture",
    "packetBridgeAndHEV",
    "sshEngine",
}
EXPECTED_COMPATIBILITY_ROWS = {
    "M1-CONTRACT-SCHEMA",
    "M1-GRAPH-DIRECTION",
    "M1-CANDIDATE-NEUTRAL-CORE",
    "M1-PACKET-ACTIVATION-ORDER",
    "M1-SSH-BEFORE-ROUTES",
    "M1-BOUND-VALUES",
    "M1-DEFERRED-NOT-PROMOTED",
    "M1-SOLE-BINDING-SOURCE",
}
# SHA-256 of canonical_contract_payload() for the reviewer-accepted manifest.
# Resource content digests are verified against the board-owned bytes and are
# also part of this independently pinned payload. That second binding prevents
# changed upstream bytes plus a synchronized mutable-manifest digest update
# from silently retaining permission.
EXPECTED_NORMALIZED_CONTRACT_SHA256 = (
    "26722ad220282b56169329e98e4351cd39d0fa6922385e2e3fb0e61260cbfb2b"
)
ROOT_KEYS = {
    "schemaVersion",
    "schemaIdentifier",
    "taskId",
    "runtimeContract",
    "acceptedInputs",
    "compatibilityChecks",
    "productionCompositionPermitted",
    "consumerContract",
}
RUNTIME_KEYS = {
    "taskId",
    "resourceName",
    "sha256",
    "schema",
    "reviewerVerdict",
    "supersession",
}
INPUT_KEYS = {
    "kind",
    "taskId",
    "acceptedOutcome",
    "reviewerVerdict",
    "supersession",
    "sourceOrBinaryPins",
    "requiredCapabilities",
    "bindings",
    "licenseAndMaintenanceObligations",
    "revalidationTriggers",
}
RESOURCE_KEYS = {"resourceName", "sha256"}
VERDICT_KEYS = {
    "resourceName",
    "sha256",
    "verdict",
    "acceptedAt",
    "timestampPrecision",
}
SUPERSESSION_KEYS = {"status", "supersededBy"}
COMPATIBILITY_KEYS = {"id", "result", "condition"}
CONSUMER_KEYS = {
    "taskId",
    "soleM0BindingSource",
    "productionCallSite",
    "failureBehavior",
}


class BindingError(Exception):
    """One stable validation failure."""

    def __init__(self, row: str, detail: str) -> None:
        super().__init__(detail)
        self.row = row
        self.detail = detail


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def decode_json_document(text: str, path: Path, row: str) -> Any:
    """Decode one trust-boundary JSON document without accepting duplicate keys."""

    def reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        value: dict[str, Any] = {}
        for key, item in pairs:
            if key in value:
                raise BindingError(row, f"duplicate JSON key {key!r} in {path}")
            value[key] = item
        return value

    return json.loads(text, object_pairs_hook=reject_duplicate_keys)


def load_repository_json(path: Path, row: str) -> dict[str, Any]:
    """Load a checked-in pin document without accepting duplicate JSON keys."""

    try:
        decoded = decode_json_document(
            path.read_text(encoding="utf-8"), path, row
        )
    except BindingError:
        raise
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise BindingError(row, f"unreadable or malformed {path}: {error}") from error
    return require_object(decoded, row)


def canonical_contract_payload(manifest: dict[str, Any]) -> dict[str, Any]:
    """Return every immutable binding, including accepted resource digests."""

    runtime = manifest["runtimeContract"]
    runtime_verdict = runtime["reviewerVerdict"]
    inputs = []
    for item in manifest["acceptedInputs"]:
        outcome = item["acceptedOutcome"]
        verdict = item["reviewerVerdict"]
        inputs.append(
            {
                "kind": item["kind"],
                "taskId": item["taskId"],
                "acceptedOutcome": {
                    "resourceName": outcome["resourceName"],
                    "sha256": outcome["sha256"],
                },
                "reviewerVerdict": {
                    key: verdict[key]
                    for key in (
                        "resourceName",
                        "sha256",
                        "verdict",
                        "acceptedAt",
                        "timestampPrecision",
                    )
                },
                "supersession": item["supersession"],
                "sourceOrBinaryPins": item["sourceOrBinaryPins"],
                "requiredCapabilities": item["requiredCapabilities"],
                "bindings": item["bindings"],
                "licenseAndMaintenanceObligations": item[
                    "licenseAndMaintenanceObligations"
                ],
                "revalidationTriggers": item["revalidationTriggers"],
            }
        )
    return {
        "schemaVersion": manifest["schemaVersion"],
        "schemaIdentifier": manifest["schemaIdentifier"],
        "taskId": manifest["taskId"],
        "runtimeContract": {
            "taskId": runtime["taskId"],
            "resourceName": runtime["resourceName"],
            "sha256": runtime["sha256"],
            "schema": runtime["schema"],
            "reviewerVerdict": {
                key: runtime_verdict[key]
                for key in (
                    "resourceName",
                    "sha256",
                    "verdict",
                    "acceptedAt",
                    "timestampPrecision",
                )
            },
            "supersession": runtime["supersession"],
        },
        "acceptedInputs": inputs,
        "compatibilityChecks": manifest["compatibilityChecks"],
        "consumerContract": manifest["consumerContract"],
    }


def canonical_sha256(value: Any) -> str:
    encoded = json.dumps(
        value,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def retained_tree_identity(root: Path, row: str) -> tuple[int, str]:
    """Hash the exact retained tree as sorted path/file-digest records."""

    if not root.is_dir():
        raise BindingError(row, f"retained ReluxNIOSSH tree missing: {root}")
    entries: list[dict[str, str]] = []
    try:
        for path in sorted(root.rglob("*")):
            relative = path.relative_to(root)
            if any(component in {".build", ".swiftpm"} for component in relative.parts):
                continue
            if path.is_symlink() or (path.exists() and not path.is_file() and not path.is_dir()):
                raise BindingError(row, f"unsupported retained tree entry: {relative}")
            if path.is_file():
                entries.append({"path": relative.as_posix(), "sha256": sha256(path)})
    except BindingError:
        raise
    except OSError as error:
        raise BindingError(row, f"retained ReluxNIOSSH tree unreadable: {error}") from error
    return len(entries), canonical_sha256(entries)


def require_object(value: Any, row: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise BindingError(row, "expected object")
    return value


def require_exact_keys(value: dict[str, Any], expected: set[str], row: str) -> None:
    actual = set(value)
    if actual != expected:
        missing = sorted(expected - actual)
        unknown = sorted(actual - expected)
        raise BindingError(row, f"missing={missing}; unknown={unknown}")


def require_nonempty_strings(value: Any, row: str) -> None:
    if not isinstance(value, list) or not value:
        raise BindingError(row, "expected non-empty array")
    if any(not isinstance(item, str) or not item.strip() for item in value):
        raise BindingError(row, "array entries must be non-empty strings")


def validate_verdict(verdict: Any, row: str) -> dict[str, Any]:
    value = require_object(verdict, row)
    require_exact_keys(value, VERDICT_KEYS, row)
    if value["verdict"] != "accepted":
        raise BindingError(row, "reviewer verdict is not accepted")
    if value["timestampPrecision"] != "date":
        raise BindingError(row, "unknown acceptance timestamp precision")
    accepted_at = value["acceptedAt"]
    if (
        not isinstance(accepted_at, str)
        or len(accepted_at) != 10
        or accepted_at[4] != "-"
        or accepted_at[7] != "-"
    ):
        raise BindingError(row, "acceptedAt must be an evidence-backed ISO date")
    return value


def validate_supersession(value: Any, row: str) -> None:
    supersession = require_object(value, row)
    require_exact_keys(supersession, SUPERSESSION_KEYS, row)
    if supersession["status"] != "current" or supersession["supersededBy"] is not None:
        raise BindingError(row, "accepted evidence is stale or superseded")


def verify_resource(
    resources_root: Path,
    task_id: str,
    resource: dict[str, Any],
    row: str,
) -> None:
    require_exact_keys(resource, RESOURCE_KEYS, row)
    resource_name = resource["resourceName"]
    expected_digest = resource["sha256"]
    if not isinstance(resource_name, str) or not resource_name.startswith(task_id):
        raise BindingError(row, "resource name is not task-scoped")
    path = resources_root / task_id / resource_name
    if not path.is_file():
        raise BindingError(row, f"accepted resource missing: {task_id}/{resource_name}")
    actual_digest = sha256(path)
    if actual_digest != expected_digest:
        raise BindingError(
            row,
            f"SHA-256 mismatch for {task_id}/{resource_name}: expected {expected_digest}, got {actual_digest}",
        )


def swift_lexical_view(text: str, row: str) -> tuple[str, list[bool]]:
    """Blank Swift comments and identify code positions without parsing strings as code."""

    visible = list(text)
    code = [False] * len(text)
    index = 0
    state = "code"
    block_depth = 0
    raw_hashes = 0
    while index < len(text):
        if state == "code":
            if text.startswith("//", index):
                visible[index : index + 2] = "  "
                state = "line-comment"
                index += 2
            elif text.startswith("/*", index):
                visible[index : index + 2] = "  "
                state = "block-comment"
                block_depth = 1
                index += 2
            elif text.startswith('\"\"\"', index):
                state = "multiline-string"
                index += 3
            elif text[index] == '"':
                state = "string"
                index += 1
            elif text[index] == "#":
                hashes = 1
                while index + hashes < len(text) and text[index + hashes] == "#":
                    hashes += 1
                delimiter = index + hashes
                if text.startswith('\"\"\"', delimiter):
                    state = "raw-multiline-string"
                    raw_hashes = hashes
                    index = delimiter + 3
                elif delimiter < len(text) and text[delimiter] == '"':
                    state = "raw-string"
                    raw_hashes = hashes
                    index = delimiter + 1
                else:
                    code[index] = True
                    index += 1
            else:
                code[index] = True
                index += 1
        elif state == "line-comment":
            if text[index] == "\n":
                visible[index] = "\n"
                code[index] = True
                state = "code"
            else:
                visible[index] = " "
            index += 1
        elif state == "block-comment":
            if text.startswith("/*", index):
                visible[index : index + 2] = "  "
                block_depth += 1
                index += 2
            elif text.startswith("*/", index):
                visible[index : index + 2] = "  "
                block_depth -= 1
                index += 2
                if block_depth == 0:
                    state = "code"
            else:
                if text[index] != "\n":
                    visible[index] = " "
                index += 1
        elif state == "string":
            if text[index] == "\\":
                index += min(2, len(text) - index)
            elif text[index] == '"':
                state = "code"
                index += 1
            else:
                index += 1
        elif state == "multiline-string":
            if text.startswith('\"\"\"', index):
                state = "code"
                index += 3
            else:
                index += 1
        elif state == "raw-string":
            closing = '"' + ("#" * raw_hashes)
            if text.startswith(closing, index):
                state = "code"
                index += len(closing)
            else:
                index += 1
        else:
            closing = '\"\"\"' + ("#" * raw_hashes)
            if text.startswith(closing, index):
                state = "code"
                index += len(closing)
            else:
                index += 1
    if state in {
        "block-comment",
        "string",
        "multiline-string",
        "raw-string",
        "raw-multiline-string",
    }:
        raise BindingError(row, f"unterminated Swift lexical region: {state}")
    return "".join(visible), code


def target_block(text: str, name: str) -> str:
    row = "REPOSITORY-GRAPH"
    visible, code = swift_lexical_view(text, row)
    declarations = [
        match
        for match in re.finditer(
            rf"\.target\s*\(\s*name:\s*\"{re.escape(name)}\"\s*,", visible
        )
        if code[match.start()]
    ]
    if len(declarations) != 1:
        raise BindingError(
            row, f"expected exactly one target declaration for {name}, got {len(declarations)}"
        )
    declaration = declarations[0]
    opening = declaration.start()
    depth = 0
    for index in range(visible.find("(", opening), len(visible)):
        if not code[index]:
            continue
        if visible[index] == "(":
            depth += 1
        elif visible[index] == ")":
            depth -= 1
            if depth == 0:
                return visible[opening : index + 1]
    raise BindingError(row, f"unterminated target block {name}")


def array_field(block: str, field: str, row: str) -> str:
    visible, code = swift_lexical_view(block, row)
    matches = [
        match
        for match in re.finditer(rf"\b{re.escape(field)}\s*:\s*\[", visible)
        if code[match.start()]
    ]
    if len(matches) != 1:
        raise BindingError(row, f"expected exactly one {field} array, got {len(matches)}")
    opening = visible.find("[", matches[0].start())
    depth = 0
    for index in range(opening, len(visible)):
        if not code[index]:
            continue
        character = visible[index]
        if character == "[":
            depth += 1
        elif character == "]":
            depth -= 1
            if depth == 0:
                return visible[opening + 1 : index]
    raise BindingError(row, f"unterminated {field} array")


def split_swift_array(value: str, row: str) -> list[str]:
    entries: list[str] = []
    start = 0
    depths = {"(": 0, "[": 0, "{": 0}
    closing = {")": "(", "]": "[", "}": "{"}
    in_string = False
    escaped = False
    for index, character in enumerate(value):
        if in_string:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                in_string = False
            continue
        if character == '"':
            in_string = True
        elif character in depths:
            depths[character] += 1
        elif character in closing:
            opening = closing[character]
            depths[opening] -= 1
            if depths[opening] < 0:
                raise BindingError(row, "malformed Swift array entry")
        elif character == "," and not any(depths.values()):
            entry = value[start:index].strip()
            if entry:
                entries.append(entry)
            start = index + 1
    if in_string or any(depths.values()):
        raise BindingError(row, "malformed Swift array entry")
    final = value[start:].strip()
    if final:
        entries.append(final)
    return entries


def package_dependencies(block: str, row: str) -> list[str]:
    dependencies: list[str] = []
    for entry in split_swift_array(array_field(block, "dependencies", row), row):
        match = re.fullmatch(r'"([^"\\]+)"', entry)
        if match is None:
            raise BindingError(row, f"unknown package dependency expression: {entry}")
        dependencies.append(match.group(1))
    return dependencies


def project_package_dependencies(block: str, row: str) -> list[str]:
    dependencies: list[str] = []
    pattern = re.compile(r'\.package\s*\(\s*product:\s*"([^"\\]+)"\s*\)')
    for entry in split_swift_array(array_field(block, "dependencies", row), row):
        match = pattern.fullmatch(entry)
        if match is None:
            raise BindingError(row, f"unknown provider dependency expression: {entry}")
        dependencies.append(match.group(1))
    return dependencies


def project_folder_resources(project: str, block: str, row: str) -> list[str]:
    resources: list[str] = []
    pattern = re.compile(r"\.folderReference\s*\(\s*path:\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)")
    for entry in split_swift_array(array_field(block, "resources", row), row):
        match = pattern.fullmatch(entry)
        if match is None:
            raise BindingError(row, f"unknown provider resource expression: {entry}")
        variable = match.group(1)
        visible, code = swift_lexical_view(project, row)
        declarations = [
            match.group(1)
            for match in re.finditer(
                rf'\b(?:let|var)\s+{re.escape(variable)}\s*:\s*Path\s*=\s*"([^"\\]+)"',
                visible,
            )
            if code[match.start()]
        ]
        if len(declarations) != 1:
            raise BindingError(
                row, f"expected one literal Path declaration for {variable}, got {len(declarations)}"
            )
        resources.append(declarations[0])
    return resources


def require_exact_entries(actual: list[str], expected: list[str], row: str, label: str) -> None:
    duplicates = sorted({entry for entry in actual if actual.count(entry) > 1})
    if duplicates:
        raise BindingError(row, f"duplicate {label}: {duplicates}")
    actual_set = set(actual)
    expected_set = set(expected)
    if actual_set != expected_set or len(actual) != len(expected):
        raise BindingError(
            row,
            f"{label} closure drift: missing={sorted(expected_set - actual_set)}; "
            f"extra={sorted(actual_set - expected_set)}",
        )


def verify_ssh_repository_pins(
    repository_root: Path,
    native_manifest: dict[str, Any],
    ssh_pins: dict[str, Any],
) -> None:
    """Bind accepted selected-engine pins to the checked-in source/artifact graph."""

    row = "REPOSITORY-SSH-PIN"
    try:
        ssh = require_object(native_manifest["dependencies"]["libssh2-openssl"], row)
        source = require_object(ssh["source"], row)
        libssh2 = require_object(source["libssh2"], row)
        openssl = require_object(source["openssl"], row)
        if libssh2["revision"] != ssh_pins["libssh2Commit"]:
            raise BindingError(row, "libssh2 revision drift")
        if libssh2["archive_sha256"] != ssh_pins["libssh2ArchiveSha256"]:
            raise BindingError(row, "libssh2 archive digest drift")
        if openssl["revision"] != ssh_pins["opensslTag"]:
            raise BindingError(row, "OpenSSL tag drift")
        if openssl["archive_sha256"] != ssh_pins["opensslArchiveSha256"]:
            raise BindingError(row, "OpenSSL archive digest drift")

        license_components = ssh["license"]["components"]
        if not isinstance(license_components, list):
            raise BindingError(row, "selected license records are missing or malformed")
        actual_license_pins: dict[tuple[str, str], str] = {}
        for component in license_components:
            component = require_object(component, row)
            identity = (component.get("name"), component.get("path"))
            digest = component.get("sha256")
            if (
                not all(isinstance(value, str) and value for value in identity)
                or not isinstance(digest, str)
                or not digest
                or identity in actual_license_pins
            ):
                raise BindingError(row, "selected license record is ambiguous or malformed")
            actual_license_pins[identity] = digest
        expected_license_pins = {
            ("libssh2", "COPYING"): ssh_pins["libssh2CopyingSha256"],
            ("OpenSSL", "LICENSE.txt"): ssh_pins["opensslLicenseSha256"],
            ("OpenSSL acknowledgements", "ACKNOWLEDGEMENTS.md"): ssh_pins[
                "opensslAcknowledgementsSha256"
            ],
        }
        if actual_license_pins != expected_license_pins:
            raise BindingError(row, "selected license integrity graph drift")

        patch_manifest_relative = source["patch_manifest"]
        if patch_manifest_relative != "Dependencies/ReluxLibSSH2/PATCH_MANIFEST.json":
            raise BindingError(row, "unknown or ambiguous patch manifest path")
        patch_manifest_path = repository_root / patch_manifest_relative
        patch_manifest = load_repository_json(patch_manifest_path, row)
        if patch_manifest.get("schema_version") != 1:
            raise BindingError(row, "unknown patch manifest schema")
        upstream = require_object(patch_manifest["upstream"], row)
        if upstream.get("revision") != ssh_pins["libssh2Commit"]:
            raise BindingError(row, "patch manifest libssh2 revision drift")
        if upstream.get("archive_sha256") != ssh_pins["libssh2ArchiveSha256"]:
            raise BindingError(row, "patch manifest libssh2 archive digest drift")
        patches = patch_manifest["patches"]
        if not isinstance(patches, list) or len(patches) != 1:
            raise BindingError(row, "expected exactly one selected patch pin")
        patch = require_object(patches[0], row)
        if patch.get("sha256") != ssh_pins["patchSha256"]:
            raise BindingError(row, "selected patch digest drift")
        patch_path = patch.get("path")
        if not isinstance(patch_path, str) or not patch_path:
            raise BindingError(row, "selected patch path is missing or malformed")
        selected_patch = patch_manifest_path.parent / patch_path
        if not selected_patch.is_file() or sha256(selected_patch) != ssh_pins["patchSha256"]:
            raise BindingError(row, "selected patch bytes drift")

        compiler = require_object(ssh["compiler"], row)
        slices = compiler["slices"]
        if not isinstance(slices, list) or not slices:
            raise BindingError(row, "required artifact slices are missing or malformed")
        slice_ids: list[str] = []
        for item in slices:
            slice_id = require_object(item, row).get("library_identifier")
            if not isinstance(slice_id, str) or not slice_id:
                raise BindingError(row, "artifact slice identifier is missing or malformed")
            slice_ids.append(slice_id)
        if len(slice_ids) != len(set(slice_ids)):
            raise BindingError(row, "duplicate artifact slice identifier")

        file_pins = require_object(ssh["artifact"]["file_sha256"], row)
        expected_header_digest = ssh_pins["publicHeaderSha256"]
        artifact_path = ssh["integration"]["artifact_path"]
        if artifact_path != "NativeDependencies/Artifacts/ReluxLibSSH2.xcframework":
            raise BindingError(row, "unknown or ambiguous selected artifact path")
        for slice_id in slice_ids:
            relative_header = f"{slice_id}/Headers/libssh2.h"
            if file_pins.get(relative_header) != expected_header_digest:
                raise BindingError(row, f"public-header pin drift for {slice_id}")
            header_path = repository_root / artifact_path / relative_header
            if not header_path.is_file() or sha256(header_path) != expected_header_digest:
                raise BindingError(row, f"public-header bytes drift for {slice_id}")

        retained_manifest = load_repository_json(
            repository_root / "Dependencies/ReluxNIOSSH/PATCH_MANIFEST.json", row
        )
        if retained_manifest.get("schemaVersion") != 1:
            raise BindingError(row, "unknown retained ReluxNIOSSH manifest schema")
        retained_upstream = require_object(retained_manifest["upstream"], row)
        if retained_upstream.get("commit") != ssh_pins["retainedReluxNIOSSHCommit"]:
            raise BindingError(row, "retained ReluxNIOSSH commit drift")
        if (
            retained_upstream.get("archiveSHA256")
            != ssh_pins["retainedReluxNIOSSHArchiveSha256"]
        ):
            raise BindingError(row, "retained ReluxNIOSSH archive digest drift")
        if (
            retained_upstream.get("licenseSHA256")
            != ssh_pins["retainedReluxNIOSSHLicenseSha256"]
        ):
            raise BindingError(row, "retained ReluxNIOSSH license digest drift")
        if (
            ssh_pins.get("retainedReluxNIOSSHTreeDigestSchema")
            != "relux.sorted-path-file-sha256/1"
        ):
            raise BindingError(row, "unknown retained ReluxNIOSSH tree digest schema")
        retained_count, retained_digest = retained_tree_identity(
            repository_root / "Dependencies/ReluxNIOSSH", row
        )
        if retained_count != ssh_pins.get("retainedReluxNIOSSHTreeFileCount"):
            raise BindingError(
                row,
                "retained ReluxNIOSSH tree file set drift: "
                f"expected {ssh_pins.get('retainedReluxNIOSSHTreeFileCount')}, "
                f"got {retained_count}",
            )
        if retained_digest != ssh_pins.get("retainedReluxNIOSSHTreeSha256"):
            raise BindingError(row, "retained ReluxNIOSSH tree bytes drift")
    except BindingError:
        raise
    except (KeyError, TypeError) as error:
        raise BindingError(row, f"missing or malformed selected SSH pin record: {error}") from error


def verify_hev_repository_pins(
    repository_root: Path,
    native_manifest: dict[str, Any],
    packet_pins: dict[str, Any],
) -> None:
    """Bind the accepted HEV graph, complete artifact lock, and actual bytes."""

    row = "REPOSITORY-HEV-PIN"
    try:
        if packet_pins["artifactLock"] != "NativeDependencies/manifest.json":
            raise BindingError(row, "unknown or ambiguous HEV artifact lock path")
        hev = require_object(native_manifest["dependencies"]["hev-lwip"], row)
        if hev.get("revision") != packet_pins["hevSocks5Tunnel"]:
            raise BindingError(row, "HEV top-level revision drift")
        expected_submodules = {
            "src/core": packet_pins["hevSocks5Core"],
            "third-part/hev-task-system": packet_pins["hevTaskSystem"],
            "third-part/lwip": packet_pins["lwip"],
            "third-part/yaml": packet_pins["yaml"],
        }
        submodules = hev["source"]["submodules"]
        if not isinstance(submodules, list):
            raise BindingError(row, "HEV recursive graph is missing or malformed")
        actual_submodules: dict[str, str] = {}
        for raw_submodule in submodules:
            submodule = require_object(raw_submodule, row)
            path = submodule.get("path")
            revision = submodule.get("revision")
            if (
                not isinstance(path, str)
                or not path
                or not isinstance(revision, str)
                or not revision
                or path in actual_submodules
            ):
                raise BindingError(row, "HEV recursive graph is ambiguous or malformed")
            actual_submodules[path] = revision
        if actual_submodules != expected_submodules:
            raise BindingError(row, "HEV recursive graph drift")

        artifact_path = hev["integration"]["artifact_path"]
        if artifact_path != "NativeDependencies/Artifacts/HevSocks5Tunnel.xcframework":
            raise BindingError(row, "unknown or ambiguous HEV artifact path")
        expected_file_pins = require_object(packet_pins["artifactFileSha256"], row)
        locked_file_pins = require_object(hev["artifact"]["file_sha256"], row)
        if locked_file_pins != expected_file_pins:
            raise BindingError(row, "HEV artifact lock drift")
        if not expected_file_pins:
            raise BindingError(row, "HEV artifact file set is empty")

        artifact_root = repository_root / artifact_path
        if not artifact_root.is_dir():
            raise BindingError(row, "HEV artifact root is missing or unreadable")
        if any(path.is_symlink() for path in artifact_root.rglob("*")):
            raise BindingError(row, "HEV artifact contains an ambiguous symlink")
        actual_files = {
            path.relative_to(artifact_root).as_posix()
            for path in artifact_root.rglob("*")
            if path.is_file()
        }
        expected_files = set(expected_file_pins)
        if actual_files != expected_files:
            raise BindingError(
                row,
                f"HEV artifact file set drift: missing={sorted(expected_files - actual_files)}; "
                f"extra={sorted(actual_files - expected_files)}",
            )
        for relative, expected_digest in expected_file_pins.items():
            relative_path = Path(relative)
            if (
                not isinstance(relative, str)
                or not relative
                or relative_path.is_absolute()
                or ".." in relative_path.parts
                or relative_path.as_posix() != relative
                or not isinstance(expected_digest, str)
                or re.fullmatch(r"[0-9a-f]{64}", expected_digest) is None
            ):
                raise BindingError(row, "HEV artifact lock entry is malformed")
            if sha256(artifact_root / relative_path) != expected_digest:
                raise BindingError(row, f"HEV artifact bytes drift for {relative}")
    except BindingError:
        raise
    except (KeyError, OSError, TypeError) as error:
        raise BindingError(row, f"missing or malformed HEV pin record: {error}") from error


def verify_repository(repository_root: Path, inputs: dict[str, dict[str, Any]]) -> None:
    project = (repository_root / "Project.swift").read_text(encoding="utf-8")
    package = (repository_root / "Package.swift").read_text(encoding="utf-8")
    native_manifest = load_repository_json(
        repository_root / "NativeDependencies/manifest.json", "REPOSITORY-NATIVE-MANIFEST"
    )

    graph = inputs["generatedProjectArchitecture"]["bindings"]
    provider = target_block(project, graph["providerTarget"])
    require_exact_entries(
        project_package_dependencies(provider, "REPOSITORY-GRAPH"),
        graph["providerDirectDependencies"],
        "REPOSITORY-GRAPH",
        "provider direct dependency",
    )
    require_exact_entries(
        project_folder_resources(project, provider, "REPOSITORY-GRAPH"),
        graph["providerResources"],
        "REPOSITORY-GRAPH",
        "provider resource",
    )
    require_exact_entries(
        package_dependencies(
            target_block(package, "ReluxTunnelMacOSAdapter"), "REPOSITORY-GRAPH"
        ),
        graph["macOSAdapterDirectDependencies"],
        "REPOSITORY-GRAPH",
        "macOS adapter direct dependency",
    )
    require_exact_entries(
        package_dependencies(
            target_block(package, "ReluxTunnelNativeAdapter"), "REPOSITORY-GRAPH"
        ),
        graph["nativeAdapterDirectDependencies"],
        "REPOSITORY-GRAPH",
        "native adapter direct dependency",
    )

    ssh_pins = inputs["sshEngine"]["sourceOrBinaryPins"]
    selected_ssh_adapter = ssh_pins["selectedAdapter"]
    require_exact_entries(
        package_dependencies(
            target_block(package, selected_ssh_adapter), "REPOSITORY-GRAPH"
        ),
        ["ReluxTunnelCore", ssh_pins["binaryTarget"]],
        "REPOSITORY-GRAPH",
        "selected SSH adapter direct dependency",
    )

    packet_pins = inputs["packetBridgeAndHEV"]["sourceOrBinaryPins"]
    verify_hev_repository_pins(repository_root, native_manifest, packet_pins)
    verify_ssh_repository_pins(repository_root, native_manifest, ssh_pins)


def verify_board_state(board_state_path: Path, manifest: dict[str, Any]) -> None:
    board_state = decode_json_document(
        board_state_path.read_text(encoding="utf-8"),
        board_state_path,
        "BOARD-STATE",
    )
    if not isinstance(board_state, list) or len(board_state) != 4:
        raise BindingError("BOARD-STATE", "exactly four authority rows are required")
    rows: dict[str, dict[str, Any]] = {}
    for raw_row in board_state:
        row = require_object(raw_row, "BOARD-STATE")
        require_exact_keys(row, {"id", "status", "outcomeResources"}, "BOARD-STATE-FIELDS")
        task_id = row["id"]
        if task_id in rows:
            raise BindingError("BOARD-STATE", f"duplicate task {task_id}")
        rows[task_id] = row

    required: dict[str, set[str]] = {}
    runtime = manifest["runtimeContract"]
    required[runtime["taskId"]] = {
        runtime["resourceName"], runtime["reviewerVerdict"]["resourceName"]
    }
    for item in manifest["acceptedInputs"]:
        required[item["taskId"]] = {
            item["acceptedOutcome"]["resourceName"],
            item["reviewerVerdict"]["resourceName"],
        }
    if set(rows) != set(required):
        raise BindingError("BOARD-STATE", "authority task set drift")
    for task_id, names in required.items():
        row = rows[task_id]
        if row["status"] != "done":
            raise BindingError("BOARD-STATE", f"{task_id} is not reviewer-terminal done")
        resources = row["outcomeResources"]
        if not isinstance(resources, list):
            raise BindingError("BOARD-STATE", f"{task_id} outcome resource declaration unreadable")
        declared = {
            item.get("name") for item in resources if isinstance(item, dict)
        }
        missing = sorted(names - declared)
        if missing:
            raise BindingError(
                "BOARD-STATE", f"{task_id} accepted resources are no longer declared: {missing}"
            )


def validate(
    manifest_path: Path,
    resources_root: Path,
    repository_root: Path,
    board_state_path: Path,
) -> dict[str, Any]:
    failures: list[dict[str, str]] = []
    manifest_digest = "unknown"
    try:
        manifest_digest = sha256(manifest_path)
        manifest = require_object(
            decode_json_document(
                manifest_path.read_text(encoding="utf-8"),
                manifest_path,
                "MANIFEST-JSON",
            ),
            "MANIFEST-JSON",
        )
        require_exact_keys(manifest, ROOT_KEYS, "MANIFEST-FIELDS")
        if manifest["schemaVersion"] != 1 or manifest["schemaIdentifier"] != "relux.m0-production-bindings/1":
            raise BindingError("MANIFEST-SCHEMA", "unknown binding schema version")
        if manifest["taskId"] != "TASK-260720-1qhxqa":
            raise BindingError("MANIFEST-TASK", "wrong binding task authority")
        verify_board_state(board_state_path, manifest)

        runtime = require_object(manifest["runtimeContract"], "RUNTIME-CONTRACT")
        require_exact_keys(runtime, RUNTIME_KEYS, "RUNTIME-CONTRACT")
        if runtime["taskId"] != "TASK-260715-30zng6" or runtime["schema"] != "m1-runtime-contract/1":
            raise BindingError("RUNTIME-CONTRACT", "unknown or incompatible runtime contract")
        validate_supersession(runtime["supersession"], "RUNTIME-SUPERSESSION")
        runtime_verdict = validate_verdict(runtime["reviewerVerdict"], "RUNTIME-VERDICT")
        verify_resource(
            resources_root,
            runtime["taskId"],
            {"resourceName": runtime["resourceName"], "sha256": runtime["sha256"]},
            "RUNTIME-RESOURCE",
        )
        verify_resource(resources_root, runtime["taskId"], {
            "resourceName": runtime_verdict["resourceName"],
            "sha256": runtime_verdict["sha256"],
        }, "RUNTIME-VERDICT-RESOURCE")

        raw_inputs = manifest["acceptedInputs"]
        if not isinstance(raw_inputs, list) or len(raw_inputs) != 3:
            raise BindingError("INPUT-SET", "exactly three accepted inputs are required")
        inputs: dict[str, dict[str, Any]] = {}
        task_ids: set[str] = set()
        for index, raw_input in enumerate(raw_inputs):
            value = require_object(raw_input, f"INPUT-{index}")
            require_exact_keys(value, INPUT_KEYS, f"INPUT-{index}-FIELDS")
            kind = value["kind"]
            task_id = value["taskId"]
            if kind in inputs:
                raise BindingError("INPUT-SET", f"duplicate input kind {kind}")
            inputs[kind] = value
            task_ids.add(task_id)
            validate_supersession(value["supersession"], f"{task_id}-SUPERSESSION")
            verdict = validate_verdict(value["reviewerVerdict"], f"{task_id}-VERDICT")
            outcome = require_object(value["acceptedOutcome"], f"{task_id}-OUTCOME")
            verify_resource(resources_root, task_id, outcome, f"{task_id}-OUTCOME")
            verify_resource(resources_root, task_id, {
                "resourceName": verdict["resourceName"], "sha256": verdict["sha256"]
            }, f"{task_id}-VERDICT-RESOURCE")
            require_nonempty_strings(value["requiredCapabilities"], f"{task_id}-CAPABILITIES")
            require_nonempty_strings(
                value["licenseAndMaintenanceObligations"], f"{task_id}-OBLIGATIONS"
            )
            require_nonempty_strings(value["revalidationTriggers"], f"{task_id}-TRIGGERS")
            if not value["sourceOrBinaryPins"] or not value["bindings"]:
                raise BindingError(f"{task_id}-BINDINGS", "pins and normalized bindings are required")
        if task_ids != EXPECTED_TASKS or set(inputs) != EXPECTED_KINDS:
            raise BindingError(
                "INPUT-SET",
                f"required tasks={sorted(EXPECTED_TASKS)}, got={sorted(task_ids)}; required kinds={sorted(EXPECTED_KINDS)}, got={sorted(inputs)}",
            )

        checks = manifest["compatibilityChecks"]
        if not isinstance(checks, list):
            raise BindingError("COMPATIBILITY", "compatibility checks must be an array")
        check_ids: set[str] = set()
        for check in checks:
            value = require_object(check, "COMPATIBILITY")
            require_exact_keys(value, COMPATIBILITY_KEYS, "COMPATIBILITY-FIELDS")
            check_ids.add(value["id"])
            if value["result"] != "pass" or not value["condition"]:
                raise BindingError(value["id"], "compatibility condition did not pass")
        if check_ids != EXPECTED_COMPATIBILITY_ROWS or len(checks) != len(check_ids):
            raise BindingError("COMPATIBILITY-SET", "missing, unknown, or duplicate compatibility row")

        consumer = require_object(manifest["consumerContract"], "CONSUMER-CONTRACT")
        require_exact_keys(consumer, CONSUMER_KEYS, "CONSUMER-CONTRACT")
        if consumer["taskId"] != "TASK-260715-3ejhyy":
            raise BindingError("CONSUMER-CONTRACT", "wrong or ambiguous downstream consumer")
        if not all(isinstance(consumer[key], str) and consumer[key] for key in CONSUMER_KEYS):
            raise BindingError("CONSUMER-CONTRACT", "consumer fields must be non-empty strings")

        normalized_digest = canonical_sha256(canonical_contract_payload(manifest))
        if normalized_digest != EXPECTED_NORMALIZED_CONTRACT_SHA256:
            raise BindingError(
                "NORMALIZED-CONTRACT",
                "normalized binding contract differs from the reviewer-accepted immutable payload: "
                f"expected {EXPECTED_NORMALIZED_CONTRACT_SHA256}, got {normalized_digest}",
            )

        verify_repository(repository_root, inputs)
        computed_permit = True
        if manifest["productionCompositionPermitted"] is not computed_permit:
            raise BindingError("PERMIT-ATTESTATION", "stored permit does not equal recomputed permit")
    except (BindingError, OSError, json.JSONDecodeError, KeyError, TypeError) as error:
        if isinstance(error, BindingError):
            failures.append({"row": error.row, "detail": error.detail})
        else:
            failures.append({"row": "UNREADABLE-OR-MALFORMED", "detail": str(error)})

    return {
        "schemaVersion": 1,
        "manifestSha256": manifest_digest,
        "productionCompositionPermitted": not failures,
        "failures": failures,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path("Configuration/TASK-260720-1qhxqa_m0-production-bindings-v1.json"),
    )
    parser.add_argument("--resources-root", type=Path, required=True)
    parser.add_argument("--repository-root", type=Path, default=Path("."))
    parser.add_argument("--board-state", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    arguments = parser.parse_args(argv)
    report = validate(
        arguments.manifest.resolve(),
        arguments.resources_root.resolve(),
        arguments.repository_root.resolve(),
        arguments.board_state.resolve(),
    )
    encoded = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if arguments.report:
        arguments.report.parent.mkdir(parents=True, exist_ok=True)
        arguments.report.write_text(encoded, encoding="utf-8")
    sys.stdout.write(encoded)
    return 0 if report["productionCompositionPermitted"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
