"""Check command: syntax, Godot import, GDScript tests, bot summary, Python tests, smoke run, validators, hygiene.

Usage: python tools/run_tests.py [-k <substring>] [--windowed]
Exit codes: 0 all green, 1 any failure, 2 Godot binary missing.

The default run starts no window. --windowed adds the opt-in stages smoke-windowed, perf and clip (tools/smoke.py,
windowed Godot binary) and export (tools/export.py) after the headless smoke stage; they ignore -k.

The bot stage reads the per-level summaries that the bot playthrough tests (tests/bot/test_bot_<level>.gd) write to
<testdata>/run_tests/bot/<level>.json, prints one table row per run of this test run and fails when a selected level
wrote no fresh run or a run failed.
"""
import argparse
import ast
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (  # noqa: E402
    BOT_REPORT_SUBDIR, REPO, TESTDATA, find_godot, godot_env, load_allowlist, parse_results,
    real_app_userdata, run_godot, scan_output,
)

GD_TIMEOUT = 120
# GDScript tests run on a fixed 60 fps clock: deterministic physics ticks and no real-time waiting.
GD_TEST_ARGS = ["--fixed-fps", "60"]
EXCLUDED_GD_PARTS = ("support", "fixtures")
# A GD test file whose first lines contain "## run-fps: 60,144" runs once per value (frame-rate dependent checks).
RUN_FPS_RE = re.compile(r"^##\s*run-fps:\s*([0-9][0-9,\s]*)$")
RUN_FPS_HEADER_LINES = 5
# A GD test file whose first lines contain "## watchdog: <s>" gets a longer runner watchdog (game seconds) and a
# subprocess timeout of at least s + WATCHDOG_MARGIN real seconds (long level playthroughs).
WATCHDOG_RE = re.compile(r"^##\s*watchdog:\s*([0-9]+)\s*$")
WATCHDOG_MARGIN = 30
# Bot playthrough test files per level; their level id names the summary file.
BOT_TEST_RE = re.compile(r"^res://tests/bot/test_bot_(l\d+_[a-z0-9_]+)\.gd$")
DEFAULT_STAGES = ("syntax", "import", "gdscript", "bot", "python", "smoke", "validators", "hygiene")
WINDOWED_STAGES = ("smoke-windowed", "perf", "clip", "export")
BOT_TABLE_COLUMNS = ("level", "variant", "mode", "seed", "tasks", "time_left", "stars", "result")


class Stage:
    def __init__(self, name):
        self.name = name
        self.passed = 0
        self.failed = 0
        self.failures = []

    def ok(self):
        self.passed += 1

    def fail(self, what, detail=""):
        self.failed += 1
        self.failures.append(what)
        print("FAIL [%s] %s" % (self.name, what))
        if detail:
            print(detail.rstrip())

    def report(self):
        print("== %s: pass=%d fail=%d" % (self.name, self.passed, self.failed))


