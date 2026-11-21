"""Validate the event catalogue data/events.json and the level files data/levels/*.json (standard library only).

Usage: python tools/validate_levels.py [--root DIR] [--path FILE] [--i18n-dir DIR ...]   (exit code 1 on errors)

Limits (timer range, task and event counts) come from data/balance/rules.json. Text keys must exist with
non-empty EN and DE text in root/i18n/*.csv plus every --i18n-dir. The level music must be a key of the
"music" section of root/data/audio.json when that file exists. One line per error:
"<file>: <field path>: <message>". A missing or empty data/levels folder is valid. Tasks of the real levels
below root/data/levels need a title_key (the HUD task name); test fixtures may omit it. The GDScript loader
scripts/rules/level_def.gd implements the same rule set (see docs/rules.md).
"""
import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import REPO  # noqa: E402
from validate_i18n import load_catalog, load_catalog_dir  # noqa: E402

FORMAT_VERSION = 1
RULES_FILE = "data/balance/rules.json"
EVENTS_FILE = "data/events.json"
LEVELS_DIR = "data/levels"
ID_RE = re.compile(r"^[a-z][a-z0-9_]*$")
PLAYER = "player"
WARNING_LEAD_KEY = "event_warning_lead_seconds"
RULE_KEYS = ("timer_min_seconds", "timer_max_seconds", "tasks_min", "tasks_max", "events_min")

LEVEL_REQUIRED = ("format_version", "id", "title_key", "theme", "music", "seed", "timer_seconds", "tasks",
                  "events")
LEVEL_OPTIONAL = ("three_star_share", "prompts", "notes")
TASK_REQUIRED = ("id", "required", "conditions", "hint_key", "fail_key")
TASK_OPTIONAL = ("modifiers", "title_key")
# Contextual key prompts (BI-6); the level scene checks that zone and entity anchors exist.
PROMPT_FIELDS = ("id", "anchor", "action", "text_key")
PROMPT_ACTIONS = ("move", "dash", "grab", "throw", "use")
ANCHOR_RE = re.compile(r"^(player|zone:[a-z][a-z0-9_]*|entity:[a-z][a-z0-9_]*)$")
EVENT_REQUIRED = ("id", "type", "window", "duration_s")
EVENT_OPTIONAL = ("params",)

# Condition grammar: type -> ({required field: kind}, {optional field: kind}); kinds: name, count, seconds, event.
CONDITIONS = {
    "in_zone": ({"entity": "name", "zone": "name"}, {"count": "count"}),
    "held": ({"entity": "name"}, {}),
    "worn": ({"item": "name"}, {"wearer": "name"}),
    "delivered_to": ({"entity": "name", "target": "name"}, {"count": "count"}),
    "count_reached": ({"counter": "name", "count": "count"}, {}),
    "before_time": ({"seconds": "seconds"}, {}),
}
MODIFIERS = dict(CONDITIONS)
MODIFIERS["before_event"] = ({"event": "event"}, {})
TIME_TYPES = ("before_time", "before_event")
# Condition fields that name an entity kind (checked against data/animals.json and data/items.json, except player).
ENTITY_FIELDS = {"in_zone": ("entity",), "held": ("entity",), "delivered_to": ("entity",), "worn": ("item", "wearer")}
ANIMALS_FILE = "data/animals.json"
ITEMS_FILE = "data/items.json"
AUDIO_FILE = "data/audio.json"

EFFECTS = ("relocate_entities", "take_held", "take_worn", "stun_player", "panic_animals", "slippery_ground")
PARAM_TYPES = ("string", "int", "float", "bool")


def is_int(value) -> bool:
    """True for ints and integral floats, never for bools (matches Balance.normalize_json in GDScript)."""
    if isinstance(value, bool):
        return False
    if isinstance(value, int):
        return True
    return isinstance(value, float) and value == value and abs(value) != float("inf") and value == int(value)


def is_number(value) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def is_name(value) -> bool:
    return isinstance(value, str) and ID_RE.match(value) is not None


def load_json(path: Path):
    """Return (data, error) for a JSON file."""
    try:
        return json.loads(Path(path).read_text(encoding="utf-8")), ""
    except (OSError, UnicodeDecodeError) as exc:
        return None, "cannot read (%s)" % exc
    except ValueError as exc:
        return None, "invalid JSON (%s)" % exc


