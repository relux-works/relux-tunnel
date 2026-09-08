#!/usr/bin/env python3
"""Validate element files, excluding only board-root resource/activity stores."""

import argparse
import os
from pathlib import Path


def check(root: Path) -> int:
    if not root.is_dir():
        print(f"no {root} directory")
        return 1
    bad = False
    count = 0
    for dirpath, dirnames, filenames in os.walk(root):
        # These exact root stores contain ID-keyed payloads, not elements.
        if Path(dirpath) == root:
            dirnames[:] = [name for name in dirnames if name not in (".resources", ".activity")]
        if Path(dirpath).name.split("-")[0] in ("EPIC", "STORY", "TASK", "BUG"):
            count += 1
            for required in ("README.md", "progress.md"):
                if required not in filenames:
                    print(f"FAIL {dirpath}: missing {required}")
                    bad = True
    print(f"checked {count} board elements")
    return 1 if bad or count == 0 else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", type=Path, default=Path(".task-board"))
    return check(parser.parse_args().root)


if __name__ == "__main__":
    raise SystemExit(main())
