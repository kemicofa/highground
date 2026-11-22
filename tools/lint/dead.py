"""Report-only search for unused code, locale keys, files and assets in runtime addon code.

    python3 tools/lint/lint.py --dead [--root DIR]

Runtime code is everything under addons/ and libs/ outside tests/ folders.
References are found by name, so the report is conservative: a function
counts as used when its name appears anywhere else, as an identifier, a
string or a word in XML or a TOC. Confidence reflects what name matching
cannot see:

- high: the name occurs only at its definitions and in no test.
- medium: only tests use it, or a string fragment could build its name.
- low: engine callbacks (On..., mixins) or a table indexed with computed
  keys, where dispatch can reach any member.

Unused locals (the validator's rule, baselined ones included) are listed
too. Event handlers (ALL_CAPS names) are skipped. A module-level function
defined twice is reported when both definitions load from one TOC: high in
one file, medium across files (possibly an intended override). Locale keys
are looked up outside the catalogs. Nothing is deleted.
"""
from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
import os
from pathlib import Path, PurePosixPath
import re
import subprocess

import references
import scopes

ASSETS = {".tga", ".blp", ".ogg", ".mp3", ".ttf", ".png", ".jpg"}
CATALOG = re.compile(r"^[a-z]{2}[A-Z]{2}\.lua$")
KEY = re.compile(r'^\s*\["([^"]+)"\]\s*=', re.M)
PLURAL = {"zero", "one", "two", "few", "many", "other"}
ENGINE = re.compile(r"^On[A-Z]|^(SetPosition|RefreshAllData|RemoveAllData)$")
COVERAGE = Path(__file__).resolve().parents[1] / "coverage.lua"


@dataclass
class Finding:
    kind: str
    confidence: str
    path: str
    line: int
    name: str
    size: int = 0
    reason: str = ""

    def __str__(self) -> str:
        where = f"{self.path}:{self.line}" if self.line else self.path
        size = f"{self.size:4d} lines" if self.size else " " * 10
        return f"{self.confidence:6s} {size} {where} {self.name}  ({self.reason})"


def files(root: Path) -> tuple[list[str], list[str]]:
    """(runtime files, test Lua files) under addons/ and libs/, without following links."""
    runtime, tests = [], []
    for top in ("addons", "libs", "tests"):
        for folder, dirs, names in os.walk(root / top):
            dirs[:] = sorted(d for d in dirs if not (Path(folder) / d).is_symlink() and d != "docs")
            for name in sorted(names):
                path = (Path(folder) / name)
                if path.is_symlink():
                    continue
                relative = path.relative_to(root).as_posix()
                in_tests = top == "tests" or "tests" in PurePosixPath(relative).parts
                if in_tests and name.endswith(".lua"):
                    tests.append(relative)
                elif not in_tests and top != "tests":
                    runtime.append(relative)
    return runtime, tests


def lua_words(root: Path, names: list[str], identifiers: bool = True) -> tuple[Counter, dict[str, list]]:
    """String-literal (and optionally identifier) counts over Lua files, and each file's tokens."""
    counts, tokens = Counter(), {}
    for name in names:
        try:
            tokens[name] = scopes.tokenize((root / name).read_text(encoding="utf-8", errors="replace"))
        except SyntaxError:
            continue
        for kind, value, _ in tokens[name]:
            if kind == "name" and identifiers:
                counts[value] += 1
            elif kind == "string" and value[:1] in "\"'":
                counts[value[1:-1]] += 1
    return counts, tokens


def definitions(tokens: list) -> list[tuple[str, str, int]]:
    """(qualified name, table, line) for function X.y / X:y and X.y = function definitions."""
    found, values = [], [value for _, value, _ in tokens]
    for i, (kind, value, line) in enumerate(tokens):
        parts, j = [], None
        if value == "function" and kind == "keyword" and tokens[i + 1][0] == "name":
            j = i + 1
        elif kind == "name" and (i == 0 or values[i - 1] not in {".", ":", "local", "function"}):
            j = i
        if j is None:
            continue
        parts.append(values[j])
        while values[j + 1] in {".", ":"} and tokens[j + 2][0] == "name":
            parts.append(values[j + 2])
            j += 2
        if len(parts) < 2:
            continue
        is_def = (value == "function" and values[j + 1] == "(") or \
            (value != "function" and values[j + 1] == "=" and values[j + 2] == "function")
        if is_def:
            found.append((".".join(parts), parts[-2], line))
    return found