def load_rules(root: Path):
    """Return (rules dict, errors) from root/data/balance/rules.json."""
    data, err = load_json(Path(root) / RULES_FILE)
    if err:
        return {}, ["%s: %s" % (RULES_FILE, err)]
    if not isinstance(data, dict):
        return {}, ["%s: top level must be an object" % RULES_FILE]
    errors = ["%s: %s: missing or not an integer" % (RULES_FILE, key) for key in RULE_KEYS
              if not is_int(data.get(key))]
    lead = data.get(WARNING_LEAD_KEY, 0)
    if isinstance(lead, bool) or not isinstance(lead, (int, float)) or lead < 0:
        errors.append("%s: %s: must be a number >= 0" % (RULES_FILE, WARNING_LEAD_KEY))
    return data, errors


def load_entity_kinds(root: Path) -> set:
    """Return the animal and item kinds of root/data (empty when the files are missing or broken)."""
    kinds = set()
    for rel, key in ((ANIMALS_FILE, "animals"), (ITEMS_FILE, "items")):
        data, err = load_json(Path(root) / rel)
        if not err and isinstance(data, dict) and isinstance(data.get(key), dict):
            kinds.update(data[key])
    return kinds


def load_music_ids(root: Path) -> set:
    """Return the music ids of root/data/audio.json (empty when the file is missing or broken)."""
    data, err = load_json(Path(root) / AUDIO_FILE)
    if err or not isinstance(data, dict) or not isinstance(data.get("music"), dict):
        return set()
    return set(data["music"])


def validate_event_types(data, fname: str = "events.json") -> list:
    """Return the errors of an event catalogue (the parsed data/events.json)."""
    errors = []
    if not isinstance(data, dict):
        return ["%s: top level must be an object" % fname]
    for key in data:
        if key not in ("format_version", "types"):
            errors.append("%s: %s: unknown field" % (fname, key))
    if not is_int(data.get("format_version")) or int(data.get("format_version")) != FORMAT_VERSION:
        errors.append("%s: format_version: must be %d" % (fname, FORMAT_VERSION))
    types = data.get("types")
    if not isinstance(types, dict) or not types:
        errors.append("%s: types: must be a non-empty object" % fname)
        return errors
    for name, spec in types.items():
        path = "types.%s" % name
        if not is_name(name):
            errors.append("%s: %s: type name must match %s" % (fname, path, ID_RE.pattern))
        if not isinstance(spec, dict):
            errors.append("%s: %s: must be an object" % (fname, path))
            continue
        for key in spec:
            if key not in ("params", "effects"):
                errors.append("%s: %s.%s: unknown field" % (fname, path, key))
        params = spec.get("params", {})
        if not isinstance(params, dict):
            errors.append("%s: %s.params: must be an object" % (fname, path))
        else:
            for pname, pspec in params.items():
                ppath = "%s.params.%s" % (path, pname)
                if not is_name(pname):
                    errors.append("%s: %s: parameter name must match %s" % (fname, ppath, ID_RE.pattern))
                if not isinstance(pspec, dict) or set(pspec) != {"type", "required"}:
                    errors.append("%s: %s: must be {type, required}" % (fname, ppath))
                    continue
                if pspec["type"] not in PARAM_TYPES:
                    errors.append("%s: %s.type: must be one of %s" % (fname, ppath, ", ".join(PARAM_TYPES)))
                if not isinstance(pspec["required"], bool):
                    errors.append("%s: %s.required: must be a bool" % (fname, ppath))
        effects = spec.get("effects")
        if not isinstance(effects, list) or not effects:
            errors.append("%s: %s.effects: must be a non-empty list" % (fname, path))
        else:
            for effect in effects:
                if effect not in EFFECTS:
                    errors.append("%s: %s.effects: unknown effect %r" % (fname, path, effect))
    return errors


def _check_keys(obj: dict, required, optional, path: str, err) -> None:
    for key in required:
        if key not in obj:
            err("%s.%s" % (path, key) if path else key, "missing")
    for key in obj:
        if key not in required and key not in optional:
            err("%s.%s" % (path, key) if path else key, "unknown field")


def _check_text_key(value, path: str, catalog: dict, err) -> None:
    if not isinstance(value, str) or not value.strip():
        err(path, "must be a non-empty text key")
        return
    entry = catalog.get(value)
    if entry is None:
        err(path, "text key %s not found in the i18n catalogue" % value)
        return
    if not str(entry.get("en", "")).strip():
        err(path, "EN text missing or empty for %s" % value)
    if not str(entry.get("de", "")).strip():
        err(path, "DE text missing or empty for %s" % value)


