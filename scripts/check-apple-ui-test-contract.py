#!/usr/bin/env python3
"""Static safety and single-source checks for Apple UI-test infrastructure."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SHARED = ROOT / "Sources/ReluxAppleUITestShared"
FIXTURE_HOST = ROOT / "App/ReluxUITestFixtureHost"
UI_TESTS = ROOT / "Tests/ReluxAppleUITestsShared"
LAUNCH_KEYS = SHARED / "ReluxUITestLaunchConfiguration.swift"


def fail(message: str) -> None:
    raise SystemExit(f"error: {message}")


def swift_files(*roots: Path) -> list[Path]:
    return sorted(path for root in roots for path in root.rglob("*.swift"))


def main() -> int:
    files = swift_files(SHARED, FIXTURE_HOST, UI_TESTS)
    if not files:
        fail("Apple UI-test sources are missing")

    forbidden_waits = re.compile(r"\b(Thread\.sleep|sleep|usleep)\s*\(")
    for path in files:
        text = path.read_text(encoding="utf-8")
        if forbidden_waits.search(text):
            fail(f"fixed wall-clock wait found in {path.relative_to(ROOT)}")
        if path != LAUNCH_KEYS and "RELUX_UI_TEST_" in text:
            fail(f"raw launch key duplicated outside shared authority: {path.relative_to(ROOT)}")

    project = (ROOT / "Project.swift").read_text(encoding="utf-8")
    for name in (
        "ReluxProxyMacUITestFixtureHost",
        "ReluxProxyMacUITests",
        "ReluxProxyIOSUITestFixtureHost",
        "ReluxProxyIOSUITests",
    ):
        if name not in project:
            fail(f"missing generated target definition: {name}")
    infrastructure = project[project.index("private let appleUITestInfrastructureTargets") :]
    infrastructure = infrastructure[: infrastructure.index("private var generatedSchemeNames")]
    for forbidden in ("NetworkExtension", "ReluxTunnelIOSAdapter", "ReluxTunnelMacOSAdapter"):
        if forbidden in infrastructure:
            fail(f"fixture graph contains prohibited production dependency: {forbidden}")

    fixtures = (SHARED / "ReluxUITestFixture.swift").read_text(encoding="utf-8")
    for category in (
        "profile",
        "trust",
        "capability",
        "failure",
        "diagnostic",
        "onboarding",
        "migration",
        "privacy",
    ):
        if f"case {category}" not in fixtures:
            fail(f"fixture category missing: {category}")

    smoke = (ROOT / "scripts/run-apple-ui-test-smoke.sh").read_text(encoding="utf-8")
    for required in (
        "build-for-testing",
        "macos_runtime_status=deferred",
        "macos_runtime_owner=TASK-260822-3q4grm",
        "validate_apple_ui_test_artifacts.py",
        "ios_simulator_artifact_exit",
        "aggregate_build_host_exit",
    ):
        if required not in smoke:
            fail(f"build-host smoke contract missing: {required}")
    if "run_ui_test \\\n  ReluxProxyMacUITests" in smoke:
        fail("build-host smoke must not launch native macOS XCUITest")

    print("Apple UI-test source, synchronization, fixture, and safety contracts passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
