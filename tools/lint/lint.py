"""Generic checks for a WoW addon folder: TOCs, XML, loaded modules, globals, scopes, file size and Lua 5.1 compilation.

An addon's tests/validate.py imports this module and passes its own inputs:
the TOC files, the globs of runtime modules every TOC must load, and the
global names it may write. Each check raises AssertionError with the files
at fault. LuaJIT runs the compilation and global scans (Lua 5.1, like WoW).

    import lint
    runtime = lint.validate(root, ["Addon.toc"], modules=["*.lua"],
                            allowed_globals={"AddonDB"}, allowed_prefixes=("SLASH_",))

validate() also fails on global reads that are probably missing locals
(unknown lowercase names, or a file-level local read before its
declaration) and on unused locals (scopes.py) not listed in baseline.txt. Run this file to
lint every runtime module in the repository, including report-only
warnings: shadowed locals, allocations in OnUpdate handlers and literal UI
text that bypasses localization.

    python3 tools/lint/lint.py [--errors-only] [--strict] [--all | path ...]
    python3 tools/lint/lint.py --dead [--root DIR]   # report-only unused code (dead.py)

Paths are Lua files or folders (searched for *.lua); without paths, or with
--all, every tracked runtime module under addons/ and libs/ is linted.
"""
import argparse
from collections import Counter
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

sys.dont_write_bytecode = True  # no __pycache__ in tools/lint
import scopes  # noqa: E402

GLOBALS_SCANNER = Path(__file__).resolve().with_name("globals.lua")
BASELINE = Path(__file__).resolve().with_name("baseline.txt")
REPOSITORY = Path(__file__).resolve().parents[2]
MAX_LINES = 400
# Lua 5.1's library and WoW's lowercase API. Any other lowercase global read
# is usually a missing, misspelled or out-of-scope local.
LOWERCASE_GLOBALS = frozenset("""
    _G _VERSION assert collectgarbage error getfenv getmetatable ipairs load loadstring next pairs pcall
    print rawequal rawget rawset select setfenv setmetatable tonumber tostring type unpack xpcall
    bit coroutine math string table
    abs ceil floor max min mod fmod sqrt random sort getn foreach foreachi format gsub gmatch
    strbyte strchar strfind strlen strlower strmatch strrep strrev strsub strupper
    strsplit strsplittable strjoin strtrim strconcat strlenutf8 strcmputf8i
    wipe tinsert tremove tContains tInvert tIndexOf tFilter tAppendAll tCompare tDeleteItem tUnorderedRemove
    date time difftime hooksecurefunc securecall securecallfunction secureexecuterange issecure forceinsecure
    issecretvalue issecrettable canaccessvalue canaccesstable canaccesssecrets scrubsecretvalues secretwrap
    debugstack debuglocals debugprofilestart debugprofilestop geterrorhandler seterrorhandler
    loadstring_untainted getglobal setglobal scrub
    sin cos tan asin acos atan atan2 deg rad exp log log10 frexp ldexp fastrandom tostringall gcinfo
""".split())
# The standalone interpreter's extra globals, allowed in tests and tools.
TOOL_GLOBALS = frozenset("arg debug dofile io jit loadfile os package require newproxy".split())
# Literal text passed straight to a widget (comments are stripped first).
UI_LITERAL = re.compile(r""":(?:SetText|SetFormattedText|AddLine|AddDoubleLine)\(\s*(["'])[^"']*[A-Za-z]{2}""")
# Explicit _G.Name = ... or _G["Name"] = ... writes (table sets, not GSET).
EXPLICIT_GLOBAL = re.compile(r"""^\s*_G(?:\.(\w+)|\[["']([^"']+)["']\])\s*=(?!=)""")


def require_luajit():
    """Fail early without LuaJIT."""
    assert shutil.which("luajit"), "Validation requires LuaJIT (Lua 5.1 semantics, matching WoW)."


def toc_entries(root, toc):
    """The files a TOC loads, in order; fails on a duplicate entry."""
    lines = (Path(root) / toc).read_text().splitlines()
    entries = [s.strip() for s in lines if s.strip() and not s.startswith("#")]
    assert len(entries) == len(set(entries)), f"Duplicate load entry in {toc}"
    return entries


