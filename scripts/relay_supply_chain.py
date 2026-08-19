#!/usr/bin/env python3
"""Generate and audit relay supply-chain inventory, notices, and provenance."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
from typing import Any
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parent.parent
SOURCE_PATH = ROOT / "relay" / "supply-chain-source-v1.json"
ASSET_SOURCE_PATH = ROOT / "relay" / "asset-bundle-source-v1.json"
ASSET_SCHEMA_PATH = ROOT / "relay" / "asset-manifest-v1.schema.json"
SCHEMA_VERSION = 1
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40}$")
APPROVED_RELAY_VERSION = "0.1.0"
APPROVED_RUNTIME_POLICY = {
    "applicationCodeDownloadAllowed": False,
    "relayExecutionSource": "application-bundled-hash-verified-assets-only",
    "scanRoots": ["App", "Sources", "relay"],
    "scanExtensions": [
        ".c",
        ".cc",
        ".cpp",
        ".cxx",
        ".go",
        ".h",
        ".hh",
        ".hpp",
        ".hxx",
        ".m",
        ".mm",
        ".swift",
    ],
    "excludedFileSuffixes": ["_test.go"],
    "excludedPaths": [
        "App/ReluxProxyMac/Info.plist",
        "App/ReluxProxyMacTunnel/Info.plist",
        "Sources/ReluxTunnelCore/ReluxTunnelCore.docc/ReluxTunnelCore.md",
        "Sources/ReluxTunnelCore/ReluxTunnelCore.docc/RuntimeMessages.md",
        "Sources/ReluxTunnelIOSAdapter/ReluxTunnelIOSAdapter.docc/ReluxTunnelIOSAdapter.md",
        "Sources/ReluxTunnelMacOSAdapter/ReluxTunnelMacOSAdapter.docc/ReluxTunnelMacOSAdapter.md",
        "relay/PRODUCT_NOTICES.txt",
        "relay/README.md",
        "relay/asset-bundle-source-v1.json",
        "relay/asset-manifest-v1.schema.json",
        "relay/dependency-inventory-v1.json",
        "relay/go.mod",
        "relay/licenses/Go-BSD-3-Clause.txt",
        "relay/manifest-v1.schema.json",
        "relay/source-build-provenance-v1.json",
        "relay/supply-chain-source-v1.json",
        "relay/toolchain-manifest-v1.json",
    ],
}
APPROVED_BOUNDARY = [
    {
        "control": "source pinning",
        "milestone": "M2",
        "owner": "relay build",
        "scopeTaskID": "TASK-260715-27uz4n",
        "evidence": "source revision, tree and file SHA-256 inventory",
    },
    {
        "control": "build reproducibility",
        "milestone": "M2",
        "owner": "relay build",
        "scopeTaskID": "TASK-260715-27uz4n",
        "evidence": "pinned compiler, recipe, target matrix and deterministic command",
    },
    {
        "control": "asset integrity",
        "milestone": "M2",
        "owner": "relay asset packaging",
        "scopeTaskID": "TASK-260715-1ue4oy",
        "evidence": "archive and four executable SHA-256 values plus manifest linkage",
    },
    {
        "control": "license notices",
        "milestone": "M2",
        "owner": "relay supply-chain audit",
        "scopeTaskID": "TASK-260715-vtot05",
        "evidence": "generated product notice input with fail-closed coverage",
    },
    {
        "control": "application signing",
        "milestone": "M5",
        "owner": "Apple release pipeline",
        "scopeTaskID": "TASK-260715-3sk5cd",
        "evidence": "signed app/archive verification",
    },
    {
        "control": "notarization",
        "milestone": "M5",
        "owner": "Apple release pipeline",
        "scopeTaskID": "TASK-260715-387eof",
        "evidence": "notarization submission and staple verification",
    },
    {
        "control": "release attestation",
        "milestone": "M5",
        "owner": "release engineering",
        "scopeTaskID": "TASK-260715-1gzhnk",
        "evidence": "release-level attestation binding signed deliverables",
    },
    {
        "control": "distribution approval",
        "milestone": "M5",
        "owner": "release approver",
        "scopeTaskID": "TASK-260715-312u2k",
        "evidence": "explicit release-channel approval",
    },
]
COMPONENT_KEYS = {
    "id",
    "name",
    "version",
    "revision",
    "contentSHA256",
    "source",
    "license",
    "licenseTextPath",
    "licenseTextSHA256",
    "noticeObligation",
    "approved",
    "byteAffecting",
    "distribution",
}
C_FAMILY_EXTENSIONS = {
    ".c",
    ".cc",
    ".cpp",
    ".cxx",
    ".h",
    ".hh",
    ".hpp",
    ".hxx",
    ".m",
    ".mm",
}
OBJECTIVE_C_EXTENSIONS = {".m", ".mm"}
C_PROCESS_SYMBOLS = {
    "system",
    "popen",
    "posix_spawn",
    "posix_spawnp",
    "execl",
    "execle",
    "execlp",
    "execv",
    "execve",
    "execvp",
    "execvpe",
    "fexecve",
    "execveat",
}
FOUNDATION_NETWORK_SYMBOLS = {"URLSession", "NSURLSession", "NSURLConnection"}
OBJECTIVE_C_URL_SELECTORS = {"dataWithContentsOfURL", "initWithContentsOfURL"}
OBJECTIVE_C_REFLECTION_SYMBOLS = {
    "NSInvocation",
    "NSSelectorFromString",
    "performSelector",
    "methodForSelector",
    "instanceMethodForSelector",
    "sel_getUid",
    "sel_registerName",
    "objc_msgSend",
}
GO_FORBIDDEN_IMPORTS = {"net/http", "os/exec", "plugin"}
SHELL_OR_DOWNLOAD_PATTERN = re.compile(
    r"(?<![A-Za-z0-9_])(?:/(?:usr/)?bin/)?(?:sh|bash|zsh|curl|wget)\b"
)
HTTP_LOCATOR_PATTERN = re.compile(r"https?://")
SENSITIVE_PATTERNS = (
    re.compile(r"/Users/"),
    re.compile(r"/home/[^/]+"),
    re.compile(r"(?:token|password|secret|credential)\s*[:=]", re.IGNORECASE),
    re.compile(r"AKIA[0-9A-Z]{16}"),
    re.compile(r"-----BEGIN (?:OPENSSH |RSA |EC )?PRIVATE KEY-----"),
)


class SupplyChainError(RuntimeError):
    pass


def stable_json(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=True, indent=2) + "\n").encode("ascii")


def compact_json(value: Any) -> bytes:
    return json.dumps(
        value, ensure_ascii=True, separators=(",", ":"), sort_keys=True
    ).encode("ascii")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as error:
        raise SupplyChainError(f"required file is unavailable: {path.name}") from error
    return digest.hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SupplyChainError(f"invalid JSON: {path.name}") from error
    if not isinstance(value, dict):
        raise SupplyChainError(f"JSON root must be an object: {path.name}")
    return value


def git(*arguments: str) -> str:
    try:
        result = subprocess.run(
            ["git", *arguments], cwd=ROOT, check=True, capture_output=True, text=True
        )
    except (OSError, subprocess.CalledProcessError) as error:
        raise SupplyChainError(
            f"Git provenance lookup failed: {' '.join(arguments)}"
        ) from error
    return result.stdout.rstrip("\n")


def git_bytes(revision: str, path: str) -> bytes:
    try:
        result = subprocess.run(
            ["git", "show", f"{revision}:{path}"],
            cwd=ROOT,
            check=True,
            capture_output=True,
        )
    except (OSError, subprocess.CalledProcessError) as error:
        raise SupplyChainError(f"pinned Git input is unavailable: {path}") from error
    return result.stdout


def aggregate_file_records(records: list[dict[str, Any]], revision: str) -> str:
    lines = []
    for record in records:
        contents = git_bytes(revision, record["path"])
        digest = sha256_bytes(contents)
        if digest != record["sha256"]:
            raise SupplyChainError(f"pinned source hash mismatch: {record['path']}")
        lines.append(f"{digest}  {record['path']}\n")
    return sha256_bytes("".join(lines).encode("utf-8"))


def validate_file_records(records: Any, label: str) -> list[dict[str, Any]]:
    if not isinstance(records, list) or not records:
        raise SupplyChainError(f"{label} is empty")
    for record in records:
        if (
            not isinstance(record, dict)
            or set(record) != {"path", "sha256"}
            or not isinstance(record.get("path"), str)
            or not record["path"]
            or record["path"].startswith("/")
            or ".." in Path(record["path"]).parts
            or SHA256_PATTERN.fullmatch(record.get("sha256", "")) is None
        ):
            raise SupplyChainError(f"{label} contains an invalid file record")
    return records


def validate_exact_immutable_url(value: Any, label: str, expected: str) -> None:
    if not isinstance(value, str):
        raise SupplyChainError(f"{label} must be an immutable HTTPS URL")
    try:
        parsed = urlsplit(value)
        port = parsed.port
    except ValueError as error:
        raise SupplyChainError(
            f"{label} is outside its immutable pinned allowlist"
        ) from error
    if (
        parsed.scheme != "https"
        or not parsed.hostname
        or parsed.username is not None
        or parsed.password is not None
        or port is not None
        or parsed.query
        or parsed.fragment
        or value != expected
    ):
        raise SupplyChainError(f"{label} is outside its immutable pinned allowlist")


def validate_license(component: dict[str, Any]) -> None:
    for key in ("license", "licenseTextPath", "licenseTextSHA256", "noticeObligation"):
        if not isinstance(component.get(key), str) or not component[key]:
            raise SupplyChainError(
                f"dependency lacks approved license metadata: {component.get('id')}"
            )
    if SHA256_PATTERN.fullmatch(component["licenseTextSHA256"]) is None:
        raise SupplyChainError(f"dependency license hash is invalid: {component['id']}")
    license_path = ROOT / component["licenseTextPath"]
    if sha256_file(license_path) != component["licenseTextSHA256"]:
        raise SupplyChainError(f"dependency license text mismatch: {component['id']}")
    allowed_obligations = {"include-full-license", "none-build-only-tool"}
    if component["noticeObligation"] not in allowed_obligations:
        raise SupplyChainError(
            f"dependency notice obligation is unapproved: {component['id']}"
        )
    if (
        component["distribution"] != "build-only"
        and component["noticeObligation"] != "include-full-license"
    ):
        raise SupplyChainError(
            f"distributed dependency lacks notice coverage: {component['id']}"
        )


def validate_runtime_policy(policy: Any) -> None:
    if policy != APPROVED_RUNTIME_POLICY:
        raise SupplyChainError("runtime audit scope or code-download policy changed")


def one_record(records: Any, label: str, predicate) -> dict[str, Any]:
    if not isinstance(records, list):
        raise SupplyChainError(f"{label} inventory is invalid")
    matches = [
        record for record in records if isinstance(record, dict) and predicate(record)
    ]
    if len(matches) != 1:
        raise SupplyChainError(f"{label} is missing or duplicated")
    return matches[0]


def validate_component_mapping(
    components: list[dict[str, Any]], expected: dict[str, dict[str, Any]]
) -> None:
    expected_order = [
        "relay-build-recipe",
        "relux-relay-source",
        "go-compiler-linker",
        "go-standard-library",
    ]
    if [component.get("id") for component in components] != expected_order:
        raise SupplyChainError("relay byte-affecting dependency set or order changed")
    license_fields = {
        "license",
        "licenseTextPath",
        "licenseTextSHA256",
        "noticeObligation",
        "distribution",
    }
    for component in components:
        identifier = component["id"]
        authoritative = expected[identifier]
        for field, value in authoritative.items():
            if component.get(field) == value:
                continue
            if field in license_fields:
                raise SupplyChainError(
                    f"dependency approved license mapping mismatch: {identifier}.{field}"
                )
            raise SupplyChainError(
                f"dependency authoritative provenance mismatch: {identifier}.{field}"
            )


def validate_config(config: dict[str, Any]) -> None:
    expected_root = {
        "schemaVersion",
        "taskID",
        "source",
        "dependencyLock",
        "build",
        "components",
        "metadataTools",
        "artifactManifest",
        "runtimePolicy",
        "boundary",
        "outputs",
    }
    if (
        set(config) != expected_root
        or config.get("schemaVersion") != SCHEMA_VERSION
        or config.get("taskID") != "TASK-260715-vtot05"
    ):
        raise SupplyChainError("relay supply-chain source root contract changed")

    source = config["source"]
    if set(source) != {
        "name",
        "repository",
        "revisionType",
        "revision",
        "repositoryTree",
        "relayTree",
        "sourceDateEpoch",
        "aggregateSHA256",
        "license",
        "byteAffectingFiles",
    }:
        raise SupplyChainError("relay source provenance field set changed")
    revision = source.get("revision")
    if COMMIT_PATTERN.fullmatch(revision or "") is None:
        raise SupplyChainError("relay source revision is not a full Git commit")
    if (
        source.get("name") != "Relux Tunnel relay"
        or source.get("revisionType") != "gitCommit"
    ):
        raise SupplyChainError("relay source identity changed")
    expected_source_url = (
        "https://github.com/relux-works/relux-tunnel/tree/" f"{revision}/relay"
    )
    validate_exact_immutable_url(
        source.get("repository"), "relay source repository", expected_source_url
    )
    if git("rev-parse", revision) != revision:
        raise SupplyChainError("relay source revision is unavailable")
    if git("rev-parse", f"{revision}^{{tree}}") != source.get("repositoryTree"):
        raise SupplyChainError("relay repository tree mismatch")
    if git("rev-parse", f"{revision}:relay") != source.get("relayTree"):
        raise SupplyChainError("relay source tree mismatch")
    files = validate_file_records(
        source.get("byteAffectingFiles"), "relay byte-affecting source inventory"
    )
    paths = [record.get("path") for record in files if isinstance(record, dict)]
    if (
        len(paths) != len(files)
        or len(set(paths)) != len(paths)
        or paths != sorted(paths)
    ):
        raise SupplyChainError("relay byte-affecting source inventory is not canonical")
    expected_source_paths = {
        "relay/cmd/relux-relay/main.go",
        "relay/go.mod",
        "relay/internal/buildinfo/buildinfo.go",
        "relay/internal/buildinfo/identity.go",
        "relay/internal/protocol/codec.go",
        "relay/internal/protocol/generated_v1.go",
        "relay/internal/protocol/handshake.go",
        "relay/internal/protocol/session.go",
        "relay/internal/stdio/session.go",
    }
    if set(paths) != expected_source_paths:
        raise SupplyChainError("relay compiled source inventory is incomplete")
    if aggregate_file_records(files, revision) != source.get("aggregateSHA256"):
        raise SupplyChainError("relay source aggregate hash mismatch")
    if source.get("sourceDateEpoch") != int(
        git("show", "-s", "--format=%ct", revision)
    ):
        raise SupplyChainError(
            "relay source date epoch does not match the pinned commit"
        )
    source_license = source.get("license")
    pinned_source_license_sha256 = sha256_bytes(git_bytes(revision, "LICENSE"))
    if (
        source_license
        != {
            "spdx": "MIT",
            "path": "LICENSE",
            "sha256": pinned_source_license_sha256,
            "noticeObligation": "include-full-license",
        }
        or sha256_file(ROOT / "LICENSE") != pinned_source_license_sha256
    ):
        raise SupplyChainError("relay source license metadata mismatch")

    lock = config["dependencyLock"]
    source_lock_digest = next(
        record["sha256"] for record in files if record["path"] == "relay/go.mod"
    )
    if lock != {
        "path": "relay/go.mod",
        "sha256": source_lock_digest,
        "goSum": "absent",
        "policy": "standard-library-only",
    }:
        raise SupplyChainError("relay dependency lock contract changed")
    module_text = git_bytes(revision, lock["path"]).decode("utf-8")
    if re.search(r"(?m)^\s*(?:require|replace|exclude|retract)\b", module_text):
        raise SupplyChainError("relay dependency lock is not standard-library-only")
    if (ROOT / "relay" / "go.sum").exists():
        raise SupplyChainError("unexpected relay/go.sum dependency lock exists")
    if sha256_file(ROOT / lock["path"]) != lock["sha256"]:
        raise SupplyChainError("checked-in relay dependency lock drifted")

    build = config["build"]
    if set(build) != {
        "recipeRevision",
        "recipeSource",
        "recipeAggregateSHA256",
        "recipeFiles",
        "command",
        "targets",
        "environment",
    }:
        raise SupplyChainError("relay build provenance field set changed")
    recipe_revision = build.get("recipeRevision")
    if COMMIT_PATTERN.fullmatch(recipe_revision or "") is None:
        raise SupplyChainError("build recipe revision is not pinned")
    expected_recipe_url = (
        "https://github.com/relux-works/relux-tunnel/tree/" f"{recipe_revision}"
    )
    validate_exact_immutable_url(
        build.get("recipeSource"), "relay build recipe", expected_recipe_url
    )
    recipe_files = validate_file_records(
        build.get("recipeFiles"), "relay build recipe file inventory"
    )
    if [record.get("path") for record in recipe_files if isinstance(record, dict)] != [
        "Makefile",
        "relay/toolchain-manifest-v1.json",
        "scripts/relay_release.py",
    ]:
        raise SupplyChainError("build recipe file inventory changed")
    if aggregate_file_records(recipe_files, recipe_revision) != build.get(
        "recipeAggregateSHA256"
    ):
        raise SupplyChainError("build recipe hashes do not match the pinned revision")
    environment = build.get("environment")
    if environment != {
        "hostPlatform": "darwin/arm64",
        "baseImage": {"kind": "none", "identifier": "none", "digest": "none"},
        "network": "disabled-during-build",
        "cgoEnabled": False,
        "goToolchain": "local",
    }:
        raise SupplyChainError("build base-image boundary is not explicit")
    if build.get("targets") != [
        "darwin/amd64",
        "darwin/arm64",
        "linux/amd64",
        "linux/arm64",
    ]:
        raise SupplyChainError("relay target matrix changed")
    expected_command = (
        "make -j4 relay-toolchain-build-all "
        f"RELAY_VERSION={APPROVED_RELAY_VERSION} SOURCE_COMMIT={revision} "
        f"SOURCE_DATE_EPOCH={source['sourceDateEpoch']} "
        "RELAY_BUILD_CLEAN_FLAG=--require-clean"
    )
    if build.get("command") != expected_command:
        raise SupplyChainError("relay build command does not match pinned inputs")
    toolchain_path = ROOT / "relay" / "toolchain-manifest-v1.json"
    toolchain_record = one_record(
        recipe_files,
        "build recipe toolchain manifest",
        lambda item: item.get("path") == "relay/toolchain-manifest-v1.json",
    )
    toolchain_digest = toolchain_record["sha256"]
    if sha256_file(toolchain_path) != toolchain_digest:
        raise SupplyChainError("checked-in relay toolchain manifest drifted")
    toolchain = load_json(toolchain_path)
    if (
        toolchain.get("module", {}).get("lockFileSha256") != lock["sha256"]
        or toolchain.get("module", {}).get("dependencyPolicy") != lock["policy"]
        or toolchain.get("compiler", {}).get("version") != "go1.26.5"
        or toolchain.get("compiler", {}).get("linkMode") != "internal"
        or toolchain.get("compiler", {}).get("cgoEnabled") is not False
    ):
        raise SupplyChainError("relay compiler or dependency-lock metadata drifted")

    components = config["components"]
    if not isinstance(components, list) or not components:
        raise SupplyChainError("relay dependency inventory is empty")
    identifiers: set[str] = set()
    for component in components:
        if not isinstance(component, dict) or set(component) != COMPONENT_KEYS:
            raise SupplyChainError("dependency lacks approved metadata")
        identifier = component.get("id")
        if not isinstance(identifier, str) or identifier in identifiers:
            raise SupplyChainError("dependency identifier is missing or duplicated")
        identifiers.add(identifier)
        if (
            component.get("approved") is not True
            or component.get("byteAffecting") is not True
        ):
            raise SupplyChainError(
                f"byte-affecting dependency is unapproved: {identifier}"
            )
        if not isinstance(component.get("revision"), str) or not component["revision"]:
            raise SupplyChainError(f"dependency revision is missing: {identifier}")
        if SHA256_PATTERN.fullmatch(component.get("contentSHA256", "")) is None:
            raise SupplyChainError(f"dependency content hash is invalid: {identifier}")
        validate_license(component)
    expected_identifiers = {
        "relay-build-recipe",
        "relux-relay-source",
        "go-compiler-linker",
        "go-standard-library",
    }
    if identifiers != expected_identifiers:
        raise SupplyChainError("relay byte-affecting dependency set changed")
    go_archive = one_record(
        toolchain.get("hostToolArchives"),
        "build host Go archive",
        lambda item: item.get("host") == environment["hostPlatform"],
    )
    compiler_version = toolchain["compiler"]["version"]
    expected_go_source = f"https://go.dev/dl/{compiler_version}.darwin-arm64.tar.gz"
    validate_exact_immutable_url(
        go_archive.get("source"), "build host Go archive", expected_go_source
    )
    if go_archive.get("artifact") != f"{compiler_version}.darwin-arm64.tar.gz" or (
        SHA256_PATTERN.fullmatch(go_archive.get("sha256", "")) is None
    ):
        raise SupplyChainError("build host Go archive identity is invalid")
    go_standard_library = one_record(
        toolchain.get("dependencies"),
        "Go standard library dependency",
        lambda item: item.get("name") == "Go standard library",
    )
    if go_standard_library != {
        "name": "Go standard library",
        "revision": compiler_version,
        "sourceHashAuthority": "hostToolArchives[].sha256",
        "license": "BSD-3-Clause",
        "licenseFile": "GOROOT/LICENSE",
        "licenseSha256": "911f8f5782931320f5b8d1160a76365b83aea6447ee6c04fa6d5591467db9dad",
    }:
        raise SupplyChainError("Go standard library authority changed")
    go_license_path = "relay/licenses/Go-BSD-3-Clause.txt"
    if sha256_file(ROOT / go_license_path) != go_standard_library["licenseSha256"]:
        raise SupplyChainError("checked-in Go license text mismatch")
    pinned_recipe_license_sha256 = sha256_bytes(git_bytes(recipe_revision, "LICENSE"))
    expected_components = {
        "relay-build-recipe": {
            "id": "relay-build-recipe",
            "name": "Relux relay build recipe",
            "version": recipe_revision,
            "revision": recipe_revision,
            "contentSHA256": build["recipeAggregateSHA256"],
            "source": build["recipeSource"],
            "license": "MIT",
            "licenseTextPath": "LICENSE",
            "licenseTextSHA256": pinned_recipe_license_sha256,
            "noticeObligation": "none-build-only-tool",
            "approved": True,
            "byteAffecting": True,
            "distribution": "build-only",
        },
        "relux-relay-source": {
            "id": "relux-relay-source",
            "name": "Relux Tunnel relay source",
            "version": APPROVED_RELAY_VERSION,
            "revision": revision,
            "contentSHA256": source["aggregateSHA256"],
            "source": source["repository"],
            "license": source_license["spdx"],
            "licenseTextPath": source_license["path"],
            "licenseTextSHA256": source_license["sha256"],
            "noticeObligation": source_license["noticeObligation"],
            "approved": True,
            "byteAffecting": True,
            "distribution": "bundled-relay",
        },
        "go-compiler-linker": {
            "id": "go-compiler-linker",
            "name": "Go gc compiler and internal linker",
            "version": compiler_version,
            "revision": compiler_version,
            "contentSHA256": go_archive["sha256"],
            "source": go_archive["source"],
            "license": go_standard_library["license"],
            "licenseTextPath": go_license_path,
            "licenseTextSHA256": go_standard_library["licenseSha256"],
            "noticeObligation": "none-build-only-tool",
            "approved": True,
            "byteAffecting": True,
            "distribution": "build-only",
        },
        "go-standard-library": {
            "id": "go-standard-library",
            "name": "Go standard library",
            "version": compiler_version,
            "revision": compiler_version,
            "contentSHA256": go_archive["sha256"],
            "source": go_archive["source"],
            "license": go_standard_library["license"],
            "licenseTextPath": go_license_path,
            "licenseTextSHA256": go_standard_library["licenseSha256"],
            "noticeObligation": "include-full-license",
            "approved": True,
            "byteAffecting": True,
            "distribution": "statically-linked",
        },
    }
    components_by_id = {component["id"]: component for component in components}
    for identifier, expected in expected_components.items():
        validate_exact_immutable_url(
            components_by_id[identifier]["source"],
            f"dependency source {identifier}",
            expected["source"],
        )
    validate_component_mapping(components, expected_components)

    syft = one_record(
        toolchain.get("buildOnlyTools"),
        "Syft metadata tool",
        lambda item: item.get("name") == "syft",
    )
    syft_archive = one_record(
        syft.get("hostArchives"),
        "build host Syft archive",
        lambda item: item.get("host") == environment["hostPlatform"],
    )
    expected_metadata_tools = [
        {
            "id": "syft",
            "version": syft.get("version"),
            "revision": syft.get("revision"),
            "contentSHA256": syft_archive.get("sha256"),
            "license": syft.get("license"),
            "purpose": "build-time SPDX inspection; does not affect relay executable bytes",
        }
    ]
    if config["metadataTools"] != expected_metadata_tools:
        raise SupplyChainError("metadata-tool inventory is inconsistent")

    artifact = config["artifactManifest"]
    if artifact != {
        "sourceContract": "relay/asset-bundle-source-v1.json",
        "schema": "relay/asset-manifest-v1.schema.json",
        "manifestName": "relux-relay-assets-v1.json",
        "archiveTaskID": "TASK-260715-24icoz",
        "archiveResourceName": "TASK-260715-24icoz_portable-relay-assets.tar.gz",
        "archiveSHA256": "1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e",
    }:
        raise SupplyChainError("accepted asset manifest linkage contract changed")
    asset_source = load_json(ROOT / artifact["sourceContract"])
    if (
        asset_source.get("sourceCommit") != revision
        or asset_source.get("relayVersion") != APPROVED_RELAY_VERSION
    ):
        raise SupplyChainError("asset manifest source revision mismatch")
    if asset_source.get("buildProvenance", {}).get("archiveSHA256") != artifact.get(
        "archiveSHA256"
    ):
        raise SupplyChainError("asset archive provenance mismatch")
    if artifact.get("archiveTaskID") != asset_source.get("buildProvenance", {}).get(
        "taskID"
    ):
        raise SupplyChainError("asset archive task mismatch")
    if artifact.get("archiveResourceName") != asset_source.get(
        "buildProvenance", {}
    ).get("resourceName"):
        raise SupplyChainError("asset archive resource mismatch")
    if len(asset_source.get("assets", [])) != 4:
        raise SupplyChainError("asset manifest source does not contain four assets")

    validate_runtime_policy(config["runtimePolicy"])
    if config["boundary"] != APPROVED_BOUNDARY:
        raise SupplyChainError("M2/M5 supply-chain boundary is incomplete")
    if config["outputs"] != {
        "inventory": "relay/dependency-inventory-v1.json",
        "provenance": "relay/source-build-provenance-v1.json",
        "notices": "relay/PRODUCT_NOTICES.txt",
    }:
        raise SupplyChainError("generated output paths changed")


def manifest_linkage_subject(config: dict[str, Any]) -> dict[str, Any]:
    artifact = config["artifactManifest"]
    asset_source = load_json(ROOT / artifact["sourceContract"])
    return {
        "manifestName": artifact["manifestName"],
        "manifestSchemaSHA256": sha256_file(ROOT / artifact["schema"]),
        "sourceCommit": config["source"]["revision"],
        "sourceAggregateSHA256": config["source"]["aggregateSHA256"],
        "buildRecipeRevision": config["build"]["recipeRevision"],
        "buildRecipeAggregateSHA256": config["build"]["recipeAggregateSHA256"],
        "toolchainManifestSHA256": next(
            item["sha256"]
            for item in config["build"]["recipeFiles"]
            if item["path"] == "relay/toolchain-manifest-v1.json"
        ),
        "archiveSHA256": artifact["archiveSHA256"],
        "assets": [
            {
                key: entry[key]
                for key in ("os", "arch", "fileName", "byteSize", "sha256")
            }
            for entry in asset_source["assets"]
        ],
    }


def linkage_id(config: dict[str, Any]) -> str:
    return sha256_bytes(compact_json(manifest_linkage_subject(config)))


def render_inventory(config: dict[str, Any]) -> bytes:
    link = linkage_id(config)
    components = []
    for component in config["components"]:
        components.append(
            {
                "id": component["id"],
                "name": component["name"],
                "version": component["version"],
                "revision": component["revision"],
                "contentSHA256": component["contentSHA256"],
                "source": component["source"],
                "license": component["license"],
                "noticeObligation": component["noticeObligation"],
                "byteAffecting": component["byteAffecting"],
                "distribution": component["distribution"],
                "vulnerabilityReview": {
                    "identifier": component["id"],
                    "version": component["version"],
                },
            }
        )
    return stable_json(
        {
            "schemaVersion": 1,
            "kind": "relay-scoped-dependency-inventory",
            "manifestLinkageSHA256": link,
            "dependencyLock": config["dependencyLock"],
            "components": components,
            "metadataTools": config["metadataTools"],
            "runtimePolicy": config["runtimePolicy"],
        }
    )


def render_notices(config: dict[str, Any]) -> bytes:
    lines = [
        "Relux Relay product notice input\n",
        "Generated by scripts/relay_supply_chain.py from relay/supply-chain-source-v1.json.\n",
        "Do not edit this generated file.\n",
    ]
    groups: dict[tuple[str, str], list[dict[str, Any]]] = {}
    for component in config["components"]:
        if component["noticeObligation"] != "include-full-license":
            continue
        key = (component["license"], component["licenseTextSHA256"])
        groups.setdefault(key, []).append(component)
    for components in groups.values():
        component = components[0]
        text = (
            (ROOT / component["licenseTextPath"]).read_text(encoding="utf-8").rstrip()
        )
        covered = ", ".join(item["name"] for item in components)
        revisions = ", ".join(f"{item['id']}={item['revision']}" for item in components)
        lines.extend(
            [
                "\n",
                "=" * 72 + "\n",
                f"{covered} ({component['license']})\n",
                f"Revisions: {revisions}\n",
                f"License SHA-256: {component['licenseTextSHA256']}\n",
                "=" * 72 + "\n",
                text + "\n",
            ]
        )
    return "".join(lines).encode("utf-8")


def render_provenance(config: dict[str, Any]) -> bytes:
    subject = manifest_linkage_subject(config)
    return stable_json(
        {
            "_type": "https://in-toto.io/Statement/v1",
            "subject": [
                {"name": item["fileName"], "digest": {"sha256": item["sha256"]}}
                for item in subject["assets"]
            ],
            "predicateType": "https://slsa.dev/provenance/v1",
            "predicate": {
                "buildDefinition": {
                    "buildType": "https://relux.works/build-types/relay-portable-v1",
                    "externalParameters": {
                        "command": config["build"]["command"],
                        "targets": config["build"]["targets"],
                        "sourceDateEpoch": config["source"]["sourceDateEpoch"],
                    },
                    "resolvedDependencies": [
                        {
                            "name": item["id"],
                            "uri": item["source"],
                            "digest": {"sha256": item["contentSHA256"]},
                            "revision": item["revision"],
                        }
                        for item in config["components"]
                    ],
                },
                "runDetails": {
                    "builder": {"id": "repository-local-darwin-arm64-no-container"},
                    "metadata": {
                        "invocationId": config["artifactManifest"]["archiveTaskID"]
                    },
                    "byproducts": [
                        {
                            "name": "assetArchive",
                            "digest": {
                                "sha256": config["artifactManifest"]["archiveSHA256"]
                            },
                        },
                        {
                            "name": "assetManifestLinkage",
                            "digest": {"sha256": linkage_id(config)},
                        },
                    ],
                },
                "source": config["source"],
                "buildRecipe": config["build"],
                "artifactManifest": subject,
                "supplyChainBoundary": config["boundary"],
                "runtimePolicy": config["runtimePolicy"],
            },
        }
    )


def generated_outputs(config: dict[str, Any]) -> dict[str, bytes]:
    return {
        config["outputs"]["inventory"]: render_inventory(config),
        config["outputs"]["provenance"]: render_provenance(config),
        config["outputs"]["notices"]: render_notices(config),
    }


def supply_chain_reference(
    config: dict[str, Any], outputs: dict[str, bytes]
) -> dict[str, Any]:
    return {
        "kind": "repositoryGenerated",
        "taskID": config["taskID"],
        "manifestLinkageSHA256": linkage_id(config),
        "provenanceFile": config["outputs"]["provenance"],
        "provenanceSHA256": sha256_bytes(outputs[config["outputs"]["provenance"]]),
        "inventoryFile": config["outputs"]["inventory"],
        "inventorySHA256": sha256_bytes(outputs[config["outputs"]["inventory"]]),
        "noticesFile": config["outputs"]["notices"],
        "noticesSHA256": sha256_bytes(outputs[config["outputs"]["notices"]]),
    }


def expected_asset_source(
    config: dict[str, Any], outputs: dict[str, bytes]
) -> dict[str, Any]:
    contract = load_json(ASSET_SOURCE_PATH)
    contract["supplyChain"] = supply_chain_reference(config, outputs)
    return contract


def c_or_go_lexical_tokens(text: str, *, language: str) -> list[tuple[str, str]]:
    """Return comment-free C-family or Go tokens for the bounded audit."""
    if language == "c-family":
        text = re.sub(r"\\\r?\n", "", text)
    tokens: list[tuple[str, str]] = []
    index = 0
    while index < len(text):
        character = text[index]
        if character.isspace():
            index += 1
            continue
        if text.startswith("//", index):
            newline = text.find("\n", index + 2)
            index = len(text) if newline < 0 else newline + 1
            continue
        if text.startswith("/*", index):
            index += 2
            end = text.find("*/", index)
            index = len(text) if end < 0 else end + 2
            continue
        if character in {'"', "'"} or (language == "go" and character == "`"):
            quote = character
            raw = quote == "`"
            index += 1
            content: list[str] = []
            while index < len(text):
                character = text[index]
                if character == quote:
                    index += 1
                    break
                if character == "\\" and not raw and index + 1 < len(text):
                    content.extend((character, text[index + 1]))
                    index += 2
                    continue
                content.append(character)
                index += 1
            tokens.append(("string", "".join(content)))
            continue
        identifier = re.match(r"[A-Za-z_][A-Za-z0-9_]*", text[index:])
        if identifier is not None:
            value = identifier.group(0)
            tokens.append(("identifier", value))
            index += len(value)
            continue
        if language == "c-family" and (
            text.startswith("##", index) or text.startswith("%:%:", index)
        ):
            tokens.append(("symbol", "##"))
            index += 2 if text.startswith("##", index) else 4
            continue
        tokens.append(("symbol", character))
        index += 1
    return tokens


def swift_lexical_tokens(text: str) -> list[tuple[str, str]]:
    """Return Swift tokens, including code inside string interpolation."""

    def string_start(index: int) -> tuple[int, int] | None:
        cursor = index
        while cursor < len(text) and text[cursor] == "#":
            cursor += 1
        if cursor >= len(text) or text[cursor] != '"':
            return None
        quote_length = 3 if text.startswith('"""', cursor) else 1
        return cursor - index, quote_length

    def tokenize(
        index: int, *, stop_at_closing_paren: bool
    ) -> tuple[list[tuple[str, str]], int]:
        tokens: list[tuple[str, str]] = []
        paren_depth = 0
        while index < len(text):
            character = text[index]
            if character.isspace():
                index += 1
                continue
            if text.startswith("//", index):
                newline = text.find("\n", index + 2)
                index = len(text) if newline < 0 else newline + 1
                continue
            if text.startswith("/*", index):
                depth = 1
                index += 2
                while index < len(text) and depth:
                    if text.startswith("/*", index):
                        depth += 1
                        index += 2
                    elif text.startswith("*/", index):
                        depth -= 1
                        index += 2
                    else:
                        index += 1
                continue

            literal = string_start(index)
            if literal is not None:
                pound_count, quote_length = literal
                quote_index = index + pound_count
                index = quote_index + quote_length
                closing = '"' * quote_length + "#" * pound_count
                interpolation = "\\" + "#" * pound_count + "("
                content: list[str] = []
                interpolation_tokens: list[tuple[str, str]] = []
                while index < len(text):
                    if text.startswith(interpolation, index):
                        nested, index = tokenize(
                            index + len(interpolation), stop_at_closing_paren=True
                        )
                        interpolation_tokens.extend(nested)
                        continue
                    if text.startswith(closing, index):
                        index += len(closing)
                        break
                    if (
                        pound_count == 0
                        and text[index] == "\\"
                        and index + 1 < len(text)
                    ):
                        content.extend((text[index], text[index + 1]))
                        index += 2
                        continue
                    content.append(text[index])
                    index += 1
                tokens.append(("string", "".join(content)))
                tokens.extend(interpolation_tokens)
                continue

            if character == "`":
                end = text.find("`", index + 1)
                if end > index + 1:
                    value = text[index + 1 : end]
                    if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", value):
                        tokens.append(("identifier", value))
                        index = end + 1
                        continue
            identifier = re.match(r"[A-Za-z_][A-Za-z0-9_]*", text[index:])
            if identifier is not None:
                value = identifier.group(0)
                tokens.append(("identifier", value))
                index += len(value)
                continue
            if character == "(":
                paren_depth += 1
            elif character == ")":
                if stop_at_closing_paren and paren_depth == 0:
                    return tokens, index + 1
                paren_depth = max(0, paren_depth - 1)
            tokens.append(("symbol", character))
            index += 1
        return tokens, index

    return tokenize(0, stop_at_closing_paren=False)[0]


