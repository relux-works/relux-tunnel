import json
import tempfile
import unittest
from pathlib import Path

from scripts.validate_apple_ui_test_artifacts import validate_artifacts


class ArtifactValidationTests(unittest.TestCase):
    def test_accepts_complete_expected_step_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            screenshots = output / "screenshots" / "test"
            screenshots.mkdir(parents=True)
            paths = []
            for name in ("Step_01__ready_0_UUID", "Step_02__confirmed_0_UUID"):
                path = screenshots / f"{name}.png"
                path.write_bytes(b"png")
                paths.append(path)
            self.write_manifest(output, paths)

            validated = validate_artifacts(output, ["Step_01__ready", "Step_02__confirmed"])

            self.assertEqual(validated, [path.resolve() for path in paths])

    def test_rejects_missing_empty_and_malformed_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            with self.assertRaisesRegex(ValueError, "valid screenshots.json"):
                validate_artifacts(output, [])

            (output / "screenshots.json").write_text("not-json", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "valid screenshots.json"):
                validate_artifacts(output, [])

            (output / "screenshots.json").write_text(
                json.dumps({"schemaVersion": 1, "stepScreenshotCount": 0, "screenshots": []}),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "at least one screenshot"):
                validate_artifacts(output, [])

    def test_rejects_missing_expected_step_and_empty_png(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            screenshots = output / "screenshots" / "test"
            screenshots.mkdir(parents=True)
            empty = screenshots / "Step_01__ready.png"
            empty.touch()
            self.write_manifest(output, [empty])

            with self.assertRaisesRegex(ValueError, "non-empty PNG"):
                validate_artifacts(output, ["Step_01__ready", "Step_02__confirmed"])

            empty.write_bytes(b"png")
            with self.assertRaisesRegex(ValueError, "Step_02__confirmed"):
                validate_artifacts(output, ["Step_01__ready", "Step_02__confirmed"])

    @staticmethod
    def write_manifest(output: Path, paths: list[Path]) -> None:
        (output / "screenshots.json").write_text(
            json.dumps(
                {
                    "schemaVersion": 1,
                    "stepScreenshotCount": len(paths),
                    "screenshots": [{"path": str(path)} for path in paths],
                }
            ),
            encoding="utf-8",
        )


if __name__ == "__main__":
    unittest.main()
