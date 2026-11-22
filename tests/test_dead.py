"""tools/lint/dead.py: report-only unused functions, locals, locale keys, files and assets."""
import contextlib
import io
import os
from pathlib import Path
import sys
import tempfile
import textwrap
import unittest

from support import ROOT

sys.dont_write_bytecode = True  # no __pycache__ in tools/lint
sys.path.insert(0, str(ROOT / "tools" / "lint"))
import dead  # noqa: E402
import lint  # noqa: E402
import references  # noqa: E402
import scopes  # noqa: E402

FILES = {
    "addons/Example/Example.toc": "## Title: Example\n## IconTexture: Interface\\AddOns\\Example\\Icon\nMain.lua\nOther.lua\n",
    "addons/Example/Main.lua": """
        local _, ns = ...
        local M = {}
        ns.Mod = M
        function M.Used() end
        function M.Dead()
          return 1
        end
        function M.Tested() end
        function M:OnShow() end
        function M.Dispatch() end
        local handlers = {}
        function handlers.PLAYER_LOGIN() end
        local Built = {}
        function Built.ShowPanel() end
        ns.Mod.Used()
        local key = ns.Mod["Dispatch"]
        local L = ns.Locale
        L:Get("used.key"); L:Get("family." .. key); L:Get(("format.%s.x"):format(key)); L:Get("plural.count")
        local fn = Built["Show" .. key]
        local unused = 1
        return handlers, fn
    """,
    "addons/Example/Other.lua": """
        local _, ns = ...
        local P = ns.Mod
        function P.Dead2() end
        function ns.Mod.Used() end
        P.Used()
    """,
    "addons/Example/Unlisted.lua": "return 1\n",
    "addons/Example/Bindings.xml": "<Bindings/>\n",
    "addons/Example/Icon.tga": "",
    "addons/Example/Orphan.tga": "",
    "addons/Example/tests/use_test.lua": "return ns.Mod.Tested, L:Get('test.key')\n",
    "libs/Kit/locale/enUS.lua": """
        local _, ns = ...
        ns.Locale:Register("enUS", {
          ["used.key"] = "Used",
          ["family.anything"] = "Built",
          ["format.one.x"] = "Formatted",
          ["plural.count.one"] = "One",
          ["test.key"] = "Tests",
          ["dead.key"] = "Dead",
        })
    """,
}


class DeadCodeTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        for name, text in FILES.items():
            (self.root / name).parent.mkdir(parents=True, exist_ok=True)
            (self.root / name).write_text(textwrap.dedent(text).lstrip("\n"))

    def findings(self):
        return {(f.kind, f.name): f for f in dead.report(self.root)}

    def test_report_ranks_unused_code_by_confidence(self):
        found = self.findings()
        expected = {
            ("function", "M.Dead"): "high", ("function", "P.Dead2"): "high",
            ("function", "M.Tested"): "medium", ("function", "Built.ShowPanel"): "medium",
            ("function", "M.OnShow"): "low", ("redefined", "ns.Mod.Used"): "medium",
            ("local", "unused"): "high",
            ("locale", "dead.key"): "high", ("locale", "test.key"): "medium",
            ("locale", "family.anything"): "low", ("locale", "format.one.x"): "low",
            ("file", "Unlisted.lua"): "high", ("file", "enUS.lua"): "high", ("asset", "Orphan.tga"): "medium",
        }
        self.assertEqual({key: f.confidence for key, f in found.items()}, expected)
        self.assertEqual(found[("function", "M.Dead")].size, 3)
        self.assertEqual(found[("function", "M.Dead")].line, 5)
        self.assertIn("addons/Example/Other.lua:4", found[("redefined", "ns.Mod.Used")].reason)
        ranks = [dead.RANK[f.confidence] for f in dead.report(self.root)]
        self.assertEqual(ranks, sorted(ranks))

    def test_command_line_prints_the_report_without_failing(self):
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            self.assertEqual(lint.main(["--dead", "--root", str(self.root)]), 0)
        lines = stdout.getvalue().splitlines()
        self.assertTrue(lines[0].startswith("high"))
        self.assertIn("2 function (high)", lines[-1])

    def test_aliases_follow_shared_tables(self):
        source = textwrap.dedent("""
            local _, ns = ...
            local A, B = ns.Core, ns.Util.Text
            local C, D = {}, setmetatable({}, {})
            ns.Published = C
            local function f(self) return self:Run(), A.Go(), B.Trim(), C.Make(), D.Hidden(), Get().Value end
        """)
        checker = scopes.Checker(source)
        checker.chunk()
        resolver = references.Resolver("f.lua", scopes.tokenize(source), checker.free)
        self.assertEqual(resolver.aliases["A"], "ns.Core")
        self.assertEqual(resolver.aliases["B"], "ns.Util.Text")
        self.assertEqual(resolver.aliases["C"], "ns.Published")
        self.assertEqual(resolver.aliases["D"], "f.lua#D")
        accesses = resolver.accesses()
        for key in ((None, "Run"), ("ns.Core", "Go"), ("ns.Util.Text", "Trim"), ("ns.Published", "Make"),
                    ("f.lua#D", "Hidden"), (None, "Value")):
            self.assertIn(key, accesses)

    @unittest.skipUnless(os.name == "posix", "symbolic links")
    def test_files_loaded_through_links_count_as_loaded(self):
        (self.root / "addons/Example/Example.toc").write_text("Main.lua\nOther.lua\nlibs/Shared.lua\nlibs/locale/enUS.lua\n")
        (self.root / "libs/Kit/Shared.lua").write_text("return 1\n")
        os.symlink("../../libs/Kit", self.root / "addons/Example/libs")
        names = {f.name for f in dead.report(self.root) if f.kind == "file"}
        self.assertEqual(names, {"Unlisted.lua"})


if __name__ == "__main__":
    unittest.main()