def token_is(tokens: list[tuple[str, str]], index: int, value: str) -> bool:
    return 0 <= index < len(tokens) and tokens[index][1] == value


def c_family_identifiers(tokens: list[tuple[str, str]]) -> set[str]:
    """Return complete and forbidden identifiers reconstructed by token paste."""
    identifiers = {value for kind, value in tokens if kind == "identifier"}
    if ("symbol", "##") not in tokens:
        return identifiers

    fragments = tuple(identifiers)

    def can_reconstruct(target: str) -> bool:
        reachable: dict[int, int] = {0: 0}
        for offset in range(len(target) + 1):
            if offset not in reachable:
                continue
            for fragment in fragments:
                if fragment and target.startswith(fragment, offset):
                    next_offset = offset + len(fragment)
                    reachable[next_offset] = max(
                        reachable.get(next_offset, 0), reachable[offset] + 1
                    )
        return reachable.get(len(target), 0) >= 2

    paste_targets = (
        C_PROCESS_SYMBOLS
        | FOUNDATION_NETWORK_SYMBOLS
        | OBJECTIVE_C_URL_SELECTORS
        | OBJECTIVE_C_REFLECTION_SYMBOLS
    )
    identifiers.update(target for target in paste_targets if can_reconstruct(target))

    # Libcurl's public surface is prefix-based rather than a finite symbol list.
    # Keep the reconstruction bounded to the fixed `curl_` prefix, then stop as
    # soon as two or more source fragments form a longer identifier.
    frontier = {("", 0)}
    visited = set(frontier)
    while frontier:
        prefix, part_count = frontier.pop()
        for fragment in fragments:
            candidate = prefix + fragment
            next_count = part_count + 1
            if candidate.startswith("curl_") and len(candidate) > len("curl_"):
                if next_count >= 2:
                    identifiers.add(candidate)
                continue
            if "curl_".startswith(candidate):
                state = (candidate, next_count)
                if state not in visited:
                    visited.add(state)
                    frontier.add(state)
    return identifiers


