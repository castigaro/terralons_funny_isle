"""Build the Windows release exe: python tools/export.py [--out <path>].

Exports the preset "Windows Desktop" of export_presets.cfg (pack embedded, one file) to build/TerralonsFunnyIsle.exe
and runs the headless smoke test on the built exe with its user and data folders below <testdata>/export.
Needs the Godot 4.7.2 export templates in %APPDATA%/Godot/export_templates/4.7.2.stable.
Exit codes: 0 built and smoke OK, 1 export or smoke failed, 2 Godot missing.
"""
import argparse
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import REPO, TESTDATA, find_godot, godot_env, load_allowlist, run_godot, scan_output  # noqa: E402

PRESET = "Windows Desktop"
DEFAULT_OUT = REPO / "build" / "TerralonsFunnyIsle.exe"
SMOKE_ARGS = ["--headless", "--", "--smoke", "--seed=12345"]


def smoke(exe: Path) -> bool:
    """Run the smoke mode of the built exe in a sandbox and report whether it printed SMOKE OK."""
    try:
        proc = subprocess.run(
            [str(exe)] + SMOKE_ARGS, env=godot_env(TESTDATA / "export"), capture_output=True,
            text=True, encoding="utf-8", errors="replace", timeout=120,
        )
    except subprocess.TimeoutExpired:
        print("smoke run of the exe timed out", file=sys.stderr)
        return False
    output = proc.stdout + proc.stderr
    ok = proc.returncode == 0 and "SMOKE OK" in output and not scan_output(output, load_allowlist())
    print(output.strip().splitlines()[-1] if output.strip() else "(no output)", file=sys.stdout if ok else sys.stderr)
    return ok


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="path of the exe to write")
    opts = parser.parse_args(argv)
    godot = find_godot(console=True)
    if godot is None:
        print("Godot not found: set GODOT_BIN", file=sys.stderr)
        return 2
    out = opts.out.resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    code, output = run_godot(godot, ["--export-release", PRESET, str(out)], None, timeout=600)
    errors = scan_output(output, load_allowlist())
    if code != 0 or errors or not out.is_file():
        print(output, file=sys.stderr)
        print("export failed (missing export templates?)", file=sys.stderr)
        return 1
    print("Built %s (%.1f MB)" % (out, out.stat().st_size / 1e6))
    return 0 if smoke(out) else 1


if __name__ == "__main__":
    sys.exit(main())
