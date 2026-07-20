#!/usr/bin/env python3
"""Rebuild and verify Relux Apple native dependency artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


REPOSITORY_ROOT = Path(
    os.environ.get(
        "RELUX_NATIVE_REPOSITORY_ROOT",
        str(Path(__file__).resolve().parent.parent),
    )
).resolve()
MANIFEST_PATH = REPOSITORY_ROOT / "NativeDependencies" / "manifest.json"
UNSAFE_LOAD_COMMANDS = {
    "LC_LOAD_DYLIB",
    "LC_LOAD_WEAK_DYLIB",
    "LC_REEXPORT_DYLIB",
    "LC_LOAD_UPWARD_DYLIB",
    "LC_RPATH",
}
UNSAFE_DYNAMIC_SYMBOLS = {
    "_NSAddImage",
    "_NSCreateObjectFileImageFromFile",
    "_dladdr",
    "_dlclose",
    "_dlopen",
    "_dlsym",
}
ABSOLUTE_BUILD_PATH = re.compile(rb"/(?:Users|private/(?:tmp|var)|tmp)/[^\x00\n ]+")


class NativeDependencyError(RuntimeError):
    pass


def load_manifest() -> dict[str, Any]:
    with MANIFEST_PATH.open("rb") as stream:
        manifest = json.load(stream)
    if manifest.get("schema_version") != 1:
        raise NativeDependencyError("unsupported native dependency manifest schema")
    if manifest.get("cache_policy", {}).get("runtime_downloads_allowed") is not False:
        raise NativeDependencyError("native dependency runtime downloads must be disabled")
    return manifest


def dependency(manifest: dict[str, Any], name: str) -> dict[str, Any]:
    try:
        return manifest["dependencies"][name]
    except KeyError as error:
        raise NativeDependencyError(f"unknown dependency: {name}") from error


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def repository_files_hash(files: list[str]) -> str:
    digest = hashlib.sha256()
    for relative in sorted(files):
        path = REPOSITORY_ROOT / relative
        if not path.is_file():
            raise NativeDependencyError(f"missing pinned source file: {relative}")
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def artifact_hashes(path: Path) -> dict[str, str]:
    if not path.is_dir():
        raise NativeDependencyError(f"missing XCFramework: {path}")
    return {
        str(file.relative_to(path)): sha256_file(file)
        for file in sorted(path.rglob("*"))
        if file.is_file()
    }


def run(
    command: list[str],
    *,
    cwd: Path | None = None,
    capture: bool = False,
    environment: dict[str, str] | None = None,
) -> str:
    merged_environment = os.environ.copy()
    if environment:
        merged_environment.update(environment)
    result = subprocess.run(
        command,
        cwd=cwd,
        env=merged_environment,
        check=False,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.STDOUT if capture else None,
        text=True,
    )
    if result.returncode != 0:
        output = result.stdout.strip() if result.stdout else ""
        suffix = f"\n{output}" if output else ""
        raise NativeDependencyError(f"command failed: {' '.join(command)}{suffix}")
    return result.stdout if capture and result.stdout else ""


def verify_fixture_source(item: dict[str, Any]) -> None:
    source = item["source"]
    actual = repository_files_hash(source["files"])
    if actual != source["sha256"]:
        raise NativeDependencyError(
            f"relux-native-fixture source checksum mismatch: expected "
            f"{source['sha256']}, got {actual}"
        )


def git_value(source_dir: Path, arguments: list[str]) -> str:
    return run(["git", *arguments], cwd=source_dir, capture=True).strip()


def git_archive_sha256(source_dir: Path, revision: str) -> str:
    result = subprocess.run(
        ["git", "archive", "--format=tar", revision],
        cwd=source_dir,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        raise NativeDependencyError(
            f"git archive failed in {source_dir}: {result.stderr.decode().strip()}"
        )
    return sha256_bytes(result.stdout)


def verify_hev_source(item: dict[str, Any], source_dir: Path) -> None:
    source_dir = source_dir.resolve()
    if not (source_dir / ".git").exists():
        raise NativeDependencyError(f"HEV source is not a git checkout: {source_dir}")

    revision = item["revision"]
    actual_revision = git_value(source_dir, ["rev-parse", "HEAD"])
    if actual_revision != revision:
        raise NativeDependencyError(
            f"HEV revision mismatch: expected {revision}, got {actual_revision}"
        )
    dirty_paths = git_value(source_dir, ["status", "--porcelain", "--untracked-files=all"])
    if dirty_paths:
        raise NativeDependencyError(f"HEV checkout is dirty:\n{dirty_paths}")
    actual_archive = git_archive_sha256(source_dir, revision)
    if actual_archive != item["source"]["sha256"]:
        raise NativeDependencyError(
            f"HEV source archive mismatch: expected {item['source']['sha256']}, "
            f"got {actual_archive}"
        )

    for submodule in item["source"]["submodules"]:
        submodule_dir = source_dir / submodule["path"]
        actual_revision = git_value(submodule_dir, ["rev-parse", "HEAD"])
        if actual_revision != submodule["revision"]:
            raise NativeDependencyError(
                f"HEV submodule revision mismatch at {submodule['path']}: expected "
                f"{submodule['revision']}, got {actual_revision}"
            )
        dirty_paths = git_value(
            submodule_dir,
            ["status", "--porcelain", "--untracked-files=all"],
        )
        if dirty_paths:
            raise NativeDependencyError(
                f"HEV submodule checkout is dirty at {submodule['path']}:\n{dirty_paths}"
            )
        actual_archive = git_archive_sha256(submodule_dir, submodule["revision"])
        if actual_archive != submodule["sha256"]:
            raise NativeDependencyError(
                f"HEV submodule archive mismatch at {submodule['path']}: expected "
                f"{submodule['sha256']}, got {actual_archive}"
            )


def expected_slices(item: dict[str, Any]) -> list[dict[str, Any]]:
    compiler = item["compiler"]
    return compiler.get("slices", compiler.get("required_slices", []))


def normalize_xcframework_plist(path: Path) -> None:
    info_path = path / "Info.plist"
    with info_path.open("rb") as stream:
        info = plistlib.load(stream)
    info["AvailableLibraries"] = sorted(
        info.get("AvailableLibraries", []),
        key=lambda library: library["LibraryIdentifier"],
    )
    with info_path.open("wb") as stream:
        plistlib.dump(info, stream, fmt=plistlib.FMT_XML, sort_keys=True)


def inspect_xcframework(item: dict[str, Any], path: Path, *, verify_lock: bool) -> None:
    path = path.resolve()
    info_path = path / "Info.plist"
    if not info_path.is_file():
        raise NativeDependencyError(f"missing XCFramework Info.plist: {info_path}")
    with info_path.open("rb") as stream:
        info = plistlib.load(stream)

    libraries = {
        library["LibraryIdentifier"]: library
        for library in info.get("AvailableLibraries", [])
    }
    expected = {slice_["library_identifier"]: slice_ for slice_ in expected_slices(item)}
    missing = sorted(set(expected) - set(libraries))
    if missing:
        raise NativeDependencyError(f"missing required XCFramework slices: {missing}")

    for identifier, slice_ in expected.items():
        library = libraries[identifier]
        if library.get("SupportedPlatform") != slice_["platform"]:
            raise NativeDependencyError(f"wrong platform for {identifier}")
        if library.get("SupportedPlatformVariant") != slice_.get("variant"):
            raise NativeDependencyError(f"wrong platform variant for {identifier}")
        actual_architectures = sorted(library.get("SupportedArchitectures", []))
        required_architectures = sorted(slice_["architectures"])
        if actual_architectures != required_architectures:
            raise NativeDependencyError(
                f"architecture mismatch for {identifier}: expected "
                f"{required_architectures}, got {actual_architectures}"
            )

        library_path = path / identifier / library["LibraryPath"]
        if not library_path.is_file():
            raise NativeDependencyError(f"missing static library: {library_path}")
        file_description = run(["file", str(library_path)], capture=True)
        if "ar archive" not in file_description:
            raise NativeDependencyError(
                f"native dependency is not a static archive: {file_description.strip()}"
            )
        architectures = sorted(run(["lipo", "-archs", str(library_path)], capture=True).split())
        if architectures != required_architectures:
            raise NativeDependencyError(
                f"archive architecture mismatch for {identifier}: expected "
                f"{required_architectures}, got {architectures}"
            )

        load_commands = run(["otool", "-l", str(library_path)], capture=True)
        present_load_commands = {
            line.strip().split(maxsplit=1)[1]
            for line in load_commands.splitlines()
            if line.strip().startswith("cmd ")
        }
        disallowed_load_commands = sorted(present_load_commands & UNSAFE_LOAD_COMMANDS)
        if disallowed_load_commands:
            raise NativeDependencyError(
                f"extension-unsafe load commands in {identifier}: {disallowed_load_commands}"
            )

        undefined_symbols = run(["nm", "-u", str(library_path)], capture=True)
        disallowed_symbols = sorted(
            symbol for symbol in UNSAFE_DYNAMIC_SYMBOLS if symbol in undefined_symbols.split()
        )
        if disallowed_symbols:
            raise NativeDependencyError(
                f"dynamic loading symbols in {identifier}: {disallowed_symbols}"
            )

        headers_path = library.get("HeadersPath")
        if headers_path:
            headers = path / identifier / headers_path
            module_maps = list(headers.rglob("module.modulemap"))
            if len(module_maps) != 1:
                raise NativeDependencyError(f"missing module map for {identifier}")

    for file in path.rglob("*"):
        if not file.is_file():
            continue
        match = ABSOLUTE_BUILD_PATH.search(file.read_bytes())
        if match:
            raise NativeDependencyError(
                f"absolute build path in {file.relative_to(path)}: "
                f"{match.group(0).decode(errors='replace')}"
            )

    if verify_lock:
        expected_hashes = item.get("artifact", {}).get("file_sha256", {})
        if not expected_hashes:
            raise NativeDependencyError("artifact hash lock is empty")
        actual_hashes = artifact_hashes(path)
        if actual_hashes != expected_hashes:
            raise NativeDependencyError("XCFramework file hashes do not match manifest lock")


def inspect_linked_binary(path: Path, required_architectures: list[str]) -> None:
    path = path.resolve()
    if not path.is_file():
        raise NativeDependencyError(f"missing linked binary: {path}")
    file_description = run(["file", str(path)], capture=True)
    if "Mach-O" not in file_description:
        raise NativeDependencyError(f"linked product is not Mach-O: {file_description.strip()}")

    architectures = sorted(run(["lipo", "-archs", str(path)], capture=True).split())
    if architectures != sorted(required_architectures):
        raise NativeDependencyError(
            f"linked binary architecture mismatch: expected {sorted(required_architectures)}, "
            f"got {architectures}"
        )

    dependencies = []
    for line in run(["otool", "-L", str(path)], capture=True).splitlines()[1:]:
        candidate = line.strip().split(" (", maxsplit=1)[0]
        if candidate and candidate.rstrip(":") != str(path):
            dependencies.append(candidate)
    allowed_prefixes = ("/usr/lib/", "/System/Library/Frameworks/")
    disallowed = sorted(
        candidate for candidate in dependencies if not candidate.startswith(allowed_prefixes)
    )
    if disallowed:
        raise NativeDependencyError(f"disallowed linked dynamic dependencies: {disallowed}")

    undefined_symbols = run(["nm", "-u", str(path)], capture=True)
    disallowed_symbols = sorted(
        symbol for symbol in UNSAFE_DYNAMIC_SYMBOLS if symbol in undefined_symbols.split()
    )
    if disallowed_symbols:
        raise NativeDependencyError(f"dynamic loading symbols in linked binary: {disallowed_symbols}")

    match = ABSOLUTE_BUILD_PATH.search(path.read_bytes())
    if match:
        raise NativeDependencyError(
            f"absolute build path in linked binary: {match.group(0).decode(errors='replace')}"
        )


def compile_fixture_architecture(
    item: dict[str, Any],
    source: Path,
    include: Path,
    sdk: str,
    triple: str,
    output: Path,
) -> None:
    sdk_path = run(["xcrun", "--sdk", sdk, "--show-sdk-path"], capture=True).strip()
    command = [
        "xcrun",
        "--sdk",
        sdk,
        "clang",
        "-c",
        str(source),
        "-o",
        str(output),
        "-target",
        triple,
        "-isysroot",
        sdk_path,
        "-I",
        str(include),
        *item["compiler"]["common_c_flags"],
    ]
    run(command)


def build_fixture(item: dict[str, Any], output: Path) -> None:
    verify_fixture_source(item)
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    fixture = REPOSITORY_ROOT / "NativeDependencies" / "Fixtures" / "ReluxNativeFixture"
    source = fixture / "Sources" / "relux_native_fixture.c"
    include = fixture / "include"

    with tempfile.TemporaryDirectory(prefix="relux-native-fixture-") as temporary:
        work = Path(temporary)
        xcframework_arguments: list[str] = []
        for slice_ in item["compiler"]["slices"]:
            slice_dir = work / slice_["library_identifier"]
            slice_dir.mkdir()
            architecture_archives: list[Path] = []
            for architecture, triple in zip(
                slice_["architectures"], slice_["target_triples"], strict=True
            ):
                object_path = slice_dir / f"relux_native_fixture-{architecture}.o"
                archive_path = slice_dir / f"libCReluxNativeFixture-{architecture}.a"
                compile_fixture_architecture(
                    item,
                    source,
                    include,
                    slice_["sdk"],
                    triple,
                    object_path,
                )
                run(
                    [
                        "xcrun",
                        "--sdk",
                        slice_["sdk"],
                        "libtool",
                        "-static",
                        "-o",
                        str(archive_path),
                        str(object_path),
                    ],
                    environment={"ZERO_AR_DATE": "1"},
                )
                architecture_archives.append(archive_path)

            universal_archive = slice_dir / "libCReluxNativeFixture.a"
            if len(architecture_archives) == 1:
                shutil.copy2(architecture_archives[0], universal_archive)
            else:
                run(
                    [
                        "xcrun",
                        "lipo",
                        "-create",
                        *map(str, architecture_archives),
                        "-output",
                        str(universal_archive),
                    ]
                )
            xcframework_arguments.extend(
                ["-library", str(universal_archive), "-headers", str(include)]
            )

        candidate = work / "ReluxNativeFixture.xcframework"
        run(
            [
                "xcodebuild",
                "-create-xcframework",
                *xcframework_arguments,
                "-output",
                str(candidate),
            ]
        )
        normalize_xcframework_plist(candidate)
        inspect_xcframework(item, candidate, verify_lock=False)
        if output.exists():
            shutil.rmtree(output)
        shutil.copytree(candidate, output, copy_function=shutil.copy2)


def write_notices(item: dict[str, Any], source_root: Path, output: Path) -> None:
    license_data = item["license"]
    components = license_data.get("components")
    if components is None:
        components = [
            {
                "name": "relux-native-fixture",
                "revision": item["revision"],
                "spdx": license_data["spdx"],
                "path": path,
            }
            for path in license_data["files"]
        ]

    sections = [
        "ReluxTunnel third-party notices",
        "Generated from NativeDependencies/manifest.json and verified pinned sources.",
    ]
    for component in components:
        license_path = source_root / component["path"]
        if not license_path.is_file():
            raise NativeDependencyError(f"missing license input: {license_path}")
        revision = component.get("revision", item.get("revision", "unspecified"))
        sections.extend(
            [
                "",
                "=" * 72,
                f"{component['name']} @ {revision}",
                f"SPDX-License-Identifier: {component['spdx']}",
                f"Source license: {component['path']}",
                "=" * 72,
                license_path.read_text(encoding="utf-8").rstrip(),
            ]
        )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(sections) + "\n", encoding="utf-8")


def build_hev(item: dict[str, Any], source_dir: Path, output: Path, notices: Path) -> None:
    verify_hev_source(item, source_dir)
    write_notices(item, source_dir, notices)
    run(["./build-apple.sh"], cwd=source_dir)
    candidate = source_dir / "HevSocks5Tunnel.xcframework"
    normalize_xcframework_plist(candidate)
    inspect_xcframework(item, candidate, verify_lock=False)
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        shutil.rmtree(output)
    shutil.copytree(candidate, output, copy_function=shutil.copy2)


def verify_dependency(
    manifest: dict[str, Any], name: str, source_dir: Path | None
) -> None:
    item = dependency(manifest, name)
    integration = item["integration"]
    if integration["linkage"] != "static":
        raise NativeDependencyError(f"{name} is not pinned to static linkage")
    if integration["application_extension_api_only"] is not True:
        raise NativeDependencyError(f"{name} is not marked extension-safe")

    if name == "relux-native-fixture":
        verify_fixture_source(item)
        inspect_xcframework(
            item,
            REPOSITORY_ROOT / integration["artifact_path"],
            verify_lock=True,
        )
    elif name == "hev-lwip":
        if source_dir is None:
            raise NativeDependencyError("--source-dir is required to verify hev-lwip")
        verify_hev_source(item, source_dir)
    else:
        raise NativeDependencyError(f"no verifier implemented for {name}")


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    subparsers = result.add_subparsers(dest="command", required=True)

    source_hash = subparsers.add_parser("source-hash")
    source_hash.add_argument("--dependency", required=True)

    artifact_lock = subparsers.add_parser("artifact-lock")
    artifact_lock.add_argument("--dependency", required=True)
    artifact_lock.add_argument("--xcframework", type=Path)

    verify = subparsers.add_parser("verify")
    verify.add_argument("--dependency", required=True)
    verify.add_argument("--source-dir", type=Path)

    inspect = subparsers.add_parser("inspect")
    inspect.add_argument("--dependency", required=True)
    inspect.add_argument("--xcframework", type=Path, required=True)
    inspect.add_argument("--verify-lock", action="store_true")

    linked = subparsers.add_parser("inspect-linked")
    linked.add_argument("--binary", type=Path, required=True)
    linked.add_argument("--architectures", nargs="+", required=True)

    fixture = subparsers.add_parser("build-fixture")
    fixture.add_argument("--output", type=Path, required=True)

    notices = subparsers.add_parser("notices")
    notices.add_argument("--dependency", required=True)
    notices.add_argument("--source-dir", type=Path)
    notices.add_argument("--output", type=Path, required=True)

    hev = subparsers.add_parser("build-hev")
    hev.add_argument("--source-dir", type=Path, required=True)
    hev.add_argument("--output", type=Path, required=True)
    hev.add_argument("--notices", type=Path, required=True)
    return result


def main() -> int:
    arguments = parser().parse_args()
    manifest = load_manifest()
    selected_dependency = getattr(arguments, "dependency", None)
    if selected_dependency is None:
        selected_dependency = (
            "relux-native-fixture" if arguments.command == "build-fixture" else "hev-lwip"
        )
    item = dependency(manifest, selected_dependency)

    if arguments.command == "source-hash":
        source = item["source"]
        if source["kind"] != "repository_files":
            raise NativeDependencyError("source-hash supports repository_files dependencies")
        print(repository_files_hash(source["files"]))
    elif arguments.command == "artifact-lock":
        path = arguments.xcframework or REPOSITORY_ROOT / item["integration"]["artifact_path"]
        print(json.dumps(artifact_hashes(path), indent=2, sort_keys=True))
    elif arguments.command == "verify":
        verify_dependency(manifest, arguments.dependency, arguments.source_dir)
        print(f"{arguments.dependency} source and packaging inputs are verified")
    elif arguments.command == "inspect":
        inspect_xcframework(item, arguments.xcframework, verify_lock=arguments.verify_lock)
        print(f"{arguments.dependency} XCFramework is static and extension-safe")
    elif arguments.command == "inspect-linked":
        inspect_linked_binary(arguments.binary, arguments.architectures)
        print(f"{arguments.binary} linked dependencies and architectures are valid")
    elif arguments.command == "build-fixture":
        build_fixture(item, arguments.output)
        print(f"rebuilt relux-native-fixture at {arguments.output}")
    elif arguments.command == "notices":
        source_root = arguments.source_dir or REPOSITORY_ROOT
        write_notices(item, source_root, arguments.output)
        print(f"wrote notices to {arguments.output}")
    elif arguments.command == "build-hev":
        build_hev(item, arguments.source_dir, arguments.output, arguments.notices)
        print(f"rebuilt pinned HEV XCFramework at {arguments.output}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except NativeDependencyError as error:
        print(f"native-dependency-tool: {error}", file=sys.stderr)
        raise SystemExit(1)