def c_family_surface(identifiers: set[str]) -> str | None:
    for identifier in identifiers:
        if identifier in C_PROCESS_SYMBOLS:
            return "C-family process execution"
        if identifier.startswith("curl_") and identifier != "curl_":
            return "C/C++ libcurl use"
    return None


def swift_loader_types(tokens: list[tuple[str, str]]) -> set[str]:
    loader_types = {"Data", "String", "NSData"}
    changed = True
    while changed:
        changed = False
        for index, token in enumerate(tokens):
            if token != ("identifier", "typealias") or index + 3 >= len(tokens):
                continue
            alias = tokens[index + 1]
            if alias[0] != "identifier" or not token_is(tokens, index + 2, "="):
                continue
            referenced_types = {
                value
                for kind, value in tokens[index + 3 : index + 7]
                if kind == "identifier"
            }
            if referenced_types & loader_types and alias[1] not in loader_types:
                loader_types.add(alias[1])
                changed = True
    return loader_types


def swift_contents_of_surface(tokens: list[tuple[str, str]]) -> str | None:
    loader_types = swift_loader_types(tokens)
    for index, (kind, value) in enumerate(tokens):
        if kind != "identifier" or value != "contentsOf":
            continue
        initializer_type: str | None = None
        if token_is(tokens, index - 1, "(") and index >= 2:
            candidate = tokens[index - 2]
            if candidate == ("identifier", "init") and token_is(tokens, index - 3, "."):
                receiver = tokens[index - 4] if index >= 4 else None
                if receiver is not None and receiver[0] == "identifier":
                    initializer_type = receiver[1]
                if initializer_type not in loader_types:
                    initializer_type = "ambiguous"
            elif candidate[0] == "identifier":
                initializer_type = candidate[1]
        if initializer_type not in loader_types | {"ambiguous"}:
            continue

        explicit_local_url = False
        if (
            token_is(tokens, index + 1, ":")
            and token_is(tokens, index + 2, "URL")
            and token_is(tokens, index + 3, "(")
            and token_is(tokens, index + 4, "fileURLWithPath")
            and token_is(tokens, index + 5, ":")
        ):
            depth = 1
            cursor = index + 6
            while cursor < len(tokens) and depth:
                if token_is(tokens, cursor, "("):
                    depth += 1
                elif token_is(tokens, cursor, ")"):
                    depth -= 1
                cursor += 1
            explicit_local_url = depth == 0 and (
                token_is(tokens, cursor, ")") or token_is(tokens, cursor, ",")
            )
        if explicit_local_url:
            continue
        if initializer_type == "Data":
            return "Foundation Data URL loader"
        if initializer_type == "String":
            return "Foundation String URL loader"
        if initializer_type == "NSData":
            return "Foundation NSData URL loader"
        return "Foundation Data/String URL loader"
    return None


