"""Validate the i18n CSVs and the key usage in product code (standard library only).

Usage: python tools/validate_i18n.py [--root <dir>]   (exit code 1 on any error)

Checks i18n/*.csv (UTF-8 without BOM, header key,en,de, 3 columns, non-empty EN and DE, unique keys
across files, key prefix = csv stem, equal {placeholder} sets) and the .gd/.tscn files below scripts/,
scenes/ and ui/: literal keys in tr()/tr_n()/atr()/I18n.t(), key-like literals, literals assigned to
.text/.tooltip_text/.placeholder_text/.title and .tscn text properties that are not existing keys.
"""
import argparse
import csv
import io
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import REPO, code_files, gd_strip  # noqa: E402

HEADER = ["key", "en", "de"]
PLACEHOLDER_RE = re.compile(r"\{([A-Za-z0-9_]+)\}")
CALL_RE = re.compile(r'(?:(?<![\w.])(?:tr|tr_n|atr|atr_n)|\bI18n\.t)\s*\(\s*&?"((?:[^"\\\n]|\\.)*)"(?=\s*[,)])')
ASSIGN_RE = re.compile(r'\.(text|tooltip_text|placeholder_text|title)\s*=\s*"((?:[^"\\\n]|\\.)*)"')
TSCN_PROP_RE = re.compile(r'^(text|tooltip_text|placeholder_text|title)\s*=\s*"((?:[^"\\\n]|\\.)*)"\s*$')
FORMAT_RE = re.compile(r"%[-+ #0-9.*]*[a-zA-Z]|\{[A-Za-z0-9_]*\}")
FILE_EXTENSIONS = {
    "json", "csv", "gd", "tscn", "tres", "res", "png", "svg", "jpg", "ogg", "wav", "mp3", "txt", "md",
    "cfg", "import", "translation", "uid", "py", "html", "ttf", "otf",
}


def load_catalog(root: Path):
    """Return ({key: {"en", "de", "file"}}, errors) for root/i18n/*.csv."""
    messages = {}
    errors = []
    folder = Path(root) / "i18n"
    if not folder.is_dir():
        return messages, errors
    for path in sorted(folder.glob("*.csv")):
        name = path.name
        stem = path.stem
        raw = path.read_bytes()
        if raw.startswith(b"\xef\xbb\xbf"):
            errors.append("%s: UTF-8 BOM is not allowed" % name)
            raw = raw[3:]
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError as exc:
            errors.append("%s: not UTF-8 (%s)" % (name, exc))
            continue
        rows = list(csv.reader(io.StringIO(text)))
        if not rows or rows[0] != HEADER:
            errors.append("%s: header must be key,en,de" % name)
            continue
        for line_no, row in enumerate(rows[1:], start=2):
            if not row or (len(row) == 1 and not row[0].strip()):
                continue
            if len(row) != 3:
                errors.append("%s:%d: expected 3 columns, got %d" % (name, line_no, len(row)))
                continue
            key, en, de = row[0].strip(), row[1], row[2]
            if not key:
                errors.append("%s:%d: empty key" % (name, line_no))
                continue
            if not key.startswith(stem + "."):
                errors.append("%s:%d: key %s must start with '%s.'" % (name, line_no, key, stem))
            if key in messages:
                errors.append("%s:%d: duplicate key %s (also in %s)" % (name, line_no, key, messages[key]["file"]))
                continue
            if not en.strip():
                errors.append("%s:%d: EN text missing or empty for %s" % (name, line_no, key))
            if not de.strip():
                errors.append("%s:%d: DE text missing or empty for %s" % (name, line_no, key))
            if set(PLACEHOLDER_RE.findall(en)) != set(PLACEHOLDER_RE.findall(de)):
                errors.append("%s:%d: placeholders differ between EN and DE for %s" % (name, line_no, key))
            messages[key] = {"en": en, "de": de, "file": name}
    return messages, errors


def key_like_pattern(root: Path):
    """Return a regex matching literals that look like keys of an existing CSV area, or None."""
    folder = Path(root) / "i18n"
    stems = sorted(p.stem for p in folder.glob("*.csv")) if folder.is_dir() else []
    if not stems:
        return None
    alternatives = "|".join(re.escape(s) for s in stems)
    return re.compile(r"^(?:%s)\.[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)*$" % alternatives)


def _line_of(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def check_code(root: Path, messages: dict) -> list:
    """Return key usage errors of the .gd and .tscn product files."""
    errors = []
    key_like = key_like_pattern(root)
    for path in code_files(root, ".gd"):
        rel = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8")
        no_comments, _bare, strings = gd_strip(text)
        for match in CALL_RE.finditer(no_comments):
            if match.group(1) not in messages:
                errors.append("%s: unknown key in translation call: %s" % (rel, match.group(1)))
        for match in ASSIGN_RE.finditer(no_comments):
            value = match.group(2)
            if value == "" or not re.search(r"[A-Za-z]", FORMAT_RE.sub("", value)) or value in messages:
                continue
            errors.append("%s: hard-coded literal assigned to .%s is not an i18n key: \"%s\""
                          % (rel, match.group(1), value))
        if key_like is None:
            continue
        for literal, offset in strings:
            if not key_like.match(literal) or literal.rsplit(".", 1)[-1].lower() in FILE_EXTENSIONS:
                continue
            if literal not in messages:
                errors.append("%s:%d: unknown i18n key literal %s" % (rel, _line_of(text, offset), literal))
    for path in code_files(root, ".tscn"):
        rel = path.relative_to(root).as_posix()
        for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            match = TSCN_PROP_RE.match(line.strip())
            if match and match.group(2) != "" and match.group(2) not in messages:
                errors.append("%s:%d: hard-coded %s is not an i18n key: \"%s\""
                              % (rel, line_no, match.group(1), match.group(2)))
    return sorted(set(errors))


def validate(root: Path = REPO) -> list:
    """Return every i18n error below root (empty = valid)."""
    root = Path(root)
    messages, errors = load_catalog(root)
    return errors + check_code(root, messages)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Validate i18n CSVs and key usage.")
    parser.add_argument("--root", default=str(REPO))
    opts = parser.parse_args(argv)
    errors = validate(Path(opts.root))
    for err in errors:
        print("i18n: " + err)
    print("validate_i18n: %d error(s)" % len(errors))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