def fragments(tokens: dict[str, list]) -> list[str]:
    """String literals concatenated with something else: pieces of computed names and keys."""
    pieces = []
    for stream in tokens.values():
        for i, (kind, value, _) in enumerate(stream):
            if kind == "string" and value[:1] in "\"'" and len(value) > 4 and (
                    stream[i + 1][1] == ".." or i and stream[i - 1][1] == ".."):
                pieces.append(value[1:-1])
    return pieces


def spans(root: Path, names: list[str]) -> dict[tuple[str, int], int]:
    """(file, first line) -> executable size of each function, from LuaJIT bytecode."""
    output = subprocess.run(["luajit", str(COVERAGE), "lines", *names], cwd=root,
                            capture_output=True, text=True).stdout
    result = {}
    for row in output.splitlines():
        kind, name, *numbers = row.split("\t")
        if kind == "F":
            result[(name, int(numbers[0]))] = int(numbers[1]) - int(numbers[0]) + 1
    return result


def manifests(root: Path) -> dict[str, set[str]]:
    """TOC path -> real paths of everything it loads (XML includes followed)."""
    import lint
    loads = {}
    for toc in sorted((root / "addons").glob("*/*.toc")):
        addon = toc.parent
        loaded = set()
        for entry in lint.toc_entries(addon, toc.name):
            try:
                loaded |= {os.path.realpath(addon / f) for f in lint.dependencies(addon, entry)}
            except (AssertionError, OSError):
                continue
        loads[toc.relative_to(root).as_posix()] = loaded
    return loads


def unused_functions(root, code, counts, test_counts, tokens, loads) -> list[Finding]:
    resolvers, found = {}, []
    for name in code:
        if name in tokens:
            checker = scopes.Checker((root / name).read_text(encoding="utf-8", errors="replace"))
            checker.chunk()
            resolvers[name] = references.Resolver(name, tokens[name], checker.free)
            # The validator's unused locals, including those its baseline allows.
            found += [Finding("local", "high", name, line, symbol, 0, message)
                      for line, rule, symbol, message in checker.findings if rule == "unused"]
    accesses, defined, defs = Counter(), Counter(), {}
    for name, resolver in resolvers.items():
        accesses.update(resolver.accesses())
        defs[name] = [(resolver.table(q.split(".")[:-1]), q.split(".")[-1], q, line)
                      for q, _, line in definitions(tokens[name])]
        defined.update((table, member) for table, member, _, _ in defs[name])
    dynamic = {resolver.canonical([stream[i][1]]) for name, resolver in resolvers.items()
               for stream in [tokens[name]] for i in range(len(stream) - 2)
               if stream[i][0] == "name" and stream[i + 1][1] == "[" and stream[i + 2][0] != "string"}
    # An access to a member its resolved table never defines means the alias
    # is not the table we think (Host.Kit is ns.Kit, a constructor's local
    # self): count it like an access through an unknown value.
    unknown = Counter()
    for (table, member), count in accesses.items():
        if table is None or (table, member) not in defined:
            unknown[member] += count
    pieces, sizes = fragments(tokens), spans(root, code)
    for name, items in defs.items():
        for table, member, qualified, line in items:
            if re.fullmatch(r"[A-Z0-9_]+", member) or unknown[member] or counts[member] or \
                    accesses[(table, member)] > defined[(table, member)]:
                continue
            if ENGINE.search(member) or table.endswith("Mixin"):
                confidence, reason = "low", "engine callback or mixin method"
            elif table in dynamic:
                confidence, reason = "low", f"{qualified.rsplit('.', 1)[0]}[...] is indexed with computed keys"
            elif test_counts[member]:
                confidence, reason = "medium", "used only by tests"
            elif any(len(p) >= 4 and (member.startswith(p) or member.endswith(p)) for p in pieces):
                confidence, reason = "medium", "a concatenated string may build the name"
            else:
                confidence, reason = "high", "no reference to this table's member"
            found.append(Finding("function", confidence, name, line, qualified, sizes.get((name, line), 0),
                                 f"{reason}; table {table}"))
    # Redefinitions of module-level functions (unindented) that load together.
    places: dict[str, list[tuple[str, int]]] = {}
    for name, items in defs.items():
        lines = (root / name).read_text(encoding="utf-8", errors="replace").splitlines()
        for table, member, _, line in items:
            if line <= len(lines) and not lines[line - 1][:1].isspace():
                places.setdefault(f"{table}.{member}", []).append((name, line))
    for qualified, where in places.items():
        real = {os.path.realpath(root / name) for name, _ in where}
        together = len(real) > 1 and any(len(real & loaded) > 1 for loaded in loads.values())
        if len(where) > 1 and (together or len(real) == 1):
            first = min(where)
            others = ", ".join(f"{n}:{l}" for n, l in sorted(where) if (n, l) != first)
            confidence = "high" if len(real) == 1 else "medium"
            found.append(Finding("redefined", confidence, first[0], first[1], qualified, 0, f"also defined at {others}"))
    return found