def go_import_surface(tokens: list[tuple[str, str]]) -> str | None:
    def normalized_import_path(value: str) -> str:
        def replace_escape(match: re.Match[str]) -> str:
            escape = match.group(1)
            if escape.startswith("x"):
                return chr(int(escape[1:], 16))
            if escape.startswith("u") or escape.startswith("U"):
                return chr(int(escape[1:], 16))
            if escape[0] in "01234567":
                return chr(int(escape, 8))
            return {
                "a": "\a",
                "b": "\b",
                "f": "\f",
                "n": "\n",
                "r": "\r",
                "t": "\t",
                "v": "\v",
                "\\": "\\",
                '"': '"',
            }.get(escape, escape)

        return re.sub(
            r"\\(x[0-9A-Fa-f]{2}|u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8}|[0-7]{3}|.)",
            replace_escape,
            value,
        )

    for index, token in enumerate(tokens):
        if token != ("identifier", "import"):
            continue
        index += 1
        if not token_is(tokens, index, "("):
            for candidate in tokens[index : index + 2]:
                if (
                    candidate[0] == "string"
                    and normalized_import_path(candidate[1]) in GO_FORBIDDEN_IMPORTS
                ):
                    return "Go network or code-loading import"
            continue
        depth = 1
        index += 1
        while index < len(tokens) and depth:
            kind, value = tokens[index]
            if value == "(":
                depth += 1
            elif value == ")":
                depth -= 1
            elif (
                kind == "string"
                and normalized_import_path(value) in GO_FORBIDDEN_IMPORTS
            ):
                return "Go network or code-loading import"
            index += 1
    return None


