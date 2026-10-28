"""Generic checks for a WoW addon folder: TOCs, XML, loaded modules, globals, file size and Lua 5.1 compilation.

An addon's tests/validate.py imports this module and passes its own inputs:
the TOC files, the globs of runtime modules every TOC must load, and the
global names it may write. Each check raises AssertionError with the files
at fault. LuaJIT runs the compilation and global scans (Lua 5.1, like WoW).

    import lint
    runtime = lint.validate(root, ["Addon.toc"], modules=["*.lua"],
                            allowed_globals={"AddonDB"}, allowed_prefixes=("SLASH_",))
"""
from pathlib import Path
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET

GLOBALS_SCANNER = Path(__file__).resolve().with_name("globals.lua")
MAX_LINES = 400
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
        assert count <= max_lines, f"{path.relative_to(root)} has {count} lines (maximum {max_lines})"
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
    return runtime_lua, check_sources(root, max_lines)
