"""Validate Highground Battlegrounds with the repository's generic checks (tools/lint).

Both TOCs load every file of this folder; the shared/ files they load must
write no globals but the TOCs' saved variables and slash commands. The
size and compile checks cover this folder's own files (shared/ is
Highground's, checked there).
"""
from pathlib import Path
import sys

root = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True  # no __pycache__ in tools/lint
sys.path.insert(0, str(root.parent.parent / "tools" / "lint"))
import lint  # noqa: E402

tocs = ["HighgroundBattlegrounds.toc", "HighgroundBattlegrounds_Cata.toc"]
saved = set().union(*(lint.saved_variables(root, toc) for toc in tocs))
_, lua_count = lint.validate(root, tocs, modules=["*.lua", "*.xml"], allowed_globals=saved,
                             allowed_prefixes=("SLASH_",))

# No kill order: none of its files, nor Highground's settings, hub or other
# features, in either TOC.
omitted = ("shared/core/Scoring.lua", "shared/core/Targeting.lua", "shared/core/Calling.lua", "shared/core/Bursts.lua",
           "shared/core/Preview.lua", "shared/ui/Panel.lua", "shared/ui/Rows.lua", "shared/ui/Render.lua",
           "shared/ui/Actions.lua", "shared/ui/Sniper.lua", "shared/ui/Hero.lua", "shared/ui/Focus.lua",
           "shared/options/", "shared/commands/", "shared/hub/", "shared/macros/", "shared/bounty/", "shared/arena/",
           "shared/world/", "shared/map/Pins.xml", "shared/standalone/Core.lua")
for toc in tocs:
    entries = lint.toc_entries(root, toc)
    assert entries[0] == "shared/standalone/Bootstrap.lua", f"{toc}: Bootstrap.lua loads first"
    loaded = [e for e in entries if e.startswith(omitted)]
    assert not loaded, f"{toc} loads kill-order or Highground-only files: {loaded}"
# Pins.xml is Highground's map pin template under this addon's names (XML
# templates are global): the same template otherwise.
ours = (root / "Pins.xml").read_text()
theirs = (root / "shared/map/Pins.xml").read_text()
body = lambda xml: xml[xml.index("<Frame "):]
assert body(ours).replace("HighgroundBattlegrounds", "Highground") == body(theirs), \
    "Pins.xml differs from shared/map/Pins.xml beyond its names: copy the change"
assert '<Script file="shared/map/Pins.lua"/>' in ours

print(f"Manifests, XML, 400-line limit, and {lua_count} Lua files validated")
