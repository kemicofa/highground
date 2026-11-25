"""Keep Highground's translation catalogs in step with enUS.

  python3 scripts/l10n_sync.py missing  [ROOT] [--json]
  python3 scripts/l10n_sync.py template [ROOT] [-o FILE]
  python3 scripts/l10n_sync.py apply    [ROOT] FILE [--overwrite] [--prune-stale] [--dry-run]
  python3 scripts/l10n_sync.py index    [ROOT] [--check]

ROOT is a repository or worktree and defaults to this repository.

Catalogs are libs/HighgroundKit/locale/<locale>.lua (files named like enUS,
other than enUS). Each one has one entry per line,
`  ["key"] = "value",`, in enUS order. `apply` keeps that order: a new key
goes after the nearest earlier enUS key already in the catalog.

Only English and the selected language load in game, so Index.lua in the same
folder keeps what Highground reads from the others: each catalog's coverage
and every catalog's text for the keys passed to Locale:Variants in runtime
code (literal keys only). `apply` rewrites it; `index` writes it, or with
--check fails when it is stale (tests/test_localization.py checks it too).

Plural families are English keys <base>.one and <base>.other (Locale:Plural).
A catalog whose language needs more CLDR categories (Russian: few, many)
must also have <base>.few / <base>.many; they are checked against the
English other form and placed after the family's English keys.

Translations JSON: {"key": {"deDE": "...", "frFR": "...", ...}}. Keys
starting with "_" (such as the template's "_en") and empty strings are
ignored. An entry is refused when its inline controls (|cXXXXXXXX, |r, |H,
|T, slash commands, #showtooltip), command-syntax literals or {placeholders}
differ from English, mirroring tests/test_localization.py and the Lua
library's placeholder check.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
LOCALE_DIR = Path("libs/HighgroundKit/locale")
CATALOG_NAME = re.compile(r"[a-z]{2}[A-Z]{2}")
INDEX = "Index.lua"
VARIANTS_CALL = re.compile(r":\s*Variants\s*\(")  # Locale:Variants(...), not other modules' Variants
VARIANTS_KEY = re.compile(r':\s*Variants\s*\(\s*"([\w.]+)"\s*\)')
ENTRY = re.compile(r'^(\s*)\["([^"]+)"\]\s*=\s*("(?:\\.|[^"\\])*")\s*,\s*$')
CONTROLS = re.compile(r"\|c[0-9a-fA-F]{8}|\|[rHhTt]|/(?:highground|hgbg|hgrep|hgb|hgn|hgm|hga|hg|reload|castsequence|run)\b"
                      r"|#showtooltip|#show\b", re.ASCII)
TOKENS = re.compile(r"\{([A-Za-z_][A-Za-z0-9_]*)\}")
# Literals the repository test requires verbatim in every translation.
SYNTAX = (
    "{CMD} [board] | list | add [GOLD] NAME [; note] | submit NAME | approve NAME | reject NAME | shared | suggestions | claims | gold | remove NAME | claim NAME | share NAME | export NAME | import [CODE] | sync | test [FEATURE|stop] | guide [CHAPTER|stop] | on | off",
    "{CMD} share NAME", "{CMD} add [GOLD] NAME [; note]", "{CMD} {sub} NAME",
    "{B_CMD} shared add GOLD DURATION NAME [; note]", "500 2h target",
    "communities | manage | report [target/full name] | sync | status | on | off",
    "board | receive on/off | publish on/off | threshold GOLD | add GOLD 2h NAME | claim NAME | withdraw NAME | claims | sync",
)
# CLDR categories each language needs beyond English's one/other, for whole
# numbers. Mirrors Library.PLURAL_EXTRA in libs/HighgroundKit/locale/Library.lua.
PLURAL_EXTRA = {"ru": ("few", "many")}
LUA_ESCAPES = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "'": "'", "\\": "\\", "a": "\a", "b": "\b", "f": "\f", "v": "\v"}


def decode(literal):
    """Lua double-quoted string literal -> text."""
    body, out, i = literal[1:-1], [], 0
    while i < len(body):
        ch = body[i]
        if ch != "\\":
            out.append(ch)
            i += 1
            continue
        nxt = body[i + 1]
        if nxt.isdigit():
            digits = re.match(r"\d{1,3}", body[i + 1:]).group(0)
            out.append(chr(int(digits)))
            i += 1 + len(digits)
        else:
            out.append(LUA_ESCAPES.get(nxt, nxt))
            i += 2
    # Decimal escapes produce bytes; reassemble UTF-8 sequences.
    text = "".join(out)
    try:
        return text.encode("latin-1").decode("utf-8")
    except (UnicodeEncodeError, UnicodeDecodeError):
        return text


def encode(text):
    """Text -> Lua literal that json.loads also reads (raw UTF-8, like #212)."""
    escaped = text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t").replace("\r", "\\r")
    return f'"{escaped}"'


class Catalog:
    def __init__(self, path):
        self.path, self.lines = path, path.read_text(encoding="utf-8").splitlines(keepends=True)
        self.index()

    def index(self):
        self.entries, self.indent = {}, "  "
        for n, line in enumerate(self.lines):
            m = ENTRY.match(line)
            if m:
                self.indent = m.group(1)
                self.entries[m.group(2)] = (n, decode(m.group(3)))

    def write(self):
        # Replace the catalog only once its new text is complete, so an interruption cannot truncate it.
        temporary = self.path.with_name(f".{self.path.name}.tmp")
        try:
            temporary.write_text("".join(self.lines), encoding="utf-8")
            os.replace(temporary, self.path)
        except BaseException:
            temporary.unlink(missing_ok=True)
            raise

    def line(self, key, text):
        return f'{self.indent}["{key}"] = {encode(text)},\n'

    def insert(self, key, text, order):
        """Insert after the nearest earlier English key present; else after the Register line."""
        position = order.index(key)
        anchor = None
        for earlier in reversed(order[:position]):
            if earlier in self.entries:
                anchor = self.entries[earlier][0]
                break
        if anchor is None:
            anchor = next((n for n, l in enumerate(self.lines) if "Register(" in l), None)
            if anchor is None:
                raise SystemExit(f"{self.path}: no Register( line to insert {key} after")
        self.lines.insert(anchor + 1, self.line(key, text))
        self.index()

    def replace(self, key, text):
        self.lines[self.entries[key][0]] = self.line(key, text)
        self.index()

    def remove(self, key):
        del self.lines[self.entries[key][0]]
        self.index()


def load(root):
    folder = Path(root) / LOCALE_DIR
    if not folder.is_dir():
        raise SystemExit(f"No locale folder: {folder}")
    english = Catalog(folder / "enUS.lua")
    order = list(english.entries)
    catalogs = {p.stem: Catalog(p) for p in sorted(folder.glob("*.lua"))
                if CATALOG_NAME.fullmatch(p.stem) and p.stem != "enUS"}
    return english, order, catalogs


def variant_keys(root):
    """Message keys runtime code passes to Locale:Variants; each must be a literal."""
    root = Path(root)
    keys = set()
    for base in (root / "addons", root / "libs/HighgroundKit"):
        for directory, folders, files in os.walk(base):
            folders[:] = sorted(f for f in folders if f != "tests")
            if Path(directory) == root / LOCALE_DIR:
                continue
            for name in files:
                if not name.endswith(".lua"):
                    continue
                path = Path(directory) / name
                text = path.read_text(encoding="utf-8")
                calls, literal = VARIANTS_CALL.findall(text), VARIANTS_KEY.findall(text)
                if len(calls) != len(literal):
                    raise SystemExit(f"{path.relative_to(root)}: Locale:Variants needs a literal message key")
                keys.update(literal)
    return sorted(keys)


def render_index(root):
    """Index.lua for the catalogs under root: coverage and Variants texts."""
    english, order, catalogs = load(root)
    english_keys = set(order)
    coverage = {"enUS": len(order)}
    coverage.update({locale: sum(key in english_keys for key in catalog.entries)
                     for locale, catalog in catalogs.items()})
    lines = ["-- Generated by scripts/l10n_sync.py from the catalogs; do not edit.",
             "-- Only English and the selected language load (docs/localization.md).",
             "local _, ns = ...", "ns.LocaleIndex = {",
             "  -- Source messages each catalog translates.",
             "  coverage = { " + ", ".join(f"{locale} = {count}" for locale, count in coverage.items()) + " },",
             "  -- Every catalog's text for the keys runtime code passes to Locale:Variants.",
             "  variants = {"]
    for key in variant_keys(root):
        if key not in english.entries:
            raise SystemExit(f"Locale:Variants key is not an enUS key: {key}")
        texts = []
        for catalog in (english, *catalogs.values()):
            text = catalog.entries.get(key, (None, None))[1]
            if text is not None and text not in texts:
                texts.append(text)
        lines.append(f'    ["{key}"] = {{ ' + ", ".join(encode(text) for text in texts) + " },")
    lines += ["  },", "}", ""]
    return "\n".join(lines)


def write_index(root):
    """Write Index.lua when it differs; returns whether it changed."""
    path = Path(root) / LOCALE_DIR / INDEX
    text = render_index(root)
    if path.exists() and path.read_text(encoding="utf-8") == text:
        return False
    temporary = path.with_name(f".{path.name}.tmp")
    try:
        temporary.write_text(text, encoding="utf-8")
        os.replace(temporary, path)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise
    return True


def families(english_keys):
    """Plural family bases: English has both <base>.one and <base>.other."""
    keys = set(english_keys)
    return [k[:-len(".other")] for k in english_keys if k.endswith(".other") and k[:-len(".other")] + ".one" in keys]


def expected_keys(english_keys, locale):
    """The keys a catalog must have, in English order: every English key plus
    the extra plural forms its language needs after each family."""
    extra = PLURAL_EXTRA.get(locale[:2].lower(), ())
    bases = set(families(english_keys)) if extra else set()
    out = []
    for key in english_keys:
        out.append(key)
        if key.endswith(".other") and key[:-len(".other")] in bases:
            out.extend(f"{key[:-len('.other')]}.{category}" for category in extra)
    return out


def source_key(english_keys, key):
    """The English key a catalog key is checked against (extra plural forms:
    the family's other form), or None."""
    if key in english_keys:
        return key
    stem, _, category = key.rpartition(".")
    if category in ("zero", "two", "few", "many") and stem + ".other" in english_keys and stem + ".one" in english_keys:
        return stem + ".other"
    return None


def problems(source, text):
    """Why a translation would fail the repository checks, or []."""
    issues = []
    if not text.strip():
        issues.append("empty")
    if Counter(CONTROLS.findall(source)) != Counter(CONTROLS.findall(text)):
        issues.append(f"inline controls differ: {sorted(CONTROLS.findall(source))} vs {sorted(CONTROLS.findall(text))}")
    if set(TOKENS.findall(source)) != set(TOKENS.findall(text)):
        issues.append(f"placeholders differ: {sorted(set(TOKENS.findall(source)))} vs {sorted(set(TOKENS.findall(text)))}")
    for literal in SYNTAX:
        if literal in source and literal not in text:
            issues.append(f"missing literal: {literal}")
    if 'NAME can be "target"' in source and '"target"' not in text:
        issues.append('missing "target"')
    return issues


def status(english, order, catalogs):
    report = {}
    for locale, catalog in catalogs.items():
        expected = expected_keys(order, locale)
        wanted = set(expected)
        report[locale] = {
            "missing": [k for k in expected if k not in catalog.entries],
            "stale": [k for k in catalog.entries if k not in wanted],
        }
    return report


def cmd_missing(args):
    english, order, catalogs = load(args.root)
    report = status(english, order, catalogs)
    if args.json:
        print(json.dumps(report, indent=2, ensure_ascii=False))
    else:
        for locale, entry in report.items():
            print(f"{locale}: {len(entry['missing'])} missing, {len(entry['stale'])} stale")
            for key in entry["missing"]:
                print(f"  - {key}")
            for key in entry["stale"]:
                print(f"  x {key} (not in enUS)")
    return 1 if any(e["missing"] or e["stale"] for e in report.values()) else 0


def cmd_template(args):
    english, order, catalogs = load(args.root)
    report = status(english, order, catalogs)
    template = {}
    every = []
    for locale in catalogs:
        for key in expected_keys(order, locale):
            if key not in every:
                every.append(key)
    for key in every:
        locales = [loc for loc, entry in report.items() if key in entry["missing"]]
        if locales:
            source = source_key(english.entries, key)
            template[key] = {"_en": english.entries[source][1], **{loc: "" for loc in locales}}
    text = json.dumps(template, indent=2, ensure_ascii=False) + "\n"
    if args.output:
        Path(args.output).write_text(text, encoding="utf-8")
        print(f"{len(template)} keys -> {args.output}", file=sys.stderr)
    else:
        sys.stdout.write(text)
    return 0


def cmd_apply(args):
    english, order, catalogs = load(args.root)
    data = json.loads(Path(args.translations).read_text(encoding="utf-8"))
    added = updated = skipped = removed = 0
    refused = []
    for key, values in data.items():
        if key.startswith("_"):
            continue
        origin = source_key(english.entries, key)
        if not origin:
            refused.append(f"{key}: not an enUS key")
            continue
        source = english.entries[origin][1]
        for locale, text in values.items():
            if locale.startswith("_") or text == "":
                continue
            catalog = catalogs.get(locale)
            if not catalog:
                refused.append(f"{key} [{locale}]: no such catalog")
                continue
            if key not in expected_keys(order, locale):
                refused.append(f"{key} [{locale}]: this language has no such plural form")
                continue
            issues = problems(source, text)
            if issues:
                refused.append(f"{key} [{locale}]: " + "; ".join(issues))
                continue
            if key in catalog.entries:
                if catalog.entries[key][1] == text:
                    continue
                if not args.overwrite:
                    skipped += 1
                    continue
                catalog.replace(key, text)
                updated += 1
            else:
                catalog.insert(key, text, expected_keys(order, locale))
                added += 1
    if args.prune_stale:
        for locale, catalog in catalogs.items():
            wanted = set(expected_keys(order, locale))
            for key in [k for k in catalog.entries if k not in wanted]:
                catalog.remove(key)
                removed += 1
    if not args.dry_run:
        for catalog in catalogs.values():
            catalog.write()
        write_index(args.root)
    print(f"{'Would add' if args.dry_run else 'Added'} {added}, updated {updated}, "
          f"kept {skipped} existing (use --overwrite), pruned {removed}, refused {len(refused)}")
    for line in refused:
        print(f"  refused {line}")
    remaining = status(english, order, catalogs)
    left = sum(len(e["missing"]) for e in remaining.values())
    if left:
        print(f"{left} catalog entries still missing; run `missing` for details")
    return 1 if refused or left else 0


def cmd_index(args):
    if args.check:
        path = Path(args.root) / LOCALE_DIR / INDEX
        if not path.exists() or path.read_text(encoding="utf-8") != render_index(args.root):
            print(f"{LOCALE_DIR / INDEX} is stale; run: python3 scripts/l10n_sync.py index", file=sys.stderr)
            return 1
        return 0
    print(f"{LOCALE_DIR / INDEX} {'updated' if write_index(args.root) else 'is current'}")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    commands = (
        ("missing", "list missing and stale keys per catalog; exit 1 if any", cmd_missing),
        ("template", "JSON skeleton of missing keys with their English source", cmd_template),
        ("apply", "insert translations from a filled template into the catalogs", cmd_apply),
        ("index", "write Index.lua: coverage and Locale:Variants texts of every catalog", cmd_index),
    )
    for name, summary, run in commands:
        command = sub.add_parser(name, help=summary)
        command.add_argument("root", nargs="?", type=Path, default=ROOT, help="repository or worktree (default: this one)")
        command.set_defaults(run=run)
        if name == "missing":
            command.add_argument("--json", action="store_true")
        elif name == "template":
            command.add_argument("-o", "--output")
        elif name == "index":
            command.add_argument("--check", action="store_true", help="exit 1 when Index.lua is stale")
        else:
            command.add_argument("translations")
            command.add_argument("--overwrite", action="store_true", help="replace existing translations")
            command.add_argument("--prune-stale", action="store_true", help="remove keys that enUS no longer has")
            command.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    return args.run(args)


if __name__ == "__main__":
    sys.exit(main())
