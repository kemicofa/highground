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

# Two /hgprobe world snapshots (out of and in combat) and the kill listener.
WORLD = r'''
HighgroundApiProbeDB = {
	["runs"] = {
	},
	["world"] = {
		{
			["context"] = {
				["date"] = "2026-11-24 12:00:00",
				["inInstance"] = false,
				["instanceType"] = "none",
				["combat"] = false,
				["exists"] = true,
				["enemy"] = true,
				["player"] = true,
				["zone"] = "Ashenvale",
				["nameplates"] = {
					"nameplate4", -- [1]
				},
				["events"] = {
					["PARTY_KILL"] = true,
					["UNIT_DEATH"] = false,
				},
			},
			["reads"] = {
				{
					["call"] = "C_RestrictedActions.IsAddOnRestrictionActive(Combat)",
					["ok"] = true,
					["r"] = {
						{
							["t"] = "boolean",
							["v"] = false,
						}, -- [1]
					},
				}, -- [1]
				{
					["call"] = "UnitGUID(target)",
					["ok"] = true,
					["r"] = {
						{
							["t"] = "string",
							["v"] = "Player-1-0A",
						}, -- [1]
					},
				}, -- [2]
				{
					["call"] = "C_ChatInfo.AreOutgoingAddonChatMessagesRestricted()",
					["missing"] = true,
				}, -- [3]
				{
					["call"] = "C_Map.GetPlayerMapPosition(map, party1)",
					["ok"] = true,
					["r"] = {
						{
							["t"] = "table",
							["k"] = 22,
							["f"] = {
								["x"] = {
									["t"] = "number",
									["v"] = 0.41,
								},
								["y"] = {
									["t"] = "number",
									["v"] = 0.52,
								},
								["GetXY"] = {
									["t"] = "function",
								},
							},
						}, -- [1]
					},
				}, -- [4]
			},
		}, -- [1]
		{
			["context"] = {
				["date"] = "2026-11-24 12:01:00",
				["inInstance"] = false,
				["instanceType"] = "none",
				["combat"] = true,
				["exists"] = true,
				["enemy"] = true,
				["player"] = true,
				["zone"] = "Ashenvale",
				["nameplates"] = {
				},
			},
			["reads"] = {
				{
					["call"] = "C_RestrictedActions.IsAddOnRestrictionActive(Combat)",
					["ok"] = true,
					["r"] = {
						{
							["t"] = "boolean",
							["v"] = true,
						}, -- [1]
					},
				}, -- [1]
				{
					["call"] = "UnitGUID(target)",
					["ok"] = true,
					["r"] = {
						{
							["t"] = "string",
							["s"] = true,
						}, -- [1]
					},
				}, -- [2]
				{
					["call"] = "C_UnitAuras.GetAuraDataByIndex(target, 1, HELPFUL)",
					["ok"] = false,
					["err"] = "Auras cannot be accessed when secret while tainted",
				}, -- [3]
			},
		}, -- [2]
	},
	["kills"] = {
		["PARTY_KILL"] = {
			["world"] = {
				["n"] = 2,
				["plain"] = 1,
				["secret"] = 1,
				["combat"] = 2,
				["last"] = {
					{
						["t"] = "string",
						["v"] = "Player-1-0A",
					}, -- [1]
					{
						["t"] = "string",
						["s"] = true,
					}, -- [2]
				},
			},
		},
	},
}
'''


def run_report(text: str) -> str:
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "HighgroundApiProbe.lua"
        path.write_text(text, encoding="utf-8")
        return report.report(report.load(path))


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
        match, outside, undocumented, world, kills = run_report(SAVED).split("\n\n")
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
        self.assertEqual(world, "(d) Open-world snapshots (/hgprobe world): 0")
        self.assertIn("none recorded", kills)

    def test_report_world_snapshots_side_by_side(self):
        world, kills = run_report(WORLD).split("\n\n")[3:]
        lines = world.splitlines()
        self.assertEqual(lines[0], "(d) Open-world snapshots (/hgprobe world): 2")
        self.assertIn("[1] 2026-11-24 12:00:00 world, out of combat; target: enemy player; zone: Ashenvale; "
                      "enemy nameplates: nameplate4", lines[1])
        self.assertIn("[2] 2026-11-24 12:01:00 world, in combat; target: enemy player", lines[2])
        self.assertIn("enemy nameplates: none", lines[2])
        self.assertIn("C_RestrictedActions.IsAddOnRestrictionActive(Combat): [1] boolean=False  [2] boolean=True",
                      world)
        self.assertIn("UnitGUID(target): [1] string='Player-1-0A'  [2] string=SECRET", world)
        self.assertIn("C_ChatInfo.AreOutgoingAddonChatMessagesRestricted(): [1] missing  [2] -", world)
        self.assertIn("C_Map.GetPlayerMapPosition(map, party1): [1] table[22] {x=0.41, y=0.52}  [2] -", world)
        self.assertIn("C_UnitAuras.GetAuraDataByIndex(target, 1, HELPFUL): [1] -  [2] error: Auras cannot", world)
        self.assertLess(world.index("IsAddOnRestrictionActive"), world.index("UnitGUID"), "reads in the order taken")
        self.assertIn("registered: PARTY_KILL yes, UNIT_DEATH no", kills)
        self.assertIn("PARTY_KILL world: 2 (1 readable, 1 with secret arguments, 2 in combat); "
                      "last: string='Player-1-0A', string=SECRET", kills)

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
