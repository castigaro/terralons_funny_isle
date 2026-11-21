"""Validate the asset folder, its sources and every asset reference (standard library only).

Usage: python tools/validate_assets.py [--root <dir>] [--quiet]   (exit code 1 on any error)

Errors:
- assets/SOURCES.md is missing, a table row lacks pack, author, licence or source, or a listed folder is missing;
- a file below assets/ lies outside every pack folder listed in SOURCES.md (foreign asset);
- a media resource (image, audio, font) referenced by a .tscn, .tres, .gd, project.godot or data/**/*.json file
  lies outside assets/ or in a pack not listed in SOURCES.md;
- a referenced file does not exist;
- a referenced asset file name contains a token of the deny list data/assets/deny_list.json;
- an image (png, jpg, jpeg, webp, svg) lies outside assets/ (git-tracked files, or every file without git); only
  the project icon (application/config/icon) is excepted.
Warnings (listed, exit code stays 0): imported asset files that nothing references, and imported files whose
name matches the deny list. Folders with a .gdignore file are not imported by Godot and are skipped.
A reference with a format placeholder (%s, %d, {name}) counts as a pattern: its fixed folder must follow the
rules and every file it matches counts as used.
"""
import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import REPO, gd_strip, split_identifier  # noqa: E402

SOURCES_REL = "assets/SOURCES.md"
DENY_REL = "data/assets/deny_list.json"
MEDIA_EXT = {"png", "jpg", "jpeg", "webp", "svg", "bmp", "tga", "ogg", "wav", "mp3", "ttf", "otf", "woff",
             "woff2", "fnt"}
META_FILES = {"SOURCES.md", ".gdignore"}
META_EXT = {"import", "uid"}
SKIP_DIRS = {".godot", ".git", "build", "__pycache__", "assets"}
SKIP_PREFIXES = ("tests/fixtures/",)
SCAN_EXT = {"tscn", "tres", "gd", "godot"}
QUOTED_RE = re.compile(r'"([^"\n]*)"')
JSON_ASSET_RE = re.compile(r"^(?:res://)?assets/")
PLACEHOLDER_RE = re.compile(r"%[-+ #0-9.]*[a-zA-Z]|\{[A-Za-z0-9_]*\}|\*")
ROW_RE = re.compile(r"^\|\s*`([^`]+)`\s*\|(.*)\|\s*$")
IMAGE_EXT = {"png", "jpg", "jpeg", "webp", "svg"}
IMAGE_SKIP_DIRS = {".godot", ".git", "build", "__pycache__"}
ICON_RE = re.compile(r'^config/icon="res://([^"]+)"', re.M)


def parse_sources(root: Path):
    """Return ({folder relative to assets/ without trailing slash: row dict}, errors)."""
    path = root / SOURCES_REL
    if not path.is_file():
        return {}, ["%s missing" % SOURCES_REL]
    packs = {}
    errors = []
    for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        match = ROW_RE.match(line.strip())
        if not match:
            continue
        folder = match.group(1).strip().strip("/")
        cells = [c.strip() for c in match.group(2).split("|")]
        names = ("pack", "author", "licence", "source")
        row = dict(zip(names, cells + [""] * len(names)))
        for name in names:
            if not row[name]:
                errors.append("%s:%d: %s has no %s" % (SOURCES_REL, line_no, folder, name))
        if folder in packs:
            errors.append("%s:%d: pack folder listed twice: %s" % (SOURCES_REL, line_no, folder))
        if not (root / "assets" / folder).is_dir():
            errors.append("%s:%d: listed pack folder missing: assets/%s" % (SOURCES_REL, line_no, folder))
        packs[folder] = row
    if not packs:
        errors.append("%s: no pack rows found" % SOURCES_REL)
    return packs, errors


def load_deny(root: Path):
    """Return (list of token tuples, errors) from the deny list data file."""
    path = root / DENY_REL
    if not path.is_file():
        return [], ["%s missing" % DENY_REL]
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (ValueError, UnicodeDecodeError) as exc:
        return [], ["%s: invalid JSON (%s)" % (DENY_REL, exc)]
    tokens = data.get("tokens") if isinstance(data, dict) else None
    if not isinstance(tokens, list) or not tokens or not all(isinstance(t, str) and t for t in tokens):
        return [], ["%s: 'tokens' must be a non-empty list of strings" % DENY_REL]
    return [tuple(t.lower().split("_")) for t in tokens], []