def _check_condition(cond, path: str, grammar: dict, timer, event_ids, err, kinds=()) -> None:
    if not isinstance(cond, dict):
        err(path, "must be an object")
        return
    ctype = cond.get("type")
    if ctype not in grammar:
        err(path + ".type", "unknown condition type %r" % (ctype,))
        return
    required, optional = grammar[ctype]
    for key in required:
        if key not in cond:
            err("%s.%s" % (path, key), "missing")
    for key in cond:
        if key != "type" and key not in required and key not in optional:
            err("%s.%s" % (path, key), "unknown field")
    fields = dict(required)
    fields.update(optional)
    for key, kind in fields.items():
        if key not in cond:
            continue
        value = cond[key]
        fpath = "%s.%s" % (path, key)
        if kind == "name":
            if not is_name(value):
                err(fpath, "must match %s" % ID_RE.pattern)
        elif kind == "count":
            if not is_int(value) or int(value) < 1:
                err(fpath, "count must be an integer >= 1")
        elif kind == "seconds":
            if not is_number(value) or value <= 0 or (is_number(timer) and value > timer):
                err(fpath, "before_time seconds must be > 0 and <= timer_seconds")
        elif kind == "event":
            if value not in event_ids:
                err(fpath, "before_event must name an event of this level, got %r" % (value,))
    if not kinds:
        return
    for key in ENTITY_FIELDS.get(ctype, ()):
        name = cond.get(key)
        if is_name(name) and name != PLAYER and name not in kinds:
            err("%s.%s" % (path, key), "unknown entity kind %s (not in data/animals.json or data/items.json)" % name)


def _counting(conds) -> list:
    return [c for c in conds if isinstance(c, dict) and is_int(c.get("count")) and int(c.get("count")) > 1
            and c.get("type") in CONDITIONS]


def _check_prompts(prompts, catalog: dict, err) -> None:
    if not isinstance(prompts, list):
        err("prompts", "must be a list")
        return
    seen = {}
    for i, prompt in enumerate(prompts):
        ppath = "prompts[%d]" % i
        if not isinstance(prompt, dict):
            err(ppath, "must be an object")
            continue
        _check_keys(prompt, PROMPT_FIELDS, (), ppath, err)
        pid = prompt.get("id")
        if "id" in prompt:
            if not is_name(pid):
                err(ppath + ".id", "must match %s" % ID_RE.pattern)
            elif pid in seen:
                err(ppath + ".id", "duplicate prompt id %s (also at %s)" % (pid, seen[pid]))
            else:
                seen[pid] = ppath
        anchor = prompt.get("anchor")
        if "anchor" in prompt and (not isinstance(anchor, str) or not ANCHOR_RE.match(anchor)):
            err(ppath + ".anchor", "must be player, zone:<name> or entity:<uid>, got %s" % (anchor,))
        action = prompt.get("action")
        if "action" in prompt and action not in PROMPT_ACTIONS:
            err(ppath + ".action", "unknown action %s (one of %s)" % (action, ", ".join(PROMPT_ACTIONS)))
        if "text_key" in prompt:
            _check_text_key(prompt["text_key"], ppath + ".text_key", catalog, err)


