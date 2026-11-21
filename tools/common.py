"""Shared helpers for the Python tooling (standard library only)."""
import os
import re
import subprocess
from pathlib import Path
from typing import Mapping

REPO = Path(__file__).resolve().parent.parent
GODOT_VERSION_NAME = "Godot_v4.7.2-stable_win64"
WINGET_SUBDIR = "Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
APP_USERDATA_NAME = "Terralon's Funny Isle"
ALLOWLIST_FILE = REPO / "tools" / "godot_error_allowlist.txt"

_ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]")
_ERROR_RE = re.compile(r"^\s*(SCRIPT ERROR|USER ERROR|ERROR):")
_RESULT_RE = re.compile(r"^RESULT (\S+) passed=(\d+) failed=(\d+)\s*$")


def resolve_testdata_root(repo: Path, environ: Mapping[str, str]) -> Path:
    """Return the testdata root: TFI_TESTDATA, else <main>.testdata/<name> for worktrees, else <repo>.testdata."""
    override = environ.get("TFI_TESTDATA", "")
    if override:
        return Path(override)
    repo = Path(repo)
    parent = repo.parent
    if parent.name.endswith(".worktrees"):
        main_name = parent.name[: -len(".worktrees")]
        return parent.parent / (main_name + ".testdata") / repo.name
    return parent / (repo.name + ".testdata")


TESTDATA = resolve_testdata_root(REPO, os.environ)


def default_godot_dir(environ: Mapping[str, str] = os.environ) -> Path:
    """Return the documented WinGet folder of Godot 4.7.2 below LOCALAPPDATA."""
    return Path(environ.get("LOCALAPPDATA", "")) / WINGET_SUBDIR


DEFAULT_GODOT = default_godot_dir()


def find_godot(console: bool = True):
    """Return the Godot binary from GODOT_BIN or the documented WinGet path, else None."""
    env = os.environ.get("GODOT_BIN")
    if env:
        return Path(env) if Path(env).is_file() else None
    name = GODOT_VERSION_NAME + ("_console.exe" if console else ".exe")
    candidate = DEFAULT_GODOT / name
    return candidate if candidate.is_file() else None


def godot_env(base: Path) -> dict:
    """Return a copy of os.environ with APPDATA, LOCALAPPDATA and TFI_DATA_DIR redirected below base."""
    base = Path(base)
    env = dict(os.environ)
    dirs = {
        "APPDATA": base / "appdata",
        "LOCALAPPDATA": base / "localappdata",
        "TFI_DATA_DIR": base / "data",
    }
    for key, path in dirs.items():
        path.mkdir(parents=True, exist_ok=True)
        env[key] = str(path)
    return env


def real_app_userdata(environ: Mapping[str, str] = os.environ) -> Path:
    """Return the game's real user folder below the user's APPDATA."""
    return Path(environ.get("APPDATA", "")) / "Godot" / "app_userdata" / APP_USERDATA_NAME


def strip_ansi(text: str) -> str:
    """Remove ANSI colour sequences from Godot output."""
    return _ANSI_RE.sub("", text)


def load_allowlist(path: Path = ALLOWLIST_FILE) -> list:
    """Read allowlisted regexes (one per line, '#' starts a comment)."""
    patterns = []
    if not Path(path).is_file():
        return patterns
    for raw in Path(path).read_text(encoding="utf-8").splitlines():
        line = raw.split("#", 1)[0].strip()
        if line:
            patterns.append(re.compile(line))
    return patterns


def scan_output(text: str, allowlist=()) -> list:
    """Return the error lines of Godot output that are not allowlisted."""
    hits = []
    for line in strip_ansi(text).splitlines():
        if _ERROR_RE.match(line) or "Parse Error" in line or "Compile Error" in line:
            if any(p.search(line) for p in allowlist):
                continue
            hits.append(line.strip())
    return hits


def run_godot(godot, args, env, timeout: int = 120):
    """Run headless Godot on the repo; return (returncode or None on timeout, combined output)."""
    cmd = [str(godot), "--headless", "--path", str(REPO)] + list(args)
    proc = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, encoding="utf-8", errors="replace", env=env,
    )
    try:
        out, _ = proc.communicate(timeout=timeout)
        return proc.returncode, out or ""
    except subprocess.TimeoutExpired:
        proc.kill()
        out, _ = proc.communicate()
        return None, (out or "") + "\nTIMEOUT after %d s" % timeout


def parse_results(output: str) -> dict:
    """Map each test file of the RESULT lines to (passed, failed)."""
    results = {}
    for line in strip_ansi(output).splitlines():
        match = _RESULT_RE.match(line.strip())
        if match:
            results[match.group(1)] = (int(match.group(2)), int(match.group(3)))
    return results


CODE_DIRS = ("scripts", "scenes", "ui")


def code_files(root: Path, suffix: str) -> list:
    """Return the product files with this suffix below scripts/, scenes/ and ui/ (sorted)."""
    files = []
    for name in CODE_DIRS:
        base = Path(root) / name
        if base.is_dir():
            files.extend(sorted(base.rglob("*" + suffix)))
    return files


def gd_strip(text: str):
    """Split GDScript source: returns (code without comments, code without comments and strings, [(literal, offset)])."""
    no_comments = []
    bare = []
    strings = []
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == "#":
            j = text.find("\n", i)
            i = n if j < 0 else j
            continue
        if c in "\"'":
            quote = c * 3 if text.startswith(c * 3, i) else c
            raw = i > 0 and text[i - 1] == "r" and (i < 2 or not (text[i - 2].isalnum() or text[i - 2] == "_"))
            j = i + len(quote)
            while j < n:
                if not raw and text[j] == "\\":
                    j += 2
                    continue
                if text.startswith(quote, j) or (len(quote) == 1 and text[j] == "\n"):
                    break
                j += 1
            end = min(j + len(quote), n)
            no_comments.append(text[i:end])
            bare.append('""')
            strings.append((text[i + len(quote):j], i))
            i = end
            continue
        no_comments.append(c)
        bare.append(c)
        i += 1
    return "".join(no_comments), "".join(bare), strings