def saved_variables(root, toc):
    """The names in a TOC's SavedVariables and SavedVariablesPerCharacter fields."""
    names = set()
    for match in re.finditer(r"^## SavedVariables(?:PerCharacter)?:(.*)$", (Path(root) / toc).read_text(), re.M):
        names.update(match.group(1).replace(",", " ").split())
    return names


def dependencies(root, name):
    """name and every file its XML includes (Script and Include), recursively."""
    root = Path(root)
    path = root / name
    assert path.is_file(), f"Missing runtime file: {name}"
    result = {name}
    if path.suffix == ".xml":
        for node in ET.parse(path).iter():
            if node.tag.rsplit("}", 1)[-1] in {"Script", "Include"} and "file" in node.attrib:
                relative = (path.parent / node.attrib["file"]).relative_to(root).as_posix()
                result.update(dependencies(root, relative))
    return result


def loaded_files(root, entries):
    """Every file the TOC entries load, XML includes included."""
    loaded = set()
    for entry in entries:
        loaded.update(dependencies(root, entry))
    return loaded


def check_unloaded(root, loaded, modules, toc):
    """Every file matching the module globs is loaded."""
    root = Path(root)
    actual = {p.relative_to(root).as_posix() for pattern in modules for p in root.glob(pattern)}
    assert actual <= loaded, f"Unloaded modules in {toc}: {sorted(actual - loaded)}"


def check_globals(root, lua_files, allowed_globals=(), allowed_prefixes=()):
    """No global writes outside the allowed names and prefixes."""
    root = Path(root)
    files = sorted(lua_files)
    writes = subprocess.run(["luajit", str(GLOBALS_SCANNER), *files],
                            cwd=root, check=True, capture_output=True, text=True).stdout.splitlines()
    for name in files:
        for number, line in enumerate((root / name).read_text().splitlines(), 1):
            if match := EXPLICIT_GLOBAL.match(line):
                writes.append(f"{name}:{number}: {match.group(1) or match.group(2)}")
    prefixes = tuple(allowed_prefixes)
    accidental = [w for w in writes if not (
        (name := w.rsplit(": ", 1)[1]) in allowed_globals or name.startswith(prefixes))]
    assert not accidental, "Accidental globals (declare them local):\n  " + "\n  ".join(accidental)


def global_reads(root, lua_files):
    """(file, line, name) for every global read, from LuaJIT bytecode."""
    files = sorted(lua_files)
    output = subprocess.run(["luajit", str(GLOBALS_SCANNER), "--reads", *files],
                            cwd=root, check=True, capture_output=True, text=True).stdout
    reads = []
    for row in output.splitlines():
        location, name = row.rsplit(": ", 1)
        path, line = location.rsplit(":", 1)
        reads.append((path, int(line), name))
    return sorted(reads)


def repository_path(root, name):
    """name (relative to root, possibly through a libs/ or features/ link) relative to the repository."""
    path = Path(os.path.realpath(Path(root) / name))
    real = Path(os.path.realpath(REPOSITORY))
    return path.relative_to(real).as_posix() if path.is_relative_to(real) else path.as_posix()


def load_baseline(path=BASELINE):
    """Counter of (repository path, rule, name) findings that predate their rule.

    Entries carry no line numbers, so edits elsewhere in a file keep them
    valid; a repeated line allows that many findings of the same name.
    """
    entries = Counter()
    for line in Path(path).read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            entries[tuple(line.split())] += 1
    return entries


def unused_findings(root, analysis):
    """{(repository path, "unused", name): [(file, line, message)]} for every unused local."""
    found = {}
    for name, (findings, _) in analysis.items():
        for line, rule, symbol, message in findings:
            if rule == "unused":
                found.setdefault((repository_path(root, name), rule, symbol), []).append((name, line, message))
    return found


