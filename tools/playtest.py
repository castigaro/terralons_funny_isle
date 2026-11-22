"""Opt-in visual playtest (not part of run_tests.py).

Usage: python tools/playtest.py [--out <dir>] [--levels l1,l3] [--every 9] [--locale en|de]

Starts the windowed Godot binary at 1920x1080 on tools/playtest.gd in the given locale: screenshots of title, level
select and settings, then the bot plays every level through the real flow (intro card, play, pause menu, result) with
a screenshot every --every seconds, then a lost result of the first played level and the credits. APPDATA and the
game data folder go to <out>/data.
Output (default <testdata>/playtest-<locale>): numbered PNGs named with the locale suffix, log.txt with EventBus
events, announcer lines, audio bus peaks and one line per level "PLAYTEST level=… won=… stars=… bot_s=… timer_s=…
time_left_s=… used=…%".
used = share of the level timer the bot needed; a human needs roughly two to three times the bot time.
Exit codes: 0 ok, 1 Godot failed or watchdog, 2 windowed Godot missing.
"""
import argparse
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import REPO, TESTDATA, find_godot, godot_env  # noqa: E402

SCRIPT = "res://tools/playtest.gd"


LOCALES = ("en", "de")


def default_out(locale: str) -> Path:
    """Default output folder of a locale."""
    return TESTDATA / f"playtest-{locale}"


def build_args(out: Path, levels: str, every: float, locale: str = "en") -> list:
    """Godot arguments for the playtest script."""
    user = [f"--out={out.as_posix()}", f"--every={every}", f"--locale={locale}"]
    if levels:
        user.append(f"--levels={levels}")
    return ["--path", str(REPO), "--resolution", "1920x1080", "-s", SCRIPT, "--"] + user


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=None, help="output folder (default <testdata>/playtest-<locale>)")
    parser.add_argument("--levels", default="", help="comma-separated level id prefixes, e.g. l1,l3")
    parser.add_argument("--every", type=float, default=9.0, help="seconds between in-level screenshots")
    parser.add_argument("--locale", choices=LOCALES, default="en", help="game language of the run")
    args = parser.parse_args(argv)
    godot = find_godot(console=True)
    if godot is None:
        print("Godot not found: set GODOT_BIN", file=sys.stderr)
        return 2
    out = (args.out or default_out(args.locale)).resolve()
    out.mkdir(parents=True, exist_ok=True)
    env = godot_env(out / "data")
    code = subprocess.call([str(godot)] + build_args(out, args.levels, args.every, args.locale), env=env)
    summary = [line for line in (out / "log.txt").read_text(encoding="utf-8").splitlines()
               if line.startswith(("PLAYTEST", "FINISH"))] if (out / "log.txt").is_file() else []
    print("\n".join(summary))
    print(f"Screenshots and log: {out}")
    return 0 if code == 0 and summary and summary[-1] == "FINISH DONE" else 1


if __name__ == "__main__":
    sys.exit(main())
