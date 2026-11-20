"""Validate Reputation's manifests, globals, Lua 5.1 syntax and module sizes."""
from pathlib import Path
import sys

root = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
sys.path.insert(0, str(root.parent.parent / "tools" / "lint"))
import lint  # noqa: E402

tocs = ["HighgroundReputation.toc", "HighgroundReputation_Cata.toc"]
saved = set().union(*(lint.saved_variables(root, toc) for toc in tocs))
_, count = lint.validate(root, tocs, modules=["*.lua", "src/**/*.lua"],
                         allowed_globals=saved | {"HighgroundReputationNetworkDB", "HighgroundWindowCoordinator"}, allowed_prefixes=("SLASH_",))
print(f"Reputation manifests, globals, 400-line limit and {count} Lua files validated")