def analyse(root, lua_files):
    """{file: (scope findings, file-level local names)} for each Lua file."""
    result = {}
    for name in sorted(lua_files):
        try:
            result[name] = scopes.analyse((Path(root) / name).read_text(encoding="utf-8"))
        except SyntaxError as error:  # such as LuaJIT's goto, which WoW's Lua 5.1 lacks
            raise AssertionError(f"{name}: not Lua 5.1: {error}") from None
    return result


def is_runtime(name):
    """Whether a path is addon runtime code (not a test or tool), which WoW loads."""
    parts = PurePosixPath(Path(name).as_posix()).parts
    return "tests" not in parts and "tools" not in parts


def scope_errors(root, analysis, reads, baseline):
    """Unused locals outside the baseline, and global reads that are probably missing locals."""
    errors = []
    allowed = Counter(baseline)
    for key, found in unused_findings(root, analysis).items():
        if len(found) > allowed[key]:
            # Without line numbers the new one is unknown: list them all.
            note = f" ({len(found)} found, {allowed[key]} baselined)" if allowed[key] else ""
            errors += [f"{name}:{line}: {message}{note}" for name, line, message in found]
    for name, line, symbol in reads:
        declared = analysis[name][1].get(symbol)
        # Reads on or after the declaration line belong to its own initializer,
        # such as a multi-line "local GetTime =\n  GetTime".
        if declared and line < declared:
            errors.append(f"{name}:{line}: global '{symbol}' read before the file-level local on line {declared}")
        elif symbol[:1].islower() and symbol not in LOWERCASE_GLOBALS and not (
                symbol in TOOL_GLOBALS and not is_runtime(name)):
            errors.append(f"{name}:{line}: unknown lowercase global '{symbol}' (missing local?)")
    return errors


def check_scopes(root, lua_files, baseline=None):
    """No unused locals (except baseline.txt) and no global reads of locals or unknown lowercase names."""
    files = sorted(lua_files)
    baseline = load_baseline() if baseline is None else baseline
    errors = scope_errors(root, analyse(root, files), global_reads(root, files), baseline)
    assert not errors, "Scope errors (declare or remove the local):\n  " + "\n  ".join(errors)


def check_sources(root, max_lines=MAX_LINES):
    """Text files git tracks (or would track) fit max_lines; Lua files compile.

    Links to folders (such as libs/) are skipped. Returns the number of
    Lua files compiled.
    """
    root = Path(root)
    names = subprocess.check_output(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=root
    ).decode().split("\0")
    files = sorted({root / name for name in names if name and (root / name).is_file()})
    lua_count = 0
    for path in files:
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        count = len(text.splitlines())
        # Translation catalogs are flat data, with one reviewable message per
        # line. Keep the runtime-module budget; exempt only this exact data
        # grammar, never arbitrary code placed in the locale directory.
        catalog = (path.parent.name == "locale"
                   and path.stem in {"enUS", "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW"}
                   and re.fullmatch(
                       r'local _, ns = \.\.\.\nassert\(ns\.Locale:Register\("' + path.stem
                       + r'", \{\n(?:  \["[\w.]+"\] = "(?:[^"\\\n]|\\.)*",\n)*\}\)\)\n', text))
        assert count <= max_lines or catalog, f"{path.relative_to(root)} has {count} lines (maximum {max_lines})"
        if path.suffix == ".lua":
            lua_count += 1
            subprocess.run(["luajit", "-b", str(path), "/dev/null"], check=True)
    return lua_count


def validate(root, tocs, modules=(), allowed_globals=(), allowed_prefixes=(), max_lines=MAX_LINES):
    """Runs every check; returns (runtime Lua files, Lua files compiled).

    tocs maps each TOC to the module globs it must load, or is a list of
    TOCs that share modules.
    """
    require_luajit()
    if not isinstance(tocs, dict):
        tocs = {toc: modules for toc in tocs}
    runtime_lua = set()
    for toc, globs in tocs.items():
        loaded = loaded_files(root, toc_entries(root, toc))
        check_unloaded(root, loaded, globs, toc)
        runtime_lua.update(name for name in loaded if name.endswith(".lua"))
    check_globals(root, runtime_lua, allowed_globals, allowed_prefixes)
    compiled = check_sources(root, max_lines)
    check_scopes(root, runtime_lua)
    return runtime_lua, compiled


