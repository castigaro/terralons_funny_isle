"""Validate the animal and item kinds data/animals.json and data/items.json (standard library only).

Usage: python tools/validate_entities.py [--root DIR] [--animals FILE] [--items FILE] [--balance-dir DIR]
(exit code 1 on errors)

Structure: exact keys per entry, types and ranges (numbers > 0), kind ids ^[a-z][a-z0-9_]*$, animal and item kinds
disjoint, lure_item "" or a known item kind, items never swim. Sprites: the res:// path exists, lies in a folder Godot
imports (no .gdignore), has no deny-list token in its file name and is at least 24 px on its smaller side at 720p
(PNG size x sprite_scale x 720/1080). Cross-checks: name_key exists with EN and DE text in i18n/*.csv, carry_weight
lies within the castaway carry_weight_min..carry_weight_max, and bonk_seconds + panic_duration stays within
reaction_max_seconds (data/balance/entities.json). The GDScript loader scripts/gameplay/entities/entity_defs.gd
applies the same rules except the deny-list and size checks (see docs/entities.md).
"""
import argparse
import json
import re
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import REPO, split_identifier  # noqa: E402
from validate_i18n import load_catalog  # noqa: E402

FORMAT_VERSION = 1
ANIMALS_FILE = "data/animals.json"
ITEMS_FILE = "data/items.json"
BALANCE_DIR = "data/balance"
DENY_FILE = "data/assets/deny_list.json"
ID_RE = re.compile(r"^[a-z][a-z0-9_]*$")
MIN_SIDE_720P = 24.0
SCALE_720P = 720.0 / 1080.0
ANIMAL_FIELDS = {
    "sprite": "sprite", "sprite_scale": "number", "speed": "number", "wander_radius": "number",
    "flee_radius": "number", "flee_speed_factor": "number", "panic_duration": "number", "lure_item": "lure",
    "lure_radius": "number", "follow_distance": "number", "herdable": "bool", "swims": "bool",
    "carry_weight": "number", "pitch": "number", "name_key": "key",
}
ITEM_FIELDS = {
    "sprite": "sprite", "sprite_scale": "number", "carry_weight": "number", "wearable": "bool", "swims": "bool",
    "name_key": "key",
}


def is_number(value) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def load_json(path: Path):
    """Return (data, error) for a JSON file."""
    try:
        return json.loads(Path(path).read_text(encoding="utf-8")), ""
    except (OSError, UnicodeDecodeError) as exc:
        return None, "cannot read (%s)" % exc
    except ValueError as exc:
        return None, "invalid JSON (%s)" % exc


def png_size(path: Path):
    """Return (width, height) from the PNG header, or None."""
    try:
        with open(path, "rb") as handle:
            head = handle.read(24)
    except OSError:
        return None
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", head[16:24])


def _ignored(root: Path, path: Path) -> bool:
    folder = path.parent
    root = Path(root).resolve()
    while True:
        if (folder / ".gdignore").is_file():
            return True
        if folder.resolve() == root or folder.parent == folder:
            return False
        folder = folder.parent


def _section(data, key: str, fname: str, errors: list) -> dict:
    if not isinstance(data, dict):
        errors.append("%s: (top): top level must be an object" % fname)
        return {}
    for field in data:
        if field not in ("format_version", key):
            errors.append("%s: %s: unknown field" % (fname, field))
    version = data.get("format_version")
    if isinstance(version, bool) or not is_number(version) or version != FORMAT_VERSION:
        errors.append("%s: format_version: must be %d" % (fname, FORMAT_VERSION))
    entries = data.get(key)
    if not isinstance(entries, dict) or not entries:
        errors.append("%s: %s: must be a non-empty object" % (fname, key))
        return {}
    out = {}
    for kind, entry in entries.items():
        if not ID_RE.match(kind):
            errors.append("%s: %s.%s: kind must match %s" % (fname, key, kind, ID_RE.pattern))
            continue
        out[kind] = entry
    return out


def _check_sprite(value, fpath: str, ctx: dict, scale, errors: list) -> None:
    if not isinstance(value, str) or not value.startswith("res://assets/"):
        errors.append("%s: must be a res://assets/ path" % fpath)
        return
    root = ctx.get("root")
    if root is None:
        return
    path = Path(root) / value[len("res://"):]
    if not path.is_file():
        errors.append("%s: sprite not found: %s" % (fpath, value))
        return
    if _ignored(root, path):
        errors.append("%s: sprite lies in a folder with .gdignore (not imported): %s" % (fpath, value))
    hits = sorted(set(split_identifier(path.stem)) & set(ctx.get("deny", ())))
    if hits:
        errors.append("%s: sprite name is deny-listed (%s): %s" % (fpath, ", ".join(hits), value))
    size = png_size(path)
    if size is None:
        errors.append("%s: sprite is not a PNG: %s" % (fpath, value))
    elif is_number(scale) and scale > 0 and min(size) * scale * SCALE_720P < MIN_SIDE_720P:
        errors.append("%s: sprite too small at 720p (%.1f px, at least %d px)"
                      % (fpath, min(size) * scale * SCALE_720P, MIN_SIDE_720P))


