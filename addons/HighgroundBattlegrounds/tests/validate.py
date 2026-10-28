"""Validate Highground Battlegrounds with the repository's generic checks (tools/lint).

Both TOCs load every file of this folder and its src/; the library files
they load (libs/, HighgroundKit) must write no globals but the TOCs' saved
variables, slash commands and bindings. The size and compile checks cover
this folder (libs/ is checked once, by Highground's validator).
"""
from pathlib import Path
import sys

root = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True  # no __pycache__ in tools/lint
sys.path.insert(0, str(root.parent.parent / "tools" / "lint"))
import lint  # noqa: E402

tocs = ["HighgroundBattlegrounds.toc", "HighgroundBattlegrounds_Cata.toc"]
saved = set().union(*(lint.saved_variables(root, toc) for toc in tocs))
# Each TOC loads every own file but the other client's class configuration.
common = ["*.lua", "*.xml", "src/config/*.lua", "src/config/battlegrounds/*.lua",
          *(f"src/{d}/**/*.lua" for d in ("core", "rules", "timers", "flags", "map", "ui"))]
modules = {tocs[0]: [*common, "src/config/retail/*.lua", "src/config/forever/*.lua"],
           tocs[1]: [*common, "src/config/cata/*.lua"]}
_, lua_count = lint.validate(root, modules, allowed_globals=saved, allowed_prefixes=("SLASH_",))

for toc in tocs:
    assert lint.toc_entries(root, toc)[0] == "libs/standalone/Bootstrap.lua", f"{toc}: Bootstrap.lua loads first"
# Pins.xml is the map pin template (src/map/Pins.xml, Highground's names)
# under this addon's names (XML templates are global): the same template otherwise.
ours = (root / "Pins.xml").read_text()
theirs = (root / "src/map/Pins.xml").read_text()
body = lambda xml: xml[xml.index("<Frame "):]
assert body(ours).replace("HighgroundBattlegrounds", "Highground") == body(theirs), \
    "Pins.xml differs from src/map/Pins.xml beyond its names: copy the change"
assert '<Script file="src/map/Pins.lua"/>' in ours

print(f"Manifests, XML, 400-line limit, and {lua_count} Lua files validated")
