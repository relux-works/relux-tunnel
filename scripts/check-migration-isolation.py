#!/usr/bin/env python3
"""Fail closed when the generated tunnel product overlaps the legacy app lane."""

from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import re
import sys
from pathlib import Path
from typing import Any


LEGACY_BUNDLE_ID = "works.relux.proxy"
GENERATED_HOST_BUNDLE_ID = "works.relux.tunnel.mac"
GENERATED_PROVIDER_BUNDLE_ID = "works.relux.tunnel.mac.tunnel"
GENERATED_KEYCHAIN_SERVICE = "works.relux.tunnel.credential.v1"

LEGACY_DEFAULTS = {
    "sshHost": "relux",
    "sshAccount": "administrator",
    "localPort": "1080",
}

GENERATED_RUNTIME_TOKENS = (
    "ReluxTunnelCore",
    "ReluxTunnelNativeAdapter",
    "ReluxTunnelMacOSAdapter",
    "HevSocks5Tunnel",
    "ReluxLibSSH2",
    "CReluxNativeFixture",
)

LEGACY_RELEASE_MARKERS = (
    "ReluxProxy.dmg",
    "dist/ReluxProxy.app",
    "ReluxProxy-v",
)

LEGACY_OWNED_PATHS = (
    "Sources/ReluxProxy",
    "Tests/ReluxProxyTests",
    "Resources/Info.plist",
    "scripts/build-app.sh",
    "scripts/create-dmg.sh",
)


class IsolationError(RuntimeError):
    """A migration-isolation invariant could not be established."""


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        raise IsolationError(
            f"cannot read required text file {path}: {error}"
        ) from error


def read_plist(path: Path) -> dict[str, Any]:
    try:
        with path.open("rb") as stream:
            value = plistlib.load(stream)
    except (OSError, plistlib.InvalidFileException) as error:
        raise IsolationError(f"cannot read required plist {path}: {error}") from error
    if not isinstance(value, dict):
        raise IsolationError(f"required plist is not a dictionary: {path}")
    return value


def require(condition: bool, message: str) -> None:
    if not condition:
        raise IsolationError(message)


