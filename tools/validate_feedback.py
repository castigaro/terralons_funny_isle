"""Validate data/feedback.json and data/balance/feedback.json (standard library only).

Usage: python tools/validate_feedback.py [--root <dir>] [--feedback <file>] [--balance <file>] [--event-bus <file>]
(exit code 1 on any error)

Checks:
- schema: format_version, no unknown top-level, signal or entry keys, effect and anchor enums;
- coverage: every custom signal of scripts/autoload/event_bus.gd is mapped or listed in no_visual (not both), no key
  names anything else (Node built-ins such as ready are rejected), every signal has at most 4 arguments, the
  required gameplay signals have visual entries and every event type of data/events.json has a warning entry;
- entries: the strength key exists under balance strengths.<effect>, sound words exist in i18n with EN and DE text
  of at most 8 characters plus "!", assets and every animation frame exist, lie in an imported folder (no
  .gdignore), match no deny-list token and their folder appears in a backticked path of docs/asset_map.md;
- family-friendly materials: exactly mud, water and sand with colours that are not red-dominant; splats need one;
- balance: unknown or missing keys (recursive schema), hit-stop at most hitstop_max_ms and at most 80 ms, cooldown at
  least the longest hit-stop, 0 < hitstop_time_scale < 1, 0 <= reduce_motion_factor <= 0.25, 0 <= fx_scale <= 1,
  popup_seconds <= 1.2, emote_seconds <= 2, flash alpha <= 0.4, flash_min_interval_ms >= 334 (at most 3 flashes per
  second) and every cap >= 1.
"""
import argparse
import functools
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import REPO  # noqa: E402
from validate_assets import asset_files, deny_hits, load_deny  # noqa: E402
from validate_i18n import load_catalog  # noqa: E402

FEEDBACK_REL = "data/feedback.json"
BALANCE_REL = "data/balance/feedback.json"
EVENT_BUS_REL = "scripts/autoload/event_bus.gd"
EVENTS_REL = "data/events.json"
ASSET_MAP_REL = "docs/asset_map.md"
FORMAT_VERSION = 1
SIGNAL_RE = re.compile(r"^signal\s+(\w+)\s*\(([^)]*)\)", re.M)
BACKTICK_RE = re.compile(r"`([^`]+)`")
HEX_RE = re.compile(r"^#[0-9A-Fa-f]{6}$")
MAX_ARGS = 4
MAX_WORD = 8
MAX_HITSTOP_MS = 80
MAX_REDUCE = 0.25
MAX_POPUP_SECONDS = 1.2
MAX_EMOTE_SECONDS = 2.0
MAX_FLASH_ALPHA = 0.4
MIN_FLASH_INTERVAL_MS = 334

