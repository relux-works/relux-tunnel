#!/usr/bin/env python3
"""Verify and compare the pinned ReluxNIOSSH source fork."""

from __future__ import annotations

import argparse
import difflib
import hashlib
import json
from pathlib import Path
import sys
import tarfile
import tempfile
import urllib.request


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
FORK_ROOT = REPOSITORY_ROOT / "Dependencies" / "ReluxNIOSSH"
MANIFEST_PATH = FORK_ROOT / "PATCH_MANIFEST.json"
IGNORED_COMPONENTS = {".build", ".swiftpm"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_manifest() -> dict:
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


def download_archive(source_ref: str, destination: Path) -> None:
    url = f"https://github.com/apple/swift-nio-ssh/archive/{source_ref}.tar.gz"
    with urllib.request.urlopen(url) as response, destination.open("wb") as output:
        while chunk := response.read(1024 * 1024):
            output.write(chunk)


def extract_archive(archive: Path, destination: Path) -> Path:
    with tarfile.open(archive, "r:gz") as bundle:
        roots = {Path(member.name).parts[0] for member in bundle.getmembers() if member.name}
        if len(roots) != 1:
            raise RuntimeError("upstream archive does not have exactly one root")
        bundle.extractall(destination, filter="data")
    return destination / roots.pop()


def source_files(root: Path) -> dict[str, Path]:
    result: dict[str, Path] = {}
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        relative = path.relative_to(root)
        if any(component in IGNORED_COMPONENTS for component in relative.parts):
            continue
        result[relative.as_posix()] = path
    return result


def changed_files(upstream: Path, fork: Path) -> list[str]:
    upstream_files = source_files(upstream)
    fork_files = source_files(fork)
    changed: list[str] = []
    for relative in sorted(upstream_files.keys() | fork_files.keys()):
        before = upstream_files.get(relative)
        after = fork_files.get(relative)
        if before is None or after is None or before.read_bytes() != after.read_bytes():
            changed.append(relative)
    return changed


def with_upstream(source_ref: str):
    temporary = tempfile.TemporaryDirectory(prefix="reluxniossh-")
    temporary_root = Path(temporary.name)
    archive = temporary_root / "upstream.tar.gz"
    download_archive(source_ref, archive)
    extracted = extract_archive(archive, temporary_root / "source")
    return temporary, archive, extracted


def verify(_: argparse.Namespace) -> int:
    manifest = load_manifest()
    upstream = manifest["upstream"]
    temporary, archive, extracted = with_upstream(upstream["commit"])
    try:
        failures: list[str] = []
        if sha256(archive) != upstream["archiveSHA256"]:
            failures.append("source archive SHA-256 mismatch")
        if sha256(FORK_ROOT / upstream["licenseFile"]) != upstream["licenseSHA256"]:
            failures.append("fork license SHA-256 mismatch")

        expected = sorted(manifest["patchedUpstreamFiles"] + manifest["addedFiles"])
        actual = changed_files(extracted, FORK_ROOT)
        if actual != expected:
            failures.append(
                "unexpected upstream delta\n"
                f"expected: {json.dumps(expected, indent=2)}\n"
                f"actual:   {json.dumps(actual, indent=2)}"
            )

        if failures:
            for failure in failures:
                print(f"error: {failure}", file=sys.stderr)
            return 1

        print(
            f"verified ReluxNIOSSH at {upstream['commit']}: "
            f"archive/license hashes and {len(actual)}-file delta match"
        )
        return 0
    finally:
        temporary.cleanup()


def unified_diff(before: Path | None, after: Path | None, relative: str) -> str:
    before_bytes = before.read_bytes() if before else b""
    after_bytes = after.read_bytes() if after else b""
    try:
        before_lines = before_bytes.decode("utf-8").splitlines(keepends=True)
        after_lines = after_bytes.decode("utf-8").splitlines(keepends=True)
    except UnicodeDecodeError:
        return f"Binary files a/{relative} and b/{relative} differ\n"
    return "".join(
        difflib.unified_diff(
            before_lines,
            after_lines,
            fromfile=f"a/{relative}" if before else "/dev/null",
            tofile=f"b/{relative}" if after else "/dev/null",
        )
    )


def write_diff(arguments: argparse.Namespace) -> int:
    manifest = load_manifest()
    temporary, _, extracted = with_upstream(manifest["upstream"]["commit"])
    try:
        upstream_files = source_files(extracted)
        fork_files = source_files(FORK_ROOT)
        pieces = [
            unified_diff(upstream_files.get(relative), fork_files.get(relative), relative)
            for relative in changed_files(extracted, FORK_ROOT)
        ]
        output = "".join(pieces)
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        arguments.output.write_text(output, encoding="utf-8")
        print(f"wrote {arguments.output} ({len(output.encode('utf-8'))} bytes)")
        return 0
    finally:
        temporary.cleanup()


def conflict_test(arguments: argparse.Namespace) -> int:
    manifest = load_manifest()
    pin_temporary, _, pinned = with_upstream(manifest["upstream"]["commit"])
    candidate_temporary, _, candidate = with_upstream(arguments.upstream_ref)
    try:
        conflicts: list[str] = []
        for relative in manifest["patchedUpstreamFiles"]:
            pinned_file = pinned / relative
            candidate_file = candidate / relative
            if not candidate_file.is_file() or pinned_file.read_bytes() != candidate_file.read_bytes():
                conflicts.append(relative)

        if conflicts:
            print("patched upstream files changed; semantic rebase required:", file=sys.stderr)
            for conflict in conflicts:
                print(f"- {conflict}", file=sys.stderr)
            return 1

        print(f"no patched upstream file changed at {arguments.upstream_ref}")
        return 0
    finally:
        pin_temporary.cleanup()
        candidate_temporary.cleanup()


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    subparsers = result.add_subparsers(dest="command", required=True)
    subparsers.add_parser("verify", help="verify pin hashes and exact changed-file allowlist")
    diff_parser = subparsers.add_parser("diff", help="write a unified diff against the audited pin")
    diff_parser.add_argument("--output", type=Path, required=True)
    conflict_parser = subparsers.add_parser("conflict-test", help="detect candidate changes to patched upstream files")
    conflict_parser.add_argument("--upstream-ref", required=True)
    return result


def main() -> int:
    arguments = parser().parse_args()
    if arguments.command == "verify":
        return verify(arguments)
    if arguments.command == "diff":
        return write_diff(arguments)
    if arguments.command == "conflict-test":
        return conflict_test(arguments)
    raise AssertionError(arguments.command)


if __name__ == "__main__":
    raise SystemExit(main())

