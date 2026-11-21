"""Build data/credits.json (credits screen, D-2) from the table in assets/SOURCES.md.

Usage: python tools/build_credits.py [--check]
Groups the packs by author (text before " (" so derived rows count for the original author), keeps the table
order and replaces the en dash by a hyphen because the menu fonts have no en dash glyph. --check only compares.
"""
import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import REPO  # noqa: E402

SOURCES = REPO / "assets" / "SOURCES.md"
CREDITS = REPO / "data" / "credits.json"
EN_DASH = "–"


def parse_sources(text: str) -> list:
    """Return [{"pack", "author", "licence"}] of the SOURCES.md table rows in order."""
    rows = []
    header = None
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if header is None:
            header = [c.lower() for c in cells]
            continue
        if all(set(c) <= set("-: ") for c in cells):
            continue
        row = dict(zip(header, cells))
        if row.get("pack") and row.get("author"):
            rows.append({"pack": row["pack"], "author": row["author"], "licence": row.get("licence", "")})
    return rows


def normalise_author(author: str) -> str:
    return author.split(" (", 1)[0].strip()


def build(text: str) -> dict:
    groups = []
    by_author = {}
    for row in parse_sources(text):
        author = normalise_author(row["author"])
        if author not in by_author:
            by_author[author] = {"author": author, "packs": []}
            groups.append(by_author[author])
        by_author[author]["packs"].append({
            "pack": row["pack"].replace(EN_DASH, "-"),
            "licence": row["licence"].replace(EN_DASH, "-"),
        })
    return {"format_version": 1, "groups": groups}


def render(data: dict) -> str:
    return json.dumps(data, indent="\t", ensure_ascii=False) + "\n"


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Build data/credits.json from assets/SOURCES.md.")
    parser.add_argument("--check", action="store_true", help="only report drift, do not write")
    opts = parser.parse_args(argv)
    expected = render(build(SOURCES.read_text(encoding="utf-8")))
    current = CREDITS.read_text(encoding="utf-8") if CREDITS.is_file() else ""
    if opts.check:
        if current != expected:
            print("credits: data/credits.json is out of date – run python tools/build_credits.py")
            return 1
        print("credits: up to date")
        return 0
    CREDITS.write_text(expected, encoding="utf-8", newline="\n")
    print("credits: wrote %s" % CREDITS.relative_to(REPO).as_posix())
    return 0


if __name__ == "__main__":
    sys.exit(main())