TOP_KEYS = {"format_version", "materials", "no_visual", "signals", "events"}
SIGNAL_KEYS = {"variant_arg", "default", "variants"}
ENTRY_KEYS = {"effect", "anchor", "strength", "asset", "frames", "frame_count", "word", "material", "offset"}
EFFECTS = ("popup", "splat", "puff", "particles", "emote", "shake", "flash", "hitstop", "squash", "recoil")
ANCHORS = ("auto", "screen", "follow", "event_zone")
PHASES = ("warning", "start")
EVENT_SIGNALS = {"event_warning": "warning", "event_triggered": "start"}
MATERIALS = {"mud", "water", "sand"}
NEEDS_ASSET = {"particles", "emote"}
NEEDS_FRAMES = {"puff", "splat", "flash"}
REQUIRED_VISUAL = (
    "castaway_step", "castaway_dashed", "object_grabbed", "object_thrown", "object_landed", "object_used",
    "task_completed", "object_bonked", "animal_fled", "animal_bonked", "animal_panicked", "animal_caught",
    "animal_lured", "timer_warning", "event_triggered", "event_warning",
)
CAP_TYPES = ("popup", "splat", "puff", "particles", "emote", "shake", "flash", "squash", "recoil")
STRENGTH_FIELDS = {
    "shake": ("amplitude", "trauma"),
    "hitstop": ("ms",),
    "squash": ("x", "y", "seconds"),
    "particles": ("amount", "lifetime", "speed", "spread", "scale"),
    "flash": ("alpha",),
    "popup": ("scale",),
    "puff": ("scale",),
    "splat": ("scale",),
    "emote": ("scale",),
    "recoil": ("px", "seconds"),
}
NUM, INT, VEC2 = "number", "integer", "vec2"
BALANCE_SCHEMA = {
    "schema_version": INT, "fx_scale": NUM, "hitstop_scale": NUM, "reduce_motion_factor": NUM,
    "hitstop_max_ms": NUM, "hitstop_time_scale": NUM, "hitstop_cooldown_ms": NUM, "hitstop_safety_grace_ms": NUM,
    "flash_min_interval_ms": NUM, "shake_decay_per_second": NUM, "shake_noise_speed": NUM, "shake_seed": INT,
    "popup_font_size": INT, "popup_outline_size": INT, "popup_rise_px": NUM, "popup_seconds": NUM,
    "popup_pop_seconds": NUM, "popup_pop_scale": NUM, "popup_face_offset": VEC2, "popup_screen_offset": VEC2,
    "popup_stack_px": NUM, "popup_stack_radius": NUM,
    "emote_seconds": NUM, "emote_pop_seconds": NUM, "emote_scale": NUM, "emote_height": NUM, "puff_seconds": NUM,
    "puff_scale": NUM, "splat_seconds": NUM, "splat_fade_seconds": NUM, "splat_scale": NUM, "splat_alpha": NUM,
    "flash_seconds": NUM, "flash_scale": NUM, "particle_lifetime_margin": NUM,
    "z": {"splat": INT, "fx": INT, "popup": INT},
    "screen_layer": INT,
    "caps": {t: INT for t in CAP_TYPES},
    "strengths": "strengths",
}


def is_num(v) -> bool:
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def is_int(v) -> bool:
    return is_num(v) and float(v) == int(v)


