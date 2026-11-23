"""scripts/bg_profile.py: reading /hg bg profiler recordings from SavedVariables."""
import contextlib
import io
from pathlib import Path
import tempfile
import unittest

from support import ROOT  # noqa: F401  (puts scripts/ on the path)
import bg_profile

SAVED = r'''
HighgroundDB = {
	["other"] = {
		["quote\"d"] = "a\\b\nc\195\169",
		["big"] = 1e+20,
		["neg"] = -3,
		[7] = true,
	},
	["bgProfiles"] = {
		{
			["map"] = {
				["name"] = "Arathi Basin",
				["id"] = "arathi_basin",
				["kind"] = "nodes",
			},
			["locale"] = "deDE",
			["stop"] = "left",
			["duration"] = 95.5,
			["dropped"] = 0,
			["stages"] = {
				["timers"] = {
					["calls"] = 40,
					["ms"] = 12.5,
					["maxMS"] = 1.25,
				},
			},
			["errors"] = {
				"12.0 timers: boom", -- [1]
			},
			["rows"] = {
				"0.0 start entered map=Arathi Basin inst=529 tracked=true runtime=0", -- [1]
				"3.0 chat A Buddy hat den Stall angegriffen! => Buddy has assaulted the Stables!", -- [2]
				"4.0 chat N Die Schlacht hat begonnen!", -- [3]
				"5.0 node Stables owner=- assault=A capLeft=60.0 icon=9 gy=true", -- [4]
				"10.0 wave exact H Farm at=4.0 err=0.5 kept=true was=cap", -- [5]
				"40.0 wave exact H Farm at=3.0 err=-4.0 kept=true was=exact", -- [6]
				"41.0 obj WIN:A:1500 - 900:120.0 | CAP:A:Stables:24.0", -- [7]
				"52.0 me healer left=8.0 gyNext=9.0 gy=Farm Graveyard", -- [8]
				"60.0 me rez after=12.0 healerErr=0.2 gyErr=-1.0 gy=Farm Graveyard", -- [9]
				"65.0 node Stables owner=A assault=- capLeft=- icon=10 gy=true", -- [10]
				"90.0 match complete winner=1 mine=A duration=95 runtime=95000", -- [11]
				"95.5 end left", -- [12]
			},
		}, -- [1]
	},
}
HighgroundCharDB = nil
'''


class BgProfileTests(unittest.TestCase):
    def saved(self, text=SAVED) -> Path:
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        path = Path(temp.name) / "Highground.lua"
        path.write_text(text, encoding="utf-8")
        return path

    def test_parser_reads_wow_savedvariables(self):
        doc = bg_profile.Parser(SAVED).document()
        other = doc["HighgroundDB"]["other"]
        self.assertEqual(other['quote"d'], "a\\b\ncé")
        self.assertEqual(other["big"], 1e20)
        self.assertEqual(other["neg"], -3)
        self.assertIs(other[7], True)
        self.assertIsNone(doc["HighgroundCharDB"])
        self.assertEqual(doc["HighgroundDB"]["bgProfiles"][0]["errors"], ["12.0 timers: boom"])

    def test_report_measures_resurrection_bases_prediction_and_translation(self):
        session = bg_profile.load_sessions(self.saved())[0]
        text = bg_profile.report(session)
        self.assertIn("your rez 1:00: dead 12.0s at Farm Graveyard; vs game countdown 0.2s, vs Highground's clock -1.0s", text)
        self.assertIn("waves exact: 2 seen; prediction before them: n=2 mean|err|=2.2s max|err|=4.0s within 1.5s=1/2", text)
        self.assertIn("0:40 exact H Farm at=3.0 err=-4.0", text)
        self.assertIn("Stables: assault at 0:05 ended after 60s (timer said 60.0s), owner A", text)
        self.assertIn("0:41 predicts A: 1500 - 900", text)
        self.assertIn("no English form", text)
        self.assertIn("1x N Die Schlacht hat begonnen!", text.split("no English form")[1])
        self.assertIn("timers", text)
        self.assertIn("12.0 timers: boom", text)

    def test_cli_timeline_json_and_missing_data(self):
        path = self.saved()
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(bg_profile.main([str(path), "--timeline", "--kinds", "me"]), 0)
        self.assertEqual([line.split()[1] for line in out.getvalue().splitlines() if line], ["me", "me"])
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(bg_profile.main([str(path), "--json"]), 0)
        self.assertIn('"Arathi Basin"', out.getvalue())
        empty = self.saved("HighgroundDB = {\n}\n")
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(bg_profile.main([str(empty)]), 1)

    def test_damaged_rows_are_skipped(self):
        session = {"rows": ["oops", 5, "1.0 chat N ok"], "stages": {"x": "bad"}}
        self.assertEqual(list(bg_profile.rows(session)), [(1.0, "chat", "N ok")])
        self.assertIn("Session 1", bg_profile.report(session))


if __name__ == "__main__":
    unittest.main()
