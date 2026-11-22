"""Validate the zone markers of the shipped level scenes (standard library only).

Usage: python tools/validate_level_art.py [--root DIR]   (exit code 1 on errors)

Every player-action zone of a level needs exactly one ZoneMarker instance (scenes/levels/props/zone_marker.tscn)
below the ZoneMarkers node of scenes/levels/<id>.tscn with that zone_id. Action zones are the zone ids of the level
scene that a task names through a "zone" field (in_zone conditions and modifiers of data/levels/<id>.json), as a
delivered_to target, or as the target_kind of a PenTarget, DeliveryTarget or BuildTarget node of the scene. Large
area zones listed in AREA_ZONES are exempt; helper zones (lanes, flee areas, perches of event actors) must not get a
marker. Flat single-colour placeholder nodes and draw calls are checked by validate_code.py rule (j).
One line per error: "<scene>: <message>".
"""
import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import REPO  # noqa: E402

LEVELS_DIR = "data/levels"
SCENES_DIR = "scenes/levels"
MARKER_SCENE = "res://scenes/levels/props/zone_marker.tscn"
MARKER_PARENT = "ZoneMarkers"
TARGET_SCRIPTS = ("pen_target.gd", "delivery_target.gd", "build_target.gd")
TARGET_LABELS = {"pen_target.gd": "PenTarget", "delivery_target.gd": "DeliveryTarget",
                 "build_target.gd": "BuildTarget"}
# Area zones that cover a whole stretch of the level (a beach, a lagoon) and read as terrain, not as a marked spot.
AREA_ZONES = {"l4_lagoon": ["beach", "lagoon"]}

EXT_RE = re.compile(r'^\[ext_resource [^\]]*path="([^"]+)"[^\]]*id="([^"]+)"', re.M)
NODE_RE = re.compile(r'^\[node (.*)\]\s*$', re.M)
ATTR_RE = re.compile(r'(\w+)=("([^"]*)"|ExtResource\("([^"]+)"\))')
PROP_RE = re.compile(r'^(\w+) = (.*)$', re.M)


def parse_nodes(text: str) -> list:
    """Return the [node] blocks of a .tscn as dicts {attrs: {...}, props: {...}}."""
    nodes = []
    matches = list(NODE_RE.finditer(text))
    for i, match in enumerate(matches):
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        body = text[match.end():end]
        body = body.split("\n[", 1)[0]
        attrs = {}
        for attr in ATTR_RE.finditer(match.group(1)):
            attrs[attr.group(1)] = attr.group(3) if attr.group(3) is not None else "ext:" + attr.group(4)
        props = {key: value.strip() for key, value in PROP_RE.findall(body)}
        nodes.append({"attrs": attrs, "props": props})
    return nodes


def _string_value(raw: str) -> str:
    raw = raw.strip()
    return raw[1:-1] if len(raw) >= 2 and raw[0] == raw[-1] == '"' else raw


def _ext_id(raw: str) -> str:
    match = re.match(r'ExtResource\("([^"]+)"\)', raw.strip())
    return match.group(1) if match else ""


def task_references(level: dict) -> dict:
    """Return {name: reason} for zone fields and delivered_to targets of the level tasks."""
    found = {}

    def walk(value):
        if isinstance(value, dict):
            if isinstance(value.get("zone"), str):
                found.setdefault(value["zone"], "in_zone")
            if value.get("type") == "delivered_to" and isinstance(value.get("target"), str):
                found.setdefault(value["target"], "delivered_to")
            for item in value.values():
                walk(item)
        elif isinstance(value, list):
            for item in value:
                walk(item)

    walk(level.get("tasks", []))
    return found


def scene_facts(text: str) -> dict:
    """Return {zones: set, targets: {kind: label}, markers: [(name, zone_id)]} of a level scene."""
    ext = {rid: path for path, rid in EXT_RE.findall(text)}
    zones = set()
    targets = {}
    markers = []
    for node in parse_nodes(text):
        attrs, props = node["attrs"], node["props"]
        script = ext.get(_ext_id(props.get("script", "")), "")
        if attrs.get("parent") == "Zones" and "zone_id" in props:
            zones.add(_string_value(props["zone_id"]))
        base = script.rsplit("/", 1)[-1]
        if base in TARGET_SCRIPTS and "target_kind" in props:
            targets.setdefault(_string_value(props["target_kind"]), TARGET_LABELS[base])
        instance = attrs.get("instance", "")
        if instance.startswith("ext:") and ext.get(instance[4:], "") == MARKER_SCENE:
            if attrs.get("parent") == MARKER_PARENT:
                markers.append((attrs.get("name", ""), _string_value(props.get("zone_id", '""'))))
    return {"zones": zones, "targets": targets, "markers": markers}


def action_zones(level_id: str, level: dict, facts: dict) -> dict:
    """Return {zone_id: reason} of the zones that need a marker."""
    out = {}
    for name, reason in task_references(level).items():
        if name in facts["zones"]:
            out.setdefault(name, reason)
    for kind, label in facts["targets"].items():
        if kind in facts["zones"]:
            out.setdefault(kind, label)
    for name in AREA_ZONES.get(level_id, []):
        out.pop(name, None)
    return out


def validate_level(root: Path, level_path: Path) -> list:
    level_id = level_path.stem
    scene = root / SCENES_DIR / (level_id + ".tscn")
    rel = scene.relative_to(root).as_posix() if scene.is_relative_to(root) else str(scene)
    if not scene.is_file():
        return ["%s: missing level scene for %s" % (rel, level_path.name)]
    try:
        level = json.loads(level_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return ["%s: cannot read %s (%s)" % (rel, level_path.name, exc)]
    facts = scene_facts(scene.read_text(encoding="utf-8"))
    needed = action_zones(level_id, level, facts)
    errors = []
    counts = {}
    for name, zone_id in facts["markers"]:
        counts[zone_id] = counts.get(zone_id, 0) + 1
        if zone_id not in facts["zones"]:
            errors.append("%s: extra ZoneMarker '%s' names unknown zone '%s'" % (rel, name, zone_id))
        elif zone_id not in needed:
            errors.append("%s: extra ZoneMarker '%s' marks helper or area zone '%s'" % (rel, name, zone_id))
    for zone_id in sorted(needed):
        if counts.get(zone_id, 0) == 0:
            errors.append("%s: missing ZoneMarker: zone '%s' (%s) has no ZoneMarker" % (rel, zone_id, needed[zone_id]))
        elif counts[zone_id] > 1:
            errors.append("%s: extra ZoneMarker: zone '%s' has %d ZoneMarkers" % (rel, zone_id, counts[zone_id]))
    return errors


def validate(root: Path) -> list:
    errors = []
    levels = root / LEVELS_DIR
    if not levels.is_dir():
        return errors
    for level_path in sorted(levels.glob("*.json")):
        errors += validate_level(root, level_path)
    return errors


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Validate the zone markers of the level scenes.")
    parser.add_argument("--root", default=str(REPO))
    opts = parser.parse_args(argv)
    errors = validate(Path(opts.root))
    for err in errors:
        print(err)
    print("validate_level_art: %d error(s)" % len(errors))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