def load_json(path: Path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8")), ""
    except (OSError, UnicodeDecodeError) as exc:
        return None, "cannot read (%s)" % exc
    except ValueError as exc:
        return None, "invalid JSON (%s)" % exc


def custom_signals(text: str) -> dict:
    """Return {signal name: [argument names]} of the signal declarations in GDScript source."""
    out = {}
    for match in SIGNAL_RE.finditer(text):
        args = [part.strip().split(":", 1)[0].strip() for part in match.group(2).split(",") if part.strip()]
        out[match.group(1)] = args
    return out


def asset_map_folders(root: Path) -> set:
    """Return the folders of every backticked path in docs/asset_map.md (without res:// and trailing slash)."""
    path = Path(root) / ASSET_MAP_REL
    if not path.is_file():
        return set()
    folders = set()
    for text in BACKTICK_RE.findall(path.read_text(encoding="utf-8")):
        rel = text.replace("res://", "").strip()
        if not rel.startswith("assets/"):
            continue
        folders.add(rel.rstrip("/") if rel.endswith("/") else rel.rsplit("/", 1)[0])
    return folders


def red_dominant(hex_colour: str) -> bool:
    r, g, b = (int(hex_colour[i:i + 2], 16) / 255.0 for i in (1, 3, 5))
    return r >= 0.55 and r > g * 1.6 and r > b * 1.6


# --- balance ---------------------------------------------------------------------------------------------

def _check_schema(value, schema, path: str, errors: list) -> None:
    if schema == NUM:
        if not is_num(value):
            errors.append("%s: must be a number" % path)
    elif schema == INT:
        if not is_int(value):
            errors.append("%s: must be an integer" % path)
    elif schema == VEC2:
        if not (isinstance(value, list) and len(value) == 2 and all(is_num(v) for v in value)):
            errors.append("%s: must be [x, y]" % path)
    elif schema == "strengths":
        _check_strengths(value, path, errors)
    elif isinstance(schema, dict):
        if not isinstance(value, dict):
            errors.append("%s: must be an object" % path)
            return
        for key in value:
            if key not in schema:
                errors.append("%s.%s: unknown key" % (path, key))
        for key, sub in schema.items():
            if key not in value:
                errors.append("%s.%s: missing" % (path, key))
            else:
                _check_schema(value[key], sub, "%s.%s" % (path, key), errors)


def _check_strengths(value, path: str, errors: list) -> None:
    if not isinstance(value, dict):
        errors.append("%s: must be an object" % path)
        return
    for effect, group in value.items():
        if effect not in STRENGTH_FIELDS:
            errors.append("%s.%s: unknown effect" % (path, effect))
            continue
        if not isinstance(group, dict) or not group:
            errors.append("%s.%s: must be a non-empty object" % (path, effect))
            continue
        for key, entry in group.items():
            at = "%s.%s.%s" % (path, effect, key)
            if not isinstance(entry, dict):
                errors.append("%s: must be an object" % at)
                continue
            fields = STRENGTH_FIELDS[effect]
            for field in entry:
                if field not in fields:
                    errors.append("%s.%s: unknown key" % (at, field))
            for field in fields:
                if not is_num(entry.get(field)):
                    errors.append("%s.%s: missing or not a number" % (at, field))
                elif entry[field] < 0:
                    errors.append("%s.%s: must be >= 0" % (at, field))


def _range(errors: list, data: dict, key: str, lo=None, hi=None, lo_open=False, hi_open=False) -> None:
    v = data.get(key)
    if not is_num(v):
        return
    if lo is not None and (v <= lo if lo_open else v < lo):
        errors.append("balance %s: %s must be %s %s" % (key, v, ">" if lo_open else ">=", lo))
    if hi is not None and (v >= hi if hi_open else v > hi):
        errors.append("balance %s: %s must be %s %s" % (key, v, "<" if hi_open else "<=", hi))


def validate_balance(data) -> list:
    """Return the errors of the parsed balance file data/balance/feedback.json."""
    if not isinstance(data, dict):
        return ["balance: top level must be an object"]
    errors = []
    _check_schema(data, BALANCE_SCHEMA, "balance", errors)
    _range(errors, data, "fx_scale", 0, 1)
    _range(errors, data, "hitstop_scale", 0, 1)
    _range(errors, data, "reduce_motion_factor", 0, MAX_REDUCE)
    _range(errors, data, "hitstop_time_scale", 0, 1, lo_open=True, hi_open=True)
    _range(errors, data, "hitstop_max_ms", 0, MAX_HITSTOP_MS)
    _range(errors, data, "popup_seconds", 0, MAX_POPUP_SECONDS, lo_open=True)
    _range(errors, data, "emote_seconds", 0, MAX_EMOTE_SECONDS, lo_open=True)
    _range(errors, data, "flash_min_interval_ms", MIN_FLASH_INTERVAL_MS)
    _range(errors, data, "splat_alpha", 0, 1)
    strengths = data.get("strengths") if isinstance(data.get("strengths"), dict) else {}
    max_ms = data.get("hitstop_max_ms") if is_num(data.get("hitstop_max_ms")) else MAX_HITSTOP_MS
    longest = 0
    for key, entry in (strengths.get("hitstop") or {}).items():
        ms = entry.get("ms") if isinstance(entry, dict) else None
        if is_num(ms):
            longest = max(longest, min(ms, max_ms))
            if ms > max_ms or ms > MAX_HITSTOP_MS:
                errors.append("balance strengths.hitstop.%s.ms: %s exceeds %s ms" % (key, ms,
                                                                                   min(max_ms, MAX_HITSTOP_MS)))
    cooldown = data.get("hitstop_cooldown_ms")
    if is_num(cooldown) and cooldown < longest:
        errors.append("balance hitstop_cooldown_ms: %s is shorter than the longest hit-stop %s ms" % (cooldown, longest))
    for key, entry in (strengths.get("flash") or {}).items():
        alpha = entry.get("alpha") if isinstance(entry, dict) else None
        if is_num(alpha) and alpha > MAX_FLASH_ALPHA:
            errors.append("balance strengths.flash.%s.alpha: %s exceeds %s" % (key, alpha, MAX_FLASH_ALPHA))
    for key, entry in (strengths.get("shake") or {}).items():
        trauma = entry.get("trauma") if isinstance(entry, dict) else None
        if is_num(trauma) and trauma > 1:
            errors.append("balance strengths.shake.%s.trauma: %s exceeds 1" % (key, trauma))
    for key, cap in (data.get("caps") or {}).items() if isinstance(data.get("caps"), dict) else []:
        if is_num(cap) and cap < 1:
            errors.append("balance caps.%s: %s must be >= 1" % (key, cap))
    return errors


# --- feedback map ----------------------------------------------------------------------------------------

@functools.lru_cache(maxsize=4)
def repo_info(root: str):
    """Return (i18n catalog, deny list, imported asset files, asset map folders) of a root (cached per run)."""
    path = Path(root)
    catalog, _errors = load_catalog(path)
    deny, _deny_errors = load_deny(path)
    _all, imported = asset_files(path)
    return catalog, deny, frozenset(imported), frozenset(asset_map_folders(path))


class Context:
    """Everything the entry checks need from the repository."""

    def __init__(self, root: Path, strengths: dict, materials: dict):
        self.root = Path(root)
        self.strengths = strengths
        self.materials = materials
        self.catalog, self.deny, self.imported, self.map_folders = repo_info(str(self.root.resolve()))


def _asset_errors(res_path: str, at: str, ctx: Context) -> list:
    if not isinstance(res_path, str) or not res_path.startswith("res://assets/"):
        return ["%s: asset %r must start with res://assets/" % (at, res_path)]
    rel = res_path[len("res://"):]
    errors = []
    if not (ctx.root / rel).is_file():
        errors.append("%s: missing asset %s" % (at, rel))
    elif rel[len("assets/"):] not in ctx.imported:
        errors.append("%s: %s lies in a folder Godot does not import (.gdignore)" % (at, rel))
    hits = deny_hits(rel.rsplit("/", 1)[-1], ctx.deny)
    if hits:
        errors.append("%s: asset %s matches the deny list (%s)" % (at, rel, ", ".join(hits)))
    folder = rel.rsplit("/", 1)[0]
    if folder not in ctx.map_folders:
        errors.append("%s: folder %s is not named in %s" % (at, folder, ASSET_MAP_REL))
    return errors


def check_entries(entries, where: str, ctx: Context) -> list:
    if not isinstance(entries, list):
        return ["%s: must be a list" % where]
    errors = []
    for i, entry in enumerate(entries):
        at = "%s[%d]" % (where, i)
        if not isinstance(entry, dict):
            errors.append("%s: must be an object" % at)
            continue
        for key in entry:
            if key not in ENTRY_KEYS:
                errors.append("%s.%s: unknown key" % (at, key))
        effect = entry.get("effect")
        if effect not in EFFECTS:
            errors.append("%s.effect: unknown effect %r" % (at, effect))
            continue
        anchor = entry.get("anchor", "auto")
        if anchor not in ANCHORS:
            errors.append("%s.anchor: unknown anchor %r" % (at, anchor))
        strength = entry.get("strength")
        group = ctx.strengths.get(effect)
        if not isinstance(group, dict) or strength not in group:
            errors.append("%s.strength: balance strengths.%s.%s missing" % (at, effect, strength))
        material = entry.get("material")
        if material is not None and material not in ctx.materials:
            errors.append("%s.material: unknown material %r" % (at, material))
        if effect == "splat" and material is None:
            errors.append("%s: a splat needs a material (mud, water or sand)" % at)
        if effect == "popup":
            word = entry.get("word")
            texts = ctx.catalog.get(word) if isinstance(word, str) else None
            if texts is None:
                errors.append("%s.word: unknown i18n key %r" % (at, word))
            else:
                for loc in ("en", "de"):
                    text = (texts.get(loc) or "").strip()
                    if not text:
                        errors.append("%s.word: %s has no %s text" % (at, word, loc))
                    elif len(text.rstrip("!")) > MAX_WORD:
                        errors.append("%s.word: %s %s text %r longer than %d characters plus '!'"
                                      % (at, word, loc, text, MAX_WORD))
        if effect in NEEDS_ASSET:
            if "asset" not in entry:
                errors.append("%s: %s needs an asset" % (at, effect))
            else:
                errors.extend(_asset_errors(entry["asset"], at, ctx))
        if effect in NEEDS_FRAMES:
            pattern = entry.get("frames")
            count = entry.get("frame_count")
            if not isinstance(pattern, str) or "%" not in pattern or not is_int(count) or count < 1:
                errors.append("%s: %s needs frames (a %%02d pattern) and frame_count >= 1" % (at, effect))
            else:
                for n in range(int(count)):
                    try:
                        frame = pattern % n
                    except (TypeError, ValueError):
                        errors.append("%s.frames: bad pattern %r" % (at, pattern))
                        break
                    errors.extend(_asset_errors(frame, at, ctx))
        offset = entry.get("offset")
        if offset is not None and not (isinstance(offset, list) and len(offset) == 2 and all(is_num(v) for v in offset)):
            errors.append("%s.offset: must be [x, y]" % at)
    return errors


def _has_entries(spec) -> bool:
    if not isinstance(spec, dict):
        return False
    if isinstance(spec.get("default"), list) and spec["default"]:
        return True
    variants = spec.get("variants")
    return isinstance(variants, dict) and any(isinstance(v, list) and v for v in variants.values())


def validate_feedback(data, signals: dict, event_types, ctx: Context) -> list:
    """Return the errors of the parsed data/feedback.json against the EventBus signals and event types."""
    if not isinstance(data, dict):
        return ["feedback: top level must be an object"]
    errors = []
    for key in data:
        if key not in TOP_KEYS:
            errors.append("feedback: unknown top-level key %s" % key)
    if data.get("format_version") != FORMAT_VERSION:
        errors.append("feedback: format_version must be %d" % FORMAT_VERSION)
    for name, args in signals.items():
        if len(args) > MAX_ARGS:
            errors.append("event_bus: signal %s has %d arguments (at most %d)" % (name, len(args), MAX_ARGS))
    materials = data.get("materials")
    if not isinstance(materials, dict) or set(materials) != MATERIALS:
        errors.append("feedback: materials must be exactly %s" % ", ".join(sorted(MATERIALS)))
    if isinstance(materials, dict):
        for name, colour in materials.items():
            if not isinstance(colour, str) or not HEX_RE.match(colour):
                errors.append("feedback: materials.%s: colour %r must be #rrggbb" % (name, colour))
            elif red_dominant(colour):
                errors.append("feedback: materials.%s: colour %s is red-dominant (looks like blood)" % (name, colour))
    no_visual = data.get("no_visual") if isinstance(data.get("no_visual"), dict) else {}
    if not isinstance(data.get("no_visual"), dict):
        errors.append("feedback: no_visual must be an object")
    for name, reason in no_visual.items():
        if name not in signals:
            errors.append("feedback: no_visual.%s: not a custom EventBus signal" % name)
        if not isinstance(reason, str) or not reason.strip():
            errors.append("feedback: no_visual.%s: needs a reason" % name)
    mapped = data.get("signals") if isinstance(data.get("signals"), dict) else {}
    if not isinstance(data.get("signals"), dict):
        errors.append("feedback: signals must be an object")
    for name, spec in mapped.items():
        where = "feedback: signals.%s" % name
        if name not in signals:
            errors.append("%s: not a custom EventBus signal" % where)
            continue
        if name in no_visual:
            errors.append("%s: also listed in no_visual" % where)
        if not isinstance(spec, dict):
            errors.append("%s: must be an object" % where)
            continue
        for key in spec:
            if key not in SIGNAL_KEYS:
                errors.append("%s.%s: unknown key" % (where, key))
        variant_arg = spec.get("variant_arg")
        if variant_arg is not None and variant_arg not in signals[name]:
            errors.append("%s.variant_arg: %r is not an argument of %s" % (where, variant_arg, name))
        if "variants" in spec and variant_arg is None:
            errors.append("%s: variants need a variant_arg" % where)
        errors.extend(check_entries(spec.get("default", []), where + ".default", ctx))
        variants = spec.get("variants", {})
        if not isinstance(variants, dict):
            errors.append("%s.variants: must be an object" % where)
        else:
            for value, entries in variants.items():
                errors.extend(check_entries(entries, "%s.variants.%s" % (where, value), ctx))
    events = data.get("events") if isinstance(data.get("events"), dict) else {}
    if not isinstance(data.get("events"), dict):
        errors.append("feedback: events must be an object")
    for etype, spec in events.items():
        where = "feedback: events.%s" % etype
        if etype not in event_types:
            errors.append("%s: unknown event type" % where)
        if not isinstance(spec, dict):
            errors.append("%s: must be an object" % where)
            continue
        for phase, entries in spec.items():
            if phase not in PHASES:
                errors.append("%s.%s: unknown phase" % (where, phase))
            else:
                errors.extend(check_entries(entries, "%s.%s" % (where, phase), ctx))
    for etype in event_types:
        spec = events.get(etype)
        if not isinstance(spec, dict) or not isinstance(spec.get("warning"), list) or not spec["warning"]:
            errors.append("feedback: events.%s.warning: every event type needs a warning entry" % etype)
    for name in signals:
        covered = name in mapped or name in no_visual or name in EVENT_SIGNALS
        if not covered:
            errors.append("feedback: signal %s is neither mapped nor listed in no_visual" % name)
    for name in REQUIRED_VISUAL:
        if name not in signals:
            continue
        if name in EVENT_SIGNALS:
            phase = EVENT_SIGNALS[name]
            ok = _has_entries(mapped.get(name)) or (bool(event_types) and all(
                isinstance(events.get(t), dict) and events[t].get(phase) for t in event_types))
        else:
            ok = _has_entries(mapped.get(name))
        if not ok:
            errors.append("feedback: signal %s needs at least one visual entry" % name)
    return errors


def validate(root: Path = REPO, feedback: Path = None, balance: Path = None, event_bus: Path = None) -> list:
    """Return every feedback error below root (empty = valid)."""
    root = Path(root)
    feedback = Path(feedback) if feedback else root / FEEDBACK_REL
    balance = Path(balance) if balance else root / BALANCE_REL
    event_bus = Path(event_bus) if event_bus else root / EVENT_BUS_REL
    errors = []
    bal, err = load_json(balance)
    if err:
        return ["balance %s: %s" % (balance.name, err)]
    errors.extend(validate_balance(bal))
    data, err = load_json(feedback)
    if err:
        return errors + ["feedback %s: %s" % (feedback.name, err)]
    try:
        signals = custom_signals(event_bus.read_text(encoding="utf-8"))
    except OSError as exc:
        return errors + ["event_bus: cannot read (%s)" % exc]
    events, err = load_json(root / EVENTS_REL)
    event_types = events.get("types", {}) if isinstance(events, dict) and not err else {}
    if err:
        errors.append("%s: %s" % (EVENTS_REL, err))
    strengths = bal.get("strengths") if isinstance(bal, dict) and isinstance(bal.get("strengths"), dict) else {}
    materials = data.get("materials") if isinstance(data, dict) and isinstance(data.get("materials"), dict) else {}
    ctx = Context(root, strengths, materials)
    errors.extend(validate_feedback(data, signals, event_types, ctx))
    return errors


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Validate the feedback map and its balance values.")
    parser.add_argument("--root", default=str(REPO))
    parser.add_argument("--feedback", default="")
    parser.add_argument("--balance", default="")
    parser.add_argument("--event-bus", default="")
    opts = parser.parse_args(argv)
    errors = validate(Path(opts.root), opts.feedback or None, opts.balance or None, opts.event_bus or None)
    for err in errors:
        print("feedback: " + err if not err.startswith("feedback:") else err)
    print("validate_feedback: %d error(s)" % len(errors))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