def git_status():
    """Return the set of `git status --porcelain` lines, or None without git."""
    if shutil.which("git") is None:
        return None
    try:
        out = subprocess.run(
            ["git", "status", "--porcelain", "--untracked-files=all"],
            cwd=str(REPO), capture_output=True, text=True, encoding="utf-8", check=True,
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        return None
    return set(line for line in out.splitlines() if line.strip())


def folder_snapshot(root: Path):
    """Return {(relpath, size, mtime)} of every file below root (empty if missing)."""
    snap = set()
    if not root.is_dir():
        return snap
    for path in root.rglob("*"):
        if path.is_file():
            st = path.stat()
            snap.add((path.relative_to(root).as_posix(), st.st_size, int(st.st_mtime)))
    return snap


def gd_test_files(filter_text):
    files = []
    for gd in sorted((REPO / "tests").rglob("test_*.gd")):
        rel = gd.relative_to(REPO / "tests")
        if rel.as_posix() == "test_case.gd" or rel.parts[0] in EXCLUDED_GD_PARTS:
            continue
        res = "res://" + gd.relative_to(REPO).as_posix()
        if filter_text and filter_text not in res:
            continue
        files.append(res)
    return files


def py_test_files(filter_text):
    files = []
    for py in sorted((REPO / "tests").rglob("test_*.py")):
        rel = py.relative_to(REPO / "tests")
        if "fixtures" in rel.parts:
            continue
        if filter_text and filter_text not in py.as_posix():
            continue
        files.append(py)
    return files


def gdscript_args(res, fps=None, watchdog=None):
    """Return the Godot arguments that run one GDScript test file with the headless runner.

    Without fps the file runs on the default 60 fps clock; with fps it runs with --fixed-fps <fps> and the user
    argument --fps=<fps> (read by TestCase.run_fps()). watchdog adds --watchdog=<s> for the runner.
    """
    extra = ["--watchdog=%d" % watchdog] if watchdog else []
    if fps is None:
        return GD_TEST_ARGS + ["--script", "res://tests/runner.gd", "--"] + extra + [res]
    return ["--fixed-fps", str(fps), "--script", "res://tests/runner.gd", "--"] + extra + [res, "--fps=%d" % fps]


def _header(res, repo=None):
    path = Path(repo or REPO) / res[len("res://"):]
    try:
        with open(path, encoding="utf-8") as handle:
            return [handle.readline().strip() for _ in range(RUN_FPS_HEADER_LINES)]
    except OSError:
        return []


def watchdog_seconds(res, repo=None):
    """Return the seconds of a "## watchdog:" header in the first lines of a GD test file, else None."""
    for line in _header(res, repo):
        match = WATCHDOG_RE.match(line)
        if match:
            return int(match.group(1))
    return None


def gd_timeout(watchdog):
    """Subprocess timeout for a GD test file: GD_TIMEOUT, raised for files with a long watchdog."""
    return GD_TIMEOUT if not watchdog else max(GD_TIMEOUT, watchdog + WATCHDOG_MARGIN)


def run_fps_values(res, repo=None):
    """Return the fps values of a "## run-fps:" header in the first lines of a GD test file, else [None]."""
    path = Path(repo or REPO) / res[len("res://"):]
    try:
        with open(path, encoding="utf-8") as handle:
            head = [handle.readline() for _ in range(RUN_FPS_HEADER_LINES)]
    except OSError:
        return [None]
    for line in head:
        match = RUN_FPS_RE.match(line.strip())
        if match:
            values = [int(v) for v in re.split(r"[,\s]+", match.group(1).strip()) if v]
            if values:
                return values
    return [None]


def stage_syntax(stage):
    pys = sorted((REPO / "tools").glob("*.py")) + sorted((REPO / "tests").rglob("*.py"))
    for py in pys:
        try:
            ast.parse(py.read_text(encoding="utf-8"), filename=str(py))
            stage.ok()
        except SyntaxError as exc:
            stage.fail("syntax: %s" % exc)


def stage_import(stage, godot, env, allowlist):
    code, out = run_godot(godot, ["--import", "--quit"], env, timeout=300)
    hits = scan_output(out, allowlist)
    if code != 0 or hits:
        stage.fail("godot --import (rc=%s)" % code, "\n".join(hits) or out[-3000:])
    else:
        stage.ok()


def stage_gdscript(stage, godot, env, allowlist, files):
    for res in files:
        for fps in run_fps_values(res):
            _run_gdscript_file(stage, godot, env, allowlist, res, fps)


def _run_gdscript_file(stage, godot, env, allowlist, res, fps):
    label = res if fps is None else "%s@%d" % (res, fps)
    start = time.time()
    watchdog = watchdog_seconds(res)
    code, out = run_godot(godot, gdscript_args(res, fps, watchdog), env, timeout=gd_timeout(watchdog))
    results = parse_results(out)
    hits = scan_output(out, allowlist)
    problems = []
    if code is None:
        problems.append("timeout")
    elif code != 0:
        problems.append("exit code %s" % code)
    if res not in results:
        problems.append("missing RESULT line")
    else:
        passed, failed = results[res]
        if failed > 0:
            problems.append("%d failed" % failed)
        if passed == 0:
            problems.append("no passing test")
    if hits:
        problems.append("%d error line(s)" % len(hits))
    summary = results.get(res, (0, 0))
    print("  %s passed=%d failed=%d (%.1f s)" % (label, summary[0], summary[1], time.time() - start))
    if problems:
        detail = [ln for ln in out.splitlines() if ln.startswith(("FAIL", "WATCHDOG", "TIMEOUT"))]
        detail += hits
        if not detail:
            detail = out.splitlines()[-40:]
        stage.fail("%s: %s" % (label, ", ".join(problems)), "\n".join(detail))
    else:
        stage.ok()


def bot_levels(files):
    """Return the sorted level ids of the selected bot playthrough test files."""
    levels = set()
    for res in files:
        match = BOT_TEST_RE.match(res)
        if match:
            levels.add(match.group(1))
    return sorted(levels)


def read_bot_summaries(report_dir, since):
    """Load <report_dir>/<level>.json and keep the runs written at or after since: {level: [run, ...]}."""
    summaries = {}
    folder = Path(report_dir)
    if not folder.is_dir():
        return summaries
    for path in sorted(folder.glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        runs = [r for r in data.get("runs", []) if isinstance(r, dict) and float(r.get("written_at", 0)) >= since]
        if runs:
            summaries[data.get("level", path.stem)] = runs
    return summaries


def format_bot_table(summaries):
    """Render one row per run: level, variant, mode, seed, tasks done/total, time left, stars and result."""
    rows = [BOT_TABLE_COLUMNS]
    for level in sorted(summaries):
        for run in summaries[level]:
            rows.append((
                level, str(run.get("variant", "")), str(run.get("mode", "")), str(run.get("seed", "")),
                "%s/%s" % (run.get("tasks_done", "?"), run.get("tasks_total", "?")),
                "%.1f" % float(run.get("time_left", 0.0)), str(run.get("stars", "")),
                str(run.get("result", "")) + ("" if run.get("result") == "pass" else " " + str(run.get("reason", ""))),
            ))
    widths = [max(len(row[i]) for row in rows) for i in range(len(BOT_TABLE_COLUMNS))]
    return "\n".join("  ".join(cell.ljust(widths[i]) for i, cell in enumerate(row)).rstrip() for row in rows)


def bot_problems(expected_levels, summaries):
    """Name each expected level without a fresh run and each run whose result is not 'pass'."""
    problems = ["%s: no bot summary written in this run" % level for level in expected_levels if level not in summaries]
    for level in sorted(summaries):
        if level not in expected_levels:
            continue
        for run in summaries[level]:
            if run.get("result") != "pass":
                problems.append("%s %s %s seed=%s: %s" % (level, run.get("variant"), run.get("mode"), run.get("seed"),
                                                          run.get("reason", "fail")))
    return problems


def stage_bot(stage, files, report_dir, since):
    levels = bot_levels(files)
    if not levels:
        print("  no bot tests selected")
        stage.ok()
        return
    summaries = read_bot_summaries(report_dir, since)
    shown = {level: runs for level, runs in summaries.items() if level in levels}
    if shown:
        print(format_bot_table(shown))
    print("  summaries: %s" % report_dir)
    problems = bot_problems(levels, summaries)
    if problems:
        stage.fail("bot playthrough", "\n".join(problems))
    else:
        stage.ok()


def stage_python(stage, files):
    suite = unittest.TestSuite()
    loader = unittest.defaultTestLoader
    for idx, path in enumerate(files):
        name = "tfi_test_%d_%s" % (idx, path.stem)
        try:
            spec = importlib.util.spec_from_file_location(name, str(path))
            module = importlib.util.module_from_spec(spec)
            sys.modules[name] = module
            spec.loader.exec_module(module)
            suite.addTests(loader.loadTestsFromModule(module))
        except Exception as exc:  # noqa: BLE001 – report import failures as test failures
            stage.fail("import %s: %s" % (path.name, exc))
    result = unittest.TextTestRunner(verbosity=1, stream=sys.stdout).run(suite)
    bad = len(result.failures) + len(result.errors)
    stage.passed += result.testsRun - bad
    for test, trace in result.failures + result.errors:
        stage.fail(str(test), trace)


def stage_smoke(stage, godot, base, allowlist):
    env = godot_env(base)
    args = ["--", "--data-dir=%s" % (base / "data"), "--smoke", "--seed=12345"]
    code, out = run_godot(godot, args, env, timeout=GD_TIMEOUT)
    hits = scan_output(out, allowlist)
    smoke_lines = [ln for ln in out.splitlines() if ln.startswith("SMOKE")]
    print("  " + (smoke_lines[-1] if smoke_lines else "(no SMOKE line)"))
    ok = code == 0 and any(ln.startswith("SMOKE OK") for ln in smoke_lines) and not hits
    if ok:
        stage.ok()
    else:
        stage.fail("smoke (rc=%s)" % code, "\n".join(hits) or out[-3000:])


def stage_names(windowed: bool) -> list:
    """Stage order: the default headless stages, with the windowed stages after smoke when windowed is set."""
    names = list(DEFAULT_STAGES)
    if windowed:
        at = names.index("smoke") + 1
        names[at:at] = list(WINDOWED_STAGES)
    return names


def _record_checks(stage, checks):
    for name, ok, detail in checks:
        if ok:
            stage.ok()
        else:
            stage.fail(name, detail)


def stage_windowed(stage, mode):
    """Run one tools/smoke.py stage (smoke, perf or clip) in-process and count its checks."""
    import smoke  # noqa: PLC0415 – only loaded for the opt-in windowed run
    _record_checks(stage, smoke.run_stage(mode))


def stage_export(stage):
    """Build the Windows exe with tools/export.py and smoke-run it; missing templates fail with a clear message."""
    import export  # noqa: PLC0415 – only loaded for the opt-in windowed run
    code = export.build(export.DEFAULT_OUT)
    if code == export.EXIT_OK:
        stage.ok()
    elif code == export.EXIT_NO_TEMPLATES:
        stage.fail(export.check_templates())
    else:
        stage.fail("export.py exit code %d" % code)


def stage_validators(stage):
    for val in sorted((REPO / "tools").glob("validate_*.py")):
        proc = subprocess.run(
            [sys.executable, str(val)], cwd=str(REPO), capture_output=True,
            text=True, encoding="utf-8", errors="replace",
        )
        if proc.returncode == 0:
            stage.ok()
            print("  %s ok" % val.name)
        else:
            stage.fail(val.name, proc.stdout + proc.stderr)


def stage_hygiene(stage, before_git, before_userdata, userdata_dir):
    after_git = git_status()
    if before_git is None or after_git is None:
        print("  git not available – status check skipped")
    else:
        new = sorted(after_git - before_git)
        uids = [ln for ln in new if ln.rstrip().endswith(".gd.uid")]
        others = [ln for ln in new if ln not in uids]
        if uids:
            print("  WARNING: new .gd.uid files – commit these:\n    " + "\n    ".join(uids))
        if others:
            stage.fail("git status changed by the test run", "\n".join(others))
        else:
            stage.ok()
    if folder_snapshot(userdata_dir) != before_userdata:
        stage.fail("the real user folder changed: %s" % userdata_dir)
    else:
        stage.ok()


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("-k", dest="filter", default="", help="only run test files whose path contains this text")
    parser.add_argument("--windowed", action="store_true",
                        help="also run the windowed smoke, perf and clip stages and the export (opens windows)")
    opts = parser.parse_args(argv)
    os.environ.setdefault("PYTHONIOENCODING", "utf-8")
    run_start = time.time()

    stages = []
    before_git = git_status()
    userdata_dir = real_app_userdata()
    before_userdata = folder_snapshot(userdata_dir)

    godot = None
    base = TESTDATA / "run_tests"
    env = None
    allowlist = None
    gd_files = []
    for name in stage_names(opts.windowed):
        stage = Stage(name)
        stages.append(stage)
        start = time.time()
        if name == "syntax":
            stage_syntax(stage)
        elif name == "import":
            godot = find_godot()
            if godot is None:
                print("Godot binary not found (set GODOT_BIN)", file=sys.stderr)
                return 2
            env = godot_env(base)
            allowlist = load_allowlist()
            stage_import(stage, godot, env, allowlist)
        elif name == "gdscript":
            gd_files = gd_test_files(opts.filter)
            stage_gdscript(stage, godot, env, allowlist, gd_files)
        elif name == "bot":
            stage_bot(stage, gd_files, base / BOT_REPORT_SUBDIR, run_start)
        elif name == "python":
            stage_python(stage, py_test_files(opts.filter))
        elif name == "smoke":
            stage_smoke(stage, godot, base / "smoke", allowlist)
        elif name == "smoke-windowed":
            stage_windowed(stage, "smoke")
        elif name in ("perf", "clip"):
            stage_windowed(stage, name)
        elif name == "export":
            stage_export(stage)
        elif name == "validators":
            stage_validators(stage)
        elif name == "hygiene":
            stage_hygiene(stage, before_git, before_userdata, userdata_dir)
        stage.report()
        if name in ("gdscript",) + WINDOWED_STAGES:
            print("   (%.0f s)" % (time.time() - start))

    failures = [(s.name, f) for s in stages for f in s.failures]
    print("")
    for s in stages:
        print("%-14s pass=%-4d fail=%d" % (s.name, s.passed, s.failed))
    if failures:
        print("FAILED:\n  " + "\n  ".join("[%s] %s" % f for f in failures))
        return 1
    print("ALL TESTS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
