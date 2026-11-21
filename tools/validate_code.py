"""Validate the code rules of the product, its tests and its tools (standard library only).

Usage: python tools/validate_code.py [--root <dir>]   (exit code 1 on any error)

(a) Comments are English and use the en dash: no em dash, no German umlaut or sharp s and not two or more
    distinct German function words in one comment (.gd comments, .py comments and docstrings).
(b) No magic tuning numbers in gameplay scripts (scripts/gameplay, scripts/levels, scripts/feedback,
    scripts/rules): every
    numeric literal other than 0, 0.5, 1 and 2 must come from the Balance autoload; a line may opt out with
    the comment "# balance-exempt: <reason>".
(c) No networking: no Godot network classes in .gd code and no network modules imported by .py files.
(d) Python files in tools/ and tests/ import only the standard library or local modules.
(e) No survival stats: no hunger/energy/health/food/rest/faint token in .gd identifiers, .tscn node names,
    balance keys, balance file names or i18n keys.
(f) No global randomness outside scripts/core/seeded_rng.gd, no zero-argument shuffle()/pick_random(),
    no get_meta(<key>, null), and every git-tracked .gd has a git-tracked .gd.uid (skipped without git).
(g) No turn-based, grid or inventory mechanics: no action_point(s), end_turn, turn_count, turn_based, snap_to_grid,
    tile_step or grid_move sequence and no inventory/recipe/crafting part in .gd identifiers and .tscn node names
    below scripts/ and scenes/ or in the [input] action names of project.godot (turn_speed stays allowed).
(h) No harm to animals or the castaway: no damage/death/dead/die/died/dies/kill/killed/blood/bloody/hurt/wound/
    wounded token, no exact hp token and no token starting with injur in .gd identifiers and .tscn node names below
    scripts/, scenes/, ui/ and tests/, in balance file names and keys, in the keys of data/animals.json and
    data/items.json or in i18n keys. The engine call .kill( (Tween.kill) stays allowed.
(i) No fog of war, darkness or procedural maps: no fog/darkness/unexplored/explored part and no fog_of_war,
    reveal_tile, revealed_cells or visibility_grid sequence in .gd identifiers and .tscn node names below scripts/
    and scenes/; no CanvasModulate, PointLight2D or LightOccluder2D node (.tscn) or .new() (.gd) there; no
    set_cell(), set_cells_terrain_connect(), set_cells_terrain_path() or FastNoiseLite in .gd below scripts/
    (layouts are painted offline by tools/build_level_layout.gd).
(j) No placeholder graphics: no ColorRect, Polygon2D or Line2D node in .tscn files below scenes/ (scenes/ui/ is
    allowed) and no ColorRect.new(), Polygon2D.new(), draw_rect(), draw_circle() or draw_polygon() in
    scripts/gameplay, scripts/levels and scripts/feedback. GradientTexture2D and NoiseTexture2D stay allowed.
    A .gd line may opt out of (i) and (j) with the comment "# art-exempt: <reason>".
Comments and string literals never count as code.
"""
import argparse
import ast
import io
import json
import re
import shutil
import subprocess
import sys
import tokenize
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import REPO, code_files, gd_comments, gd_strip, split_identifier  # noqa: E402

SELF_EXCLUDED = {"tools/validate_code.py", "tests/core/test_validate_code.py"}
COMMENT_GD_DIRS = ("scripts", "scenes", "ui", "tests", "tools")
PY_DIRS = ("tools", "tests")
EM_DASH = "—"
GERMAN_CHARS = set("äöüÄÖÜß")
GERMAN_WORDS = {"und", "der", "die", "das", "nicht", "ist", "mit", "für", "ein", "eine", "auch", "wird",
                "sind", "oder"}
WORD_RE = re.compile(r"[^\W\d_]+", re.UNICODE)

