#!/usr/bin/env python3
"""Fail-closed validation for the generated macOS provider production graph."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from relay_asset_manifest import (
    AssetManifestError,
    load_source_contract,
    validate_bundle,
    verify_schema,
)


class ContractError(Exception):
    pass


def named_invocation(
    text: str, kind: str, name: str, required_marker: str | None = None
) -> str:
    pattern = re.compile(rf"\.{re.escape(kind)}\s*\(\s*name:\s*\"{re.escape(name)}\"")
    for match in pattern.finditer(text):
        start = match.start()
        opening = text.find("(", start)
        depth = 0
        in_string = False
        escaped = False
        for index in range(opening, len(text)):
            character = text[index]
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
            elif character == "(":
                depth += 1
            elif character == ")":
                depth -= 1
                if depth == 0:
                    block = text[start : index + 1]
                    if required_marker is None or required_marker in block:
                        return block
                    break
    if not pattern.search(text):
        raise ContractError(f"missing {kind} declaration for {name}")
    raise ContractError(f"unterminated {kind} declaration for {name}")


def dependency_products(block: str) -> set[str]:
    return set(re.findall(r'\.package\(product:\s*"([^"]+)"\)', block))


def target_dependencies(block: str) -> set[str]:
    dependency_match = re.search(
        r"dependencies:\s*\[(.*?)\](?:\s*,\s*(?:linkerSettings|plugins):|\s*\))",
        block,
        re.DOTALL,
    )
    if dependency_match is None:
        raise ContractError("target dependencies are not statically inspectable")
    return set(re.findall(r'"([A-Za-z][A-Za-z0-9]+)"', dependency_match.group(1)))


def verify_manifests(project_path: Path, package_path: Path) -> None:
    project = project_path.read_text(encoding="utf-8")
    provider = named_invocation(
        project, "target", "ReluxProxyMacTunnel", "product: .systemExtension"
    )
    if dependency_products(provider) != {"ReluxTunnelMacOSAdapter"}:
        raise ContractError(
            "ReluxProxyMacTunnel must directly depend only on ReluxTunnelMacOSAdapter"
        )
    if ".folderReference(path: verifiedRelayBundleInput)" not in provider:
        raise ContractError(
            "ReluxProxyMacTunnel is missing the verified relay folder resource"
        )
    if (
        'private let verifiedRelayBundleInput: Path = ".build/relay/relay-assets-v1"'
        not in project
    ):
        raise ContractError("verified relay bundle input path drift")
    if "CReluxNativeFixture" in provider:
        raise ContractError("CReluxNativeFixture leaked into the provider target")

    package = package_path.read_text(encoding="utf-8")
    native = named_invocation(package, "target", "ReluxTunnelNativeAdapter")
    if target_dependencies(native) != {"ReluxTunnelCore", "HevSocks5Tunnel"}:
        raise ContractError(
            "ReluxTunnelNativeAdapter production dependencies must be Core plus HEV"
        )
    macos = named_invocation(package, "target", "ReluxTunnelMacOSAdapter")
    if target_dependencies(macos) != {
        "ReluxTunnelCore",
        "ReluxTunnelLibSSH2Adapter",
        "ReluxTunnelNativeAdapter",
    }:
        raise ContractError("ReluxTunnelMacOSAdapter production closure drift")
    ios = named_invocation(package, "target", "ReluxTunnelIOSAdapter")
    if target_dependencies(ios) != {"ReluxTunnelCore", "ReluxTunnelNativeAdapter"}:
        raise ContractError("ReluxTunnelIOSAdapter production closure drift")
    generated_lookup = (
        Path(__file__).resolve().parent.parent
        / "Sources/ReluxTunnelCore/RelayAssets/Generated/RelayAssetManifest+Generated.swift"
    )
    if not generated_lookup.is_file():
        raise ContractError("generated typed relay asset lookup is missing from Core")
    evidence = named_invocation(package, "testTarget", "ReluxTunnelNativeAdapterTests")
    if "CReluxNativeFixture" not in target_dependencies(evidence):
        raise ContractError("CReluxNativeFixture must remain test evidence")


def verify_relay_root(root: Path) -> None:
    try:
        verify_schema()
        validate_bundle(root, load_source_contract())
    except AssetManifestError as error:
        raise ContractError(str(error)) from error


def pbx_object(text: str, object_id: str) -> str:
    """Return one generated PBX object body, including its outer braces."""
    declaration = re.search(
        rf"(?m)^\s*{re.escape(object_id)}(?:\s+/\*.*?\*/)?\s*=\s*\{{", text
    )
    if declaration is None:
        raise ContractError(
            f"generated project references missing PBX object {object_id}"
        )

    opening = text.find("{", declaration.start())
    depth = 0
    in_string = False
    escaped = False
    for index in range(opening, len(text)):
        character = text[index]
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
        elif character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth == 0:
                return text[opening : index + 1]
    raise ContractError(f"unterminated generated PBX object {object_id}")


def pbx_list_ids(block: str, key: str) -> list[str]:
    match = re.search(rf"\b{re.escape(key)}\s*=\s*\((.*?)\);", block, re.DOTALL)
    if match is None:
        raise ContractError(f"generated PBX object is missing inspectable {key}")
    return re.findall(r"(?m)^\s*([0-9A-F]{24})(?:\s+/\*.*?\*/)?\s*,", match.group(1))


def named_native_target(text: str, name: str) -> str:
    candidates: list[str] = []
    for match in re.finditer(r"(?m)^\s*([0-9A-F]{24})(?:\s+/\*.*?\*/)?\s*=\s*\{", text):
        block = pbx_object(text, match.group(1))
        if "isa = PBXNativeTarget;" not in block:
            continue
        target_name = re.search(r"(?m)^\s*name\s*=\s*\"?([^\";]+)\"?;", block)
        if target_name is not None and target_name.group(1) == name:
            candidates.append(block)
    if len(candidates) != 1:
        raise ContractError(
            f"generated project must contain exactly one PBXNativeTarget named {name}"
        )
    return candidates[0]


def target_phase(text: str, target: str, isa: str) -> str:
    phases = [
        pbx_object(text, phase_id) for phase_id in pbx_list_ids(target, "buildPhases")
    ]
    matches = [phase for phase in phases if f"isa = {isa};" in phase]
    if len(matches) != 1:
        raise ContractError(
            f"ReluxProxyMacTunnel must reference exactly one {isa} build phase"
        )
    return matches[0]


def require_phase_edge(
    text: str, phase: str, reference_key: str, expected_name: str, phase_name: str
) -> None:
    matched_edges = 0
    for build_file_id in pbx_list_ids(phase, "files"):
        build_file = pbx_object(text, build_file_id)
        reference = re.search(
            rf"\b{re.escape(reference_key)}\s*=\s*([0-9A-F]{{24}})", build_file
        )
        if reference is None:
            continue
        referenced_object = pbx_object(text, reference.group(1))
        product_name = re.search(
            r"\bproductName\s*=\s*\"?([^\";]+)\"?;", referenced_object
        )
        path = re.search(r"\bpath\s*=\s*\"?([^\";]+)\"?;", referenced_object)
        resolved_name = product_name.group(1) if product_name is not None else None
        if resolved_name is None and path is not None:
            resolved_name = path.group(1)
        if resolved_name == expected_name:
            matched_edges += 1
    if matched_edges != 1:
        raise ContractError(
            f"ReluxProxyMacTunnel {phase_name} phase must contain exactly one "
            f"{expected_name} build-file edge"
        )


def verify_generated_project(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    provider = named_native_target(text, "ReluxProxyMacTunnel")
    frameworks = target_phase(text, provider, "PBXFrameworksBuildPhase")
    resources = target_phase(text, provider, "PBXResourcesBuildPhase")
    require_phase_edge(
        text,
        frameworks,
        "productRef",
        "ReluxTunnelMacOSAdapter",
        "Frameworks",
    )
    require_phase_edge(
        text,
        resources,
        "fileRef",
        "relay-assets-v1",
        "Resources",
    )
    if "CReluxNativeFixture" in text:
        raise ContractError("CReluxNativeFixture leaked into the generated app project")


def verify_linkage(
    libraries_path: Path | None,
    symbols_path: Path | None,
    all_symbols_path: Path | None,
) -> None:
    if libraries_path is not None:
        for line in libraries_path.read_text(encoding="utf-8").splitlines():
            if not line[:1].isspace():
                continue
            stripped = line.strip()
            if not stripped.startswith("/"):
                continue
            dependency = stripped.split()[0]
            if not (
                dependency.startswith("/usr/lib/")
                or dependency.startswith("/System/Library/Frameworks/")
            ):
                raise ContractError(
                    f"disallowed provider dynamic dependency: {dependency}"
                )
    if symbols_path is not None:
        symbols = symbols_path.read_text(encoding="utf-8")
        forbidden = (
            "_NSAddImage",
            "_NSCreateObjectFileImageFromFile",
            "_dladdr",
            "_dlclose",
            "_dlopen",
            "_dlsym",
        )
        for symbol in forbidden:
            if re.search(
                rf"(?:^|\s){re.escape(symbol)}(?:$|\s)", symbols, re.MULTILINE
            ):
                raise ContractError(
                    f"disallowed runtime-loading symbol in provider: {symbol}"
                )
    if all_symbols_path is not None:
        all_symbols = all_symbols_path.read_text(encoding="utf-8")
        if "relux_native_fixture" in all_symbols:
            raise ContractError(
                "CReluxNativeFixture symbols leaked into the provider binary"
            )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--relay-root", type=Path, required=True)
    parser.add_argument("--generated-project", type=Path)
    parser.add_argument("--provider-bundle", type=Path)
    parser.add_argument("--linked-libraries", type=Path)
    parser.add_argument("--undefined-symbols", type=Path)
    parser.add_argument("--all-symbols", type=Path)
    return parser.parse_args()


def main() -> int:
    arguments = parse_args()
    try:
        verify_manifests(arguments.project, arguments.package)
        verify_relay_root(arguments.relay_root)
        if arguments.generated_project is not None:
            verify_generated_project(arguments.generated_project)
        if arguments.provider_bundle is not None:
            verify_relay_root(
                arguments.provider_bundle / "Contents/Resources/relay-assets-v1"
            )
        verify_linkage(
            arguments.linked_libraries,
            arguments.undefined_symbols,
            arguments.all_symbols,
        )
    except (ContractError, OSError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    print("generated provider graph and relay resource contract passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