def forbidden_runtime_surface(extension: str, text: str) -> str | None:
    if extension == ".swift":
        tokens = swift_lexical_tokens(text)
    elif extension == ".go":
        tokens = c_or_go_lexical_tokens(text, language="go")
    else:
        tokens = c_or_go_lexical_tokens(text, language="c-family")
    if extension in C_FAMILY_EXTENSIONS:
        identifiers = c_family_identifiers(tokens)
    else:
        identifiers = {value for kind, value in tokens if kind == "identifier"}
    strings = [value for kind, value in tokens if kind == "string"]

    if identifiers & FOUNDATION_NETWORK_SYMBOLS or any(
        any(symbol in value for symbol in FOUNDATION_NETWORK_SYMBOLS)
        for value in strings
    ):
        return "Foundation network loader"

    if extension == ".swift":
        swift_identifiers = {value for kind, value in tokens if kind == "identifier"}
        if swift_identifiers & {"Process", "NSTask"}:
            return "Swift process execution"
        surface = swift_contents_of_surface(tokens)
        if surface is not None:
            return surface

    if extension in OBJECTIVE_C_EXTENSIONS | {".swift"}:
        if identifiers & OBJECTIVE_C_URL_SELECTORS:
            return "Objective-C NSData URL loader"
        if identifiers & OBJECTIVE_C_REFLECTION_SYMBOLS:
            return "Objective-C dynamic URL loader"

    if extension in C_FAMILY_EXTENSIONS:
        surface = c_family_surface(identifiers)
        if surface is not None:
            return surface

    if extension == ".go":
        surface = go_import_surface(tokens)
        if surface is not None:
            return surface

    for value in strings:
        if SHELL_OR_DOWNLOAD_PATTERN.search(value) is not None:
            return "shell or download command"
        if HTTP_LOCATOR_PATTERN.search(value) is not None:
            return "HTTP source locator"
    return None


