"""Opt-in windowed capture: renders a level with the windowed Godot binary, saves a screenshot below the testdata
folder and checks that the castaway is at least 64 px tall at 1920x1080 (not part of run_tests.py).

Usage: python tools/capture_level.py [--level res://tests/scenes/sample_level.tscn] [--size 1920x1080]
Exit codes: 0 ok, 1 check failed or no CAPTURE line, 2 Godot binary missing.
"""
import argparse
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import REPO, TESTDATA, find_godot, godot_env, strip_ansi  # noqa: E402

MIN_CASTAWAY_PX = 64
CAPTURE_RE = re.compile(r"CAPTURE image=(\d+)x(\d+) castaway_px=(\d+) castaway_px_1080=([\d.]+)")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--level", default="res://tests/scenes/sample_level.tscn")
    parser.add_argument("--size", default="1920x1080")
    opts = parser.parse_args(argv)
    godot = find_godot(console=False)
    if godot is None:
        print("windowed Godot binary not found", file=sys.stderr)
        return 2
    base = TESTDATA / "capture"
    env = godot_env(base)
    out = base / ("capture_%s.png" % opts.size)
    cmd = [str(godot), "--path", str(REPO), "--resolution", opts.size, "res://tests/scenes/capture_probe.tscn", "--",
           "--level=%s" % opts.level, "--size=%s" % opts.size, "--out=%s" % out.as_posix(),
           "--data-dir=%s" % (base / "data").as_posix()]
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", env=env,
                          timeout=120)
    text = strip_ansi(proc.stdout + proc.stderr)
    match = CAPTURE_RE.search(text)
    errors = [ln for ln in text.splitlines() if ln.startswith(("ERROR", "SCRIPT ERROR"))]
    if not match:
        print(text[-3000:])
        print("capture_level: no CAPTURE line")
        return 1
    px_1080 = float(match.group(4))
    print(match.group(0))
    print("screenshot: %s" % out)
    if errors:
        print("\n".join(errors))
    if px_1080 < MIN_CASTAWAY_PX or errors:
        print("capture_level: FAIL (castaway %.1f px at 1080p, minimum %d)" % (px_1080, MIN_CASTAWAY_PX))
        return 1
    print("capture_level: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