def _check_entry(entry, fields: dict, path: str, item_kinds: set, ctx: dict, errors: list) -> bool:
    if not isinstance(entry, dict):
        errors.append("%s: must be an object" % path)
        return False
    before = len(errors)
    for key in fields:
        if key not in entry:
            errors.append("%s.%s: missing" % (path, key))
    for key in entry:
        if key not in fields:
            errors.append("%s.%s: unknown field" % (path, key))
    messages = ctx.get("messages", {})
    for key, kind in fields.items():
        if key not in entry:
            continue
        value = entry[key]
        fpath = "%s.%s" % (path, key)
        if kind == "number":
            if not is_number(value) or value <= 0:
                errors.append("%s: must be a number > 0" % fpath)
        elif kind == "bool":
            if not isinstance(value, bool):
                errors.append("%s: must be a bool" % fpath)
        elif kind == "lure":
            if not isinstance(value, str) or (value != "" and value not in item_kinds):
                errors.append("%s: unknown lure item %s" % (fpath, value))
        elif kind == "sprite":
            _check_sprite(value, fpath, ctx, entry.get("sprite_scale"), errors)
        elif kind == "key":
            if not isinstance(value, str) or not value:
                errors.append("%s: must be a non-empty i18n key" % fpath)
            elif value not in messages:
                errors.append("%s: name_key %s not found in the i18n catalogue" % (fpath, value))
            else:
                for lang in ("en", "de"):
                    if not str(messages[value].get(lang, "")).strip():
                        errors.append("%s: name_key %s has no %s text" % (fpath, value, lang.upper()))
    castaway = ctx.get("castaway", {})
    weight = entry.get("carry_weight")
    if is_number(weight) and "carry_weight_min" in castaway and "carry_weight_max" in castaway:
        if weight < castaway["carry_weight_min"] or weight > castaway["carry_weight_max"]:
            errors.append("%s.carry_weight: outside the castaway carry_weight_min..carry_weight_max" % path)
    return len(errors) == before


def validate_data(animals_data, items_data, ctx: dict) -> list:
    """Return the errors of parsed animals and items data; ctx = {root, messages, castaway, entities, deny}."""
    errors = []
    items = _section(items_data, "items", "items.json", errors)
    item_kinds = set(items)
    animals = _section(animals_data, "animals", "animals.json", errors)
    for kind, entry in items.items():
        if _check_entry(entry, ITEM_FIELDS, "items.json: items.%s" % kind, item_kinds, ctx, errors):
            if entry.get("swims") is True:
                errors.append("items.json: items.%s.swims: items cannot swim, swims must be false" % kind)
    ent = ctx.get("entities", {})
    for kind, entry in animals.items():
        path = "animals.json: animals.%s" % kind
        if kind in item_kinds:
            errors.append("%s: kind %s is both an animal and an item" % (path, kind))
        if not _check_entry(entry, ANIMAL_FIELDS, path, item_kinds, ctx, errors):
            continue
        if "bonk_seconds" in ent and "reaction_max_seconds" in ent and is_number(entry.get("panic_duration")):
            if ent["bonk_seconds"] + entry["panic_duration"] > ent["reaction_max_seconds"]:
                errors.append("%s.panic_duration: bonk_seconds + panic_duration exceeds reaction_max_seconds" % path)
    return errors


def make_context(root: Path, balance_dir: Path = None) -> dict:
    """Build the validation context from root: i18n catalogue, balance sections and the deny list."""
    root = Path(root)
    balance_dir = Path(balance_dir) if balance_dir else root / BALANCE_DIR
    catalog, _errors = load_catalog(root)
    castaway, _e1 = load_json(balance_dir / "castaway.json")
    entities, _e2 = load_json(balance_dir / "entities.json")
    deny, _e3 = load_json(root / DENY_FILE)
    return {"root": root, "messages": catalog, "castaway": castaway if isinstance(castaway, dict) else {},
            "entities": entities if isinstance(entities, dict) else {},
            "deny": deny.get("tokens", []) if isinstance(deny, dict) else []}


def validate_files(animals_path: Path, items_path: Path, root: Path = REPO, balance_dir: Path = None) -> list:
    """Return the errors of an animals and an items file checked against root."""
    errors = []
    animals, err = load_json(animals_path)
    if err:
        errors.append("%s: %s" % (Path(animals_path).name, err))
    items, err2 = load_json(items_path)
    if err2:
        errors.append("%s: %s" % (Path(items_path).name, err2))
    if errors:
        return errors
    return validate_data(animals, items, make_context(root, balance_dir))


def validate(root: Path = REPO) -> list:
    """Return every entity data error below root (empty = valid)."""
    root = Path(root)
    return validate_files(root / ANIMALS_FILE, root / ITEMS_FILE, root)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Validate data/animals.json and data/items.json.")
    parser.add_argument("--root", default=str(REPO))
    parser.add_argument("--animals", default="")
    parser.add_argument("--items", default="")
    parser.add_argument("--balance-dir", default="")
    opts = parser.parse_args(argv)
    root = Path(opts.root)
    errors = validate_files(Path(opts.animals) if opts.animals else root / ANIMALS_FILE,
                            Path(opts.items) if opts.items else root / ITEMS_FILE, root,
                            Path(opts.balance_dir) if opts.balance_dir else None)
    for line in errors:
        print(line)
    print("validate_entities: %d error(s)" % len(errors))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
