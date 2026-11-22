"""Windowed smoke run: python tools/smoke.py [--stage smoke|perf|clip|all] [--sizes 1920x1080,1280x720].

Opens the game window with the windowed Godot binary and runs res://tests/scenes/smoke_probe.tscn on the real game
flow. smoke: title and every level with music, effects, an animation check and a screenshot sequence; perf: a 60 s
bot run on one level with the frame times (fails on any frame above 33 ms after the first second); clip: German clip
check of every screen, the overlong fixture and the castaway height at 1920x1080. Fails on any engine error line and
on any warning about audio or rendering. Output: <testdata>/smoke/<WxH>/*.png, perf_<WxH>.json, logs/*.log.
Exit codes: 0 ok, 1 failure, 2 windowed Godot binary missing.
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import REPO, TESTDATA, find_godot, godot_env, load_allowlist, scan_output, strip_ansi  # noqa: E402

PROBE_SCENE = "res://tests/scenes/smoke_probe.tscn"
DEFAULT_SIZES = ("1920x1080", "1280x720")
STAGES = ("smoke", "perf", "clip")
TIMEOUTS = {"smoke": 180, "perf": 150, "clip": 240}
SEED = 12345
WARN_KEYWORDS = ("Audio", "WASAPI", "Vulkan", "D3D12", "RenderingDevice", "RenderingServer", "OpenGL", "GLES",
                 "shader", "texture")
WARMUP_S = 1.0
LIMIT_MS = 33.0
MIN_CASTAWAY_PX = 64.0
MIN_SHOTS = 3
EXIT_OK, EXIT_FAIL, EXIT_NO_GODOT = 0, 1, 2

_WARNING_RE = re.compile(r"^\s*WARNING:")
_KEYWORD_RE = re.compile("|".join(re.escape(k) for k in WARN_KEYWORDS), re.IGNORECASE)
_LINE_RES = {
    "screen": re.compile(r"^SCREEN name=(\S+) shots=(\d+) ok=(true|false) reason=(\S+)"),
    "music": re.compile(r"^MUSIC screen=(\S+) expected=(\S*) actual=(\S*) errors=(\d+)"),
    "fx": re.compile(r"^FX level=(\S+) shake=(\d+) puff=(\d+) splat=(\d+)"),
    "anim": re.compile(r"^ANIM level=(\S+) changed=([\d.]+) threshold=([\d.]+) ok=(true|false)"),
    "castaway": re.compile(r"^CASTAWAY level=(\S+) px=(\d+) px_1080=([\d.]+)"),
    "clip": re.compile(r"^CLIP screen=(\S+) size=(\S+) locale=(\S+) errors=(\d+)"),
    "fixture": re.compile(r"^CLIP_FIXTURE detected=(\d+)"),
    "perf_frames": re.compile(r"^PERF_FRAMES file=(.+?) frames=(\d+) events=(\d+)\s*$"),
    "hud_state": re.compile(r"^HUD_STATE prompts=(\d+) level_cue=(\S+) hud_cue=(\S*) together=(true|false)"),
    "done": re.compile(r"^PROBE DONE ok=(true|false)"),
    "fail": re.compile(r"^PROBE FAIL (.*)$"),
}


def scan_log(text: str, allowlist=()) -> dict:
    """Sort engine output lines: errors (common.scan_output), warnings about audio or rendering, other warnings."""
    errors = scan_output(text, allowlist)
    warn_fail = []
    warn_info = []
    for line in strip_ansi(text).splitlines():
        if not _WARNING_RE.match(line) or any(p.search(line) for p in allowlist):
            continue
        (warn_fail if _KEYWORD_RE.search(line) else warn_info).append(line.strip())
    return {"errors": errors, "warn_fail": warn_fail, "warn_info": warn_info}


def perf_summary(frame_ms, warmup_s: float = WARMUP_S, limit_ms: float = LIMIT_MS) -> dict:
    """Average and maximum frame time and the frames above limit_ms, ignoring frames that start in the warm-up."""
    elapsed = 0.0
    kept = []
    for ms in frame_ms:
        if elapsed >= warmup_s * 1000.0:
            kept.append(float(ms))
        elapsed += float(ms)
    if not kept:
        return {"frames": 0, "avg_ms": 0.0, "max_ms": 0.0, "over_33": 0}
    return {"frames": len(kept), "avg_ms": sum(kept) / len(kept), "max_ms": max(kept),
            "over_33": sum(1 for ms in kept if ms > limit_ms)}


def format_perf(size: str, summary: dict) -> str:
    return "PERF size=%s frames=%d avg_ms=%.2f max_ms=%.2f over_33=%d" % (
        size, summary["frames"], summary["avg_ms"], summary["max_ms"], summary["over_33"])


def parse_probe(text: str) -> dict:
    """Collect the probe result lines: {kind: [tuple of groups, ...]} plus clip_errors per screen."""
    out = {kind: [] for kind in _LINE_RES}
    out["clip_errors"] = []
    for raw in strip_ansi(text).splitlines():
        if raw.startswith("  clip: "):
            out["clip_errors"].append(raw[len("  clip: "):].strip())
            continue
        line = raw.strip()
        for kind, regex in _LINE_RES.items():
            match = regex.match(line)
            if match:
                out[kind].append(match.groups())
                break
    return out


def probe_cmd(godot, mode: str, size: str, out: Path, data_dir: Path, log_file: Path) -> list:
    """Command line of one windowed probe run (no --headless, no --fixed-fps)."""
    return [str(godot), "--path", str(REPO), "--resolution", size, "--log-file", Path(log_file).as_posix(),
            PROBE_SCENE, "--", "--mode=%s" % mode, "--size=%s" % size, "--out=%s" % Path(out).as_posix(),
            "--data-dir=%s" % Path(data_dir).as_posix(), "--seed=%d" % SEED]


def castaway_ok(px_1080: float) -> bool:
    return float(px_1080) >= MIN_CASTAWAY_PX


def run_probe(godot, mode: str, size: str, base: Path, allowlist=None):
    """Run one probe; return (parsed result lines, scan_log result, rc, combined text)."""
    base = Path(base)
    allowlist = load_allowlist() if allowlist is None else allowlist
    log_dir = base / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / ("%s_%s.log" % (mode, size))
    if log_file.exists():
        log_file.unlink()
    env = godot_env(base / "env")
    cmd = probe_cmd(godot, mode, size, base, base / "data" / ("%s_%s" % (mode, size)), log_file)
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", env=env,
                              timeout=TIMEOUTS[mode])
        rc, text = proc.returncode, proc.stdout + proc.stderr
    except subprocess.TimeoutExpired as exc:
        rc = None
        text = (exc.stdout or "") if isinstance(exc.stdout, str) else ""
        text += "\nTIMEOUT after %d s" % TIMEOUTS[mode]
    log_text = log_file.read_text(encoding="utf-8", errors="replace") if log_file.is_file() else ""
    (log_dir / ("%s_%s.stdout.txt" % (mode, size))).write_text(text, encoding="utf-8")
    scan = scan_log(text + "\n" + log_text, allowlist)
    scan = {k: sorted(set(v)) for k, v in scan.items()}
    return parse_probe(text), scan, rc, text


def _common_checks(name: str, parsed: dict, scan: dict, rc, text: str) -> list:
    checks = []
    done = parsed["done"] and parsed["done"][-1][0] == "true"
    detail = "; ".join(f[0] for f in parsed["fail"]) or ("rc=%s" % rc)
    checks.append(("%s probe finished" % name, rc == 0 and done, "" if rc == 0 and done else detail + "\n" +
                   text[-2000:]))
    checks.append(("%s engine errors" % name, not scan["errors"], "\n".join(scan["errors"])))
    checks.append(("%s audio/render warnings" % name, not scan["warn_fail"], "\n".join(scan["warn_fail"])))
    if scan["warn_info"]:
        print("  %s other warnings (not failing):\n    %s" % (name, "\n    ".join(scan["warn_info"])))
    return checks


def smoke_checks(size: str, parsed: dict, out_dir: Path, level_ids) -> list:
    """Checks of a smoke probe run: every screen ok with enough PNGs on disk, music, effects and animation."""
    checks = []
    screens = {s[0]: s for s in parsed["screen"]}
    for screen in ["title"] + list(level_ids):
        entry = screens.get(screen)
        pngs = sorted(Path(out_dir).glob("%s_[0-9].png" % screen)) if Path(out_dir).is_dir() else []
        ok = entry is not None and entry[2] == "true" and len(pngs) >= MIN_SHOTS
        checks.append(("smoke %s %s" % (size, screen), ok,
                       "" if ok else "screen line %s, %d PNGs in %s" % (entry, len(pngs), out_dir)))
    for screen, expected, actual, errors in parsed["music"]:
        ok = expected != "" and expected == actual and errors == "0"
        checks.append(("music %s %s" % (size, screen), ok, "expected %s, got %s, errors %s" % (expected, actual, errors)))
    for level, shake, puff, splat in parsed["fx"]:
        ok = int(shake) > 0 and int(puff) + int(splat) > 0
        checks.append(("fx %s %s" % (size, level), ok, "shake=%s puff=%s splat=%s" % (shake, puff, splat)))
    for level, changed, threshold, ok in parsed["anim"]:
        checks.append(("anim %s %s" % (size, level), ok == "true", "changed %s < %s" % (changed, threshold)))
    return checks


def clip_checks(size: str, parsed: dict, measure_castaway: bool) -> list:
    """Checks of a clip probe run: no clip errors, the overlong fixture is detected, castaway at least 64 px."""
    checks = []
    if not parsed["clip"]:
        checks.append(("clip %s" % size, False, "no CLIP lines"))
    for screen, csize, _locale, errors in parsed["clip"]:
        detail = "\n".join(e for e in parsed["clip_errors"] if ("%s@%s" % (screen, csize)) in e) or errors
        checks.append(("clip %s %s" % (csize, screen), errors == "0", detail))
    detected = int(parsed["fixture"][-1][0]) if parsed["fixture"] else 0
    checks.append(("clip %s overlong fixture detected" % size, detected > 0, "detected=%d" % detected))
    for prompts, cue, hud_cue, together in parsed["hud_state"]:
        checks.append(("clip %s HUD, prompts and cues together" % size, together == "true",
                       "prompts=%s level_cue=%s hud_cue=%s" % (prompts, cue, hud_cue)))
    if measure_castaway:
        if not parsed["castaway"]:
            checks.append(("castaway %s" % size, False, "no CASTAWAY lines"))
        for level, px, px_1080 in parsed["castaway"]:
            checks.append(("castaway %s %s" % (size, level), castaway_ok(float(px_1080)),
                           "%s px at 1080p (minimum %d)" % (px_1080, MIN_CASTAWAY_PX)))
    return checks


def perf_checks(size: str, parsed: dict, base: Path) -> list:
    """Reads the probe's frame file, writes perf_<WxH>.json and checks that no frame after 1 s exceeds 33 ms."""
    if not parsed["perf_frames"]:
        return [("perf %s" % size, False, "no PERF_FRAMES line")]
    path = Path(parsed["perf_frames"][-1][0])
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return [("perf %s" % size, False, "cannot read %s: %s" % (path, exc))]
    summary = perf_summary(data.get("frame_ms", []))
    line = format_perf(size, summary)
    print("  " + line)
    report = dict(summary, size=size, level=data.get("level"), events_triggered=data.get("events_triggered"),
                  physics_per_s=data.get("physics_per_s"), vsync_mode=data.get("vsync_mode"), line=line)
    (Path(base) / ("perf_%s.json" % size)).write_text(json.dumps(report, indent=1), encoding="utf-8")
    seconds = sum(float(ms) for ms in data.get("frame_ms", [])) / 1000.0
    return [("perf %s frame time" % size, summary["over_33"] == 0 and summary["frames"] > 0, line),
            ("perf %s covers 60 s" % size, seconds >= 59.0, "%.1f s recorded" % seconds)]


