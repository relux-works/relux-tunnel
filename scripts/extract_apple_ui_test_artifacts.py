#!/usr/bin/env python3
"""Extract step screenshots from xcresult into a task-scoped review directory."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path


SAFE_COMPONENT = re.compile(r"[^A-Za-z0-9._-]+")


def safe_component(value: str) -> str:
    value = SAFE_COMPONENT.sub("_", value).strip("._")
    return value or "unnamed"


def organize_attachments(export_directory: Path, output_directory: Path) -> list[dict[str, str]]:
    manifest_path = export_directory / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    records: list[dict[str, str]] = []
    for test in manifest:
        test_name = safe_component(test["testIdentifier"])
        for attachment in test["attachments"]:
            source = export_directory / attachment["exportedFileName"]
            suggested = attachment["suggestedHumanReadableName"]
            if source.suffix.lower() != ".png" or not suggested.startswith("Step_"):
                continue
            destination_directory = output_directory / "screenshots" / test_name
            destination_directory.mkdir(parents=True, exist_ok=True)
            suggested_stem = suggested[:-4] if suggested.lower().endswith(".png") else suggested
            destination = destination_directory / f"{safe_component(suggested_stem)}.png"
            shutil.copy2(source, destination)
            records.append(
                {
                    "test": test["testIdentifier"],
                    "name": suggested,
                    "path": str(destination),
                    "failure": str(bool(attachment["isAssociatedWithFailure"])).lower(),
                }
            )
    records.sort(key=lambda record: (record["test"], record["name"]))
    return records


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("xcresult", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    if ".temp" not in args.output.parts:
        parser.error("output must be task-scoped beneath .temp")
    export_directory = args.output / "xcresult-attachments"
    screenshots_directory = args.output / "screenshots"
    if export_directory.exists():
        shutil.rmtree(export_directory)
    if screenshots_directory.exists():
        shutil.rmtree(screenshots_directory)
    export_directory.mkdir(parents=True)
    subprocess.run(
        [
            "xcrun",
            "xcresulttool",
            "export",
            "attachments",
            "--path",
            str(args.xcresult),
            "--output-path",
            str(export_directory),
        ],
        check=True,
    )
    records = organize_attachments(export_directory, args.output)
    summary = {
        "schemaVersion": 1,
        "xcresult": str(args.xcresult),
        "stepScreenshotCount": len(records),
        "screenshots": records,
    }
    (args.output / "screenshots.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    if not records:
        raise SystemExit("no step-named PNG screenshots found")
    print(f"extracted {len(records)} step screenshots to {args.output / 'screenshots'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
