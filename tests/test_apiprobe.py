"""tools/apiprobe: the developer-only API probe addon and its report."""
import contextlib
import importlib.util
import io
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from support import ROOT, addons

PROBE = ROOT / "tools/apiprobe"
sys.dont_write_bytecode = True  # no __pycache__ in tools/apiprobe
spec = importlib.util.spec_from_file_location("apiprobe_report", PROBE / "report.py")
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)

SAVED = r'''
HighgroundApiProbeDB = {
	["list"] = {
		["presentCount"] = 3,
		["undocumented"] = {
			"UnitMystery", -- [1]
			"UnitFrame_Update", -- [2]
			"C_Secret.GetHealthSomehow", -- [3]
			"GetTime", -- [4]
		},
	},
	["runs"] = {
		{
			["context"] = {
				["inInstance"] = true,
				["instanceType"] = "pvp",
				["enemy"] = true,
			},
			["results"] = {
				["UnitHealth"] = {
					["ok"] = true,
					["doc"] = true,
					["r"] = {
						{
							["t"] = "number",
							["s"] = true,
						}, -- [1]
					},
				},
				["UnitClass"] = {
					["ok"] = true,
					["doc"] = true,
					["r"] = {
						{
							["t"] = "string",
							["v"] = "Mage",
						}, -- [1]
					},
				},
				["UnitMystery"] = {
					["ok"] = true,
					["r"] = {
						{
							["t"] = "table",
							["k"] = 2,
							["f"] = {
								["a"] = {
									["t"] = "number",
									["v"] = 1,
								},
								["b"] = {
									["t"] = "number",
									["s"] = true,
								},
							},
						}, -- [1]
					},
				},
				["UnitBroken"] = {
					["ok"] = false,
					["err"] = "bad unit",
				},
			},
		}, -- [1]
		{
			["context"] = {
				["inInstance"] = false,
				["instanceType"] = "none",
				["enemy"] = true,
			},
			["results"] = {
				["UnitClass"] = {
					["ok"] = true,
					["doc"] = true,
					["r"] = {
						{
							["t"] = "string",
							["v"] = "Mage",
						}, -- [1]
					},
				},
			},
		}, -- [2]
	},
}
'''


class ApiProbeTests(unittest.TestCase):
    def test_addon_passes_the_generic_checks(self):
        if not shutil.which("luajit"):
            self.skipTest("LuaJIT is required")
        sys.path.insert(0, str(ROOT / "tools/lint"))
        import lint
        root = PROBE / "HighgroundApiProbe"
        toc = "HighgroundApiProbe.toc"
        with contextlib.redirect_stdout(io.StringIO()):
            lint.validate(root, [toc], modules=["*.lua"], allowed_globals=lint.saved_variables(root, toc),
                          allowed_prefixes=("SLASH_",))

    def test_lua_behaviour(self):
        if not shutil.which("luajit"):
            self.skipTest("LuaJIT is required")
        result = subprocess.run(["luajit", "tools/apiprobe/tests/probe_test.lua"], cwd=ROOT,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_never_packaged(self):
        self.assertNotIn("HighgroundApiProbe", addons.load(include_deprecated=True))
        self.assertFalse(list((ROOT / "addons").rglob("HighgroundApiProbe*")), "the probe stays under tools/")

    def test_report_sections(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "HighgroundApiProbe.lua"
            path.write_text(SAVED, encoding="utf-8")
            text = report.report(report.load(path))
        match, outside, undocumented = text.split("\n\n")
        self.assertIn("(a) Readable for an enemy unit in a PvP instance: 2 functions from 1 run(s)", match)
        self.assertIn("UnitClass: string='Mage'", match)
        self.assertIn("UnitMystery: table[2] (1 secret fields)  [undocumented]", match)
        self.assertNotIn("UnitHealth", match, "secret-only returns are not readable")
        self.assertNotIn("UnitBroken", match)
        self.assertIn("UnitClass: string='Mage'", outside)
        self.assertIn("C_Secret.GetHealthSomehow", undocumented)
        self.assertIn("UnitMystery", undocumented)
        self.assertNotIn("UnitFrame_Update", undocumented, "FrameXML helpers are left out")
        self.assertNotIn("GetTime", undocumented)

    def test_report_command_line(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "HighgroundApiProbe.lua"
            path.write_text(SAVED, encoding="utf-8")
            result = subprocess.run([sys.executable, "-I", str(PROBE / "report.py"), str(path)],
                                    capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("(c) Undocumented functions", result.stdout)


if __name__ == "__main__":
    unittest.main()