def parse_xcconfig(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in read_text(path).splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("//") or stripped.startswith("#"):
            continue
        if "=" not in stripped:
            raise IsolationError(f"malformed xcconfig assignment in {path}: {line}")
        key, value = stripped.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def production_swift_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for relative in ("App", "Sources"):
        directory = root / relative
        if not directory.is_dir():
            raise IsolationError(
                f"required generated source directory is missing: {directory}"
            )
        files.extend(sorted(directory.rglob("*.swift")))
    return files


def release_entry_files(root: Path) -> list[Path]:
    files = [root / "Makefile"]
    workflows = root / ".github" / "workflows"
    if not workflows.is_dir():
        raise IsolationError(f"required workflow directory is missing: {workflows}")
    files.extend(sorted(workflows.glob("*.yml")))
    files.extend(sorted(workflows.glob("*.yaml")))

    scripts = root / "scripts"
    if not scripts.is_dir():
        raise IsolationError(f"required scripts directory is missing: {scripts}")
    excluded = {
        "check-legacy-preservation.sh",
        "check-migration-isolation.py",
    }
    files.extend(
        path
        for path in sorted(scripts.iterdir())
        if path.is_file() and path.name not in excluded
    )
    return files


def verify_preservation_manifest(legacy_root: Path, manifest: Path) -> list[str]:
    entries: list[str] = []
    for line_number, line in enumerate(read_text(manifest).splitlines(), start=1):
        if not line.strip():
            continue
        parts = line.split(maxsplit=1)
        require(
            len(parts) == 2 and re.fullmatch(r"[0-9a-f]{64}", parts[0]) is not None,
            f"malformed legacy preservation manifest line {line_number}",
        )
        expected, relative = parts
        relative_path = Path(relative)
        require(
            not relative_path.is_absolute() and ".." not in relative_path.parts,
            f"unsafe legacy preservation manifest path: {relative}",
        )
        require(relative not in entries, f"duplicate legacy manifest path: {relative}")
        path = legacy_root / relative_path
        try:
            actual = hashlib.sha256(path.read_bytes()).hexdigest()
        except OSError as error:
            raise IsolationError(
                f"cannot read pinned legacy file {path}: {error}"
            ) from error
        require(actual == expected, f"pinned legacy file bytes drifted: {relative}")
        entries.append(relative)
    require(entries, "legacy preservation manifest is empty")
    return entries


def project_target_block(project: str, name: str) -> str:
    marker = f'  .target(\n    name: "{name}",'
    require(
        project.count(marker) == 1,
        f"generated target graph must contain exactly one {name} target",
    )
    start = project.index(marker)
    next_target = project.find("\n  .target(", start + len(marker))
    array_end = project.find("\n]", start + len(marker))
    candidates = [position for position in (next_target, array_end) if position >= 0]
    require(candidates, f"cannot parse generated target block: {name}")
    return project[start : min(candidates)]


def target_dependencies(block: str, name: str) -> list[str]:
    match = re.search(
        r"dependencies:\s*\[(.*?)\]\s*,\s*\n\s*settings:",
        block,
        re.DOTALL,
    )
    require(match is not None, f"cannot parse generated dependencies for {name}")
    return re.findall(
        r'\.(?:target\(name:|package\(product:)\s*"([^"]+)"', match.group(1)
    )


def verify_legacy(legacy_root: Path, preservation_manifest: Path) -> dict[str, Any]:
    package = read_text(legacy_root / "Package.swift")
    require('name: "ReluxProxy"' in package, "legacy SwiftPM package identity drifted")
    require(
        '.executable(name: "ReluxProxy", targets: ["ReluxProxy"])' in package,
        "legacy SwiftPM executable product drifted",
    )
    require('name: "ReluxProxyTests"' in package, "legacy SwiftPM test target drifted")

    product_files = [legacy_root / "Package.swift"]
    for relative in ("Sources/ReluxProxy", "Tests/ReluxProxyTests"):
        directory = legacy_root / relative
        require(directory.is_dir(), f"legacy product directory is missing: {relative}")
        product_files.extend(sorted(directory.rglob("*.swift")))
    for path in product_files:
        text = read_text(path)
        for token in GENERATED_RUNTIME_TOKENS:
            require(
                token not in text,
                f"legacy SwiftPM path cross-links generated runtime token {token}: "
                f"{path.relative_to(legacy_root)}",
            )

    plist = read_plist(legacy_root / "Resources" / "Info.plist")
    require(
        plist.get("CFBundleIdentifier") == LEGACY_BUNDLE_ID,
        "legacy bundle identifier drifted",
    )
    require(
        plist.get("CFBundleExecutable") == "ReluxProxy", "legacy executable drifted"
    )

    defaults_source = read_text(
        legacy_root / "Sources" / "ReluxProxy" / "MenuContentView.swift"
    )
    expected_defaults = (
        '@AppStorage("sshHost") private var host = "relux"',
        '@AppStorage("sshAccount") private var account = "administrator"',
        '@AppStorage("localPort") private var localPort = 1_080',
    )
    for literal in expected_defaults:
        require(
            literal in defaults_source, f"legacy defaults contract drifted: {literal}"
        )

    release_contract = {
        "Makefile": (
            "app:\n\tscripts/build-app.sh",
            "dmg: app\n\tscripts/create-dmg.sh",
        ),
        "scripts/build-app.sh": ('APP_NAME="ReluxProxy"',),
        "scripts/create-dmg.sh": ("ReluxProxy-v$VERSION-universal.dmg",),
        ".github/workflows/release.yml": (
            "cp dist/ReluxProxy-*.dmg dist/ReluxProxy.dmg",
            "dist/ReluxProxy.dmg",
        ),
    }
    for relative, literals in release_contract.items():
        text = read_text(legacy_root / relative)
        for literal in literals:
            require(
                literal in text,
                f"legacy release entry point drifted: {relative}: {literal}",
            )

    keychain_or_launch_tokens = (
        "SecItem",
        "kSecAttrService",
        "SMAppService",
        "LaunchAgent",
    )
    for path in product_files:
        text = read_text(path)
        for token in keychain_or_launch_tokens:
            require(
                token not in text,
                f"legacy v0.1.0 unexpectedly gained Keychain/launch ownership: "
                f"{path.relative_to(legacy_root)} ({token})",
            )

    pinned_files = verify_preservation_manifest(legacy_root, preservation_manifest)

    return {
        "repository": "relux-works/relux-proxy (separate checkout)",
        "pinnedFiles": pinned_files,
        "swiftpm": {
            "package": "ReluxProxy",
            "product": "ReluxProxy",
            "target": "ReluxProxy",
            "testTarget": "ReluxProxyTests",
            "generatedRuntimeDependencies": [],
        },
        "bundle": {
            "path": "dist/ReluxProxy.app",
            "identifier": LEGACY_BUNDLE_ID,
            "executable": "ReluxProxy",
        },
        "storage": {
            "defaultsDomain": LEGACY_BUNDLE_ID,
            "defaults": LEGACY_DEFAULTS,
            "keychainNamespaces": [],
        },
        "launch": {"kind": "SwiftUI MenuBarExtra", "launchAgents": []},
        "release": {
            "entries": ["make app", "make dmg", ".github/workflows/release.yml"],
            "artifacts": ["ReluxProxy-v<version>-universal.dmg", "ReluxProxy.dmg"],
        },
    }


def verify_workspace(workspace_root: Path) -> dict[str, Any]:
    for relative in LEGACY_OWNED_PATHS:
        require(
            not (workspace_root / relative).exists(),
            f"generated workspace claims legacy-owned path: {relative}",
        )

    package = read_text(workspace_root / "Package.swift")
    require(
        'name: "ReluxTunnel"' in package, "generated SwiftPM package identity drifted"
    )
    require(
        'name: "ReluxProxy"' not in package,
        "generated SwiftPM manifest defines the legacy ReluxProxy identity",
    )

    project = read_text(workspace_root / "Project.swift")
    require(
        re.search(r'name:\s*"ReluxProxy"\s*[,)]', project) is None,
        "generated target graph defines the legacy ReluxProxy target",
    )
    require(
        '.package(product: "ReluxProxy")' not in project,
        "generated target graph cross-links the legacy ReluxProxy product",
    )
    host_block = project_target_block(project, "ReluxProxyMac")
    provider_block = project_target_block(project, "ReluxProxyMacTunnel")
    host_dependencies = target_dependencies(host_block, "ReluxProxyMac")
    provider_dependencies = target_dependencies(provider_block, "ReluxProxyMacTunnel")
    require(
        host_dependencies
        == ["ReluxProxyMacTunnel", "ReluxAppleUITestShared", "ReluxTunnelCore"],
        f"generated host dependency graph drifted: {host_dependencies}",
    )
    require(
        provider_dependencies == ["ReluxTunnelMacOSAdapter"],
        f"generated provider dependency graph drifted: {provider_dependencies}",
    )
    require(
        'bundleId: "$(RELUX_MACOS_HOST_BUNDLE_ID)"' in host_block,
        "generated host bundle identity binding drifted",
    )
    require(
        'bundleId: "$(RELUX_MACOS_PROVIDER_BUNDLE_ID)"' in provider_block,
        "generated provider bundle identity binding drifted",
    )

    identities = parse_xcconfig(workspace_root / "Configuration" / "Identity.xcconfig")
    expected_identities = {
        "RELUX_MACOS_HOST_BUNDLE_ID": GENERATED_HOST_BUNDLE_ID,
        "RELUX_MACOS_PROVIDER_BUNDLE_ID": GENERATED_PROVIDER_BUNDLE_ID,
        "RELUX_IOS_HOST_BUNDLE_ID": "works.relux.tunnel.ios",
        "RELUX_IOS_PROVIDER_BUNDLE_ID": "works.relux.tunnel.ios.tunnel",
        "RELUX_IOS_APP_GROUP": "group.works.relux.tunnel",
    }
    for key, expected in expected_identities.items():
        require(identities.get(key) == expected, f"generated identity drifted: {key}")
        require(
            identities[key] != LEGACY_BUNDLE_ID,
            f"generated identifier collides with legacy bundle identifier: {key}",
        )

    keychain_source = read_text(
        workspace_root
        / "Sources"
        / "ReluxTunnelMacOSAdapter"
        / "MacOSSystemKeychainCredentialResolver.swift"
    )
    require(
        f'public static let service = "{GENERATED_KEYCHAIN_SERVICE}"'
        in keychain_source,
        "generated Keychain service namespace drifted",
    )
    require(
        GENERATED_KEYCHAIN_SERVICE != LEGACY_BUNDLE_ID,
        "generated Keychain service collides with legacy defaults domain",
    )

    production_sources = production_swift_files(workspace_root)
    for path in production_sources:
        text = read_text(path)
        require(
            LEGACY_BUNDLE_ID not in text,
            f"generated production source references legacy defaults/bundle domain: "
            f"{path.relative_to(workspace_root)}",
        )
        for key in LEGACY_DEFAULTS:
            require(
                f'@AppStorage("{key}")' not in text,
                f"generated production source reuses legacy defaults key {key}: "
                f"{path.relative_to(workspace_root)}",
            )
        for token in ("SMAppService.agent", "/Library/LaunchAgents", "LaunchAgents/"):
            require(
                token not in text,
                f"generated M1 product claims a launch-agent path: "
                f"{path.relative_to(workspace_root)} ({token})",
            )

    host_main = read_text(
        workspace_root / "App" / "ReluxProxyMac" / "Sources" / "main.swift"
    )
    provider_main = read_text(
        workspace_root / "App" / "ReluxProxyMacTunnel" / "Sources" / "main.swift"
    )
    require(
        "application.setActivationPolicy(.accessory)" in host_main
        and "application.run()" in host_main,
        "generated host launch behavior drifted",
    )
    require(
        "NEProvider.startSystemExtensionMode()" in provider_main,
        "generated provider launch behavior drifted",
    )

    for path in release_entry_files(workspace_root):
        text = read_text(path)
        for marker in LEGACY_RELEASE_MARKERS:
            require(
                marker not in text,
                f"generated release entry substitutes legacy artifact {marker}: "
                f"{path.relative_to(workspace_root)}",
            )

    return {
        "repository": "relux-works/relux-tunnel",
        "swiftpm": {
            "package": "ReluxTunnel",
            "hostDependencies": host_dependencies,
            "providerDependencies": provider_dependencies,
            "legacyProductDependencies": [],
        },
        "products": {
            "host": "ReluxProxyMac.app",
            "provider": f"{GENERATED_PROVIDER_BUNDLE_ID}.systemextension",
        },
        "identifiers": expected_identities,
        "storage": {
            "defaultsDomain": GENERATED_HOST_BUNDLE_ID,
            "legacyDefaultsKeysReused": [],
            "keychainService": GENERATED_KEYCHAIN_SERVICE,
            "iosKeychainGroup": identities.get("RELUX_IOS_KEYCHAIN_GROUP"),
        },
        "launch": {
            "host": "accessory NSApplication",
            "provider": "NetworkExtension system-extension mode",
            "launchAgents": [],
        },
        "release": {
            "legacyPackagingEntries": [],
            "legacyArtifactNames": [],
            "generatedReleaseDecision": "M5",
        },
    }


def verify_generated_project(path: Path) -> dict[str, Any]:
    text = read_text(path)
    forbidden_patterns = (
        r"\bname\s*=\s*ReluxProxy\s*;",
        r"\bproductName\s*=\s*ReluxProxy\s*;",
        r"\bpath\s*=\s*ReluxProxy\.app\s*;",
    )
    for pattern in forbidden_patterns:
        require(
            re.search(pattern, text) is None,
            f"generated Xcode project contains legacy product identity: {pattern}",
        )
    require(
        text.count("ReluxProxyMac.app") >= 1,
        "generated Xcode project does not contain the host product",
    )
    require(
        "ReluxProxyMacTunnel.systemextension" in text
        and re.search(r"\bproductName\s*=\s*ReluxProxyMacTunnel\s*;", text) is not None,
        "generated Xcode project does not contain the provider product identity",
    )
    return {
        "path": str(path),
        "legacyTargets": [],
        "hostProduct": "ReluxProxyMac.app",
        "providerProduct": "ReluxProxyMacTunnel.systemextension",
    }


def verify_products(products_root: Path) -> dict[str, Any]:
    collisions: list[str] = []
    for path in products_root.rglob("*"):
        if path.name in {"ReluxProxy", "ReluxProxy.app", "ReluxProxy.dmg"}:
            collisions.append(str(path.relative_to(products_root)))
    require(
        not collisions,
        f"generated build products collide with legacy artifacts: {collisions}",
    )

    configurations: dict[str, Any] = {}
    for configuration in ("Debug", "Release"):
        host = products_root / configuration / "ReluxProxyMac.app"
        host_plist = read_plist(host / "Contents" / "Info.plist")
        provider = (
            host
            / "Contents"
            / "Library"
            / "SystemExtensions"
            / f"{GENERATED_PROVIDER_BUNDLE_ID}.systemextension"
        )
        provider_plist = read_plist(provider / "Contents" / "Info.plist")
        host_executable = host / "Contents" / "MacOS" / "ReluxProxyMac"
        provider_executable = (
            provider / "Contents" / "MacOS" / GENERATED_PROVIDER_BUNDLE_ID
        )
        require(
            host_executable.is_file(),
            f"generated host executable missing: {host_executable}",
        )
        require(
            provider_executable.is_file(),
            f"generated provider executable missing: {provider_executable}",
        )
        require(
            host_plist.get("CFBundleIdentifier") == GENERATED_HOST_BUNDLE_ID,
            f"generated {configuration} host bundle identifier collides or drifted",
        )
        require(
            provider_plist.get("CFBundleIdentifier") == GENERATED_PROVIDER_BUNDLE_ID,
            f"generated {configuration} provider bundle identifier collides or drifted",
        )
        configurations[configuration] = {
            "host": str(host.relative_to(products_root)),
            "hostIdentifier": GENERATED_HOST_BUNDLE_ID,
            "provider": str(provider.relative_to(products_root)),
            "providerIdentifier": GENERATED_PROVIDER_BUNDLE_ID,
        }
    return {
        "root": str(products_root),
        "configurations": configurations,
        "collisions": [],
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--legacy-root", type=Path, required=True)
    parser.add_argument("--workspace-root", type=Path, required=True)
    parser.add_argument("--generated-project", type=Path)
    parser.add_argument("--products-root", type=Path)
    parser.add_argument("--report", type=Path)
    return parser.parse_args()


def main() -> int:
    arguments = parse_args()
    try:
        legacy_root = arguments.legacy_root.resolve(strict=True)
        workspace_root = arguments.workspace_root.resolve(strict=True)
        require(
            legacy_root != workspace_root,
            "legacy and generated products must remain in separate repositories",
        )
        report: dict[str, Any] = {
            "schemaVersion": 1,
            "task": "TASK-260715-3qqbbm",
            "legacy": verify_legacy(
                legacy_root, workspace_root / "config" / "legacy-v0.1.0.sha256"
            ),
            "generated": verify_workspace(workspace_root),
            "boundary": {
                "legacyMutation": "forbidden",
                "userMigration": "M4 / TASK-260715-35nc5m",
                "releaseMigration": "M5 / TASK-260715-1tzaed",
            },
        }
        if arguments.generated_project is not None:
            report["generatedProject"] = verify_generated_project(
                arguments.generated_project.resolve(strict=True)
            )
        if arguments.products_root is not None:
            report["buildProducts"] = verify_products(
                arguments.products_root.resolve(strict=True)
            )
        if arguments.report is not None:
            arguments.report.parent.mkdir(parents=True, exist_ok=True)
            arguments.report.write_text(
                json.dumps(report, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )
    except (IsolationError, OSError) as error:
        print(f"error: migration isolation check failed: {error}", file=sys.stderr)
        return 1
    print("migration isolation contract passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