MAGIC_DIRS = ("scripts/gameplay", "scripts/levels", "scripts/feedback", "scripts/rules")
MAGIC_ALLOWED_FILES = set()
MAGIC_ALLOWED_VALUES = {0.0, 0.5, 1.0, 2.0}
NUMBER_RE = re.compile(r"(?<![\w.])(0x[0-9A-Fa-f_]+|0b[01_]+|\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][-+]?\d+)?|\.\d+)")
EXEMPT_RE = re.compile(r"balance-exempt:\s*\S")

NET_GD_RE = re.compile(r"\b(HTTPRequest|HTTPClient|StreamPeerTCP|StreamPeerTLS|TCPServer|PacketPeerUDP|UDPServer|"
                       r"WebSocketPeer|WebSocketMultiplayerPeer|WebRTC\w*|ENetMultiplayerPeer|ENetConnection|"
                       r"MultiplayerPeer|JavaScriptBridge)\b")
NET_PY_MODULES = {"socket", "http.client", "http.server", "urllib.request", "ftplib", "smtplib", "poplib",
                  "imaplib", "xmlrpc", "socketserver"}

SURVIVAL = {"hunger", "hungry", "energy", "health", "healthy", "hp", "food", "rest", "resting", "faint",
            "fainting", "stamina"}
IDENTIFIER_ALLOW = {"get_rest_info"}
SURVIVAL_GD_DIRS = ("scripts", "scenes", "ui", "tests")
IDENT_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
TSCN_NODE_RE = re.compile(r'^\[node name="([^"]+)"')

GLOBAL_RNG_RE = re.compile(r"(?<![\w.])(randi|randf|randf_range|randi_range|randfn|randomize|seed)\s*\(")
ZERO_ARG_RE = re.compile(r"\.(shuffle|pick_random)\(\s*\)")
RNG_NEW_RE = re.compile(r"(?<![\w.])RandomNumberGenerator\s*\.\s*new\s*\(")
FUNC_DEF_RE = re.compile(r"\bfunc\s+$")
META_NULL_RE = re.compile(r"\bget_meta\s*\([^()]*,\s*null\s*\)")
RNG_ALLOWED = {"scripts/core/seeded_rng.gd"}

TURN_SEQUENCES = ("action_point", "action_points", "end_turn", "turn_count", "turn_based", "snap_to_grid",
                  "tile_step", "grid_move")
INVENTORY_PARTS = {"inventory", "inventories", "recipe", "recipes", "crafting"}
TURN_GD_DIRS = ("scripts", "scenes")
HARM = {"damage", "damaged", "death", "dead", "die", "died", "dies", "kill", "killed", "blood", "bloody", "hurt",
        "wound", "wounded", "hp"}
HARM_PREFIXES = ("injur",)
HARM_GD_DIRS = ("scripts", "scenes", "ui", "tests")
HARM_DATA_FILES = ("data/animals.json", "data/items.json")
INPUT_SECTION_RE = re.compile(r"^\[input\]\n(.*?)(?=^\[|\Z)", re.M | re.S)
INPUT_ACTION_RE = re.compile(r"^(\w+)=\{", re.M)

ART_EXEMPT_RE = re.compile(r"art-exempt:\s*\S")
ART_GD_DIRS = ("scripts", "scenes")
FOG_PARTS = {"fog", "darkness", "unexplored", "explored"}
FOG_SEQUENCES = ("fog_of_war", "reveal_tile", "revealed_cells", "visibility_grid")
LIGHT_TYPES = ("CanvasModulate", "PointLight2D", "LightOccluder2D")
LIGHT_TSCN_RE = re.compile(r'type="(%s)"' % "|".join(LIGHT_TYPES))
LIGHT_GD_RE = re.compile(r"\b(%s)\s*\.\s*new\s*\(" % "|".join(LIGHT_TYPES))
PROC_MAP_DIRS = ("scripts",)
PROC_MAP_RE = re.compile(r"(?<![\w.])(set_cell|set_cells_terrain_connect|set_cells_terrain_path)\s*\(|"
                         r"\.(set_cell|set_cells_terrain_connect|set_cells_terrain_path)\s*\(|\b(FastNoiseLite)\b")
