"""Minimal validator: required top-level files exist. Further validators are added by BI-1/BI-13."""
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
REQUIRED = ["project.godot", "README.md", ".gitignore", "docs/process/backlog.md", "docs/process/vision.md"]


def main() -> int:
    missing = [name for name in REQUIRED if not (REPO / name).is_file()]
    for name in missing:
        print("missing: %s" % name)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