def unused_keys(root, lua, counts, test_counts, tokens) -> list[Finding]:
    catalogs = [n for n in lua if CATALOG.match(Path(n).name) and Path(n).name == "enUS.lua"]
    pieces = [p for p in fragments(tokens) if len(p) >= 3]
    patterns = [re.compile("^" + ".*".join(map(re.escape, re.split(r"%[sd]", p))) + "$")
                for p in pieces if re.search(r"%[sd]", p)]
    patterns += [re.compile("^" + ".*".join(map(re.escape, re.split(r"%[sd]", text[1:-1]))) + "$")
                 for stream in tokens.values() for kind, text, _ in stream
                 if kind == "string" and re.search(r"%[sd]", text) and "." in text]
    found = []
    for catalog in catalogs:
        text = (root / catalog).read_text(encoding="utf-8")
        for match in KEY.finditer(text):
            key, line = match.group(1), text.count("\n", 0, match.start()) + 1
            stem, _, last = key.rpartition(".")
            if counts[key] or (last in PLURAL and counts[stem]):
                continue
            if any(key.startswith(p) or key.endswith(p) for p in pieces) or any(p.match(key) for p in patterns):
                confidence, reason = "low", "a concatenated or formatted string may build the key"
            elif test_counts[key]:
                confidence, reason = "medium", "used only by tests"
            else:
                confidence, reason = "high", "key appears nowhere else"
            found.append(Finding("locale", confidence, catalog, line, key, 0, reason))
    return found


def unloaded(root, runtime, loads) -> list[Finding]:
    loaded = set().union(*loads.values()) if loads else set()
    return [Finding("file", "high", name, 0, Path(name).name, 0, "loaded by no TOC or XML")
            for name in runtime if Path(name).suffix in {".lua", ".xml"}
            and os.path.realpath(root / name) not in loaded and "tools" not in PurePosixPath(name).parts
            and not (Path(name).name == "Bindings.xml" and len(PurePosixPath(name).parts) == 3)]  # loaded by WoW


def unused_assets(root, runtime) -> list[Finding]:
    text = "\n".join((root / n).read_text(encoding="utf-8", errors="replace")
                     for n in runtime if Path(n).suffix in {".lua", ".xml", ".toc"})
    found = []
    for name in runtime:
        path = PurePosixPath(name)
        if path.suffix.lower() not in ASSETS:
            continue
        pattern = re.compile(r"(?i)(^|[\\/\"'])" + re.escape(path.stem) + r"(\.\w{3})?([\"'\\/\s]|$)", re.M)
        if not pattern.search(text):
            found.append(Finding("asset", "medium", name, 0, path.name, 0, "file name appears in no Lua, XML or TOC"))
    return found


RANK = {"high": 0, "medium": 1, "low": 2}


def report(root: Path) -> list[Finding]:
    """Every finding, most actionable first: confidence, then size."""
    runtime, tests = files(root)
    lua = [n for n in runtime if n.endswith(".lua")]
    code = [n for n in lua if not CATALOG.match(Path(n).name)]  # locale catalogs repeat every key
    # Strings and XML/TOC words can name a function dynamically; identifiers
    # are matched through references.Resolver instead.
    counts, tokens = lua_words(root, code, identifiers=False)
    for name in runtime:
        if Path(name).suffix in {".xml", ".toc"}:
            counts.update(re.findall(r"\w+", (root / name).read_text(encoding="utf-8", errors="replace")))
    test_counts, _ = lua_words(root, tests)
    loads = manifests(root)
    found = unused_functions(root, code, counts, test_counts, tokens, loads)
    found += unused_keys(root, lua, counts, test_counts, tokens)
    found += unloaded(root, runtime, loads) + unused_assets(root, runtime)
    return sorted(found, key=lambda f: (RANK[f.confidence], -f.size, f.kind, f.path, f.line))
