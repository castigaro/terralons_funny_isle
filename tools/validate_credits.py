"""Validate data/credits.json against assets/SOURCES.md and data/balance/flow.json limits (standard library only).

Usage: python tools/validate_credits.py [--root <dir>]   (exit code 1 on any error)

(a) data/credits.json equals what tools/build_credits.py builds from assets/SOURCES.md (no drift), lists every
    pack and has no en dash (the menu fonts lack the glyph).
(b) data/balance/flow.json: result_input_delay_s in (0, 2] and not above result_input_delay_max_s (<= 2), guards
    and the debounce non-negative, every font size at least font_size_min.
"""
import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import REPO  # noqa: E402
import build_credits  # noqa: E402

MAX_RESULT_DELAY = 2.0
FONT_KEYS = ("font_size_title", "font_size_heading", "font_size_button", "font_size_body")
GUARD_KEYS = ("intro_guard_s", "credits_guard_s", "settings_save_debounce_s", "locked_label_s")


def check_credits(root: Path) -> list:
    errors = []
    sources = Path(root) / "assets" / "SOURCES.md"
    credits = Path(root) / "data" / "credits.json"
    if not credits.is_file():
        return ["data/credits.json missing – run python tools/build_credits.py"]
    expected = build_credits.build(sources.read_text(encoding="utf-8"))
    try:
        current = json.loads(credits.read_text(encoding="utf-8"))
    except ValueError as exc:
        return ["data/credits.json: invalid JSON (%s)" % exc]
    if current != expected:
        errors.append("data/credits.json differs from assets/SOURCES.md – run python tools/build_credits.py")
    packs = {p["pack"] for g in current.get("groups", []) for p in g.get("packs", [])}
    for row in build_credits.parse_sources(sources.read_text(encoding="utf-8")):
        if row["pack"].replace(build_credits.EN_DASH, "-") not in packs:
            errors.append("data/credits.json: pack %s missing" % row["pack"])
    if build_credits.EN_DASH in credits.read_text(encoding="utf-8"):
        errors.append("data/credits.json: en dash (the menu fonts have no glyph)")
    return errors


def check_flow_balance(root: Path) -> list:
    path = Path(root) / "data" / "balance" / "flow.json"
    if not path.is_file():
        return ["data/balance/flow.json missing"]
    try:
        flow = json.loads(path.read_text(encoding="utf-8"))
    except ValueError as exc:
        return ["flow.json: invalid JSON (%s)" % exc]
    errors = []

    def num(key):
        value = flow.get(key)
        if not isinstance(value, (int, float)) or isinstance(value, bool):
            errors.append("flow.json: %s must be a number" % key)
            return None
        return float(value)

    delay = num("result_input_delay_s")
    delay_max = num("result_input_delay_max_s")
    if delay is not None and not 0.0 < delay <= MAX_RESULT_DELAY:
        errors.append("flow.json: result_input_delay_s must be in (0, 2]")
    if delay_max is not None and delay_max > MAX_RESULT_DELAY:
        errors.append("flow.json: result_input_delay_max_s must be at most 2")
    if delay is not None and delay_max is not None and delay > delay_max:
        errors.append("flow.json: result_input_delay_s above result_input_delay_max_s")
    for key in GUARD_KEYS:
        value = num(key)
        if value is not None and value < 0:
            errors.append("flow.json: %s must not be negative" % key)
    minimum = num("font_size_min")
    for key in FONT_KEYS:
        value = num(key)
        if value is not None and minimum is not None and value < minimum:
            errors.append("flow.json: %s below font_size_min" % key)
    return errors


def validate(root: Path = REPO) -> list:
    return check_credits(root) + check_flow_balance(root)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Validate credits and flow balance.")
    parser.add_argument("--root", default=str(REPO))
    opts = parser.parse_args(argv)
    errors = validate(Path(opts.root))
    for err in errors:
        print("credits: " + err)
    print("validate_credits: %d error(s)" % len(errors))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
