#!/usr/bin/env python3
"""Build and verify deterministic relux-relay target-shell artifacts."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import shutil
import stat
import struct
import subprocess
import sys
import tarfile
import tempfile
from typing import Any


GO_VERSION = "go1.26.5"
SYFT_VERSION = "1.48.0"
SYFT_COMMIT = "3e2bc6ed095f7ec1a415fb38cfe1c319e95dfed6"
PROTOCOL_VERSION = 1
MANIFEST_SCHEMA_VERSION = 1
PORTABLE_REPORT_SCHEMA_VERSION = 1
PROVENANCE_SCHEMA_VERSION = 1
GO_LICENSE_SHA256 = "911f8f5782931320f5b8d1160a76365b83aea6447ee6c04fa6d5591467db9dad"
VERSION_PATTERN = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$")
COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40}$")
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
MAX_RELAY_VERSION_BYTES = 64
MAX_IDENTITY_BYTES = 512
MAX_IDENTITY_MANIFEST_BYTES = 64 * 1024

MANIFEST_NAME = "relux-relay-manifest-v1.json"
CHECKSUMS_NAME = "relux-relay-SHA256SUMS"
NOTICE_PATH = PurePosixPath("THIRD_PARTY_NOTICES/Go-BSD-3-Clause.txt")
PROVENANCE_NAME = "relux-tool-provenance-v1.json"
TOOLCHAIN_MANIFEST_NAME = "toolchain-manifest-v1.json"
CHECKOUT_ACTION = "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1"

ROOT = Path(__file__).resolve().parent.parent
RELAY_ROOT = ROOT / "relay"
BUILD_ROOT = ROOT / ".build" / "relay"
TOOLCHAIN_MANIFEST_PATH = RELAY_ROOT / TOOLCHAIN_MANIFEST_NAME
CI_WORKFLOW_PATH = ROOT / ".github" / "workflows" / "ci.yml"

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
    contracts = (
        GO_ARCHIVES if tool == "go" else SYFT_ARCHIVES if tool == "syft" else None
    )
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


def verify_archive_member_matches(
    archive: Path, member_name: str, installed: Path
) -> None:
    with tarfile.open(archive, "r:gz") as bundle:
        matches = [
            member for member in bundle.getmembers() if member.name == member_name
        ]
        if len(matches) != 1 or not matches[0].isfile():
            raise ReleaseError(f"release archive member mismatch: {member_name}")
        stream = bundle.extractfile(matches[0])
        if stream is None:
            raise ReleaseError(f"release archive member unreadable: {member_name}")
        archived_sha256 = sha256_stream(stream)
    if not installed.is_file() or sha256(installed) != archived_sha256:
        raise ReleaseError(
            f"installed release tool differs from archive: {installed.name}"
        )


def go_archive_tree(bundle: tarfile.TarFile) -> dict[str, tuple[str, int, str | None]]:
    entries: dict[str, tuple[str, int, str | None]] = {}
    for member in bundle.getmembers():
        member_path = PurePosixPath(member.name)
        canonical = member_path.as_posix()
        if (
            not member_path.parts
            or member_path.is_absolute()
            or ".." in member_path.parts
            or "\\" in member.name
            or canonical != member.name
            or member_path.parts[0] != "go"
        ):
            raise ReleaseError(
                f"Go release archive layout is unsafe: non-canonical path {member.name}"
            )
        if canonical in entries:
            raise ReleaseError(
                f"Go release archive layout is unsafe: duplicate path {canonical}"
            )
        if member.mode & ~0o777:
            raise ReleaseError(
                f"Go release archive layout is unsafe: permissions {canonical}"
            )
        if member.isdir():
            entries[canonical] = ("directory", member.mode, None)
        elif member.isfile():
            stream = bundle.extractfile(member)
            if stream is None:
                raise ReleaseError(
                    f"Go release archive member is unreadable: {canonical}"
                )
            entries[canonical] = ("file", member.mode, sha256_stream(stream))
        else:
            raise ReleaseError(
                f"Go release archive layout is unsafe: unsupported member type {canonical}"
            )
    if not entries or entries.get("go", (None,))[0] != "directory":
        raise ReleaseError("Go release archive layout is unsafe: missing go root")
    for name in entries:
        if name == "go":
            continue
        parent = PurePosixPath(name).parent.as_posix()
        if entries.get(parent, (None,))[0] != "directory":
            raise ReleaseError(
                f"Go release archive layout is unsafe: missing directory {parent}"
            )
    return entries


def installed_go_tree(
    directory: Path,
) -> dict[str, tuple[str, int, str | None]]:
    root = directory / "go"
    try:
        root_status = root.stat(follow_symlinks=False)
    except OSError as error:
        raise ReleaseError(
            "installed Go tree differs from archive: missing path go"
        ) from error
    if not stat.S_ISDIR(root_status.st_mode):
        raise ReleaseError("installed Go tree is unsafe: unsupported file type go")
    entries: dict[str, tuple[str, int, str | None]] = {
        "go": ("directory", stat.S_IMODE(root_status.st_mode), None)
    }

    def visit(path: Path, relative: PurePosixPath) -> None:
        try:
            children = sorted(os.scandir(path), key=lambda child: child.name)
        except OSError as error:
            raise ReleaseError(
                f"installed Go tree is unreadable: {relative.as_posix()}"
            ) from error
        for child in children:
            child_relative = relative / child.name
            name = child_relative.as_posix()
            try:
                status = child.stat(follow_symlinks=False)
            except OSError as error:
                raise ReleaseError(
                    f"installed Go tree is unreadable: {name}"
                ) from error
            mode = stat.S_IMODE(status.st_mode)
            if stat.S_ISDIR(status.st_mode):
                entries[name] = ("directory", mode, None)
                visit(Path(child.path), child_relative)
            elif stat.S_ISREG(status.st_mode):
                if status.st_nlink != 1:
                    raise ReleaseError(
                        f"installed Go tree is unsafe: hard-linked file {name}"
                    )
                entries[name] = ("file", mode, sha256(Path(child.path)))
            else:
                raise ReleaseError(
                    f"installed Go tree is unsafe: unsupported file type {name}"
                )

    visit(root, PurePosixPath("go"))
    return entries


def verify_installed_go_tree(archive: Path, directory: Path) -> None:
    with tarfile.open(archive, "r:gz") as bundle:
        expected = go_archive_tree(bundle)
    actual = installed_go_tree(directory)
    missing = sorted(set(expected) - set(actual))
    if missing:
        raise ReleaseError(
            f"installed Go tree differs from archive: missing path {missing[0]}"
        )
    unexpected = sorted(set(actual) - set(expected))
    if unexpected:
        raise ReleaseError(
            f"installed Go tree differs from archive: unexpected path {unexpected[0]}"
        )
    for name in sorted(expected):
        expected_kind, expected_mode, expected_digest = expected[name]
        actual_kind, actual_mode, actual_digest = actual[name]
        if actual_kind != expected_kind:
            raise ReleaseError(
                f"installed Go tree differs from archive: type mismatch {name}"
            )
        if actual_mode != expected_mode:
            raise ReleaseError(
                f"installed Go tree differs from archive: mode mismatch {name}"
            )
        if actual_digest != expected_digest:
            raise ReleaseError(
                f"installed Go tree differs from archive: content mismatch {name}"
            )


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
        raise ReleaseError(
            f"missing or invalid {tool} release-tool provenance"
        ) from error
    expected = provenance_document(tool, tool_platform)
    if text.encode("utf-8") != stable_json(expected) or provenance != expected:
        raise ReleaseError(f"{tool} release-tool provenance mismatch")
    reject_host_paths(text, provenance_path.name)
    archive = directory / contract["artifact"]
    if not archive.is_file() or sha256(archive) != contract["sha256"]:
        raise ReleaseError(f"{tool} release archive checksum mismatch")
    if tool == "go":
        verify_installed_go_tree(archive, directory)
    else:
        for member_name, installed in installed_members:
            verify_archive_member_matches(archive, member_name, installed)


def target_filename(target: dict[str, str]) -> str:
    return f"relux-relay-{target['os']}-{target['arch']}"


def target_directory(target: dict[str, str]) -> str:
    return f"{target['os']}-{target['arch']}"


def protocol_test_filename(target: dict[str, str]) -> str:
    return f"relux-relay-protocol-test-{target['os']}-{target['arch']}"


def validate_release_inputs(relay_version: str, source_commit: str) -> None:
    if (
        not relay_version
        or len(relay_version.encode("ascii", errors="ignore")) != len(relay_version)
        or len(relay_version) > MAX_RELAY_VERSION_BYTES
        or not VERSION_PATTERN.fullmatch(relay_version)
    ):
        raise ReleaseError("relay version must be a deterministic semantic version")
    if not COMMIT_PATTERN.fullmatch(source_commit):
        raise ReleaseError("source commit must be 40 lowercase hexadecimal characters")


def validate_source_date_epoch(value: str) -> str:
    if not re.fullmatch(r"0|[1-9][0-9]*", value):
        raise ReleaseError("SOURCE_DATE_EPOCH must be a non-negative decimal integer")
    return value


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


def validate_isolated_directory(path: Path, description: str, *, create: bool) -> Path:
    try:
        status = path.stat(follow_symlinks=False)
    except FileNotFoundError:
        if not create:
            return path
        try:
            path.mkdir(parents=True, exist_ok=False)
        except FileExistsError:
            pass
        except OSError as error:
            raise ReleaseError(f"{description} cannot be created") from error
        try:
            status = path.stat(follow_symlinks=False)
        except OSError as error:
            raise ReleaseError(f"{description} cannot be inspected") from error
    except OSError as error:
        raise ReleaseError(f"{description} cannot be inspected") from error
    if stat.S_ISLNK(status.st_mode):
        raise ReleaseError(f"{description} must not be a symbolic link")
    if not stat.S_ISDIR(status.st_mode):
        raise ReleaseError(f"{description} must be a directory")
    return path


def resolve_isolated_child(
    path: Path, resolved_sandbox_root: Path, description: str
) -> Path:
    validate_isolated_directory(path, description, create=True)
    resolved = path.resolve(strict=True)
    try:
        resolved.relative_to(resolved_sandbox_root)
    except ValueError as error:
        raise ReleaseError(f"{description} escapes build sandbox root") from error
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


def sanitized_environment(
    go_toolchain: str,
    target: dict[str, str] | None = None,
    *,
    sandbox: Path | None = None,
    source_date_epoch: str = "0",
) -> dict[str, str]:
    epoch = validate_source_date_epoch(source_date_epoch)
    sandbox_root = validate_output_path(
        sandbox or (BUILD_ROOT / "work" / "verification")
    )
    validate_isolated_directory(sandbox_root, "build sandbox root", create=True)
    resolved_sandbox_root = sandbox_root.resolve(strict=True)
    paths = {
        "HOME": sandbox_root / "home",
        "TMPDIR": sandbox_root / "tmp",
        "GOCACHE": sandbox_root / "go-build-cache",
        "GOMODCACHE": sandbox_root / "go-module-cache",
        "GOPATH": sandbox_root / "go-path",
    }
    for name, path in paths.items():
        paths[name] = resolve_isolated_child(
            path, resolved_sandbox_root, f"build sandbox {name}"
        )
    environment = {
        "PATH": "/usr/bin:/bin",
        **{key: str(value) for key, value in paths.items()},
    }
    environment.update(
        {
            "GOTOOLCHAIN": go_toolchain,
            "GOENV": "off",
            "GOWORK": "off",
            "GOPROXY": "off",
            "GOSUMDB": "off",
            "GOVCS": "off",
            "CGO_ENABLED": "0",
            "LC_ALL": "C",
            "LANG": "C",
            "TZ": "UTC",
            "SOURCE_DATE_EPOCH": epoch,
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
        raise ReleaseError(
            f"command failed: {Path(command[0]).name} {command[1]}"
        ) from error


def verify_go_toolchain(
    go_command: str, go_toolchain: str, require_provenance: bool = False
) -> str:
    if require_provenance and go_toolchain != "local":
        raise ReleaseError("release mode requires GOTOOLCHAIN=local")
    executable = resolve_executable(go_command)
    environment = sanitized_environment(go_toolchain)
    version = run_checked(
        [str(executable), "version"], cwd=RELAY_ROOT, environment=environment
    ).stdout.strip()
    match = re.fullmatch(
        r"go version (go[0-9.]+) (darwin|linux)/(amd64|arm64)", version
    )
    if match is None or match.group(1) != GO_VERSION:
        raise ReleaseError(f"required Go toolchain is {GO_VERSION}")
    tool_platform = f"{match.group(2)}/{match.group(3)}"
    if tool_platform != host_platform():
        raise ReleaseError("Go release-tool platform mismatch")
    values = run_checked(
        [
            str(executable),
            "env",
            "GOROOT",
            "GOTOOLDIR",
            "GOHOSTOS",
            "GOHOSTARCH",
            "GOTOOLCHAIN",
        ],
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
        expected_tool_directory = (
            root_path / "pkg" / "tool" / tool_platform.replace("/", "_")
        )
        if tool_directory != expected_tool_directory.resolve():
            raise ReleaseError("Go tool directory does not match selected GOROOT")
        critical_members = (
            ("go/bin/go", root_path / "bin" / "go"),
            *(
                (
                    f"go/pkg/tool/{tool_platform.replace('/', '_')}/{name}",
                    tool_directory / name,
                )
                for name in ("asm", "compile", "link")
            ),
        )
        verify_archive_provenance(
            root_path.parent, "go", tool_platform, critical_members
        )
    else:
        tool_directory = Path(go_tool_dir).resolve()
    for executable_name in ("compile", "link"):
        identity = run_checked(
            [str(tool_directory / executable_name), "-V=full"],
            cwd=RELAY_ROOT,
            environment=environment,
        ).stdout.strip()
        if identity != f"{executable_name} version {GO_VERSION}":
            raise ReleaseError(f"Go {executable_name} identity mismatch")
    return str(root_path)


def verify_go_module_policy() -> None:
    module_text = (RELAY_ROOT / "go.mod").read_text(encoding="utf-8")
    if not re.search(r"(?m)^go 1\.26\.0$", module_text):
        raise ReleaseError("relay/go.mod must declare go 1.26.0")
    if not re.search(r"(?m)^toolchain go1\.26\.5$", module_text):
        raise ReleaseError("relay/go.mod must pin toolchain go1.26.5")
    if re.search(r"(?m)^\s*(require|replace|exclude)\b", module_text):
        raise ReleaseError("relay/go.mod must remain standard-library-only")


def verify_checkout_action_pin() -> None:
    try:
        workflow = CI_WORKFLOW_PATH.read_text(encoding="utf-8")
    except OSError as error:
        raise ReleaseError("CI workflow checkout action pin is unreadable") from error
    references = re.findall(r"(?m)^\s*-\s+uses:\s*(actions/checkout@[^\s#]+)", workflow)
    if not references or any(reference != CHECKOUT_ACTION for reference in references):
        raise ReleaseError("CI workflow checkout action pin drift")


def verify_toolchain_manifest() -> dict[str, Any]:
    try:
        text = TOOLCHAIN_MANIFEST_PATH.read_text(encoding="utf-8")
        manifest = json.loads(text)
    except (OSError, json.JSONDecodeError) as error:
        raise ReleaseError(f"{TOOLCHAIN_MANIFEST_NAME} is invalid") from error
    if text.encode("utf-8") != stable_json(manifest):
        raise ReleaseError(f"{TOOLCHAIN_MANIFEST_NAME} is not canonical JSON")
    expected_top = {
        "schemaVersion",
        "module",
        "compiler",
        "hostToolArchives",
        "buildOnlyTools",
        "dependencies",
        "targets",
        "build",
        "runtimeContract",
        "ci",
    }
    if set(manifest) != expected_top or manifest.get("schemaVersion") != 1:
        raise ReleaseError("toolchain manifest field set or schema version changed")
    module = manifest.get("module", {})
    if module != {
        "path": "github.com/relux-works/relux-tunnel/relay",
        "directory": "relay",
        "goDirective": "1.26.0",
        "toolchainDirective": GO_VERSION,
        "lockFile": "relay/go.mod",
        "lockFileSha256": sha256(RELAY_ROOT / "go.mod"),
        "dependencyPolicy": "standard-library-only",
    }:
        raise ReleaseError("toolchain manifest module pin drift")
    compiler = manifest.get("compiler", {})
    expected_compiler = {
        "distribution": "official-go",
        "name": "gc",
        "version": GO_VERSION,
        "driver": "go",
        "compilerExecutable": "pkg/tool/<host>/compile",
        "linker": "Go internal linker",
        "linkerExecutable": "pkg/tool/<host>/link",
        "linkMode": "internal",
        "cgoEnabled": False,
        "sdk": "none",
        "sysroot": "none",
    }
    if compiler != expected_compiler:
        raise ReleaseError("toolchain manifest compiler/linker pin drift")
    expected_archives = []
    for tool_platform, contract in GO_ARCHIVES.items():
        expected_archives.append(
            {
                "host": tool_platform,
                "artifact": contract["artifact"],
                "sha256": contract["sha256"],
                "source": f"https://go.dev/dl/{contract['artifact']}",
            }
        )
    if manifest.get("hostToolArchives") != expected_archives:
        raise ReleaseError("toolchain manifest host archive pin drift")
    syft_archives = []
    for tool_platform, contract in SYFT_ARCHIVES.items():
        syft_archives.append(
            {
                "host": tool_platform,
                "artifact": contract["artifact"],
                "sha256": contract["sha256"],
                "source": (
                    f"https://github.com/anchore/syft/releases/download/v{SYFT_VERSION}/"
                    f"{contract['artifact']}"
                ),
            }
        )
    if manifest.get("buildOnlyTools") != [
        {
            "name": "syft",
            "version": SYFT_VERSION,
            "revision": SYFT_COMMIT,
            "license": "Apache-2.0",
            "purpose": "release SBOM generation only; not used by portable target builds",
            "hostArchives": syft_archives,
        }
    ]:
        raise ReleaseError("toolchain manifest build-only tool pin drift")
    dependencies = manifest.get("dependencies")
    if not isinstance(dependencies, list) or len(dependencies) != 2:
        raise ReleaseError("toolchain manifest dependency set changed")
    if (
        dependencies[0].get("revision") != GO_VERSION
        or dependencies[0].get("license") != "BSD-3-Clause"
    ):
        raise ReleaseError("toolchain manifest Go dependency pin drift")
    if dependencies[0].get("licenseSha256") != GO_LICENSE_SHA256:
        raise ReleaseError("toolchain manifest Go license hash drift")
    if dependencies[1].get("license") != "MIT" or dependencies[1].get(
        "licenseSha256"
    ) != sha256(ROOT / "LICENSE"):
        raise ReleaseError("toolchain manifest project license hash drift")
    targets = manifest.get("targets")
    expected_targets = [
        {
            "canonicalTarget": "x86_64-apple-darwin",
            "goTarget": "darwin/amd64",
            "cpuBaseline": "GOAMD64=v1",
            "minimumRuntime": "macOS 12.0",
            "libc": "system libSystem ABI",
            "dynamicLibraries": [
                "/usr/lib/libSystem.B.dylib",
                "/usr/lib/libresolv.9.dylib",
            ],
            "sdk": "none; Go internal linker emits LC_BUILD_VERSION minos/sdk 12.0",
            "sysroot": "none",
        },
        {
            "canonicalTarget": "aarch64-apple-darwin",
            "goTarget": "darwin/arm64",
            "cpuBaseline": "GOARM64=v8.0",
            "minimumRuntime": "macOS 12.0",
            "libc": "system libSystem ABI",
            "dynamicLibraries": [
                "/usr/lib/libSystem.B.dylib",
                "/usr/lib/libresolv.9.dylib",
            ],
            "sdk": "none; Go internal linker emits LC_BUILD_VERSION minos/sdk 12.0",
            "sysroot": "none",
        },
        {
            "canonicalTarget": "x86_64-unknown-linux",
            "goTarget": "linux/amd64",
            "cpuBaseline": "GOAMD64=v1",
            "minimumRuntime": "Ubuntu 24.04 native CI fixture; no kernel-version floor claimed",
            "runtimeFixture": "GitHub Actions ubuntu-24.04 x86_64 runner",
            "libc": "none",
            "dynamicLibraries": [],
            "sdk": "none",
            "sysroot": "none",
        },
        {
            "canonicalTarget": "aarch64-unknown-linux",
            "goTarget": "linux/arm64",
            "cpuBaseline": "GOARM64=v8.0",
            "minimumRuntime": "Ubuntu 24.04 native CI fixture; no kernel-version floor claimed",
            "runtimeFixture": "GitHub Actions ubuntu-24.04-arm arm64 runner",
            "libc": "none",
            "dynamicLibraries": [],
            "sdk": "none",
            "sysroot": "none",
        },
    ]
    if targets != expected_targets:
        raise ReleaseError("toolchain manifest target, runtime, SDK, or linkage drift")
    build = manifest.get("build", {})
    required_environment = {
        "GOTOOLCHAIN": "local",
        "CGO_ENABLED": "0",
        "GOENV": "off",
        "GOWORK": "off",
        "GOPROXY": "off",
        "GOSUMDB": "off",
        "GOVCS": "off",
        "LC_ALL": "C",
        "LANG": "C",
        "TZ": "UTC",
        "SOURCE_DATE_EPOCH": "required non-negative integer command input",
    }
    expected_flags = [
        "-mod=readonly",
        "-trimpath",
        "-buildvcs=false",
        "-tags=netgo,osusergo",
        "-ldflags=-s -w -buildid= -linkmode=internal -X <module>/internal/buildinfo.Version=<RELAY_VERSION> -X <module>/internal/buildinfo.Commit=<SOURCE_COMMIT>",
    ]
    expected_cache_policy = (
        "HOME, TMPDIR, GOCACHE, GOMODCACHE, and GOPATH are target-scoped below "
        ".build/relay/work; roots and children are no-follow checked directories "
        "whose resolved paths must remain below the target workspace; clean mode "
        "deletes that target workspace, incremental mode reuses only that workspace"
    )
    expected_credential_policy = (
        "the build environment is an allowlist and never inherits workstation "
        "HOME, SSH_AUTH_SOCK, credential helpers, cloud credentials, or Go proxy "
        "settings"
    )
    if (
        build.get("package") != "./cmd/relux-relay"
        or build.get("flags") != expected_flags
        or build.get("environment") != required_environment
        or build.get("cachePolicy") != expected_cache_policy
        or build.get("credentialPolicy") != expected_credential_policy
    ):
        raise ReleaseError("toolchain manifest build environment drift")
    if manifest.get("runtimeContract") != {
        "privilege": "unprivileged user",
        "linuxLinkage": "static ELF with no PT_INTERP or PT_DYNAMIC",
        "linuxRuntimeEvidence": "native smoke on declared Ubuntu 24.04 x86_64 and arm64 CI fixtures; no older kernel compatibility claim",
        "darwinLinkage": "Mach-O with only libSystem and libresolv dynamic loads and minimum OS 12.0",
        "codeSigning": "out of scope; binaries are later embedded in the signed Apple application bundle",
    }:
        raise ReleaseError("toolchain manifest runtime contract drift")
    if manifest.get("ci") != {
        "runner": "ubuntu-24.04",
        "checkoutAction": CHECKOUT_ACTION,
        "checkoutActionVersion": "v7.0.1",
        "checkoutActionSource": "https://github.com/actions/checkout/releases/tag/v7.0.1",
        "networkBoundary": "network is permitted only for the checksum-pinned host Go archive fetch; provisioning, tests, native smoke, and all four builds run with Go network resolution disabled",
        "nativeRuntimeFixtures": [
            {
                "target": "linux/amd64",
                "runner": "ubuntu-24.04",
                "command": "make relay-toolchain-native-linux-smoke",
                "source": "https://docs.github.com/en/actions/reference/runners/github-hosted-runners",
            },
            {
                "target": "linux/arm64",
                "runner": "ubuntu-24.04-arm",
                "command": "make relay-toolchain-native-linux-smoke",
                "source": "https://docs.github.com/en/actions/reference/runners/github-hosted-runners",
            },
        ],
    }:
        raise ReleaseError("toolchain manifest CI pin or runtime fixture drift")
    verify_checkout_action_pin()
    reject_host_paths(text, TOOLCHAIN_MANIFEST_NAME)
    return manifest


def verify_checkout_revision(source_commit: str) -> None:
    environment = sanitized_environment("local")
    revision = run_checked(
        ["git", "rev-parse", "HEAD"],
        cwd=ROOT,
        environment=environment,
    ).stdout.strip()
    if revision != source_commit:
        raise ReleaseError("source commit does not match checkout HEAD")


def verify_clean_checkout(source_commit: str) -> None:
    verify_checkout_revision(source_commit)
    environment = sanitized_environment("local")
    status = run_checked(
        ["git", "status", "--porcelain", "--untracked-files=all"],
        cwd=ROOT,
        environment=environment,
    ).stdout
    if status:
        raise ReleaseError("release mode requires a clean checkout")


def build_binary(
    go_command: str,
    go_toolchain: str,
    target: dict[str, str],
    package: str,
    output: Path,
    relay_version: str,
    source_commit: str,
    *,
    sandbox: Path | None = None,
    source_date_epoch: str = "0",
) -> None:
    environment = sanitized_environment(
        go_toolchain,
        target,
        sandbox=sandbox,
        source_date_epoch=source_date_epoch,
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    ldflags = " ".join(
        (
            "-s",
            "-w",
            "-buildid=",
            "-linkmode=internal",
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
    output = run_checked(
        [str(executable), "version"], cwd=ROOT, environment=environment
    ).stdout
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
    standard_library = [
        package for package in packages if package.get("name") == "stdlib"
    ]
    if (
        len(standard_library) != 1
        or standard_library[0].get("versionInfo") != GO_VERSION
    ):
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


def build_manifest(
    relay_version: str, source_commit: str, output: Path
) -> dict[str, Any]:
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


def packed_macho_version(value: int) -> str:
    return f"{value >> 16}.{(value >> 8) & 0xff}.{value & 0xff}"


def verify_linkage_contract(path: Path, target: dict[str, str]) -> None:
    data = path.read_bytes()
    if target["os"] == "linux":
        if len(data) < 64 or data[:4] != b"\x7fELF" or data[4:6] != b"\x02\x01":
            raise ReleaseError(
                f"Linux artifact is not little-endian ELF64: {path.name}"
            )
        program_offset = struct.unpack_from("<Q", data, 32)[0]
        program_entry_size, program_count = struct.unpack_from("<HH", data, 54)
        if (
            program_entry_size < 4
            or program_offset + program_entry_size * program_count > len(data)
        ):
            raise ReleaseError(f"Linux program headers are invalid: {path.name}")
        program_types = {
            struct.unpack_from("<I", data, program_offset + index * program_entry_size)[
                0
            ]
            for index in range(program_count)
        }
        if 2 in program_types or 3 in program_types:
            raise ReleaseError(
                f"Linux artifact must not contain PT_DYNAMIC or PT_INTERP: {path.name}"
            )
        return

    if len(data) < 32 or data[:4] != b"\xcf\xfa\xed\xfe":
        raise ReleaseError(
            f"Darwin artifact is not little-endian Mach-O 64: {path.name}"
        )
    command_count, command_bytes = struct.unpack_from("<II", data, 16)
    cursor = 32
    command_end = cursor + command_bytes
    if command_end > len(data):
        raise ReleaseError(f"Darwin load commands are truncated: {path.name}")
    dynamic_libraries: list[str] = []
    build_versions: list[tuple[str, str]] = []
    for _ in range(command_count):
        if cursor + 8 > command_end:
            raise ReleaseError(f"Darwin load command is truncated: {path.name}")
        command, command_size = struct.unpack_from("<II", data, cursor)
        if command_size < 8 or cursor + command_size > command_end:
            raise ReleaseError(f"Darwin load command size is invalid: {path.name}")
        if command == 0xC:
            if command_size < 24:
                raise ReleaseError(f"Darwin dylib command is invalid: {path.name}")
            name_offset = struct.unpack_from("<I", data, cursor + 8)[0]
            if name_offset >= command_size:
                raise ReleaseError(f"Darwin dylib name offset is invalid: {path.name}")
            raw_name = data[cursor + name_offset : cursor + command_size].split(
                b"\0", 1
            )[0]
            try:
                dynamic_libraries.append(raw_name.decode("ascii"))
            except UnicodeDecodeError as error:
                raise ReleaseError(
                    f"Darwin dylib name is not ASCII: {path.name}"
                ) from error
        elif command == 0x32:
            if command_size < 24:
                raise ReleaseError(
                    f"Darwin build-version command is invalid: {path.name}"
                )
            platform_value, minimum, sdk = struct.unpack_from("<III", data, cursor + 8)
            if platform_value != 1:
                raise ReleaseError(f"Darwin build platform is not macOS: {path.name}")
            build_versions.append(
                (packed_macho_version(minimum), packed_macho_version(sdk))
            )
        cursor += command_size
    expected_libraries = ["/usr/lib/libSystem.B.dylib", "/usr/lib/libresolv.9.dylib"]
    if dynamic_libraries != expected_libraries:
        raise ReleaseError(f"Darwin dynamic library contract changed: {path.name}")
    if build_versions != [("12.0.0", "12.0.0")]:
        raise ReleaseError(f"Darwin minimum OS or SDK contract changed: {path.name}")


def verify_debug_symbol_contract(path: Path, target: dict[str, str]) -> None:
    data = path.read_bytes()
    if target["os"] == "linux":
        if len(data) < 64 or data[:6] != b"\x7fELF\x02\x01":
            raise ReleaseError(f"Linux debug-symbol metadata is invalid: {path.name}")
        section_offset = struct.unpack_from("<Q", data, 40)[0]
        section_entry_size, section_count, names_index = struct.unpack_from(
            "<HHH", data, 58
        )
        if section_count == 0 and section_offset == 0:
            return
        if (
            section_count == 0
            or section_entry_size < 64
            or names_index >= section_count
            or section_offset + section_entry_size * section_count > len(data)
        ):
            raise ReleaseError(f"Linux section metadata is invalid: {path.name}")
        names_header = section_offset + names_index * section_entry_size
        names_offset, names_size = struct.unpack_from("<QQ", data, names_header + 24)
        if names_offset + names_size > len(data):
            raise ReleaseError(f"Linux section names are invalid: {path.name}")
        names = data[names_offset : names_offset + names_size]
        forbidden = {".symtab", ".gdb_index"}
        for index in range(section_count):
            header = section_offset + index * section_entry_size
            name_offset = struct.unpack_from("<I", data, header)[0]
            if name_offset >= len(names):
                raise ReleaseError(f"Linux section name is invalid: {path.name}")
            raw_name = names[name_offset:].split(b"\0", 1)[0]
            try:
                name = raw_name.decode("ascii")
            except UnicodeDecodeError as error:
                raise ReleaseError(
                    f"Linux section name is not ASCII: {path.name}"
                ) from error
            if name in forbidden or name.startswith((".debug_", ".zdebug_")):
                raise ReleaseError(f"debug symbols are present: {path.name}")
        return

    if len(data) < 32 or data[:4] != b"\xcf\xfa\xed\xfe":
        raise ReleaseError(f"Darwin debug-symbol metadata is invalid: {path.name}")
    command_count, command_bytes = struct.unpack_from("<II", data, 16)
    cursor = 32
    command_end = cursor + command_bytes
    if command_end > len(data):
        raise ReleaseError(f"Darwin load commands are truncated: {path.name}")
    for _ in range(command_count):
        if cursor + 8 > command_end:
            raise ReleaseError(f"Darwin load command is truncated: {path.name}")
        command, command_size = struct.unpack_from("<II", data, cursor)
        if command_size < 8 or cursor + command_size > command_end:
            raise ReleaseError(f"Darwin load command size is invalid: {path.name}")
        if command == 0x19:
            if command_size < 72:
                raise ReleaseError(f"Darwin segment command is invalid: {path.name}")
            segment = data[cursor + 8 : cursor + 24].split(b"\0", 1)[0]
            section_count = struct.unpack_from("<I", data, cursor + 64)[0]
            if 72 + section_count * 80 > command_size:
                raise ReleaseError(f"Darwin section table is invalid: {path.name}")
            if segment == b"__DWARF":
                raise ReleaseError(f"debug symbols are present: {path.name}")
            for index in range(section_count):
                section_offset = cursor + 72 + index * 80
                section = data[section_offset : section_offset + 16].split(b"\0", 1)[0]
                section_segment = data[section_offset + 16 : section_offset + 32].split(
                    b"\0", 1
                )[0]
                if section_segment == b"__DWARF" or section.startswith(b"__debug_"):
                    raise ReleaseError(f"debug symbols are present: {path.name}")
        cursor += command_size


def verify_go_build_info(
    go_command: str, go_toolchain: str, binary: Path, target: dict[str, str]
) -> None:
    environment = sanitized_environment(go_toolchain)
    output = run_checked(
        [go_command, "version", "-m", str(binary)],
        cwd=ROOT,
        environment=environment,
    ).stdout
    settings: dict[str, str] = {}
    for line in output.splitlines():
        fields = line.split("\t")
        if len(fields) != 3 or fields[1] != "build" or "=" not in fields[2]:
            continue
        key, value = fields[2].split("=", 1)
        if key in settings:
            raise ReleaseError(f"unexpected Go build metadata: {binary.name}")
        settings[key] = value
    required = {
        "GOOS": target["os"],
        "GOARCH": target["arch"],
        "CGO_ENABLED": "0",
        "-trimpath": "true",
        target["architectureVariable"]: target["architectureValue"],
    }
    architecture_settings = {"GOAMD64", "GOARM64"}.intersection(settings)
    if (
        not any(line.endswith(f": {GO_VERSION}") for line in output.splitlines())
        or any(settings.get(key) != value for key, value in required.items())
        or architecture_settings != {target["architectureVariable"]}
    ):
        raise ReleaseError(f"unexpected Go build metadata: {binary.name}")


def portable_asset_report(
    portable_root: Path,
    relay_version: str,
    source_commit: str,
    source_date_epoch: str,
    bundle_budget_bytes: int,
    go_command: str,
    go_toolchain: str,
    toolchain_manifest: dict[str, Any],
) -> dict[str, Any]:
    validate_release_inputs(relay_version, source_commit)
    validate_source_date_epoch(source_date_epoch)
    if bundle_budget_bytes <= 0:
        raise ReleaseError("bundle budget must be a positive byte count")
    validate_isolated_directory(portable_root, "portable asset root", create=False)
    expected_directories = {target_directory(target) for target in TARGETS}
    actual_directories = {entry.name for entry in portable_root.iterdir()}
    if actual_directories != expected_directories:
        raise ReleaseError(
            "portable asset root must contain exactly four target directories"
        )

    target_contracts = {
        contract["goTarget"]: contract for contract in toolchain_manifest["targets"]
    }
    artifacts: list[dict[str, Any]] = []
    for target in TARGETS:
        directory = portable_root / target_directory(target)
        validate_isolated_directory(
            directory,
            f"portable target directory {target_directory(target)}",
            create=False,
        )
        filename = target_filename(target)
        entries = list(directory.iterdir())
        if len(entries) != 1 or entries[0].name != filename:
            raise ReleaseError(
                f"portable target directory is not canonical: {filename}"
            )
        binary = entries[0]
        try:
            status = binary.stat(follow_symlinks=False)
        except OSError as error:
            raise ReleaseError(
                f"portable executable is unavailable: {filename}"
            ) from error
        if (
            not stat.S_ISREG(status.st_mode)
            or status.st_size <= 0
            or status.st_mode & 0o111 == 0
        ):
            raise ReleaseError(f"portable executable is invalid: {filename}")
        verify_binary_format(binary, target)
        verify_linkage_contract(binary, target)
        verify_debug_symbol_contract(binary, target)
        verify_go_build_info(go_command, go_toolchain, binary, target)
        target_name = f"{target['os']}/{target['arch']}"
        contract = target_contracts[target_name]
        is_linux = target["os"] == "linux"
        artifacts.append(
            {
                "os": target["os"],
                "arch": target["arch"],
                "goTarget": target_name,
                "canonicalTarget": target["canonicalTarget"],
                "filename": filename,
                "binaryFormat": (
                    "ELF64 little-endian" if is_linux else "Mach-O 64-bit"
                ),
                "machineArchitecture": (
                    "x86_64" if target["arch"] == "amd64" else "arm64"
                ),
                "cpuBaseline": contract["cpuBaseline"],
                "minimumRuntime": contract["minimumRuntime"],
                "linkage": (
                    "static; no PT_INTERP or PT_DYNAMIC"
                    if is_linux
                    else "dynamic; declared system libraries only"
                ),
                "dynamicLibraries": contract["dynamicLibraries"],
                "debugSymbolDisposition": (
                    "stripped by Go linker -s -w; no DWARF sections or companion debug artifact"
                ),
                "executableMode": f"{stat.S_IMODE(status.st_mode):04o}",
                "sizeBytes": status.st_size,
                "sha256": sha256(binary),
            }
        )
    total_size = sum(artifact["sizeBytes"] for artifact in artifacts)
    report = {
        "schemaVersion": PORTABLE_REPORT_SCHEMA_VERSION,
        "relayProtocolVersion": PROTOCOL_VERSION,
        "relayVersion": relay_version,
        "sourceCommit": source_commit,
        "sourceDateEpoch": source_date_epoch,
        "buildMode": "release",
        "toolchain": {
            "go": GO_VERSION,
            "compiler": "gc",
            "linker": "Go internal linker",
            "cgoEnabled": False,
        },
        "stripPolicy": {
            "linkerFlags": ["-s", "-w"],
            "externalDebugCompanion": False,
        },
        "bundleBudgetBytes": bundle_budget_bytes,
        "totalAssetSizeBytes": total_size,
        "remainingBudgetBytes": bundle_budget_bytes - total_size,
        "withinBundleBudget": total_size <= bundle_budget_bytes,
        "artifacts": artifacts,
    }
    reject_host_paths(stable_json(report).decode("utf-8"), "portable asset report")
    return report


def portable_asset_paths(portable_root: Path) -> list[tuple[str, Path]]:
    validate_isolated_directory(portable_root, "portable asset root", create=False)
    expected_directories = {target_directory(target) for target in TARGETS}
    actual_directories = {entry.name for entry in portable_root.iterdir()}
    if actual_directories != expected_directories:
        raise ReleaseError(
            "portable asset root must contain exactly four target directories"
        )

    assets: list[tuple[str, Path]] = []
    for target in TARGETS:
        directory_name = target_directory(target)
        directory = portable_root / directory_name
        validate_isolated_directory(
            directory,
            f"portable target directory {directory_name}",
            create=False,
        )
        filename = target_filename(target)
        entries = list(directory.iterdir())
        if len(entries) != 1 or entries[0].name != filename:
            raise ReleaseError(
                f"portable target directory is not canonical: {filename}"
            )
        binary = entries[0]
        try:
            status = binary.stat(follow_symlinks=False)
        except OSError as error:
            raise ReleaseError(
                f"portable executable is unavailable: {filename}"
            ) from error
        if (
            not stat.S_ISREG(status.st_mode)
            or status.st_size <= 0
            or stat.S_IMODE(status.st_mode) != 0o755
        ):
            raise ReleaseError(f"portable executable is invalid: {filename}")
        assets.append((f"{directory_name}/{filename}", binary))
    return assets


def write_portable_asset_archive(
    portable_root: Path, archive_path: Path, source_date_epoch: str
) -> None:
    epoch = int(validate_source_date_epoch(source_date_epoch))
    assets = portable_asset_paths(portable_root)
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    if archive_path.exists() or archive_path.is_symlink():
        try:
            archive_status = archive_path.stat(follow_symlinks=False)
        except OSError as error:
            raise ReleaseError("portable archive output cannot be inspected") from error
        if not stat.S_ISREG(archive_status.st_mode):
            raise ReleaseError("portable archive output must be a regular file")

    temporary_fd, temporary_name = tempfile.mkstemp(
        dir=archive_path.parent,
        prefix=f".{archive_path.name}.",
        suffix=".tmp",
    )
    temporary = Path(temporary_name)
    temporary_status = os.fstat(temporary_fd)
    try:
        with os.fdopen(temporary_fd, "wb") as raw_stream:
            temporary_fd = -1
            with gzip.GzipFile(
                filename="", mode="wb", fileobj=raw_stream, mtime=epoch
            ) as compressed_stream:
                with tarfile.open(
                    fileobj=compressed_stream,
                    mode="w",
                    format=tarfile.USTAR_FORMAT,
                ) as bundle:
                    for member_name, binary in assets:
                        contents = binary.read_bytes()
                        member = tarfile.TarInfo(member_name)
                        member.size = len(contents)
                        member.mode = 0o755
                        member.uid = 0
                        member.gid = 0
                        member.uname = "root"
                        member.gname = "root"
                        member.mtime = epoch
                        bundle.addfile(member, io.BytesIO(contents))
        os.replace(temporary, archive_path)
        archive_status = archive_path.stat(follow_symlinks=False)
        if not stat.S_ISREG(archive_status.st_mode):
            raise ReleaseError("portable archive output must be a regular file")
    finally:
        if temporary_fd >= 0:
            os.close(temporary_fd)
        try:
            current_status = temporary.stat(follow_symlinks=False)
        except FileNotFoundError:
            pass
        else:
            if (
                stat.S_ISREG(current_status.st_mode)
                and current_status.st_dev == temporary_status.st_dev
                and current_status.st_ino == temporary_status.st_ino
            ):
                temporary.unlink()


def expected_manifest_keys() -> tuple[set[str], set[str], set[str]]:
    return (
        {
            "schemaVersion",
            "relayProtocolVersion",
            "relayVersion",
            "sourceCommit",
            "toolchain",
            "artifacts",
        },
        {"go", "cgoEnabled", "syft"},
        {
            "os",
            "arch",
            "goTarget",
            "canonicalTarget",
            "filename",
            "size",
            "sha256",
            "sbom",
            "sbomSha256",
        },
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
    if (
        schema.get("additionalProperties") is not False
        or set(schema.get("required", [])) != top_keys
    ):
        raise ReleaseError("manifest schema must reject missing and unknown fields")
    toolchain_properties = schema["properties"]["toolchain"].get("properties", {})
    artifact_schema = schema.get("$defs", {}).get("artifact", {})
    artifact_properties = artifact_schema.get("properties", {})
    if (
        set(toolchain_properties) != toolchain_keys
        or set(artifact_properties) != artifact_keys
    ):
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
    if (
        set(manifest) != top_keys
        or set(manifest.get("toolchain", {})) != toolchain_keys
    ):
        raise ReleaseError("relay manifest field set changed")
    validate_release_inputs(
        manifest.get("relayVersion", ""), manifest.get("sourceCommit", "")
    )
    if (
        manifest.get("schemaVersion") != MANIFEST_SCHEMA_VERSION
        or manifest.get("relayProtocolVersion") != PROTOCOL_VERSION
    ):
        raise ReleaseError("relay manifest version changed")
    if manifest["toolchain"] != {
        "go": GO_VERSION,
        "cgoEnabled": False,
        "syft": SYFT_VERSION,
    }:
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
        if artifact.get("sha256") != sha256(binary) or not SHA256_PATTERN.fullmatch(
            artifact["sha256"]
        ):
            raise ReleaseError(f"artifact checksum mismatch: {filename}")
        if artifact.get("sbomSha256") != sha256(sbom) or not SHA256_PATTERN.fullmatch(
            artifact["sbomSha256"]
        ):
            raise ReleaseError(f"SBOM checksum mismatch: {filename}")
        verify_spdx(sbom)
        verify_binary_format(binary, target)
        verify_linkage_contract(binary, target)
        verify_go_build_info(go_command, go_toolchain, binary, target)
    expected = build_manifest(
        manifest["relayVersion"], manifest["sourceCommit"], output
    )
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


def verify_protocol_tests(
    test_output: Path, go_command: str, go_toolchain: str
) -> None:
    expected_names: list[str] = []
    for target in TARGETS:
        name = protocol_test_filename(target)
        expected_names.append(name)
        binary = test_output / name
        verify_binary_format(binary, target)
        verify_linkage_contract(binary, target)
        verify_go_build_info(go_command, go_toolchain, binary, target)
    actual_names = sorted(path.name for path in test_output.iterdir() if path.is_file())
    if actual_names != sorted(expected_names):
        raise ReleaseError("protocol-test artifact set changed")


def validate_provisioning_archive(
    path: Path, tool: str, tool_platform: str
) -> dict[str, str]:
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
    (destination / PROVENANCE_NAME).write_bytes(
        stable_json(provenance_document(tool, tool_platform))
    )


def provision_go(arguments: argparse.Namespace) -> None:
    tool_platform = host_platform()
    archive = Path(arguments.archive).resolve()
    contract = validate_provisioning_archive(archive, "go", tool_platform)
    destination = prepare_provision_destination(archive, Path(arguments.destination))
    with tarfile.open(archive, "r:gz") as bundle:
        go_archive_tree(bundle)
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
            raise ReleaseError(
                "Syft release archive does not contain one syft executable"
            )
        stream = bundle.extractfile(matches[0])
        if stream is None:
            raise ReleaseError("Syft release executable is unreadable")
        with installed.open("wb") as output:
            shutil.copyfileobj(stream, output)
    installed.chmod(0o755)
    shutil.copyfile(archive, destination / contract["artifact"])
    write_tool_provenance(destination, "syft", tool_platform)
    verify_archive_provenance(
        destination, "syft", tool_platform, (("syft", installed),)
    )
    verify_syft_toolchain(str(installed), require_provenance=True)


def target_for_name(name: str) -> dict[str, str]:
    for target in TARGETS:
        if name == f"{target['os']}/{target['arch']}":
            return target
    raise ReleaseError(f"unsupported relay target: {name}")


def read_bounded(path: Path, maximum_bytes: int, label: str) -> bytes:
    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0)
    no_follow = getattr(os, "O_NOFOLLOW", None)
    if no_follow is None:
        raise ReleaseError(f"{label} no-follow reads are unavailable")
    try:
        descriptor = os.open(path, flags | no_follow)
        with os.fdopen(descriptor, "rb") as stream:
            if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
                raise ReleaseError(f"{label} is not a regular file")
            contents = stream.read(maximum_bytes + 1)
    except OSError as error:
        raise ReleaseError(f"{label} is unavailable") from error
    if len(contents) > maximum_bytes:
        raise ReleaseError(f"{label} exceeds its size limit")
    return contents


def load_identity_manifest(path: Path) -> dict[str, Any]:
    encoded = read_bounded(path, MAX_IDENTITY_MANIFEST_BYTES, "relay identity manifest")
    try:
        manifest = json.loads(encoded.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ReleaseError("relay identity manifest is invalid JSON") from error
    if not isinstance(manifest, dict) or encoded != stable_json(manifest):
        raise ReleaseError("relay identity manifest is not canonical JSON")

    top_keys, toolchain_keys, artifact_keys = expected_manifest_keys()
    if (
        set(manifest) != top_keys
        or not isinstance(manifest.get("toolchain"), dict)
        or set(manifest["toolchain"]) != toolchain_keys
    ):
        raise ReleaseError("relay identity manifest field set changed")
    validate_release_inputs(
        manifest.get("relayVersion", ""), manifest.get("sourceCommit", "")
    )
    if (
        manifest.get("schemaVersion") != MANIFEST_SCHEMA_VERSION
        or manifest.get("relayProtocolVersion") != PROTOCOL_VERSION
        or manifest["toolchain"]
        != {"go": GO_VERSION, "cgoEnabled": False, "syft": SYFT_VERSION}
    ):
        raise ReleaseError("relay identity manifest contract changed")

    artifacts = manifest.get("artifacts")
    if not isinstance(artifacts, list) or len(artifacts) != len(TARGETS):
        raise ReleaseError("relay identity manifest target matrix changed")
    for artifact in artifacts:
        if not isinstance(artifact, dict) or set(artifact) != artifact_keys:
            raise ReleaseError("relay identity manifest artifact field set changed")
    return manifest


def verify_identity_against_manifest(
    identity_output: bytes,
    manifest_path: Path,
    executable: Path,
    target_name: str,
) -> None:
    if (
        not identity_output
        or len(identity_output) > MAX_IDENTITY_BYTES
        or not identity_output.endswith(b"\n")
        or identity_output.count(b"\n") != 1
    ):
        raise ReleaseError("relay identity output framing mismatch")
    try:
        identity = json.loads(identity_output.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ReleaseError("relay identity output is invalid JSON") from error
    identity_keys = {
        "schemaVersion",
        "relayProtocolVersion",
        "relayVersion",
        "sourceCommit",
        "os",
        "arch",
        "selfSha256",
    }
    if not isinstance(identity, dict) or set(identity) != identity_keys:
        raise ReleaseError("relay identity output field set changed")

    manifest = load_identity_manifest(manifest_path)
    target = target_for_name(target_name)
    target_index = TARGETS.index(target)
    artifact = manifest["artifacts"][target_index]
    filename = target_filename(target)
    expected_target = {
        "os": target["os"],
        "arch": target["arch"],
        "goTarget": target_name,
        "canonicalTarget": target["canonicalTarget"],
        "filename": filename,
        "sbom": f"{filename}.spdx.json",
    }
    if any(artifact.get(key) != value for key, value in expected_target.items()):
        raise ReleaseError("relay identity manifest target mismatch")
    if (
        type(artifact.get("size")) is not int
        or artifact["size"] <= 0
        or not isinstance(artifact.get("sha256"), str)
        or not SHA256_PATTERN.fullmatch(artifact["sha256"])
    ):
        raise ReleaseError("relay identity manifest artifact metadata mismatch")

    flags = os.O_RDONLY | getattr(os, "O_CLOEXEC", 0)
    no_follow = getattr(os, "O_NOFOLLOW", None)
    if no_follow is None:
        raise ReleaseError("relay identity executable no-follow reads are unavailable")
    try:
        descriptor = os.open(executable, flags | no_follow)
        with os.fdopen(descriptor, "rb") as stream:
            executable_status = os.fstat(stream.fileno())
            if not stat.S_ISREG(executable_status.st_mode):
                raise ReleaseError("relay identity executable is not a regular file")
            digest = hashlib.sha256()
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as error:
        raise ReleaseError("relay identity executable is unavailable") from error
    if executable_status.st_size != artifact["size"]:
        raise ReleaseError("relay identity executable size mismatch")
    if digest.hexdigest() != artifact["sha256"]:
        raise ReleaseError("relay identity executable checksum mismatch")

    expected_identity = {
        "schemaVersion": MANIFEST_SCHEMA_VERSION,
        "relayProtocolVersion": PROTOCOL_VERSION,
        "relayVersion": manifest["relayVersion"],
        "sourceCommit": manifest["sourceCommit"],
        "os": target["os"],
        "arch": target["arch"],
        "selfSha256": artifact["sha256"],
    }
    canonical_identity = (
        json.dumps(expected_identity, ensure_ascii=True, separators=(",", ":")) + "\n"
    ).encode("ascii")
    if identity_output != canonical_identity:
        raise ReleaseError("relay identity output mismatch")


def verify_identity(arguments: argparse.Namespace) -> None:
    identity_output = read_bounded(
        Path(arguments.identity_output), MAX_IDENTITY_BYTES, "relay identity output"
    )
    verify_identity_against_manifest(
        identity_output,
        Path(arguments.manifest),
        Path(arguments.executable),
        arguments.target,
    )


def prepare_build_sandbox(path: Path, cache_mode: str) -> Path:
    sandbox = validate_output_path(path)
    if cache_mode == "clean":
        validate_isolated_directory(sandbox, "build sandbox root", create=False)
        clean_directory(sandbox)
        validate_isolated_directory(sandbox, "build sandbox root", create=False)
    elif cache_mode == "incremental":
        validate_isolated_directory(sandbox, "build sandbox root", create=True)
    else:
        raise ReleaseError("cache mode must be clean or incremental")
    return sandbox


def build_portable_target(arguments: argparse.Namespace) -> None:
    arguments.go = resolve_tool_command(arguments.go)
    validate_release_inputs(arguments.relay_version, arguments.source_commit)
    source_date_epoch = validate_source_date_epoch(arguments.source_date_epoch)
    verify_checkout_revision(arguments.source_commit)
    if arguments.require_clean:
        verify_clean_checkout(arguments.source_commit)
    verify_toolchain_manifest()
    verify_go_module_policy()
    verify_go_toolchain(arguments.go, arguments.go_toolchain, require_provenance=True)
    target = target_for_name(arguments.target)
    output = validate_output_path(Path(arguments.output))
    if output.name != target_filename(target):
        raise ReleaseError("portable target output name is not canonical")
    sandbox = prepare_build_sandbox(Path(arguments.work_dir), arguments.cache_mode)
    if output == sandbox or output in sandbox.parents or sandbox in output.parents:
        raise ReleaseError("portable output and build sandbox must be separate")
    if arguments.cache_mode == "clean":
        clean_directory(output.parent)
    else:
        output.parent.mkdir(parents=True, exist_ok=True)
    build_binary(
        arguments.go,
        arguments.go_toolchain,
        target,
        "./cmd/relux-relay",
        output,
        arguments.relay_version,
        arguments.source_commit,
        sandbox=sandbox,
        source_date_epoch=source_date_epoch,
    )
    verify_binary_format(output, target)
    verify_linkage_contract(output, target)
    verify_go_build_info(arguments.go, arguments.go_toolchain, output, target)


def inspect_portable_assets(arguments: argparse.Namespace) -> None:
    arguments.go = resolve_tool_command(arguments.go)
    validate_release_inputs(arguments.relay_version, arguments.source_commit)
    source_date_epoch = validate_source_date_epoch(arguments.source_date_epoch)
    verify_checkout_revision(arguments.source_commit)
    if arguments.require_clean:
        verify_clean_checkout(arguments.source_commit)
    toolchain_manifest = verify_toolchain_manifest()
    verify_go_module_policy()
    verify_go_toolchain(arguments.go, arguments.go_toolchain, require_provenance=True)
    portable_root = validate_output_path(Path(arguments.portable_root))
    report_path = validate_output_path(Path(arguments.report))
    if portable_root == report_path or portable_root in report_path.parents:
        raise ReleaseError("portable report must remain outside the four-asset root")
    report = portable_asset_report(
        portable_root,
        arguments.relay_version,
        arguments.source_commit,
        source_date_epoch,
        arguments.bundle_budget_bytes,
        arguments.go,
        arguments.go_toolchain,
        toolchain_manifest,
    )
    report_path.parent.mkdir(parents=True, exist_ok=True)
    if report_path.exists() or report_path.is_symlink():
        try:
            report_status = report_path.stat(follow_symlinks=False)
        except OSError as error:
            raise ReleaseError("portable report output cannot be inspected") from error
        if not stat.S_ISREG(report_status.st_mode):
            raise ReleaseError("portable report output must be a regular file")
    report_path.write_bytes(stable_json(report))
    if not report["withinBundleBudget"]:
        overage = -report["remainingBudgetBytes"]
        raise ReleaseError(f"portable assets exceed bundle budget by {overage} bytes")


def archive_portable_assets(arguments: argparse.Namespace) -> None:
    portable_root = validate_output_path(Path(arguments.portable_root))
    archive_path = validate_output_path(Path(arguments.archive))
    if portable_root == archive_path or portable_root in archive_path.parents:
        raise ReleaseError("portable archive must remain outside the four-asset root")
    write_portable_asset_archive(
        portable_root, archive_path, arguments.source_date_epoch
    )


def extract_toolchain_licenses(arguments: argparse.Namespace) -> None:
    arguments.go = resolve_tool_command(arguments.go)
    verify_toolchain_manifest()
    go_root = verify_go_toolchain(
        arguments.go, arguments.go_toolchain, require_provenance=True
    )
    output = validate_output_path(Path(arguments.output))
    clean_directory(output)
    write_notice(output, go_root)
    verify_notice(output, go_root)


def check_toolchain(_: argparse.Namespace) -> None:
    verify_go_module_policy()
    verify_toolchain_manifest()


def build_release(arguments: argparse.Namespace) -> None:
    arguments.go = resolve_tool_command(arguments.go)
    arguments.syft = resolve_tool_command(arguments.syft)
    validate_release_inputs(arguments.relay_version, arguments.source_commit)
    source_date_epoch = validate_source_date_epoch(arguments.source_date_epoch)
    verify_checkout_revision(arguments.source_commit)
    if arguments.require_clean:
        verify_clean_checkout(arguments.source_commit)
    output = validate_output_path(Path(arguments.output))
    test_output = validate_output_path(Path(arguments.test_output))
    if output == test_output:
        raise ReleaseError("release and protocol-test outputs must be separate")
    require_provenance = arguments.require_provenance or arguments.require_clean
    go_root = verify_go_toolchain(
        arguments.go, arguments.go_toolchain, require_provenance
    )
    verify_syft_toolchain(arguments.syft, require_provenance)
    verify_go_module_policy()
    verify_toolchain_manifest()
    verify_manifest_schema()
    clean_directory(output)
    clean_directory(test_output)
    for target in TARGETS:
        target_work = prepare_build_sandbox(
            BUILD_ROOT / "work" / "release" / f"{target['os']}-{target['arch']}",
            "clean",
        )
        build_binary(
            arguments.go,
            arguments.go_toolchain,
            target,
            "./cmd/relux-relay",
            output / target_filename(target),
            arguments.relay_version,
            arguments.source_commit,
            sandbox=target_work / "relay",
            source_date_epoch=source_date_epoch,
        )
        build_binary(
            arguments.go,
            arguments.go_toolchain,
            target,
            "./cmd/relux-relay-protocol-test",
            test_output / protocol_test_filename(target),
            arguments.relay_version,
            arguments.source_commit,
            sandbox=target_work / "protocol-test",
            source_date_epoch=source_date_epoch,
        )
    for target in TARGETS:
        filename = target_filename(target)
        generate_sbom(
            arguments.syft, output / filename, output / f"{filename}.spdx.json"
        )
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
    go_root = verify_go_toolchain(
        arguments.go, arguments.go_toolchain, arguments.require_provenance
    )
    verify_go_module_policy()
    verify_toolchain_manifest()
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

    build = subparsers.add_parser(
        "build", help="build and verify all target-shell artifacts"
    )
    build.add_argument("--output", required=True)
    build.add_argument("--test-output", required=True)
    build.add_argument("--relay-version", required=True)
    build.add_argument("--source-commit", required=True)
    build.add_argument("--source-date-epoch", default="")
    build.add_argument("--syft", required=True)
    build.add_argument("--require-clean", action="store_true")
    build.add_argument("--require-provenance", action="store_true")
    add_toolchain_options(build)
    build.set_defaults(action=build_release)

    verify = subparsers.add_parser(
        "verify", help="verify an existing target-shell artifact matrix"
    )
    verify.add_argument("--output", required=True)
    verify.add_argument("--test-output", required=True)
    verify.add_argument("--require-provenance", action="store_true")
    add_toolchain_options(verify)
    verify.set_defaults(action=verify_release)

    compare = subparsers.add_parser(
        "compare", help="compare reproducible executable bytes"
    )
    compare.add_argument("--first", required=True)
    compare.add_argument("--second", required=True)
    compare.add_argument("--first-tests", required=True)
    compare.add_argument("--second-tests", required=True)
    compare.set_defaults(action=compare_release)

    identity = subparsers.add_parser(
        "verify-identity",
        help="verify canonical relay identity against one manifest-selected artifact",
    )
    identity.add_argument(
        "--target",
        required=True,
        choices=[f"{target['os']}/{target['arch']}" for target in TARGETS],
    )
    identity.add_argument("--manifest", required=True)
    identity.add_argument("--executable", required=True)
    identity.add_argument("--identity-output", required=True)
    identity.set_defaults(action=verify_identity)

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

    build_target = subparsers.add_parser(
        "build-target",
        help="build one portable relay target from pinned offline inputs",
    )
    build_target.add_argument(
        "--target",
        required=True,
        choices=[f"{target['os']}/{target['arch']}" for target in TARGETS],
    )
    build_target.add_argument("--output", required=True)
    build_target.add_argument("--work-dir", required=True)
    build_target.add_argument("--relay-version", required=True)
    build_target.add_argument("--source-commit", required=True)
    build_target.add_argument("--source-date-epoch", default="")
    build_target.add_argument(
        "--cache-mode", choices=("clean", "incremental"), default="clean"
    )
    build_target.add_argument("--require-clean", action="store_true")
    add_toolchain_options(build_target)
    build_target.set_defaults(action=build_portable_target)

    inspect_assets = subparsers.add_parser(
        "inspect-assets",
        help="inspect exactly four portable relay assets and write a budget report",
    )
    inspect_assets.add_argument("--portable-root", required=True)
    inspect_assets.add_argument("--report", required=True)
    inspect_assets.add_argument("--relay-version", required=True)
    inspect_assets.add_argument("--source-commit", required=True)
    inspect_assets.add_argument("--source-date-epoch", required=True)
    inspect_assets.add_argument("--bundle-budget-bytes", required=True, type=int)
    inspect_assets.add_argument("--require-clean", action="store_true")
    add_toolchain_options(inspect_assets)
    inspect_assets.set_defaults(action=inspect_portable_assets)

    archive_assets = subparsers.add_parser(
        "archive-assets",
        help="write a deterministic four-member portable relay archive",
    )
    archive_assets.add_argument("--portable-root", required=True)
    archive_assets.add_argument("--archive", required=True)
    archive_assets.add_argument("--source-date-epoch", required=True)
    archive_assets.set_defaults(action=archive_portable_assets)

    licenses = subparsers.add_parser(
        "extract-licenses",
        help="extract the checksum-pinned project and Go license notice",
    )
    licenses.add_argument("--output", required=True)
    add_toolchain_options(licenses)
    licenses.set_defaults(action=extract_toolchain_licenses)

    toolchain_check = subparsers.add_parser(
        "toolchain-check",
        help="verify checked-in toolchain, target, dependency, and license pins",
    )
    toolchain_check.set_defaults(action=check_toolchain)
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