def validate_level(data, fname: str, rules: dict, event_types: dict, catalog: dict, entity_kinds=(),
                   music_ids=(), require_titles=False) -> list:
    """Return the errors of one parsed level (pure): '<fname>: <field path>: <message>'.

    require_titles: every task needs a title_key (real levels below data/levels).

    entity_kinds: the known animal and item kinds; when empty, entity names are not checked.
    music_ids: the music ids of data/audio.json; when empty, the music id is not checked.
    """
    errors = []

    def err(path, message):
        errors.append("%s: %s: %s" % (fname, path, message))

    if not isinstance(data, dict):
        err("(top)", "top level must be an object")
        return errors
    _check_keys(data, LEVEL_REQUIRED, LEVEL_OPTIONAL, "", err)
    if "format_version" in data and (not is_int(data["format_version"])
                                     or int(data["format_version"]) != FORMAT_VERSION):
        err("format_version", "must be %d" % FORMAT_VERSION)
    stem = Path(fname).stem
    level_id = data.get("id")
    if "id" in data:
        if not is_name(level_id):
            err("id", "must match %s" % ID_RE.pattern)
        elif level_id != stem:
            err("id", "level id %s must equal the file name %s" % (level_id, stem))
    if "title_key" in data:
        _check_text_key(data["title_key"], "title_key", catalog, err)
    for key in ("theme", "music"):
        if key in data and not is_name(data[key]):
            err(key, "must match %s" % ID_RE.pattern)
    if music_ids and is_name(data.get("music")) and data["music"] not in music_ids:
        err("music", "unknown music id %s (not in the music section of %s)" % (data["music"], AUDIO_FILE))
    if "seed" in data and not is_int(data["seed"]):
        err("seed", "must be an integer")
    timer = data.get("timer_seconds")
    tmin, tmax = rules.get("timer_min_seconds"), rules.get("timer_max_seconds")
    if "timer_seconds" in data:
        if not is_int(timer):
            err("timer_seconds", "must be an integer")
            timer = None
        elif not (tmin <= timer <= tmax):
            err("timer_seconds", "%s outside %s..%s" % (timer, tmin, tmax))
    if "notes" in data and not isinstance(data["notes"], str):
        err("notes", "must be a string")
    if "three_star_share" in data:
        share = data["three_star_share"]
        if not is_number(share) or not (0 < share < 1):
            err("three_star_share", "must be a number between 0 and 1 (exclusive)")

    events = data.get("events")
    event_ids = set()
    if "events" in data:
        if not isinstance(events, list):
            err("events", "must be a list")
            events = []
        elif len(events) < rules.get("events_min", 0):
            err("events", "%d event(s), at least %s needed" % (len(events), rules.get("events_min")))
        for ev in events:
            if isinstance(ev, dict) and isinstance(ev.get("id"), str):
                event_ids.add(ev["id"])
    else:
        events = []

    tasks = data.get("tasks")
    if "tasks" in data:
        if not isinstance(tasks, list):
            err("tasks", "must be a list")
            tasks = []
        elif not (rules.get("tasks_min", 0) <= len(tasks) <= rules.get("tasks_max", 0)):
            err("tasks", "%d task(s), expected %s..%s" % (len(tasks), rules.get("tasks_min"), rules.get("tasks_max")))
    else:
        tasks = []

    ids = []
    if is_name(level_id):
        ids.append(("id", level_id))
    flags = []
    for i, task in enumerate(tasks):
        tpath = "tasks[%d]" % i
        if not isinstance(task, dict):
            err(tpath, "must be an object")
            continue
        _check_keys(task, TASK_REQUIRED, TASK_OPTIONAL, tpath, err)
        if "id" in task:
            if is_name(task["id"]):
                ids.append((tpath + ".id", task["id"]))
            else:
                err(tpath + ".id", "must match %s" % ID_RE.pattern)
        required = task.get("required")
        if "required" in task:
            if isinstance(required, bool):
                flags.append(required)
            else:
                err(tpath + ".required", "must be a bool")
        for key in ("hint_key", "fail_key", "title_key"):
            if key in task:
                _check_text_key(task[key], "%s.%s" % (tpath, key), catalog, err)
        if require_titles and "title_key" not in task:
            err(tpath + ".title_key", "missing (real levels need a task title for the HUD)")
        conds = task.get("conditions")
        if "conditions" in task:
            if not isinstance(conds, list) or not conds:
                err(tpath + ".conditions", "must be a non-empty list")
                conds = []
            for j, cond in enumerate(conds):
                _check_condition(cond, "%s.conditions[%d]" % (tpath, j), CONDITIONS, timer, event_ids, err, entity_kinds)
            if conds and all(isinstance(c, dict) and c.get("type") == "before_time" for c in conds):
                err(tpath + ".conditions", "before_time cannot be the only condition")
        else:
            conds = []
        mods = task.get("modifiers", [])
        if not isinstance(mods, list):
            err(tpath + ".modifiers", "must be a list")
            mods = []
        for j, mod in enumerate(mods):
            mpath = "%s.modifiers[%d]" % (tpath, j)
            _check_condition(mod, mpath, MODIFIERS, timer, event_ids, err, entity_kinds)
            if isinstance(mod, dict) and mod.get("type") == "before_event" and required is True:
                err(mpath + ".type", "before_event is only allowed on optional tasks")
        if len(_counting(list(conds) + list(mods))) > 1:
            err(tpath + ".conditions", "more than one condition with count > 1 (ambiguous progress target)")
    if tasks and isinstance(tasks, list):
        if True not in flags:
            err("tasks", "at least one required task is needed")
        if False not in flags:
            err("tasks", "at least one optional task is needed")

    if "prompts" in data:
        _check_prompts(data["prompts"], catalog, err)

    types = event_types if isinstance(event_types, dict) else {}
    for i, ev in enumerate(events):
        epath = "events[%d]" % i
        if not isinstance(ev, dict):
            err(epath, "must be an object")
            continue
        _check_keys(ev, EVENT_REQUIRED, EVENT_OPTIONAL, epath, err)
        if "id" in ev:
            if is_name(ev["id"]):
                ids.append((epath + ".id", ev["id"]))
            else:
                err(epath + ".id", "must match %s" % ID_RE.pattern)
        etype = ev.get("type")
        spec = types.get(etype) if isinstance(etype, str) else None
        if "type" in ev and spec is None:
            err(epath + ".type", "unknown event type %r" % (etype,))
        if "window" in ev:
            window = ev["window"]
            if not isinstance(window, list) or len(window) != 2 or not all(is_number(v) for v in window):
                err(epath + ".window", "must be [min_s, max_s]")
            elif not (0 <= window[0] <= window[1]):
                err(epath + ".window", "needs 0 <= min <= max, got %s" % window)
            elif is_number(timer) and window[1] >= timer:
                err(epath + ".window", "max %s must be below timer_seconds %s" % (window[1], timer))
        if "duration_s" in ev and (not is_number(ev["duration_s"]) or ev["duration_s"] <= 0):
            err(epath + ".duration_s", "must be a number > 0")
        params = ev.get("params", {})
        if not isinstance(params, dict):
            err(epath + ".params", "must be an object")
        elif isinstance(spec, dict):
            pspecs = spec.get("params", {})
            for pname, pspec in pspecs.items():
                if pspec.get("required") and pname not in params:
                    err("%s.params.%s" % (epath, pname), "missing required parameter")
            for pname, value in params.items():
                pspec = pspecs.get(pname)
                if pspec is None:
                    err("%s.params.%s" % (epath, pname), "unknown parameter")
                    continue
                ptype = pspec.get("type")
                ok = ((ptype == "string" and isinstance(value, str)) or (ptype == "int" and is_int(value))
                      or (ptype == "float" and is_number(value)) or (ptype == "bool" and isinstance(value, bool)))
                if not ok:
                    err("%s.params.%s" % (epath, pname), "must be of type %s" % ptype)

    reserved = {PLAYER} | set(MODIFIERS) | set(types)
    seen = {}
    for path, value in ids:
        if value in seen:
            err(path, "duplicate id %s (also at %s)" % (value, seen[value]))
        else:
            seen[value] = path
        if value in reserved:
            err(path, "id %s is a reserved word" % value)
    return errors


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Validate data/events.json and data/levels/*.json.")
    parser.add_argument("--root", default=str(REPO))
    parser.add_argument("--path", default="", help="validate only this level file")
    parser.add_argument("--i18n-dir", action="append", default=[], help="extra folder with key,en,de CSVs")
    opts = parser.parse_args(argv)
    root = Path(opts.root)

    rules, errors = load_rules(root)
    rules_ok = not errors
    events_data, err = load_json(root / EVENTS_FILE)
    if err:
        errors.append("%s: %s" % (EVENTS_FILE, err))
        event_types = {}
    else:
        errors.extend(validate_event_types(events_data, Path(EVENTS_FILE).name))
        event_types = events_data.get("types", {}) if isinstance(events_data, dict) else {}
        if not isinstance(event_types, dict):
            event_types = {}
    catalog, _cat_errors = load_catalog(root)
    entity_kinds = load_entity_kinds(root)
    music_ids = load_music_ids(root)
    for extra in opts.i18n_dir:
        more, _more_errors = load_catalog_dir(Path(extra))
        catalog.update(more)

    levels_dir = (root / LEVELS_DIR).resolve()
    if opts.path:
        files = [Path(opts.path)]
    else:
        folder = root / LEVELS_DIR
        files = sorted(folder.glob("*.json")) if folder.is_dir() else []
    if rules_ok:
        for path in files:
            data, err = load_json(path)
            if err:
                errors.append("%s: %s" % (path.name, err))
                continue
            strict = path.resolve().parent == levels_dir
            errors.extend(validate_level(data, path.name, rules, event_types, catalog, entity_kinds, music_ids,
                                         require_titles=strict))
    for line in errors:
        print(line)
    print("validate_levels: %d level file(s), %d error(s)" % (len(files), len(errors)))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