def stale_entries(root, analysis, baseline):
    """Baseline entries whose finding no longer occurs (as often): fixed, so the entry can go."""
    current = {key: len(found) for key, found in unused_findings(root, analysis).items()}
    return [f"{BASELINE.name}: stale: {' '.join(entry)} no longer occurs; remove it"
            for entry, count in sorted(Counter(baseline).items()) if current.get(entry, 0) < count]


def warnings(root, analysis):
    """Report-only findings: shadowing, OnUpdate allocations and literal UI text."""
    found = []
    for name, (findings, _) in analysis.items():
        found += [f"{name}:{line}: {rule}: {message}" for line, rule, _, message in findings if rule != "unused"]
        for number, text in enumerate((Path(root) / name).read_text(encoding="utf-8").splitlines(), 1):
            if UI_LITERAL.search(text.split("--", 1)[0]):
                found.append(f"{name}:{number}: ui-literal: literal UI text; use ns.Locale")
    return found


def runtime_modules(root=REPOSITORY):
    """Tracked runtime Lua under addons/ and libs/, outside tests/ and locale catalogs."""
    names = subprocess.check_output(["git", "ls-files", "-z", "--", "*.lua"], cwd=root).decode().split("\0")
    return [n for n in names if n and PurePosixPath(n).parts[0] in {"addons", "libs"}
            and not {"tests", "locale"} & set(PurePosixPath(n).parts) and not (Path(root) / n).is_symlink()]


def main(argv=None):
    parser = argparse.ArgumentParser(description="Lint runtime Lua: scope errors plus report-only warnings.")
    parser.add_argument("--errors-only", action="store_true", help="skip report-only warnings")
    parser.add_argument("--strict", action="store_true",
                        help="fail on baseline entries that no longer occur (otherwise a warning)")
    parser.add_argument("--all", action="store_true", help="every runtime module (the default without paths)")
    parser.add_argument("--dead", action="store_true", help="report unused functions, locale keys, files and assets")
    parser.add_argument("--root", type=Path, default=REPOSITORY, help="tree for --dead (default: this repository)")
    parser.add_argument("paths", nargs="*", help="Lua files or folders, relative to the repository or absolute")
    args = parser.parse_args(argv)
    if args.all and args.paths:
        parser.error("--all does not accept paths")
    require_luajit()
    if args.dead:
        import dead
        found = dead.report(args.root.resolve())
        for finding in found:
            print(finding)
        totals = Counter((f.kind, f.confidence) for f in found)
        print(", ".join(f"{count} {kind} ({confidence})" for (kind, confidence), count in sorted(totals.items())))
        return 0
    files = []
    for path in args.paths:
        target = REPOSITORY / path
        if target.is_dir():
            files += sorted(p.relative_to(REPOSITORY).as_posix() if p.is_relative_to(REPOSITORY) else str(p)
                            for p in target.rglob("*.lua"))
        elif target.is_file():
            files.append(path)
        else:
            parser.error(f"no such file or folder: {path}")
    files = files or runtime_modules()
    baseline = load_baseline()
    try:
        analysis = analyse(REPOSITORY, files)
    except AssertionError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    errors = scope_errors(REPOSITORY, analysis, global_reads(REPOSITORY, files), baseline)
    # Stale entries are only known when every runtime module was linted. A
    # fix on another branch must not fail this one, so they only warn
    # unless --strict asks to clean up the baseline.
    stale = [] if args.paths else stale_entries(REPOSITORY, analysis, baseline)
    if args.strict:
        errors += stale
    found = [] if args.errors_only else warnings(REPOSITORY, analysis) + ([] if args.strict else stale)
    for line in found:
        print(f"warning: {line}")
    for line in errors:
        print(f"error: {line}", file=sys.stderr)
    print(f"{len(files)} files: {len(errors)} errors, {len(found)} warnings")
    return int(bool(errors))


if __name__ == "__main__":
    sys.exit(main())
