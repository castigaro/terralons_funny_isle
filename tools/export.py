"""Build the Windows release exe: python tools/export.py [--out <path>].

Exports the preset "Windows Desktop" of export_presets.cfg (pack embedded, one file) to build/TerralonsFunnyIsle.exe
and runs the headless smoke test on the built exe with its user and data folders below <testdata>/export.
Needs the Godot 4.7.2 export templates in %APPDATA%/Godot/export_templates/4.7.2.stable; the export reads them from the
real APPDATA (read only), a pre-check reports clearly when they are missing.
Exit codes: 0 built and smoke OK, 1 export or smoke failed, 2 Godot missing, 3 export templates missing.
"""
import argparse
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import REPO, TESTDATA, find_godot, godot_env, load_allowlist, run_godot, scan_output  # noqa: E402

PRESET = "Windows Desktop"
DEFAULT_OUT = REPO / "build" / "TerralonsFunnyIsle.exe"
SMOKE_ARGS = ["--headless", "--", "--smoke", "--seed=12345"]
TEMPLATE_VERSION_DIR = "4.7.2.stable"
TEMPLATE_FILE = "windows_release_x86_64.exe"
EXIT_OK, EXIT_FAIL, EXIT_NO_GODOT, EXIT_NO_TEMPLATES = 0, 1, 2, 3


def template_path(environ=os.environ) -> Path:
    """Path of the Windows release template below APPDATA/Godot/export_templates."""
    return Path(environ.get("APPDATA", "")) / "Godot" / "export_templates" / TEMPLATE_VERSION_DIR / TEMPLATE_FILE


def check_templates(environ=os.environ) -> str:
    """Return an empty string when the export template exists, else a clear message."""
    path = template_path(environ)
    return "" if path.is_file() else "export templates for 4.7.2 missing at %s" % path


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


def build(out: Path, environ=os.environ) -> int:
    """Export the preset to out and smoke-run the exe; returns one of the documented exit codes."""
    godot = find_godot(console=True)
    if godot is None:
        print("Godot not found: set GODOT_BIN", file=sys.stderr)
        return EXIT_NO_GODOT
    missing = check_templates(environ)
    if missing:
        print(missing, file=sys.stderr)
        return EXIT_NO_TEMPLATES
    out = Path(out).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    code, output = run_godot(godot, ["--export-release", PRESET, str(out)], dict(environ), timeout=600)
    errors = scan_output(output, load_allowlist())
    if code != 0 or errors or not out.is_file():
        print(output, file=sys.stderr)
        print("export failed (rc=%s)" % code, file=sys.stderr)
        return EXIT_FAIL
    print("Built %s (%.1f MB)" % (out, out.stat().st_size / 1e6))
    return EXIT_OK if smoke(out) else EXIT_FAIL


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="path of the exe to write")
    opts = parser.parse_args(argv)
    return build(opts.out)


if __name__ == "__main__":
    sys.exit(main())
