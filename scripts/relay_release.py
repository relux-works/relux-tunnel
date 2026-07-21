#!/usr/bin/env python3
"""Build and verify deterministic relux-relay target-shell artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import shutil
import struct
import subprocess
import sys
import tarfile
from typing import Any


GO_VERSION = "go1.26.5"
SYFT_VERSION = "1.48.0"
SYFT_COMMIT = "3e2bc6ed095f7ec1a415fb38cfe1c319e95dfed6"
PROTOCOL_VERSION = 1
MANIFEST_SCHEMA_VERSION = 1
PROVENANCE_SCHEMA_VERSION = 1
GO_LICENSE_SHA256 = "911f8f5782931320f5b8d1160a76365b83aea6447ee6c04fa6d5591467db9dad"
VERSION_PATTERN = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$")
COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40}$")
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")

MANIFEST_NAME = "relux-relay-manifest-v1.json"
CHECKSUMS_NAME = "relux-relay-SHA256SUMS"
NOTICE_PATH = PurePosixPath("THIRD_PARTY_NOTICES/Go-BSD-3-Clause.txt")
PROVENANCE_NAME = "relux-tool-provenance-v1.json"

ROOT = Path(__file__).resolve().parent.parent
RELAY_ROOT = ROOT / "relay"
BUILD_ROOT = ROOT / ".build" / "relay"

GO_ARCHIVES: dict[str, dict[str, str]] = {
    "darwin/amd64": {
        "artifact": "go1.26.5.darwin-amd64.tar.gz",
        "sha256": "6231d8d3b8f5552ec6cbf6d685bdd5482e1e703214b120e89b3bf0d7bf1ef725",
    },
    "darwin/arm64": {
        "artifact": "go1.26.5.darwin-arm64.tar.gz",
        "sha256": "efb87ff28af9a188d0536ef5d42e63dd52ba8263cd7344a993cc48dd11dedb6a",
    },
    "linux/amd64": {
        "artifact": "go1.26.5.linux-amd64.tar.gz",
        "sha256": "5c2c3b16caefa1d968a94c1daca04a7ca301a496d9b086e17ad77bb81393f053",
    },
    "linux/arm64": {
        "artifact": "go1.26.5.linux-arm64.tar.gz",
        "sha256": "fe4789e92b1f33358680864bbe8704289e7bb5fc207d80623c308935bd696d49",
    },
}

SYFT_ARCHIVES: dict[str, dict[str, str]] = {
    "darwin/amd64": {
        "artifact": "syft_1.48.0_darwin_amd64.tar.gz",
        "sha256": "dc7b2135fa5591003596df4ddb3408f499b68174f5e7dc1c77a373b753463182",
    },
    "darwin/arm64": {
        "artifact": "syft_1.48.0_darwin_arm64.tar.gz",
        "sha256": "fef3e6d5df336a0a4c3e421e503119d1e221cf82a3ef5e426a791fcd81667e87",
    },
    "linux/amd64": {
        "artifact": "syft_1.48.0_linux_amd64.tar.gz",
        "sha256": "6cef9a7f37220d9067eaf9cfaaa2fce986e9f320a8d42cbc36658c99af78ea04",
    },
    "linux/arm64": {
        "artifact": "syft_1.48.0_linux_arm64.tar.gz",
        "sha256": "6865a3d97c4e28b4b38571c17a2bf512da4494ef1d37613c3122fce0d67e63b0",
    },
}


class ReleaseError(RuntimeError):
    pass


TARGETS: tuple[dict[str, str], ...] = (
    {
        "os": "darwin",
        "arch": "amd64",
        "canonicalTarget": "x86_64-apple-darwin",
        "architectureVariable": "GOAMD64",
        "architectureValue": "v1",
    },
    {
        "os": "darwin",
        "arch": "arm64",
        "canonicalTarget": "aarch64-apple-darwin",
        "architectureVariable": "GOARM64",
        "architectureValue": "v8.0",
    },
    {
        "os": "linux",
        "arch": "amd64",
        "canonicalTarget": "x86_64-unknown-linux",
        "architectureVariable": "GOAMD64",
        "architectureValue": "v1",
    },
    {
        "os": "linux",
        "arch": "arm64",
        "canonicalTarget": "aarch64-unknown-linux",
        "architectureVariable": "GOARM64",
        "architectureValue": "v8.0",
    },
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def stable_json(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def host_platform() -> str:
    os_name = platform.system().lower()
    machine = platform.machine().lower()
    architecture = {
        "x86_64": "amd64",
        "amd64": "amd64",
        "arm64": "arm64",
        "aarch64": "arm64",
    }.get(machine)
    if os_name not in {"darwin", "linux"} or architecture is None:
        raise ReleaseError("unsupported release-tool host platform")
    return f"{os_name}/{architecture}"


def archive_contract(tool: str, tool_platform: str) -> dict[str, str]:
    contracts = GO_ARCHIVES if tool == "go" else SYFT_ARCHIVES if tool == "syft" else None
    if contracts is None or tool_platform not in contracts:
        raise ReleaseError(f"unsupported {tool} release-tool platform")
    contract = dict(contracts[tool_platform])
    if tool == "go":
        contract.update(
            {
                "tool": "go",
                "version": GO_VERSION,
                "source": f"https://go.dev/dl/{contract['artifact']}",
            }
        )
    else:
        contract.update(
            {
                "tool": "syft",
                "version": SYFT_VERSION,
                "source": (
                    "https://github.com/anchore/syft/releases/download/"
                    f"v{SYFT_VERSION}/{contract['artifact']}"
                ),
            }
        )
    contract["platform"] = tool_platform
    return contract


def provenance_document(tool: str, tool_platform: str) -> dict[str, Any]:
    contract = archive_contract(tool, tool_platform)
    return {
        "schemaVersion": PROVENANCE_SCHEMA_VERSION,
        "tool": contract["tool"],
        "version": contract["version"],
        "platform": contract["platform"],
        "artifact": contract["artifact"],
        "sha256": contract["sha256"],
        "source": contract["source"],
    }


def resolve_executable(command: str) -> Path:
    path = Path(command)
    if len(path.parts) > 1 or path.is_absolute():
        candidate = path if path.is_absolute() else ROOT / path
        if not candidate.is_file():
            raise ReleaseError(f"release tool not found: {path.name}")
        return candidate.resolve()
    found = shutil.which(command)
    if found is None:
        raise ReleaseError(f"release tool not found: {command}")
    return Path(found).resolve()


def sha256_stream(stream: Any) -> str:
    digest = hashlib.sha256()
    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
        digest.update(chunk)
    return digest.hexdigest()


def verify_archive_member_matches(archive: Path, member_name: str, installed: Path) -> None:
    with tarfile.open(archive, "r:gz") as bundle:
        matches = [member for member in bundle.getmembers() if member.name == member_name]
        if len(matches) != 1 or not matches[0].isfile():
            raise ReleaseError(f"release archive member mismatch: {member_name}")
        stream = bundle.extractfile(matches[0])
        if stream is None:
            raise ReleaseError(f"release archive member unreadable: {member_name}")
        archived_sha256 = sha256_stream(stream)
    if not installed.is_file() or sha256(installed) != archived_sha256:
        raise ReleaseError(f"installed release tool differs from archive: {installed.name}")


def verify_archive_provenance(
    directory: Path,
    tool: str,
    tool_platform: str,
    installed_members: tuple[tuple[str, Path], ...],
) -> None:
    contract = archive_contract(tool, tool_platform)
    provenance_path = directory / PROVENANCE_NAME
    try:
        text = provenance_path.read_text(encoding="utf-8")
        provenance = json.loads(text)
    except (OSError, json.JSONDecodeError) as error:
        raise ReleaseError(f"missing or invalid {tool} release-tool provenance") from error
    expected = provenance_document(tool, tool_platform)
    if text.encode("utf-8") != stable_json(expected) or provenance != expected:
        raise ReleaseError(f"{tool} release-tool provenance mismatch")
    reject_host_paths(text, provenance_path.name)
    archive = directory / contract["artifact"]
    if not archive.is_file() or sha256(archive) != contract["sha256"]:
        raise ReleaseError(f"{tool} release archive checksum mismatch")
    for member_name, installed in installed_members:
        verify_archive_member_matches(archive, member_name, installed)


def target_filename(target: dict[str, str]) -> str:
    return f"relux-relay-{target['os']}-{target['arch']}"


def protocol_test_filename(target: dict[str, str]) -> str:
    return f"relux-relay-protocol-test-{target['os']}-{target['arch']}"


def validate_release_inputs(relay_version: str, source_commit: str) -> None:
    if not VERSION_PATTERN.fullmatch(relay_version):
        raise ReleaseError("relay version must be a deterministic semantic version")
    if not COMMIT_PATTERN.fullmatch(source_commit):
        raise ReleaseError("source commit must be 40 lowercase hexadecimal characters")


def validate_output_path(path: Path) -> Path:
    candidate = path if path.is_absolute() else ROOT / path
    resolved_parent = candidate.parent.resolve()
    resolved = resolved_parent / candidate.name
    try:
        resolved.relative_to(BUILD_ROOT)
    except ValueError as error:
        raise ReleaseError("output paths must remain under .build/relay") from error
    if resolved == BUILD_ROOT:
        raise ReleaseError("output path must be task-scoped below .build/relay")
    return resolved


def resolve_tool_command(command: str) -> str:
    path = Path(command)
    if len(path.parts) > 1 and not path.is_absolute():
        return str((ROOT / path).resolve())
    return command


def clean_directory(path: Path) -> None:
    validated = validate_output_path(path)
    if validated.exists():
        shutil.rmtree(validated)
    validated.mkdir(parents=True)


def sanitized_environment(go_toolchain: str, target: dict[str, str] | None = None) -> dict[str, str]:
    environment: dict[str, str] = {}
    for key in ("HOME", "PATH", "TMPDIR"):
        value = os.environ.get(key)
        if value:
            environment[key] = value
    environment.update(
        {
            "GOTOOLCHAIN": go_toolchain,
            "GOENV": "off",
            "GOCACHE": str(ROOT / ".temp" / "relay-go-cache"),
            "GOPATH": str(ROOT / ".temp" / "relay-go-path"),
            "CGO_ENABLED": "0",
            "LC_ALL": "C",
            "LANG": "C",
            "TZ": "UTC",
        }
    )
    if target is not None:
        environment["GOOS"] = target["os"]
        environment["GOARCH"] = target["arch"]
        environment[target["architectureVariable"]] = target["architectureValue"]
    return environment


def run_checked(
    command: list[str],
    *,
    cwd: Path,
    environment: dict[str, str],
    capture: bool = True,
) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            command,
            cwd=cwd,
            env=environment,
            check=True,
            text=True,
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.PIPE if capture else None,
        )
    except subprocess.CalledProcessError as error:
        raise ReleaseError(f"command failed: {Path(command[0]).name} {command[1]}") from error


def verify_go_toolchain(go_command: str, go_toolchain: str, require_provenance: bool = False) -> str:
    if require_provenance and go_toolchain != "local":
        raise ReleaseError("release mode requires GOTOOLCHAIN=local")
    executable = resolve_executable(go_command)
    environment = sanitized_environment(go_toolchain)
    version = run_checked([str(executable), "version"], cwd=RELAY_ROOT, environment=environment).stdout.strip()
    match = re.fullmatch(r"go version (go[0-9.]+) (darwin|linux)/(amd64|arm64)", version)
    if match is None or match.group(1) != GO_VERSION:
        raise ReleaseError(f"required Go toolchain is {GO_VERSION}")
    tool_platform = f"{match.group(2)}/{match.group(3)}"
    if tool_platform != host_platform():
        raise ReleaseError("Go release-tool platform mismatch")
    values = run_checked(
        [str(executable), "env", "GOROOT", "GOTOOLDIR", "GOHOSTOS", "GOHOSTARCH", "GOTOOLCHAIN"],
        cwd=RELAY_ROOT,
        environment=environment,
    ).stdout.splitlines()
    if len(values) != 5:
        raise ReleaseError("Go toolchain did not report complete environment identity")
    go_root, go_tool_dir, host_os, host_arch, reported_toolchain = values
    if (
        not go_root
        or host_os != match.group(2)
        or host_arch != match.group(3)
        or reported_toolchain != go_toolchain
    ):
        raise ReleaseError("Go toolchain environment identity mismatch")
    root_path = Path(go_root).resolve()
    if executable != (root_path / "bin" / "go").resolve():
        raise ReleaseError("Go executable must be the selected GOROOT binary")
    if require_provenance:
        tool_directory = Path(go_tool_dir).resolve()
        expected_tool_directory = root_path / "pkg" / "tool" / tool_platform.replace("/", "_")
        if tool_directory != expected_tool_directory.resolve():
            raise ReleaseError("Go tool directory does not match selected GOROOT")
        critical_members = (
            ("go/bin/go", root_path / "bin" / "go"),
            *(
                (f"go/pkg/tool/{tool_platform.replace('/', '_')}/{name}", tool_directory / name)
                for name in ("asm", "compile", "link")
            ),
        )
        verify_archive_provenance(root_path.parent, "go", tool_platform, critical_members)
    return str(root_path)


def verify_go_module_policy() -> None:
    module_text = (RELAY_ROOT / "go.mod").read_text(encoding="utf-8")
    if not re.search(r"(?m)^go 1\.26\.0$", module_text):
        raise ReleaseError("relay/go.mod must declare go 1.26.0")
    if not re.search(r"(?m)^toolchain go1\.26\.5$", module_text):
        raise ReleaseError("relay/go.mod must pin toolchain go1.26.5")
    if re.search(r"(?m)^\s*(require|replace|exclude)\b", module_text):
        raise ReleaseError("relay/go.mod must remain standard-library-only")


def verify_clean_checkout(source_commit: str) -> None:
    environment = sanitized_environment("local")
    status = run_checked(
        ["git", "status", "--porcelain", "--untracked-files=all"],
        cwd=ROOT,
        environment=environment,
    ).stdout
    if status:
        raise ReleaseError("release mode requires a clean checkout")
    revision = run_checked(
        ["git", "rev-parse", "HEAD"],
        cwd=ROOT,
        environment=environment,
    ).stdout.strip()
    if revision != source_commit:
        raise ReleaseError("source commit does not match checkout HEAD")


def build_binary(
    go_command: str,
    go_toolchain: str,
    target: dict[str, str],
    package: str,
    output: Path,
    relay_version: str,
    source_commit: str,
) -> None:
    environment = sanitized_environment(go_toolchain, target)
    output.parent.mkdir(parents=True, exist_ok=True)
    ldflags = " ".join(
        (
            "-s",
            "-w",
            "-buildid=",
            "-X",
            f"github.com/relux-works/relux-tunnel/relay/internal/buildinfo.Version={relay_version}",
            "-X",
            f"github.com/relux-works/relux-tunnel/relay/internal/buildinfo.Commit={source_commit}",
        )
    )
    run_checked(
        [
            go_command,
            "build",
            "-mod=readonly",
            "-trimpath",
            "-buildvcs=false",
            "-tags=netgo,osusergo",
            f"-ldflags={ldflags}",
            "-o",
            str(output),
            package,
        ],
        cwd=RELAY_ROOT,
        environment=environment,
    )


def parse_syft_version_output(output: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for line in output.splitlines():
        if not line.strip():
            continue
        match = re.fullmatch(r"([A-Za-z][A-Za-z0-9]*):\s+(.+?)\s*", line)
        if match is None or match.group(1) in fields:
            raise ReleaseError("Syft version output is not structured and unique")
        fields[match.group(1)] = match.group(2)
    required = {"Application", "Version", "GitCommit", "GitDescription", "Platform"}
    if not required.issubset(fields):
        raise ReleaseError("Syft version output is missing provenance fields")
    return fields


def verify_syft_toolchain(syft_command: str, require_provenance: bool = False) -> None:
    executable = resolve_executable(syft_command)
    environment = sanitized_environment("local")
    environment["SYFT_CHECK_FOR_APP_UPDATE"] = "false"
    output = run_checked([str(executable), "version"], cwd=ROOT, environment=environment).stdout
    fields = parse_syft_version_output(output)
    expected = {
        "Application": "syft",
        "Version": SYFT_VERSION,
        "GitCommit": SYFT_COMMIT,
        "GitDescription": f"v{SYFT_VERSION}",
        "Platform": host_platform(),
    }
    if any(fields.get(key) != value for key, value in expected.items()):
        raise ReleaseError("Syft release-tool identity mismatch")
    if require_provenance:
        verify_archive_provenance(
            executable.parent,
            "syft",
            fields["Platform"],
            (("syft", executable),),
        )


def generate_sbom(syft_command: str, binary: Path, sbom: Path) -> None:
    environment = sanitized_environment("local")
    environment["SYFT_CHECK_FOR_APP_UPDATE"] = "false"
    run_checked(
        [syft_command, "scan", f"file:{binary.name}", "-o", f"spdx-json={sbom.name}"],
        cwd=binary.parent,
        environment=environment,
    )
    verify_spdx(sbom)


def verify_spdx(path: Path) -> None:
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ReleaseError(f"invalid SPDX document: {path.name}") from error
    if document.get("spdxVersion") != "SPDX-2.3":
        raise ReleaseError(f"SBOM is not SPDX 2.3: {path.name}")
    packages = document.get("packages")
    if not isinstance(packages, list) or not packages:
        raise ReleaseError(f"SBOM package set is empty: {path.name}")
    binary_name = path.name.removesuffix(".spdx.json")
    allowed_names = {
        "stdlib",
        "github.com/relux-works/relux-tunnel/relay",
        binary_name,
    }
    package_names = {package.get("name") for package in packages}
    if not package_names.issubset(allowed_names):
        raise ReleaseError(f"unreviewed dependency found in SBOM: {path.name}")
    standard_library = [package for package in packages if package.get("name") == "stdlib"]
    if len(standard_library) != 1 or standard_library[0].get("versionInfo") != GO_VERSION:
        raise ReleaseError(f"Go standard-library provenance mismatch: {path.name}")
    if standard_library[0].get("licenseDeclared") != "BSD-3-Clause":
        raise ReleaseError(f"Go standard-library license mismatch: {path.name}")
    reject_host_paths(path.read_text(encoding="utf-8"), path.name)


def notice_text(go_root: str) -> str:
    go_license = Path(go_root) / "LICENSE"
    if sha256(go_license) != GO_LICENSE_SHA256:
        raise ReleaseError("Go 1.26.5 license checksum mismatch")
    repository_license = (ROOT / "LICENSE").read_text(encoding="utf-8").rstrip()
    go_license_text = go_license.read_text(encoding="utf-8").rstrip()
    return (
        "Relux Relay license notices\n"
        "\n"
        "Relux Tunnel repository license (MIT)\n"
        "-------------------------------------\n"
        f"{repository_license}\n"
        "\n"
        f"Go {GO_VERSION.removeprefix('go')} toolchain and standard library (BSD-3-Clause)\n"
        "-------------------------------------------------------------------\n"
        f"{go_license_text}\n"
    )


def write_notice(output: Path, go_root: str) -> Path:
    notice = output / NOTICE_PATH
    notice.parent.mkdir(parents=True, exist_ok=True)
    notice.write_text(notice_text(go_root), encoding="utf-8", newline="\n")
    return notice


def verify_notice(output: Path, go_root: str) -> None:
    if (output / NOTICE_PATH).read_text(encoding="utf-8") != notice_text(go_root):
        raise ReleaseError("license notice content mismatch")


def build_manifest(relay_version: str, source_commit: str, output: Path) -> dict[str, Any]:
    artifacts: list[dict[str, Any]] = []
    for target in TARGETS:
        filename = target_filename(target)
        binary = output / filename
        sbom_name = f"{filename}.spdx.json"
        sbom = output / sbom_name
        artifacts.append(
            {
                "os": target["os"],
                "arch": target["arch"],
                "goTarget": f"{target['os']}/{target['arch']}",
                "canonicalTarget": target["canonicalTarget"],
                "filename": filename,
                "size": binary.stat().st_size,
                "sha256": sha256(binary),
                "sbom": sbom_name,
                "sbomSha256": sha256(sbom),
            }
        )
    return {
        "schemaVersion": MANIFEST_SCHEMA_VERSION,
        "relayProtocolVersion": PROTOCOL_VERSION,
        "relayVersion": relay_version,
        "sourceCommit": source_commit,
        "toolchain": {"go": GO_VERSION, "cgoEnabled": False, "syft": SYFT_VERSION},
        "artifacts": artifacts,
    }


def write_checksums(output: Path) -> None:
    paths = [Path(MANIFEST_NAME), Path(NOTICE_PATH)]
    for target in TARGETS:
        filename = target_filename(target)
        paths.extend((Path(filename), Path(f"{filename}.spdx.json")))
    paths.sort(key=lambda path: path.as_posix())
    lines = [f"{sha256(output / path)}  {path.as_posix()}\n" for path in paths]
    (output / CHECKSUMS_NAME).write_text("".join(lines), encoding="ascii", newline="\n")


def reject_host_paths(text: str, label: str) -> None:
    forbidden = {str(ROOT.resolve()), str(Path.home().resolve())}
    for token in forbidden:
        if token and token in text:
            raise ReleaseError(f"host-specific path found in {label}")


def verify_binary_format(path: Path, target: dict[str, str]) -> None:
    data = path.read_bytes()[:24]
    if target["os"] == "linux":
        if len(data) < 20 or data[:4] != b"\x7fELF" or data[5] != 1:
            raise ReleaseError(f"unexpected Linux file format: {path.name}")
        machine = struct.unpack_from("<H", data, 18)[0]
        expected = 62 if target["arch"] == "amd64" else 183
    else:
        if len(data) < 8 or data[:4] != b"\xcf\xfa\xed\xfe":
            raise ReleaseError(f"unexpected Darwin file format: {path.name}")
        machine = struct.unpack_from("<I", data, 4)[0]
        expected = 0x01000007 if target["arch"] == "amd64" else 0x0100000C
    if machine != expected:
        raise ReleaseError(f"unexpected architecture: {path.name}")


def verify_go_build_info(go_command: str, go_toolchain: str, binary: Path, target: dict[str, str]) -> None:
    environment = sanitized_environment(go_toolchain)
    output = run_checked(
        [go_command, "version", "-m", str(binary)],
        cwd=ROOT,
        environment=environment,
    ).stdout
    required = (
        GO_VERSION,
        f"GOOS={target['os']}",
        f"GOARCH={target['arch']}",
        "CGO_ENABLED=0",
        "-trimpath=true",
    )
    if any(value not in output for value in required):
        raise ReleaseError(f"unexpected Go build metadata: {binary.name}")


def expected_manifest_keys() -> tuple[set[str], set[str], set[str]]:
    return (
        {"schemaVersion", "relayProtocolVersion", "relayVersion", "sourceCommit", "toolchain", "artifacts"},
        {"go", "cgoEnabled", "syft"},
        {"os", "arch", "goTarget", "canonicalTarget", "filename", "size", "sha256", "sbom", "sbomSha256"},
    )


def verify_manifest_schema() -> None:
    schema_path = RELAY_ROOT / "manifest-v1.schema.json"
    try:
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ReleaseError("manifest-v1.schema.json is invalid") from error
    top_keys, toolchain_keys, artifact_keys = expected_manifest_keys()
    if set(schema.get("properties", {})) != top_keys:
        raise ReleaseError("manifest schema top-level field set changed")
    if schema.get("additionalProperties") is not False or set(schema.get("required", [])) != top_keys:
        raise ReleaseError("manifest schema must reject missing and unknown fields")
    toolchain_properties = schema["properties"]["toolchain"].get("properties", {})
    artifact_schema = schema.get("$defs", {}).get("artifact", {})
    artifact_properties = artifact_schema.get("properties", {})
    if set(toolchain_properties) != toolchain_keys or set(artifact_properties) != artifact_keys:
        raise ReleaseError("manifest schema nested field set changed")
    if (
        schema["properties"]["toolchain"].get("additionalProperties") is not False
        or set(schema["properties"]["toolchain"].get("required", [])) != toolchain_keys
        or artifact_schema.get("additionalProperties") is not False
        or set(artifact_schema.get("required", [])) != artifact_keys
    ):
        raise ReleaseError("manifest schema nested objects must be strict")
    if schema["properties"]["schemaVersion"].get("const") != MANIFEST_SCHEMA_VERSION:
        raise ReleaseError("manifest schema version changed")
    if schema["properties"]["relayProtocolVersion"].get("const") != PROTOCOL_VERSION:
        raise ReleaseError("manifest protocol version changed")
    expected_toolchain = {"go": GO_VERSION, "syft": SYFT_VERSION}
    for field, expected in expected_toolchain.items():
        if toolchain_properties[field].get("const") != expected:
            raise ReleaseError("manifest schema toolchain pin changed")


def verify_manifest(output: Path, go_command: str, go_toolchain: str) -> dict[str, Any]:
    manifest_path = output / MANIFEST_NAME
    try:
        text = manifest_path.read_text(encoding="utf-8")
        manifest = json.loads(text)
    except (OSError, json.JSONDecodeError) as error:
        raise ReleaseError("relay manifest is invalid JSON") from error
    reject_host_paths(text, MANIFEST_NAME)
    top_keys, toolchain_keys, artifact_keys = expected_manifest_keys()
    if set(manifest) != top_keys or set(manifest.get("toolchain", {})) != toolchain_keys:
        raise ReleaseError("relay manifest field set changed")
    validate_release_inputs(manifest.get("relayVersion", ""), manifest.get("sourceCommit", ""))
    if manifest.get("schemaVersion") != MANIFEST_SCHEMA_VERSION or manifest.get("relayProtocolVersion") != PROTOCOL_VERSION:
        raise ReleaseError("relay manifest version changed")
    if manifest["toolchain"] != {"go": GO_VERSION, "cgoEnabled": False, "syft": SYFT_VERSION}:
        raise ReleaseError("relay manifest toolchain changed")
    artifacts = manifest.get("artifacts")
    if not isinstance(artifacts, list) or len(artifacts) != len(TARGETS):
        raise ReleaseError("relay manifest must contain the four-target matrix")
    for artifact, target in zip(artifacts, TARGETS, strict=True):
        if set(artifact) != artifact_keys:
            raise ReleaseError("relay manifest artifact field set changed")
        filename = target_filename(target)
        expected_identity = {
            "os": target["os"],
            "arch": target["arch"],
            "goTarget": f"{target['os']}/{target['arch']}",
            "canonicalTarget": target["canonicalTarget"],
            "filename": filename,
            "sbom": f"{filename}.spdx.json",
        }
        if any(artifact.get(key) != value for key, value in expected_identity.items()):
            raise ReleaseError(f"noncanonical artifact identity: {filename}")
        binary = output / filename
        sbom = output / artifact["sbom"]
        if artifact.get("size") != binary.stat().st_size or artifact["size"] <= 0:
            raise ReleaseError(f"artifact size mismatch: {filename}")
        if artifact.get("sha256") != sha256(binary) or not SHA256_PATTERN.fullmatch(artifact["sha256"]):
            raise ReleaseError(f"artifact checksum mismatch: {filename}")
        if artifact.get("sbomSha256") != sha256(sbom) or not SHA256_PATTERN.fullmatch(artifact["sbomSha256"]):
            raise ReleaseError(f"SBOM checksum mismatch: {filename}")
        verify_spdx(sbom)
        verify_binary_format(binary, target)
        verify_go_build_info(go_command, go_toolchain, binary, target)
    expected = build_manifest(manifest["relayVersion"], manifest["sourceCommit"], output)
    if text.encode("utf-8") != stable_json(expected):
        raise ReleaseError("relay manifest is not canonical deterministic JSON")
    return manifest


def verify_checksums(output: Path) -> None:
    checksum_path = output / CHECKSUMS_NAME
    lines = checksum_path.read_text(encoding="ascii").splitlines()
    if lines != sorted(lines, key=lambda line: line.split("  ", 1)[1]):
        raise ReleaseError("checksum entries are not sorted")
    expected_count = len(TARGETS) * 2 + 2
    if len(lines) != expected_count:
        raise ReleaseError("checksum file has an unexpected entry count")
    for line in lines:
        match = re.fullmatch(r"([0-9a-f]{64})  ([A-Za-z0-9_./-]+)", line)
        if match is None:
            raise ReleaseError("checksum file has a noncanonical line")
        relative = PurePosixPath(match.group(2))
        if relative.is_absolute() or ".." in relative.parts:
            raise ReleaseError("checksum file contains an unsafe path")
        if sha256(output / Path(relative)) != match.group(1):
            raise ReleaseError(f"checksum verification failed: {relative}")
    expected_files = {CHECKSUMS_NAME}
    expected_files.update(line.split("  ", 1)[1] for line in lines)
    actual_files = {
        path.relative_to(output).as_posix()
        for path in output.rglob("*")
        if path.is_file()
    }
    if actual_files != expected_files:
        raise ReleaseError("release artifact set changed")


def verify_protocol_tests(test_output: Path, go_command: str, go_toolchain: str) -> None:
    expected_names: list[str] = []
    for target in TARGETS:
        name = protocol_test_filename(target)
        expected_names.append(name)
        binary = test_output / name
        verify_binary_format(binary, target)
        verify_go_build_info(go_command, go_toolchain, binary, target)
    actual_names = sorted(path.name for path in test_output.iterdir() if path.is_file())
    if actual_names != sorted(expected_names):
        raise ReleaseError("protocol-test artifact set changed")


def validate_provisioning_archive(path: Path, tool: str, tool_platform: str) -> dict[str, str]:
    contract = archive_contract(tool, tool_platform)
    if path.name != contract["artifact"]:
        raise ReleaseError(f"unexpected {tool} release archive name")
    if not path.is_file() or sha256(path) != contract["sha256"]:
        raise ReleaseError(f"{tool} release archive checksum mismatch")
    return contract


def prepare_provision_destination(archive: Path, destination: Path) -> Path:
    source = archive.resolve()
    output = validate_output_path(destination)
    if source == output or output in source.parents or source in output.parents:
        raise ReleaseError("provisioning archive must remain outside destination")
    clean_directory(output)
    return output


def write_tool_provenance(destination: Path, tool: str, tool_platform: str) -> None:
    (destination / PROVENANCE_NAME).write_bytes(stable_json(provenance_document(tool, tool_platform)))


def provision_go(arguments: argparse.Namespace) -> None:
    tool_platform = host_platform()
    archive = Path(arguments.archive).resolve()
    contract = validate_provisioning_archive(archive, "go", tool_platform)
    destination = prepare_provision_destination(archive, Path(arguments.destination))
    with tarfile.open(archive, "r:gz") as bundle:
        members = bundle.getmembers()
        unsafe = not members
        for member in members:
            member_path = PurePosixPath(member.name)
            if (
                not member_path.parts
                or member_path.is_absolute()
                or ".." in member_path.parts
                or member_path.parts[0] != "go"
            ):
                unsafe = True
                break
        if unsafe:
            raise ReleaseError("Go release archive layout is unsafe")
        bundle.extractall(destination, filter="data")
    executable = destination / "go" / "bin" / "go"
    if not executable.is_file():
        raise ReleaseError("Go release archive does not contain go/bin/go")
    shutil.copyfile(archive, destination / contract["artifact"])
    write_tool_provenance(destination, "go", tool_platform)
    verify_archive_provenance(
        destination,
        "go",
        tool_platform,
        (("go/bin/go", executable),),
    )


def provision_syft(arguments: argparse.Namespace) -> None:
    tool_platform = host_platform()
    archive = Path(arguments.archive).resolve()
    contract = validate_provisioning_archive(archive, "syft", tool_platform)
    destination = prepare_provision_destination(archive, Path(arguments.destination))
    installed = destination / "syft"
    with tarfile.open(archive, "r:gz") as bundle:
        matches = [member for member in bundle.getmembers() if member.name == "syft"]
        if len(matches) != 1 or not matches[0].isfile():
            raise ReleaseError("Syft release archive does not contain one syft executable")
        stream = bundle.extractfile(matches[0])
        if stream is None:
            raise ReleaseError("Syft release executable is unreadable")
        with installed.open("wb") as output:
            shutil.copyfileobj(stream, output)
    installed.chmod(0o755)
    shutil.copyfile(archive, destination / contract["artifact"])
    write_tool_provenance(destination, "syft", tool_platform)
    verify_archive_provenance(destination, "syft", tool_platform, (("syft", installed),))
    verify_syft_toolchain(str(installed), require_provenance=True)


def build_release(arguments: argparse.Namespace) -> None:
    arguments.go = resolve_tool_command(arguments.go)
    arguments.syft = resolve_tool_command(arguments.syft)
    validate_release_inputs(arguments.relay_version, arguments.source_commit)
    if arguments.require_clean:
        verify_clean_checkout(arguments.source_commit)
    output = validate_output_path(Path(arguments.output))
    test_output = validate_output_path(Path(arguments.test_output))
    if output == test_output:
        raise ReleaseError("release and protocol-test outputs must be separate")
    require_provenance = arguments.require_provenance or arguments.require_clean
    go_root = verify_go_toolchain(arguments.go, arguments.go_toolchain, require_provenance)
    verify_syft_toolchain(arguments.syft, require_provenance)
    verify_go_module_policy()
    verify_manifest_schema()
    clean_directory(output)
    clean_directory(test_output)
    for target in TARGETS:
        build_binary(
            arguments.go,
            arguments.go_toolchain,
            target,
            "./cmd/relux-relay",
            output / target_filename(target),
            arguments.relay_version,
            arguments.source_commit,
        )
        build_binary(
            arguments.go,
            arguments.go_toolchain,
            target,
            "./cmd/relux-relay-protocol-test",
            test_output / protocol_test_filename(target),
            arguments.relay_version,
            arguments.source_commit,
        )
    for target in TARGETS:
        filename = target_filename(target)
        generate_sbom(arguments.syft, output / filename, output / f"{filename}.spdx.json")
    write_notice(output, go_root)
    manifest = build_manifest(arguments.relay_version, arguments.source_commit, output)
    (output / MANIFEST_NAME).write_bytes(stable_json(manifest))
    write_checksums(output)
    verify_manifest(output, arguments.go, arguments.go_toolchain)
    verify_checksums(output)
    verify_notice(output, go_root)
    verify_protocol_tests(test_output, arguments.go, arguments.go_toolchain)


def verify_release(arguments: argparse.Namespace) -> None:
    arguments.go = resolve_tool_command(arguments.go)
    go_root = verify_go_toolchain(arguments.go, arguments.go_toolchain, arguments.require_provenance)
    verify_go_module_policy()
    verify_manifest_schema()
    output = validate_output_path(Path(arguments.output))
    test_output = validate_output_path(Path(arguments.test_output))
    verify_manifest(output, arguments.go, arguments.go_toolchain)
    verify_checksums(output)
    verify_notice(output, go_root)
    verify_protocol_tests(test_output, arguments.go, arguments.go_toolchain)


def compare_release(arguments: argparse.Namespace) -> None:
    first = validate_output_path(Path(arguments.first))
    second = validate_output_path(Path(arguments.second))
    first_tests = validate_output_path(Path(arguments.first_tests))
    second_tests = validate_output_path(Path(arguments.second_tests))
    for target in TARGETS:
        for left, right, name in (
            (first, second, target_filename(target)),
            (first_tests, second_tests, protocol_test_filename(target)),
        ):
            if (left / name).read_bytes() != (right / name).read_bytes():
                raise ReleaseError(f"non-reproducible binary: {name}")


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    subparsers = result.add_subparsers(dest="command", required=True)

    def add_toolchain_options(command: argparse.ArgumentParser) -> None:
        command.add_argument("--go", default="go")
        command.add_argument("--go-toolchain", default="local")

    build = subparsers.add_parser("build", help="build and verify all target-shell artifacts")
    build.add_argument("--output", required=True)
    build.add_argument("--test-output", required=True)
    build.add_argument("--relay-version", required=True)
    build.add_argument("--source-commit", required=True)
    build.add_argument("--syft", required=True)
    build.add_argument("--require-clean", action="store_true")
    build.add_argument("--require-provenance", action="store_true")
    add_toolchain_options(build)
    build.set_defaults(action=build_release)

    verify = subparsers.add_parser("verify", help="verify an existing target-shell artifact matrix")
    verify.add_argument("--output", required=True)
    verify.add_argument("--test-output", required=True)
    verify.add_argument("--require-provenance", action="store_true")
    add_toolchain_options(verify)
    verify.set_defaults(action=verify_release)

    compare = subparsers.add_parser("compare", help="compare reproducible executable bytes")
    compare.add_argument("--first", required=True)
    compare.add_argument("--second", required=True)
    compare.add_argument("--first-tests", required=True)
    compare.add_argument("--second-tests", required=True)
    compare.set_defaults(action=compare_release)

    provision_go_command = subparsers.add_parser(
        "provision-go",
        help="verify and install the official host Go archive without downloading it",
    )
    provision_go_command.add_argument("--archive", required=True)
    provision_go_command.add_argument("--destination", required=True)
    provision_go_command.set_defaults(action=provision_go)

    provision_syft_command = subparsers.add_parser(
        "provision-syft",
        help="verify and install the official host Syft archive without downloading it",
    )
    provision_syft_command.add_argument("--archive", required=True)
    provision_syft_command.add_argument("--destination", required=True)
    provision_syft_command.set_defaults(action=provision_syft)
    return result


def main() -> int:
    arguments = parser().parse_args()
    try:
        arguments.action(arguments)
    except (ReleaseError, FileNotFoundError, OSError) as error:
        print(f"relay-release: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
