#!/usr/bin/env python3
"""Fail closed unless extracted UI-test screenshot evidence is complete."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def validate_artifacts(output: Path, expected_steps: list[str]) -> list[Path]:
    manifest_path = output / "screenshots.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"cannot read valid screenshots.json: {error}") from error

    if not isinstance(manifest, dict) or manifest.get("schemaVersion") != 1:
        raise ValueError("screenshots.json must be a schemaVersion 1 object")
    screenshots = manifest.get("screenshots")
    if not isinstance(screenshots, list) or not screenshots:
        raise ValueError("screenshots.json must contain at least one screenshot")
    if manifest.get("stepScreenshotCount") != len(screenshots):
        raise ValueError("stepScreenshotCount does not match screenshots")

    output_root = output.resolve()
    paths: list[Path] = []
    names: list[str] = []
    for index, record in enumerate(screenshots):
        if not isinstance(record, dict) or not isinstance(record.get("path"), str):
            raise ValueError(f"screenshot record {index} has no string path")
        path = Path(record["path"]).resolve()
        if output_root not in path.parents:
            raise ValueError(f"screenshot record {index} escapes the artifact directory")
        if path.suffix.lower() != ".png" or not path.is_file() or path.stat().st_size == 0:
            raise ValueError(f"screenshot record {index} is not a non-empty PNG file")
        paths.append(path)
        names.append(path.stem)

    for expected in expected_steps:
        matches = [name for name in names if name == expected or name.startswith(f"{expected}_")]
        if len(matches) != 1:
            raise ValueError(f"expected exactly one {expected} PNG, found {len(matches)}")
    return paths


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--expected-step", action="append", default=[])
    args = parser.parse_args()
    try:
        paths = validate_artifacts(args.output, args.expected_step)
    except ValueError as error:
        parser.error(str(error))
    print(f"validated {len(paths)} step screenshots in {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
