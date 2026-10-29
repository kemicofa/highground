"""Validate Highground: the repository's generic checks (tools/lint) plus manifest order and theme colours.

The generic checks cover duplicate TOC entries, XML references, unloaded
modules, accidental globals, the 400-line limit and Lua 5.1 compilation.
"""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True  # no __pycache__ in tools/lint
sys.path.insert(0, str(root.parent.parent / "tools" / "lint"))
import lint  # noqa: E402

# Highground's own folders, then what it loads from the library (libs/) and
# from each standalone addon's src/ (features/<name>/).
BG = "features/battlegrounds"
runtime_dirs = ("core", "ui", "options", "commands", "macros", "hub",
                "libs/config/themes", "libs/core", "libs/ui", "libs/world", "libs/pvp",
                "features/macros/macros", "features/arena", "features/bounties",
                *(f"{BG}/{d}" for d in ("core", "rules", "ui", "timers", "flags", "map", "config/battlegrounds")))

# Intentional global writes: SavedVariables, slash commands, key bindings, and
# names that XML or bindings reference. Anything else is an accidental global.
allowed_globals = {
    "HighgroundDB", "HighgroundCharDB",
    "BINDING_HEADER_HIGHGROUND",
    "Highground_Call", "Highground_Hub", "Highground_BountyBoard", "HighgroundPinMixin",
    "KillOrderTargetButton", "KillOrderMarkButton", "KillOrderFocusButton",
}
allowed_global_prefixes = ("SLASH_HIGHGROUND", "BINDING_NAME_HIGHGROUND_", "BINDING_NAME_CLICK Highground")

# Each TOC loads its own client's configuration and compatibility modules.
tocs = {}
for toc, client in [("Highground.toc", "retail"), ("Highground_Cata.toc", "cata")]:
    entries = lint.toc_entries(root, toc)
    assert f"{BG}/config/{client}/Classes.lua" in entries
    other = "cata" if client == "retail" else "retail"
    assert not any(s.startswith(f"{BG}/config/{other}/") for s in entries), f"Wrong client in {toc}"
    assert not any(s.startswith(f"compat/{other}/") for s in entries), f"Wrong compatibility modules in {toc}"
    assert entries.index(f"{BG}/rules/Combat.lua") < entries.index(f"{BG}/core/State.lua")
    assert entries.index("config/Focus.lua") < entries.index(f"{BG}/core/State.lua") < entries.index("ui/Focus.lua")
    assert not any(s.startswith("libs/standalone/") for s in entries), "Highground is not a standalone addon"
    extra = (f"{BG}/config/forever",) if client == "retail" else ()  # WoW Forever shares the retail manifest
    directories = (*runtime_dirs, f"{BG}/config/{client}", f"compat/{client}", *extra)
    tocs[toc] = ["config/*.lua", "libs/config/*.lua", f"{BG}/config/*.lua", "features/macros/config/*.lua",
                 *(f"{d}/**/*.lua" for d in directories)]

runtime_lua, lua_count = lint.validate(root, tocs, allowed_globals=allowed_globals,
                                       allowed_prefixes=allowed_global_prefixes)

# Colours are theme tokens (config/Theme.lua, config/themes/): no numeric
# colours or |cff codes elsewhere. Class colours come from the game at
# runtime, so they never appear as literals.
num = r"-?(?:\d+\.?\d*|\.\d+)"
three = rf"{num}\s*,\s*{num}\s*,\s*{num}"
colour_literals = [
    re.compile(rf"(?:Set(?:Text|Vertex|StatusBar|Backdrop|BackdropBorder|Shadow)Color|SetColorTexture|SetGradient"
               rf"|AddLine|AddDoubleLine|Core\.Fill|Core\.Border)\s*\([^)]*?\b{three}"),
    re.compile(rf"\{{\s*{three}\s*(?:,\s*{num}\s*)?\}}"),
    re.compile(rf"\b[rgb]\s*=\s*{num}\s*,\s*[rgb]\s*=\s*{num}"),
    re.compile(r"\|c[fF]{2}[0-9a-fA-F]{6}"),
]
# Number lists that are not colours: (file, text on the line).
colour_allowed = {("features/bounties/bounty/Alerts.lua", "ICON_CROP")}
theme_files = {"libs/config/Theme.lua"} | {p.relative_to(root).as_posix() for p in (root / "libs/config/themes").glob("*.lua")}
literals = []
for name in sorted(runtime_lua - theme_files):
    if name.startswith(tuple(f"{BG}/config/{d}/" for d in ("battlegrounds", "cata", "retail", "forever"))):
        continue  # map coordinates and spell lists
    for number, line in enumerate((root / name).read_text().splitlines(), 1):
        code = line.split("--", 1)[0]
        if any(p.search(code) for p in colour_literals) and not any(
                f == name and text in line for f, text in colour_allowed):
            literals.append(f"{name}:{number}: {line.strip()}")
assert not literals, "Colour literals outside the theme files (use a theme token):\n  " + "\n  ".join(literals)

# The repository's test tooling (tools/) that these tests run on, and the
# HighgroundKit library every addon embeds (checked here once).
lua_count += lint.check_sources(root.parent.parent / "tools")
lua_count += lint.check_sources(root.parent.parent / "libs" / "HighgroundKit")
print(f"Manifests, XML, 400-line limit, and {lua_count} Lua files validated")