def scan_runtime(config: dict[str, Any], root: Path = ROOT) -> None:
    policy = config["runtimePolicy"]
    validate_runtime_policy(policy)
    extensions = set(policy["scanExtensions"])
    excluded_suffixes = tuple(policy["excludedFileSuffixes"])
    excluded_paths = set(policy["excludedPaths"])
    scanned_files = 0
    for relative_root in policy["scanRoots"]:
        scan_root = root / relative_root
        if not scan_root.is_dir() or scan_root.is_symlink():
            raise SupplyChainError(
                f"runtime audit root is unavailable: {relative_root}"
            )
        resolved_scan_root = scan_root.resolve(strict=True)
        for path in sorted(scan_root.rglob("*")):
            if path.is_symlink():
                raise SupplyChainError(
                    f"runtime audit scope contains a symlink: {path.relative_to(root)}"
                )
            if path.is_dir():
                continue
            relative_path = path.relative_to(root).as_posix()
            if not path.is_file():
                raise SupplyChainError(
                    f"runtime audit scope contains an unclassified entry: {relative_path}"
                )
            if relative_path in excluded_paths:
                continue
            if path.suffix == ".go" and path.name.endswith(excluded_suffixes):
                continue
            if path.suffix not in extensions:
                raise SupplyChainError(
                    f"runtime audit scope contains an unclassified file: {relative_path}"
                )
            resolved_path = path.resolve(strict=True)
            if not resolved_path.is_relative_to(resolved_scan_root):
                raise SupplyChainError(
                    f"runtime audit source escapes its root: {path.relative_to(root)}"
                )
            try:
                text = path.read_text(encoding="utf-8")
            except (OSError, UnicodeDecodeError) as error:
                raise SupplyChainError(
                    f"runtime audit source is unreadable: {path.relative_to(root)}"
                ) from error
            scanned_files += 1
            label = forbidden_runtime_surface(path.suffix, text)
            if label is not None:
                raise SupplyChainError(
                    "application runtime code-download surface found "
                    f"({label}): {path.relative_to(root)}"
                )
    if scanned_files == 0:
        raise SupplyChainError("runtime audit scanned no application source files")