PLACEHOLDER_TYPES = ("ColorRect", "Polygon2D", "Line2D")
PLACEHOLDER_TSCN_RE = re.compile(r'^\[node [^\]]*type="(%s)"' % "|".join(PLACEHOLDER_TYPES))
PLACEHOLDER_TSCN_DIRS = ("scenes",)
PLACEHOLDER_TSCN_ALLOWED = ("scenes/ui/",)
PLACEHOLDER_GD_DIRS = ("scripts/gameplay", "scripts/levels", "scripts/feedback")
PLACEHOLDER_GD_RE = re.compile(r"\b(ColorRect|Polygon2D)\s*\.\s*new\s*\(|(?<![\w])(draw_rect|draw_circle|draw_polygon)\s*\(")


def _line(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def _rel(root: Path, path: Path) -> str:
    return path.relative_to(root).as_posix()


def _files(root: Path, dirs, suffix: str) -> list:
    files = []
    for name in dirs:
        base = Path(root) / name
        if base.is_dir():
            files.extend(p for p in sorted(base.rglob("*" + suffix)) if "__pycache__" not in p.parts)
    return files


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


# --- (a) comment language -------------------------------------------------------

def comment_problem(text: str):
    """Return why a comment breaks the language rule, or None."""
    if EM_DASH in text:
        return "em dash in comment (use the en dash)"
    if any(c in GERMAN_CHARS for c in text):
        return "non-English comment (umlaut or sharp s)"
    words = {w.lower() for w in WORD_RE.findall(text)} & GERMAN_WORDS
    if len(words) >= 2:
        return "non-English comment (German words: %s)" % ", ".join(sorted(words))
    return None


def py_comments(source: str) -> list:
    """Return [(line_no, text)] of the comments and docstrings of Python source."""
    found = []
    try:
        for tok in tokenize.generate_tokens(io.StringIO(source).readline):
            if tok.type == tokenize.COMMENT:
                found.append((tok.start[0], tok.string[1:]))
    except (tokenize.TokenError, IndentationError, SyntaxError):
        pass
    try:
        tree = ast.parse(source)
    except SyntaxError:
        return found
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
            body = getattr(node, "body", [])
            if body and isinstance(body[0], ast.Expr) and isinstance(body[0].value, ast.Constant) \
                    and isinstance(body[0].value.value, str):
                found.append((body[0].lineno, body[0].value.value))
    return found


def check_comments(root: Path) -> list:
    errors = []
    for path in _files(root, COMMENT_GD_DIRS, ".gd"):
        rel = _rel(root, path)
        if rel in SELF_EXCLUDED:
            continue
        for line_no, text in gd_comments(_read(path)):
            problem = comment_problem(text)
            if problem:
                errors.append("%s:%d: %s" % (rel, line_no, problem))
    for path in _files(root, PY_DIRS, ".py"):
        rel = _rel(root, path)
        if rel in SELF_EXCLUDED:
            continue
        for line_no, text in py_comments(_read(path)):
            problem = comment_problem(text)
            if problem:
                errors.append("%s:%d: %s" % (rel, line_no, problem))
    return errors


# --- (b) magic numbers ------------------------------------------------------------

def _number_value(literal: str):
    text = literal.replace("_", "")
    try:
        if text.lower().startswith("0x"):
            return float(int(text, 16))
        if text.lower().startswith("0b"):
            return float(int(text[2:], 2))
        return float(text)
    except ValueError:
        return None


def check_magic_numbers(root: Path) -> list:
    errors = []
    for path in _files(root, MAGIC_DIRS, ".gd"):
        rel = _rel(root, path)
        if rel in MAGIC_ALLOWED_FILES:
            continue
        text = _read(path)
        exempt = {line_no for line_no, body in gd_comments(text) if EXEMPT_RE.search(body)}
        _nc, bare, _strings = gd_strip(text)
        for line_no, line in enumerate(bare.split("\n"), start=1):
            if line_no in exempt:
                continue
            for match in NUMBER_RE.finditer(line):
                if _number_value(match.group(1)) in MAGIC_ALLOWED_VALUES:
                    continue
                errors.append("%s:%d: magic number %s – read tunables from Balance (data/balance/*.json) or mark "
                              "the line '# balance-exempt: <reason>'" % (rel, line_no, match.group(1)))
    return errors


# --- (c) networking and (d) third-party imports ------------------------------------

def _py_imports(source: str) -> list:
    """Return [(line_no, module)] of the absolute imports of Python source."""
    try:
        tree = ast.parse(source)
    except SyntaxError:
        return []
    found = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            found.extend((node.lineno, alias.name) for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
            found.append((node.lineno, node.module))
    return found


def check_networking(root: Path) -> list:
    errors = []
    for path in _files(root, COMMENT_GD_DIRS, ".gd"):
        _nc, bare, _strings = gd_strip(_read(path))
        for match in NET_GD_RE.finditer(bare):
            errors.append("%s:%d: networking class %s is not allowed (offline game)"
                          % (_rel(root, path), _line(bare, match.start()), match.group(1)))
    for path in _files(root, PY_DIRS, ".py"):
        for line_no, module in _py_imports(_read(path)):
            if any(module == net or module.startswith(net + ".") for net in NET_PY_MODULES):
                errors.append("%s:%d: networking module %s is not allowed" % (_rel(root, path), line_no, module))
    return errors


def check_third_party(root: Path) -> list:
    errors = []
    py_files = _files(root, PY_DIRS, ".py")
    local = {p.stem for p in py_files}
    allowed = set(sys.stdlib_module_names) | {"__future__"} | local
    for path in py_files:
        for line_no, module in _py_imports(_read(path)):
            top = module.split(".", 1)[0]
            if top not in allowed:
                errors.append("%s:%d: third-party import %s (standard library only)"
                              % (_rel(root, path), line_no, module))
    return errors


# --- (e) survival tokens ---------------------------------------------------------------

def survival_tokens(name: str) -> list:
    """Return the survival tokens contained in an identifier or key."""
    if name in IDENTIFIER_ALLOW:
        return []
    return sorted(set(split_identifier(name)) & SURVIVAL)


def _json_keys(value, prefix=""):
    if isinstance(value, dict):
        for key, sub in value.items():
            yield prefix + str(key), str(key)
            yield from _json_keys(sub, prefix + str(key) + ".")
    elif isinstance(value, list):
        for item in value:
            yield from _json_keys(item, prefix)


def check_survival(root: Path) -> list:
    errors = []
    for path in _files(root, SURVIVAL_GD_DIRS, ".gd"):
        rel = _rel(root, path)
        if rel in SELF_EXCLUDED:
            continue
        _nc, bare, _strings = gd_strip(_read(path))
        reported = set()
        for match in IDENT_RE.finditer(bare):
            name = match.group(0)
            hits = survival_tokens(name)
            if hits and name not in reported:
                reported.add(name)
                errors.append("%s:%d: survival stat identifier %s (no %s)"
                              % (rel, _line(bare, match.start()), name, "/".join(hits)))
    for path in _files(root, SURVIVAL_GD_DIRS, ".tscn"):
        for line_no, line in enumerate(_read(path).splitlines(), start=1):
            match = TSCN_NODE_RE.match(line)
            if match and survival_tokens(match.group(1)):
                errors.append("%s:%d: survival stat node name %s" % (_rel(root, path), line_no, match.group(1)))
    balance = Path(root) / "data" / "balance"
    if balance.is_dir():
        for path in sorted(balance.glob("*.json")):
            rel = _rel(root, path)
            if survival_tokens(path.stem):
                errors.append("%s: survival stat balance file %s" % (rel, path.stem))
            try:
                data = json.loads(_read(path))
            except ValueError:
                continue
            for full, key in _json_keys(data):
                if survival_tokens(key):
                    errors.append("%s: survival stat balance key %s" % (rel, full))
    i18n = Path(root) / "i18n"
    if i18n.is_dir():
        for path in sorted(i18n.glob("*.csv")):
            for line_no, line in enumerate(_read(path).splitlines(), start=1):
                key = line.split(",", 1)[0].strip()
                if line_no == 1 or not key:
                    continue
                if any(survival_tokens(part) for part in key.split(".")):
                    errors.append("%s:%d: survival stat i18n key %s" % (_rel(root, path), line_no, key))
    return errors


# --- (f) rules kept from v1 ---------------------------------------------------------------

def check_rng(root: Path) -> list:
    errors = []
    for path in code_files(root, ".gd"):
        rel = _rel(root, path)
        if rel in RNG_ALLOWED:
            continue
        _nc, bare, _strings = gd_strip(_read(path))
        for match in GLOBAL_RNG_RE.finditer(bare):
            line_start = bare.rfind("\n", 0, match.start()) + 1
            if FUNC_DEF_RE.search(bare[line_start:match.start()]):
                continue
            errors.append("%s:%d: global %s() – use SeededRng" % (rel, _line(bare, match.start()), match.group(1)))
        for match in ZERO_ARG_RE.finditer(bare):
            errors.append("%s:%d: Array.%s() – use SeededRng" % (rel, _line(bare, match.start()), match.group(1)))
        for match in RNG_NEW_RE.finditer(bare):
            errors.append("%s:%d: RandomNumberGenerator.new() – use SeededRng" % (rel, _line(bare, match.start())))
    return errors


def check_meta(root: Path) -> list:
    errors = []
    for path in code_files(root, ".gd"):
        _nc, bare, _strings = gd_strip(_read(path))
        for match in META_NULL_RE.finditer(bare):
            errors.append("%s:%d: get_meta() with a null default errors when the key is missing – use has_meta() "
                          "or a non-null default" % (_rel(root, path), _line(bare, match.start())))
    return errors


def tracked_files(root: Path):
    """Return the git-tracked files below root as posix paths, or None if root is not a git top level."""
    if shutil.which("git") is None:
        return None
    try:
        top = subprocess.run(["git", "-C", str(root), "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True, encoding="utf-8")
        if top.returncode != 0 or Path(top.stdout.strip()).resolve() != Path(root).resolve():
            return None
        out = subprocess.run(["git", "-C", str(root), "ls-files"], capture_output=True, text=True,
                             encoding="utf-8", check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return None
    return set(line.strip() for line in out.splitlines() if line.strip())


def check_uids(root: Path) -> list:
    tracked = tracked_files(root)
    if tracked is None:
        return []
    return ["%s: missing tracked %s.uid (run the import step and commit it)" % (f, f)
            for f in sorted(tracked) if f.endswith(".gd") and f + ".uid" not in tracked]


# --- (g) turn-based, grid and inventory mechanics ----------------------------------------------

def turn_grid_tokens(name: str) -> list:
    """Return the turn/grid sequences and inventory parts contained in an identifier, node or action name."""
    parts = split_identifier(name)
    joined = "_" + "_".join(parts) + "_"
    hits = [seq for seq in TURN_SEQUENCES if "_" + seq + "_" in joined]
    hits += sorted(set(parts) & INVENTORY_PARTS)
    return hits


def check_turn_grid(root: Path) -> list:
    errors = []
    for path in _files(root, TURN_GD_DIRS, ".gd"):
        rel = _rel(root, path)
        _nc, bare, _strings = gd_strip(_read(path))
        reported = set()
        for match in IDENT_RE.finditer(bare):
            name = match.group(0)
            hits = turn_grid_tokens(name)
            if hits and name not in reported:
                reported.add(name)
                errors.append("%s:%d: turn-based/grid/inventory identifier %s (%s) – the game is real-time with "
                              "one carry slot" % (rel, _line(bare, match.start()), name, "/".join(hits)))
    for path in _files(root, TURN_GD_DIRS, ".tscn"):
        for line_no, line in enumerate(_read(path).splitlines(), start=1):
            match = TSCN_NODE_RE.match(line)
            if match and turn_grid_tokens(match.group(1)):
                errors.append("%s:%d: turn-based/grid/inventory node name %s" % (_rel(root, path), line_no,
                                                                                match.group(1)))
    project = Path(root) / "project.godot"
    if project.is_file():
        text = _read(project)
        section = INPUT_SECTION_RE.search(text)
        if section:
            for match in INPUT_ACTION_RE.finditer(section.group(1)):
                if turn_grid_tokens(match.group(1)):
                    errors.append("project.godot: turn-based/grid/inventory input action %s" % match.group(1))
    return errors


# --- (h) no harm ------------------------------------------------------------------------------------

def harm_tokens(name: str) -> list:
    """Return the harm tokens contained in an identifier, node name or key."""
    parts = split_identifier(name)
    return sorted(set(p for p in parts if p in HARM or p.startswith(HARM_PREFIXES)))


def _engine_kill(bare: str, start: int, end: int) -> bool:
    """True for the engine call .kill( such as Tween.kill()."""
    return bare[start:end] == "kill" and start > 0 and bare[start - 1] == "." and bare[end:end + 1] == "("


def check_harm(root: Path) -> list:
    errors = []
    for path in _files(root, HARM_GD_DIRS, ".gd"):
        rel = _rel(root, path)
        if rel in SELF_EXCLUDED:
            continue
        _nc, bare, _strings = gd_strip(_read(path))
        reported = set()
        for match in IDENT_RE.finditer(bare):
            name = match.group(0)
            if name in reported or _engine_kill(bare, match.start(), match.end()):
                continue
            hits = harm_tokens(name)
            if hits:
                reported.add(name)
                errors.append("%s:%d: harm identifier %s (%s) – animals and the castaway are never harmed"
                              % (rel, _line(bare, match.start()), name, "/".join(hits)))
    for path in _files(root, HARM_GD_DIRS, ".tscn"):
        for line_no, line in enumerate(_read(path).splitlines(), start=1):
            match = TSCN_NODE_RE.match(line)
            if match and harm_tokens(match.group(1)):
                errors.append("%s:%d: harm node name %s" % (_rel(root, path), line_no, match.group(1)))
    json_files = []
    balance = Path(root) / "data" / "balance"
    if balance.is_dir():
        for path in sorted(balance.glob("*.json")):
            if harm_tokens(path.stem):
                errors.append("%s: harm balance file %s" % (_rel(root, path), path.stem))
            json_files.append((path, "balance key"))
    for rel in HARM_DATA_FILES:
        if (Path(root) / rel).is_file():
            json_files.append((Path(root) / rel, "data key"))
    for path, label in json_files:
        try:
            data = json.loads(_read(path))
        except ValueError:
            continue
        for full, key in _json_keys(data):
            if harm_tokens(key):
                errors.append("%s: harm %s %s" % (_rel(root, path), label, full))
    i18n = Path(root) / "i18n"
    if i18n.is_dir():
        for path in sorted(i18n.glob("*.csv")):
            for line_no, line in enumerate(_read(path).splitlines(), start=1):
                key = line.split(",", 1)[0].strip()
                if line_no == 1 or not key:
                    continue
                if any(harm_tokens(part) for part in key.split(".")):
                    errors.append("%s:%d: harm i18n key %s" % (_rel(root, path), line_no, key))
    return errors


# --- (i) fog, darkness and procedural maps; (j) placeholder graphics ----------------------------------------

def fog_tokens(name: str) -> list:
    """Return the fog/darkness/reveal parts and sequences contained in an identifier or node name."""
    parts = split_identifier(name)
    joined = "_" + "_".join(parts) + "_"
    hits = [seq for seq in FOG_SEQUENCES if "_" + seq + "_" in joined]
    hits += sorted(set(parts) & FOG_PARTS)
    return hits


def _art_exempt_lines(text: str) -> set:
    return {line_no for line_no, body in gd_comments(text) if ART_EXEMPT_RE.search(body)}


def _gd_matches(root: Path, dirs, regex, message: str) -> list:
    errors = []
    for path in _files(root, dirs, ".gd"):
        text = _read(path)
        exempt = _art_exempt_lines(text)
        _nc, bare, _strings = gd_strip(text)
        for match in regex.finditer(bare):
            line_no = _line(bare, match.start())
            if line_no in exempt:
                continue
            found = next(g for g in match.groups() if g)
            errors.append("%s:%d: %s %s" % (_rel(root, path), line_no, found, message))
    return errors


def check_fog_and_procedural(root: Path) -> list:
    errors = []
    for path in _files(root, ART_GD_DIRS, ".gd"):
        rel = _rel(root, path)
        text = _read(path)
        exempt = _art_exempt_lines(text)
        _nc, bare, _strings = gd_strip(text)
        reported = set()
        for match in IDENT_RE.finditer(bare):
            name = match.group(0)
            hits = fog_tokens(name)
            line_no = _line(bare, match.start())
            if hits and name not in reported and line_no not in exempt:
                reported.add(name)
                errors.append("%s:%d: fog/darkness/reveal identifier %s (%s) – the whole level is always visible"
                              % (rel, line_no, name, "/".join(hits)))
    for path in _files(root, ART_GD_DIRS, ".tscn"):
        for line_no, line in enumerate(_read(path).splitlines(), start=1):
            match = TSCN_NODE_RE.match(line)
            if match and fog_tokens(match.group(1)):
                errors.append("%s:%d: fog/darkness/reveal node name %s" % (_rel(root, path), line_no, match.group(1)))
            light = LIGHT_TSCN_RE.search(line)
            if light:
                errors.append("%s:%d: %s darkens or hides the level (not allowed)"
                              % (_rel(root, path), line_no, light.group(1)))
    errors += _gd_matches(root, ART_GD_DIRS, LIGHT_GD_RE, "darkens or hides the level (not allowed)")
    errors += _gd_matches(root, PROC_MAP_DIRS, PROC_MAP_RE,
                          "– levels are handcrafted; paint layouts offline with tools/build_level_layout.gd")
    return errors


def check_placeholders(root: Path) -> list:
    errors = []
    for path in _files(root, PLACEHOLDER_TSCN_DIRS, ".tscn"):
        rel = _rel(root, path)
        if rel.startswith(PLACEHOLDER_TSCN_ALLOWED):
            continue
        for line_no, line in enumerate(_read(path).splitlines(), start=1):
            match = PLACEHOLDER_TSCN_RE.match(line)
            if match:
                errors.append("%s:%d: placeholder node %s in a gameplay scene – use sprites from assets/"
                              % (rel, line_no, match.group(1)))
    errors += _gd_matches(root, PLACEHOLDER_GD_DIRS, PLACEHOLDER_GD_RE,
                          "draws a placeholder shape – use sprites from assets/")
    return errors


def validate(root: Path = REPO) -> list:
    """Return every code-rule error below root (empty = valid)."""
    root = Path(root)
    return (check_comments(root) + check_magic_numbers(root) + check_networking(root) + check_third_party(root)
            + check_survival(root) + check_rng(root) + check_meta(root) + check_uids(root) + check_turn_grid(root)
            + check_harm(root) + check_fog_and_procedural(root) + check_placeholders(root))


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Validate the code rules.")
    parser.add_argument("--root", default=str(REPO))
    opts = parser.parse_args(argv)
    errors = validate(Path(opts.root))
    for err in errors:
        print("code: " + err)
    print("validate_code: %d error(s)" % len(errors))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
