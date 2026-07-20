#!/usr/bin/env python3
"""Unit tests for deployment-target normalization in the native build seam."""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
TOOL_PATH = REPOSITORY_ROOT / "scripts" / "native-dependency-tool.py"
SPEC = importlib.util.spec_from_file_location("native_dependency_tool", TOOL_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"could not load {TOOL_PATH}")
TOOL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TOOL)


class HEVBuildScriptTests(unittest.TestCase):
    def setUp(self) -> None:
        self.item = {
            "compiler": {
                "required_slices": [
                    {"library_identifier": "ios-arm64", "platform": "ios", "minimum": "18.0"},
                    {
                        "library_identifier": "ios-simulator",
                        "platform": "ios",
                        "minimum": "18.0",
                    },
                    {"library_identifier": "macos", "platform": "macos", "minimum": "15.0"},
                    {"library_identifier": "tvos", "platform": "tvos", "minimum": "18.0"},
                    {
                        "library_identifier": "tvos-simulator",
                        "platform": "tvos",
                        "minimum": "18.0",
                    },
                ]
            }
        }
        self.script = """\
buildStatic iphoneos arm64 15.0
buildStatic iphonesimulator x86_64 15.0
buildStatic iphonesimulator arm64 15.0
buildStatic macosx x86_64 10.14
buildStatic macosx arm64 10.14
buildStatic appletvos arm64 17.0
buildStatic appletvsimulator x86_64 17.0
buildStatic appletvsimulator arm64 17.0
"""

    def test_render_uses_manifest_minimums_for_every_apple_sdk(self) -> None:
        rendered = TOOL.render_hev_build_script(self.item, self.script)
        self.assertNotIn("10.14", rendered)
        self.assertNotIn("17.0", rendered)
        self.assertEqual(rendered.count(" 18.0\n"), 6)
        self.assertEqual(rendered.count(" 15.0\n"), 2)

    def test_render_rejects_unmodeled_upstream_sdk(self) -> None:
        with self.assertRaisesRegex(TOOL.NativeDependencyError, "unsupported HEV Apple SDK"):
            TOOL.render_hev_build_script(
                self.item, self.script + "buildStatic watchos arm64 10.0\n"
            )

    def test_render_rejects_inconsistent_platform_minimums(self) -> None:
        self.item["compiler"]["required_slices"][1]["minimum"] = "17.0"
        with self.assertRaisesRegex(TOOL.NativeDependencyError, "inconsistent ios"):
            TOOL.render_hev_build_script(self.item, self.script)

    def test_hev_build_uses_deterministic_archive_environment(self) -> None:
        self.assertEqual(
            TOOL.deterministic_build_environment(),
            {"ZERO_AR_DATE": "1", "LC_ALL": "C", "LANG": "C"},
        )


if __name__ == "__main__":
    unittest.main()
