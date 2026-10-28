"""Validate Highground Nearby with the repository's generic checks (tools/lint).

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

tocs = ["HighgroundNearby.toc", "HighgroundNearby_Cata.toc"]
saved = set().union(*(lint.saved_variables(root, toc) for toc in tocs))
_, lua_count = lint.validate(root, tocs, modules=["*.lua"], allowed_globals=saved, allowed_prefixes=("SLASH_",))
print(f"Manifests, XML, 400-line limit, and {lua_count} Lua files validated")
