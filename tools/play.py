"""Start the game windowed: python tools/play.py [--sandbox] [-- --seed=<int> --data-dir=<path>].

--sandbox (consumed here) redirects APPDATA and the game data folder into <testdata>/play,
unless --data-dir is passed. All other arguments go to Godot unchanged.
"""
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import REPO, TESTDATA, find_godot, godot_env, run_godot  # noqa: E402

CLASS_CACHE = REPO / ".godot" / "global_script_class_cache.cfg"


def split_args(argv):
    """Return (sandbox flag, remaining Godot args)."""
    sandbox = "--sandbox" in argv
    rest = [a for a in argv if a != "--sandbox"]
    return sandbox, rest


def main(argv=None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    sandbox, rest = split_args(argv)
    godot = find_godot(console=False)
    console = find_godot(console=True) or godot
    if godot is None:
        print("Godot not found: set GODOT_BIN", file=sys.stderr)
        return 2
    env = None
    if sandbox:
        env = godot_env(TESTDATA / "play")
        if any(a.startswith("--data-dir=") for a in rest):
            env.pop("TFI_DATA_DIR", None)
    if not CLASS_CACHE.is_file():
        print("First start: importing the project headless ...")
        code, out = run_godot(console, ["--import", "--quit"], env, timeout=300)
        if code != 0:
            print(out, file=sys.stderr)
            return 1
    return subprocess.call([str(godot), "--path", str(REPO)] + rest, env=env)


if __name__ == "__main__":
    sys.exit(main())
