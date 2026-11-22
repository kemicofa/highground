"""Keep Highground's translation catalogs in step with enUS.

  python3 scripts/l10n_sync.py missing  [ROOT] [--json]
  python3 scripts/l10n_sync.py template [ROOT] [-o FILE]
  python3 scripts/l10n_sync.py apply    [ROOT] FILE [--overwrite] [--prune-stale] [--dry-run]

ROOT is a repository or worktree and defaults to this repository.

Catalogs are libs/HighgroundKit/locale/<locale>.lua (every *.lua except
Library, Locales, Highground and enUS). Each one has one entry per line,
`  ["key"] = "value",`, in enUS order. `apply` keeps that order: a new key
goes after the nearest earlier enUS key already in the catalog.

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
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
LOCALE_DIR = Path("libs/HighgroundKit/locale")
NOT_CATALOGS = {"Library", "Locales", "Highground", "enUS"}
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
        self.path.write_text("".join(self.lines), encoding="utf-8")

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
            anchor = next(n for n, l in enumerate(self.lines) if "Register(" in l)
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
    catalogs = {p.stem: Catalog(p) for p in sorted(folder.glob("*.lua")) if p.stem not in NOT_CATALOGS}
    return english, order, catalogs


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
        report[locale] = {
            "missing": [k for k in order if k not in catalog.entries],
            "stale": [k for k in catalog.entries if k not in english.entries],
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
    for key in order:
        locales = [loc for loc, entry in report.items() if key in entry["missing"]]
        if locales:
            template[key] = {"_en": english.entries[key][1], **{loc: "" for loc in locales}}
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
        if key not in english.entries:
            refused.append(f"{key}: not an enUS key")
            continue
        source = english.entries[key][1]
        for locale, text in values.items():
            if locale.startswith("_") or text == "":
                continue
            catalog = catalogs.get(locale)
            if not catalog:
                refused.append(f"{key} [{locale}]: no such catalog")
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
                catalog.insert(key, text, order)
                added += 1
    if args.prune_stale:
        for catalog in catalogs.values():
            for key in [k for k in catalog.entries if k not in english.entries]:
                catalog.remove(key)
                removed += 1
    if not args.dry_run:
        for catalog in catalogs.values():
            catalog.write()
    print(f"{'Would add' if args.dry_run else 'Added'} {added}, updated {updated}, "
          f"kept {skipped} existing (use --overwrite), pruned {removed}, refused {len(refused)}")
    for line in refused:
        print(f"  refused {line}")
    remaining = status(english, order, catalogs)
    left = sum(len(e["missing"]) for e in remaining.values())
    if left:
        print(f"{left} catalog entries still missing; run `missing` for details")
    return 1 if refused or left else 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    commands = (
        ("missing", "list missing and stale keys per catalog; exit 1 if any", cmd_missing),
        ("template", "JSON skeleton of missing keys with their English source", cmd_template),
        ("apply", "insert translations from a filled template into the catalogs", cmd_apply),
    )
    for name, summary, run in commands:
        command = sub.add_parser(name, help=summary)
        command.add_argument("root", nargs="?", type=Path, default=ROOT, help="repository or worktree (default: this one)")
        command.set_defaults(run=run)
        if name == "missing":
            command.add_argument("--json", action="store_true")
        elif name == "template":
            command.add_argument("-o", "--output")
        else:
            command.add_argument("translations")
            command.add_argument("--overwrite", action="store_true", help="replace existing translations")
            command.add_argument("--prune-stale", action="store_true", help="remove keys that enUS no longer has")
            command.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    return args.run(args)


if __name__ == "__main__":
    sys.exit(main())