def deny_hits(name: str, deny) -> list:
    """Return the deny entries whose token sequence occurs in the file name (without extension)."""
    stem = name.rsplit(".", 1)[0]
    tokens = split_identifier(re.sub(r"[^A-Za-z0-9_]+", "_", stem))
    hits = []
    for entry in deny:
        size = len(entry)
        if any(tuple(tokens[i:i + size]) == entry for i in range(len(tokens) - size + 1)):
            hits.append("_".join(entry))
    return hits


def pack_of(rel: str, packs) -> str:
    """Return the listed pack folder that contains rel (relative to assets/), or ''."""
    best = ""
    for folder in packs:
        if (rel == folder or rel.startswith(folder + "/")) and len(folder) > len(best):
            best = folder
    return best


def asset_files(root: Path):
    """Return (all files, imported files) below assets/ as paths relative to assets/, meta files excluded."""
    base = root / "assets"
    all_files = []
    imported = []
    if not base.is_dir():
        return all_files, imported
    ignored_dirs = [p.parent for p in base.rglob(".gdignore")]
    for path in sorted(base.rglob("*")):
        if not path.is_file() or path.name in META_FILES or path.suffix.lstrip(".").lower() in META_EXT:
            continue
        rel = path.relative_to(base).as_posix()
        all_files.append(rel)
        if not any(d == path.parent or d in path.parents for d in ignored_dirs):
            imported.append(rel)
    return all_files, imported


def scan_files(root: Path):
    """Yield the files whose references are checked."""
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(root).as_posix()
        parts = rel.split("/")
        if any(p in SKIP_DIRS for p in parts[:-1]) or rel.startswith(SKIP_PREFIXES):
            continue
        ext = path.suffix.lstrip(".").lower()
        if ext in SCAN_EXT or (ext == "json" and parts[0] == "data" and rel != DENY_REL):
            yield path, rel, ext


def json_strings(value):
    """Yield every string inside a parsed JSON value."""
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for item in value:
            yield from json_strings(item)
    elif isinstance(value, dict):
        for item in value.values():
            yield from json_strings(item)


def collect_refs(root: Path):
    """Return ([(source rel, line, repo-relative target)], errors)."""
    refs = []
    errors = []
    for path, rel, ext in scan_files(root):
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            errors.append("%s: not UTF-8" % rel)
            continue
        if ext == "gd":
            literals = [(lit, text.count("\n", 0, off) + 1) for lit, off in gd_strip(text)[2]]
        else:
            literals = [(m.group(1), text.count("\n", 0, m.start()) + 1) for m in QUOTED_RE.finditer(text)]
        for literal, line_no in literals:
            if literal.startswith("res://"):
                refs.append((rel, line_no, literal[len("res://"):]))
        if ext == "json":
            try:
                data = json.loads(text)
            except ValueError as exc:
                errors.append("%s: invalid JSON (%s)" % (rel, exc))
                continue
            for value in json_strings(data):
                if JSON_ASSET_RE.match(value) and not value.startswith("res://"):
                    refs.append((rel, 0, value))
    return refs, errors


def pattern_regex(target: str):
    """Return a compiled regex for a placeholder reference."""
    pieces = PLACEHOLDER_RE.split(target)
    return re.compile("^" + "[^/]+".join(re.escape(p) for p in pieces) + "$")


def project_icon(root: Path) -> str:
    """Return the repo-relative path of application/config/icon in project.godot, or ''."""
    project = root / "project.godot"
    if not project.is_file():
        return ""
    match = ICON_RE.search(project.read_text(encoding="utf-8", errors="replace"))
    return match.group(1) if match else ""


def candidate_images(root: Path) -> list:
    """Return repo-relative image paths: git-tracked files when root is a git top level, else every file."""
    files = None
    if shutil.which("git") is not None:
        try:
            top = subprocess.run(["git", "-C", str(root), "rev-parse", "--show-toplevel"], capture_output=True,
                                 text=True, encoding="utf-8")
            if top.returncode == 0 and Path(top.stdout.strip()).resolve() == root.resolve():
                out = subprocess.run(["git", "-C", str(root), "ls-files"], capture_output=True, text=True,
                                     encoding="utf-8", check=True).stdout
                files = [line.strip() for line in out.splitlines() if line.strip()]
        except (OSError, subprocess.CalledProcessError):
            files = None
    if files is None:
        files = []
        for path in root.rglob("*"):
            rel = path.relative_to(root).as_posix()
            if path.is_file() and not any(p in IMAGE_SKIP_DIRS for p in rel.split("/")[:-1]):
                files.append(rel)
    return sorted(f for f in files if f.rsplit(".", 1)[-1].lower() in IMAGE_EXT)


