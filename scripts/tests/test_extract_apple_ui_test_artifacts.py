import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "extract_apple_ui_test_artifacts",
    ROOT / "scripts/extract_apple_ui_test_artifacts.py",
)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ArtifactExtractionTests(unittest.TestCase):
    def test_organizes_only_step_named_png_attachments(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            exported = root / "exported"
            output = root / ".temp" / "TASK-260715-1idq8c" / "run"
            exported.mkdir()
            (exported / "image-1.png").write_bytes(b"png")
            (exported / "console.txt").write_text("ignored", encoding="utf-8")
            (exported / "manifest.json").write_text(
                json.dumps(
                    [
                        {
                            "testIdentifier": "ReluxUITestSmokeTests/test smoke()",
                            "attachments": [
                                {
                                    "exportedFileName": "image-1.png",
                                    "suggestedHumanReadableName": "Step_01__fixture ready.png",
                                    "isAssociatedWithFailure": False,
                                },
                                {
                                    "exportedFileName": "console.txt",
                                    "suggestedHumanReadableName": "Console",
                                    "isAssociatedWithFailure": True,
                                },
                            ],
                        }
                    ]
                ),
                encoding="utf-8",
            )

            records = MODULE.organize_attachments(exported, output)

            self.assertEqual(len(records), 1)
            screenshot = Path(records[0]["path"])
            self.assertTrue(screenshot.is_file())
            self.assertEqual(screenshot.name, "Step_01__fixture_ready.png")


if __name__ == "__main__":
    unittest.main()