def campaign_ids() -> list:
    data = json.loads((REPO / "data" / "campaign.json").read_text(encoding="utf-8"))
    return [entry["id"] for entry in data.get("levels", []) if entry.get("available", True)]


def run_stage(stage: str, base: Path = None, sizes=DEFAULT_SIZES, godot=None) -> list:
    """Run one windowed stage for every size; return [(check name, ok, detail)]."""
    base = Path(base or TESTDATA / "smoke")
    godot = godot or find_godot(console=False)
    if godot is None:
        return [("%s windowed Godot binary" % stage, False, "windowed Godot binary not found (set GODOT_BIN)")]
    checks = []
    for size in sizes:
        print("  %s %s ..." % (stage, size))
        parsed, scan, rc, text = run_probe(godot, stage, size, base)
        checks += _common_checks("%s %s" % (stage, size), parsed, scan, rc, text)
        if stage == "smoke":
            checks += smoke_checks(size, parsed, base / size, campaign_ids())
        elif stage == "perf":
            checks += perf_checks(size, parsed, base)
        else:
            checks += clip_checks(size, parsed, size == "1920x1080")
    return checks


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--stage", choices=STAGES + ("all",), default="all")
    parser.add_argument("--sizes", default=",".join(DEFAULT_SIZES))
    opts = parser.parse_args(argv)
    godot = find_godot(console=False)
    if godot is None:
        print("windowed Godot binary not found (set GODOT_BIN)", file=sys.stderr)
        return EXIT_NO_GODOT
    sizes = [s.strip() for s in opts.sizes.split(",") if s.strip()]
    stages = STAGES if opts.stage == "all" else (opts.stage,)
    failed = 0
    for stage in stages:
        for name, ok, detail in run_stage(stage, sizes=sizes, godot=godot):
            if not ok:
                failed += 1
                print("FAIL %s%s" % (name, ("\n    " + detail.replace("\n", "\n    ")) if detail else ""))
    print("output: %s" % (TESTDATA / "smoke"))
    print("SMOKE WINDOWED %s (%d failed checks)" % ("OK" if failed == 0 else "FAIL", failed))
    return EXIT_OK if failed == 0 else EXIT_FAIL


if __name__ == "__main__":
    sys.exit(main())