def check_images_outside_assets(root: Path) -> list:
    """Every sprite lives below assets/ (R-39); only the project icon may lie elsewhere."""
    icon = project_icon(root)
    return ["image outside assets/ (sprites must come from the asset packs): %s" % rel
            for rel in candidate_images(root) if not rel.startswith("assets/") and rel != icon]


def validate(root: Path):
    """Return (errors, warnings) for the tree at root."""
    root = Path(root)
    packs, errors = parse_sources(root)
    errors += check_images_outside_assets(root)
    deny, deny_errors = load_deny(root)
    errors += deny_errors
    warnings = []
    all_files, imported = asset_files(root)
    for rel in all_files:
        if packs and not pack_of(rel, packs):
            errors.append("foreign asset (pack not listed in %s): assets/%s" % (SOURCES_REL, rel))

    refs, ref_errors = collect_refs(root)
    errors += ref_errors
    used = set()
    known = set(all_files)
    icon = project_icon(root)
    for src, line_no, target in refs:
        if icon and target == icon and (root / target).is_file():
            continue
        where = "%s:%d" % (src, line_no) if line_no else src
        name = target.rsplit("/", 1)[-1]
        ext = name.rsplit(".", 1)[-1].lower() if "." in name else ""
        is_pattern = bool(PLACEHOLDER_RE.search(target))
        fixed = PLACEHOLDER_RE.split(target)[0].rsplit("/", 1)[0] if is_pattern else target
        in_assets = target.startswith("assets/")
        if in_assets and target.endswith("/"):
            if not (root / target).is_dir():
                errors.append("%s: referenced folder missing: res://%s" % (where, target))
            continue
        if ext in MEDIA_EXT or in_assets:
            if not in_assets:
                errors.append("%s: resource outside assets/: res://%s" % (where, target))
                continue
            if not pack_of(fixed[len("assets/"):], packs):
                errors.append("%s: resource in a pack not listed in %s: res://%s" % (where, SOURCES_REL, target))
                continue
        if is_pattern:
            regex = pattern_regex(target)
            matched = [f for f in all_files if regex.match("assets/" + f)]
            if not matched:
                errors.append("%s: pattern matches no file: res://%s" % (where, target))
            for rel in matched:
                used.add(rel)
                for hit in deny_hits(rel.rsplit("/", 1)[-1], deny):
                    errors.append("%s: used asset matches deny list '%s': assets/%s" % (where, hit, rel))
            continue
        if not ext:
            continue
        if not (root / target).is_file():
            errors.append("%s: referenced file missing: res://%s" % (where, target))
            continue
        if in_assets:
            if target[len("assets/"):] not in known:
                errors.append("%s: letter case differs from the file on disk: res://%s" % (where, target))
                continue
            used.add(target[len("assets/"):])
            for hit in deny_hits(name, deny):
                errors.append("%s: used asset matches deny list '%s': res://%s" % (where, hit, target))

    for rel in imported:
        if rel.rsplit(".", 1)[-1].lower() not in MEDIA_EXT:
            continue
        hits = deny_hits(rel.rsplit("/", 1)[-1], deny)
        if hits:
            warnings.append("imported file matches deny list '%s' (do not use it): assets/%s" % (hits[0], rel))
        if rel not in used:
            warnings.append("unused imported file: assets/%s" % rel)
    return errors, warnings


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", default=str(REPO), help="project root to check")
    parser.add_argument("--quiet", action="store_true", help="print only the number of warnings")
    opts = parser.parse_args(argv)
    errors, warnings = validate(Path(opts.root))
    if not opts.quiet:
        for line in warnings:
            print("WARNING: " + line)
    for line in errors:
        print("ERROR: " + line)
    unused = sum(1 for w in warnings if w.startswith("unused"))
    print("validate_assets: %d error(s), %d warning(s) (%d unused imported file(s))"
          % (len(errors), len(warnings), unused))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