def relay_asset_tool():
    try:
        from scripts import relay_asset_manifest
    except ModuleNotFoundError:
        import relay_asset_manifest
    return relay_asset_manifest


def expected_asset_manifest():
    tool = relay_asset_tool()
    try:
        tool.verify_schema()
        contract = tool.load_source_contract()
        contents = tool.read_archive_assets(tool.DEFAULT_ARCHIVE, contract)
        manifest = tool.build_manifest(contract, contents)
        tool.validate_manifest(manifest, contract)
    except tool.AssetManifestError as error:
        raise SupplyChainError(f"asset manifest audit failed: {error}") from error
    return tool, manifest


def reject_sensitive_generated(outputs: dict[str, bytes]) -> None:
    for name, contents in outputs.items():
        text = contents.decode("utf-8")
        for pattern in SENSITIVE_PATTERNS:
            if pattern.search(text):
                raise SupplyChainError(
                    f"sensitive or workstation-specific data found in {name}"
                )


def generate() -> None:
    config = load_json(SOURCE_PATH)
    validate_config(config)
    scan_runtime(config)
    outputs = generated_outputs(config)
    reject_sensitive_generated(outputs)
    for relative, contents in outputs.items():
        path = ROOT / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(contents)
    ASSET_SOURCE_PATH.write_bytes(stable_json(expected_asset_source(config, outputs)))
    tool, manifest = expected_asset_manifest()
    tool.DEFAULT_SWIFT.write_bytes(tool.render_swift(manifest))


