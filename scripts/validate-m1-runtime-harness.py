#!/usr/bin/env python3
"""Run the task-scoped composed M1 harness fixture manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import subprocess
import sys
from typing import Any


REQUIRED_ZERO_GAUGES = (
    "harness.m1.descriptor_growth",
    "harness.m1.task_growth",
    "harness.m1.channel_growth",
    "harness.m1.socket_growth",
    "harness.m1.native_runtime_growth",
    "harness.m1.host_owner_retained",
)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--executable", required=True, type=pathlib.Path)
    parser.add_argument(
        "--manifest",
        type=pathlib.Path,
        default=pathlib.Path(
            "Fixtures/M1Runtime/TASK-260715-m8bi8i_fixture-manifest-v1.json"
        ),
    )
    parser.add_argument(
        "--output",
        type=pathlib.Path,
        default=pathlib.Path(
            ".temp/TASK-260715-m8bi8i/m1-runtime-fixture-report.json"
        ),
    )
    return parser.parse_args()


def load_json(path: pathlib.Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def validate_manifest(manifest: dict[str, Any]) -> None:
    if manifest.get("schemaVersion") != 1 or manifest.get("command") != "m1-runtime":
        raise ValueError("unsupported M1 fixture manifest")
    fixtures = manifest.get("fixtures")
    if not isinstance(fixtures, list) or len(fixtures) != 7:
        raise ValueError("M1 fixture manifest must contain exactly seven scenarios")
    names = [fixture.get("name") for fixture in fixtures if isinstance(fixture, dict)]
    if len(names) != len(set(names)):
        raise ValueError("M1 fixture names must be unique")


def validate_configuration(
    configuration: dict[str, Any], dependency_revisions: dict[str, str]
) -> str:
    if configuration.get("schemaVersion") != 1:
        raise ValueError("fixture configuration schema mismatch")
    if configuration.get("dependencyRevisions") != dependency_revisions:
        raise ValueError("fixture dependency revisions drifted from manifest")
    profile = configuration.get("profileReference")
    if not isinstance(profile, dict) or profile.get("privacy") != "sensitive":
        raise ValueError("fixture profile reference must be sensitive")
    value = profile.get("value")
    if not isinstance(value, str) or not value:
        raise ValueError("fixture profile reference is missing")
    return value


def validate_success(stdout: bytes, profile_reference: str) -> None:
    result = json.loads(stdout)
    if result.get("command") != "m1-runtime" or result.get("status") != "succeeded":
        raise ValueError("success result identity mismatch")
    if result.get("configuration", {}).get("profileReference") != "<redacted>":
        raise ValueError("profile reference was not redacted")
    gauges = result.get("metrics", {}).get("gauges", {})
    if any(gauges.get(name) != 0 for name in REQUIRED_ZERO_GAUGES):
        raise ValueError("success result reports retained resources")
    if profile_reference.encode("utf-8") in stdout:
        raise ValueError("success output contains the profile reference")


def main() -> int:
    arguments = parse_arguments()
    manifest = load_json(arguments.manifest)
    validate_manifest(manifest)
    dependency_revisions = manifest["dependencyRevisions"]
    report_rows: list[dict[str, Any]] = []
    failed = False

    for fixture in manifest["fixtures"]:
        configuration_path = pathlib.Path(fixture["configuration"])
        configuration = load_json(configuration_path)
        profile_reference = validate_configuration(configuration, dependency_revisions)
        command = [
            str(arguments.executable),
            manifest["command"],
            "--configuration",
            str(configuration_path),
        ]
        completed = subprocess.run(
            command,
            check=False,
            capture_output=True,
            timeout=30,
        )
        expected_exit = fixture["expectedExitCode"]
        passed = completed.returncode == expected_exit
        detail = "matched"
        try:
            if expected_exit == 0:
                if completed.stderr:
                    raise ValueError("success scenario wrote standard error")
                validate_success(completed.stdout, profile_reference)
            else:
                if completed.stdout:
                    raise ValueError("failure scenario wrote standard output")
                expected_error = fixture["expectedStandardError"].encode("utf-8")
                if completed.stderr != expected_error:
                    raise ValueError("failure diagnostic mismatch")
                if profile_reference.encode("utf-8") in completed.stderr:
                    raise ValueError("failure diagnostic contains the profile reference")
        except (ValueError, json.JSONDecodeError) as error:
            passed = False
            detail = str(error)
        failed = failed or not passed
        report_rows.append(
            {
                "configuration": str(configuration_path),
                "expectedExitCode": expected_exit,
                "name": fixture["name"],
                "observedExitCode": completed.returncode,
                "outputSHA256": hashlib.sha256(
                    completed.stdout + completed.stderr
                ).hexdigest(),
                "passed": passed,
                "privacySafe": profile_reference.encode("utf-8")
                not in completed.stdout + completed.stderr,
                "validation": detail,
            }
        )

    report = {
        "command": manifest["command"],
        "fixtureCount": len(report_rows),
        "fixtures": report_rows,
        "passed": not failed,
        "schemaVersion": 1,
    }
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(
        f"m1 runtime fixtures: passed={not failed} fixtures={len(report_rows)} "
        f"report={arguments.output}"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
