"""Check file sizes, release manifests, XML references, globals, and Lua 5.1 compilation."""
from pathlib import Path
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent
assert shutil.which("luajit"), "Validation requires LuaJIT (Lua 5.1 semantics, matching WoW)."
runtime_dirs = ("core", "rules", "ui", "options", "commands", "map", "timers", "flags", "arena", "world",
                "bounty", "macros", "hub")

# Intentional global writes: SavedVariables, slash commands, key bindings, and
# names that XML or bindings reference. Anything else is an accidental global.
allowed_globals = {
    "WarboardDB", "WarboardCharDB",
    "BINDING_HEADER_WARBOARD",
    "Warboard_Call", "Warboard_Hub", "Warboard_BountyBoard", "WarboardPinMixin",
    "KillOrderTargetButton", "KillOrderMarkButton", "KillOrderFocusButton",
}
allowed_global_prefixes = ("SLASH_WARBOARD", "BINDING_NAME_WARBOARD_", "BINDING_NAME_CLICK Warboard")
# Explicit _G.Name = ... or _G["Name"] = ... writes (table sets, not GSET).
explicit_global = re.compile(r"""^\s*_G(?:\.(\w+)|\[["']([^"']+)["']\])\s*=(?!=)""")


def dependencies(name):
    path = root / name
    assert path.is_file(), f"Missing runtime file: {name}"
    result = {name}
    if path.suffix == ".xml":
        for node in ET.parse(path).iter():
            if node.tag.rsplit("}", 1)[-1] in {"Script", "Include"} and "file" in node.attrib:
                relative = (path.parent / node.attrib["file"]).relative_to(root).as_posix()
                result.update(dependencies(relative))
    return result


runtime_lua = set()
for toc, client in [("Warboard.toc", "retail"), ("Warboard_Cata.toc", "cata")]:
    entries = [s.strip() for s in (root / toc).read_text().splitlines() if s.strip() and not s.startswith("#")]
    assert len(entries) == len(set(entries)), f"Duplicate load entry in {toc}"
    assert f"config/{client}/Classes.lua" in entries
    other = "cata" if client == "retail" else "retail"
    assert not any(s.startswith(f"config/{other}/") for s in entries), f"Wrong client in {toc}"
    assert not any(s.startswith(f"compat/{other}/") for s in entries), f"Wrong compatibility modules in {toc}"
    assert entries.index("rules/Combat.lua") < entries.index("core/State.lua")
    assert entries.index("config/Focus.lua") < entries.index("core/State.lua") < entries.index("ui/Focus.lua")
    loaded = set()
    for entry in entries:
        loaded.update(dependencies(entry))
    runtime_lua.update(name for name in loaded if name.endswith(".lua"))
    extra = ("config/forever",) if client == "retail" else ()  # WoW Forever shares the retail manifest
    top = {p.relative_to(root).as_posix() for p in (root / "config").glob("*.lua")}
    assert top <= loaded, f"Unloaded modules in {toc}: {sorted(top - loaded)}"
    for directory in (*runtime_dirs, "config/battlegrounds", f"config/{client}", f"compat/{client}", *extra):
        actual = {p.relative_to(root).as_posix() for p in (root / directory).rglob("*.lua")}
        assert actual <= loaded, f"Unloaded modules in {toc}: {sorted(actual - loaded)}"

# One LuaJIT process lists global writes (GSET) for every runtime file.
writes = subprocess.run(
    ["luajit", "tests/support/globals.lua", *sorted(runtime_lua)],
    cwd=root, check=True, capture_output=True, text=True,
).stdout.splitlines()
for name in sorted(runtime_lua):
    for number, line in enumerate((root / name).read_text().splitlines(), 1):
        if match := explicit_global.match(line):
            writes.append(f"{name}:{number}: {match.group(1) or match.group(2)}")
accidental = [w for w in writes if not (
    (name := w.rsplit(": ", 1)[1]) in allowed_globals or name.startswith(allowed_global_prefixes))]
assert not accidental, "Accidental globals (declare them local):\n  " + "\n  ".join(accidental)

# Exclude ignored generated artifacts; new source files count toward the limit.
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
    assert count <= 400, f"{path.relative_to(root)} has {count} lines (maximum 400)"
    if path.suffix == ".lua":
        lua_count += 1
        subprocess.run(["luajit", "-b", str(path), "/dev/null"], check=True)
print(f"Manifests, XML, 400-line limit, and {lua_count} Lua files validated")