def audit() -> None:
    config = load_json(SOURCE_PATH)
    validate_config(config)
    scan_runtime(config)
    outputs = generated_outputs(config)
    reject_sensitive_generated(outputs)
    for relative, expected in outputs.items():
        path = ROOT / relative
        try:
            actual = path.read_bytes()
        except OSError as error:
            raise SupplyChainError(
                f"generated supply-chain output is missing: {relative}"
            ) from error
        if actual != expected:
            raise SupplyChainError(f"generated supply-chain output drift: {relative}")
    asset_source = load_json(ASSET_SOURCE_PATH)
    expected_reference = supply_chain_reference(config, outputs)
    if asset_source.get("supplyChain") != expected_reference:
        raise SupplyChainError("asset manifest supply-chain linkage mismatch")
    if set(asset_source) != {
        "schemaVersion",
        "manifestSchemaVersion",
        "relayProtocolVersion",
        "relayVersion",
        "sourceCommit",
        "bundleSubdirectory",
        "buildProvenance",
        "supplyChain",
        "assets",
    }:
        raise SupplyChainError("asset manifest source field set changed")
    tool, manifest = expected_asset_manifest()
    try:
        tool.verify_swift(tool.DEFAULT_SWIFT, manifest)
    except tool.AssetManifestError as error:
        raise SupplyChainError(f"asset manifest audit failed: {error}") from error


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("generate", "audit"))
    arguments = parser.parse_args()
    try:
        generate() if arguments.command == "generate" else audit()
    except SupplyChainError as error:
        print(f"relay supply-chain audit failed: {error}", file=sys.stderr)
        return 1
    print(f"relay supply-chain {arguments.command}: pass")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
