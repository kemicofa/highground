"""Validate Highground Macros with the repository's generic checks (tools/lint).

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

tocs = ["HighgroundMacros.toc", "HighgroundMacros_Cata.toc"]
saved = set().union(*(lint.saved_variables(root, toc) for toc in tocs))
_, lua_count = lint.validate(root, tocs, modules=["*.lua", "src/**/*.lua"], allowed_globals=saved, allowed_prefixes=("SLASH_",))
print(f"Manifests, XML, 400-line limit, and {lua_count} Lua files validated")
