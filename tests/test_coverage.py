"""Lua coverage: hook recording, executable lines, merged reports and the runner's --coverage mode."""
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from support import ROOT
import lua_coverage as coverage
import run_tests

MODULE = """local M = {}

-- a comment
function M.used(x)
  if x then
    return 1
  end
  return 2
end

function M.unused()
  local inner = function()
    return 3
  end
  return inner()
end

local function early(x)
  if x then return "a" end
  local y = x
  return y
end

M.early = early
return M
"""

SCRIPT = """local M = dofile("{module}")
assert(M.used(true) == 1 and M.early(true) == "a")
io.write(table.concat({{...}}, ","))
collectgarbage("collect"); collectgarbage("stop")
local before = collectgarbage("count")
local t = {{}}
for i = 1, 100 do t[i] = i end
io.stderr:write("allocated ", collectgarbage("count") - before, "\\n")
collectgarbage("restart")
{ending}
"""


def rows(path):
    return {tuple(row.split("\t")[:3]) for row in Path(path).read_text().splitlines()}


class CoverageToolTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        (self.root / "mod.lua").write_text(MODULE)

    def run_script(self, ending, *args):
        (self.root / "script.lua").write_text(SCRIPT.format(module="mod.lua", ending=ending))
        return subprocess.run(["luajit", str(coverage.TOOL), "run", "hits.tsv", "script.lua", *args],
                              cwd=self.root, capture_output=True, text=True)

    def test_lines_lists_code_lines_and_functions_from_bytecode(self):
        output = subprocess.check_output(["luajit", str(coverage.TOOL), "lines", "mod.lua"],
                                         cwd=self.root, text=True)
        lines = {int(r.split("\t")[2]) for r in output.splitlines() if r.startswith("L\t")}
        functions = {tuple(map(int, r.split("\t")[2:])) for r in output.splitlines() if r.startswith("F\t")}
        # Blank lines, the comment and closing ends after a return are not code.
        # A local function's closure is created on its closing line.
        self.assertEqual(lines, {1, 4, 5, 6, 8, 9, 11, 13, 14, 15, 16, 19, 20, 21, 22, 24, 25})
        self.assertEqual(functions, {(4, 9), (11, 16), (12, 14), (18, 22)})

    def test_run_records_hits_forwards_arguments_and_preserves_exit_status(self):
        for ending, status in (("", 0), ("os.exit(3)", 3), ("error('boom')", 1)):
            with self.subTest(ending=ending):
                result = self.run_script(ending, "a", "b c")
                self.assertEqual(result.returncode, status, result.stderr)
                self.assertEqual(result.stdout, "a,b c")
                hits = rows(self.root / "hits.tsv")
                self.assertIn(("L", "mod.lua", "6"), hits)
                self.assertIn(("F", "mod.lua", "4"), hits)
                self.assertIn(("F", "mod.lua", "18"), hits)
                for missing in (("L", "mod.lua", "8"), ("L", "mod.lua", "15"), ("F", "mod.lua", "11")):
                    self.assertNotIn(missing, hits)
                if status == 1:
                    self.assertIn("boom", result.stderr)

    def test_hook_pauses_while_the_collector_is_stopped(self):
        result = self.run_script("")
        self.assertEqual(result.returncode, 0, result.stderr)
        measured = float(result.stderr.split("allocated ")[1].split()[0])
        # The loop's 100-slot table needs about 1 KiB; recording its 300 line
        # events would allocate tens of KiB.
        self.assertLess(measured, 4)
        self.assertNotIn(("L", "script.lua", "7"), rows(self.root / "hits.tsv"))


class ReportTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        files = {"libs/Kit/mod.lua": MODULE, "libs/Kit/never.lua": "local function f()\n  return 1\nend\nreturn f\n",
                 "addons/Example/tests/helper.lua": "return 1\n", "addons/Example/Main.lua": "return 1\n"}
        for name, text in files.items():
            (self.root / name).parent.mkdir(parents=True, exist_ok=True)
            (self.root / name).write_text(text)
        os.symlink("../../libs/Kit", self.root / "addons/Example/libs")
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)
        subprocess.run(["git", "add", "-A"], cwd=self.root, check=True)

    def test_report_merges_suites_through_links_and_counts_unloaded_files(self):
        addon, library = self.root / "addons/Example", self.root / "libs/Kit"
        first, second = self.root / "first.tsv", self.root / "second.tsv"
        # The same file reached through the addon's libs link and directly.
        first.write_text("L\tlibs/mod.lua\t1\t1\nL\tlibs/mod.lua\t4\t2\nF\tlibs/mod.lua\t4\t1\n"
                         "L\ttests/helper.lua\t1\t1\nL\t/outside/file.lua\t1\t1\n")
        second.write_text("L\tmod.lua\t5\t1\nL\tmod.lua\t6\t1\n")
        summary = coverage.report(self.root / "out", [(first, addon), (second, library),
                                                      (self.root / "crashed.tsv", addon)], self.root)
        self.assertIn("4/21 lines", summary)
        data = {entry["path"]: entry for entry in json.loads((self.root / "out/coverage.json").read_text())}
        self.assertEqual(set(data), {"addons/Example/Main.lua", "libs/Kit/mod.lua", "libs/Kit/never.lua"})
        self.assertEqual(data["libs/Kit/mod.lua"]["hit"], 4)
        self.assertEqual(data["libs/Kit/never.lua"]["percent"], 0.0)
        functions = {f["name"]: f["calls"] for f in data["libs/Kit/mod.lua"]["functions"]}
        self.assertEqual(functions, {"M.used": 1, "M.unused": 0, "inner": 0, "early": 0})
        text = (self.root / "out/coverage.txt").read_text()
        self.assertIn("    16  20.0% libs/Kit/", text)
        self.assertIn("     1   0.0% addons/Example/", text)
        # Uncalled nested functions are reported once, inside their uncalled parent.
        self.assertIn("libs/Kit/mod.lua:11 M.unused", text)
        self.assertNotIn("libs/Kit/mod.lua:12 inner", text)
        self.assertIn("libs/Kit/mod.lua:18 early", text)

    def test_function_names(self):
        cases = {"function A.b:c(x)": "A.b:c", "local function go()": "go", "  T.key = function(self)": "T.key",
                 '  frame:SetScript("OnUpdate", function(self, elapsed)': "OnUpdate",
                 "  return function()": "<anonymous:7>"}
        for text, name in cases.items():
            with self.subTest(text=text):
                self.assertEqual(coverage.function_name(text, 7), name)


class RunnerCoverageTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        (self.root / "addons/Example/tests").mkdir(parents=True)
        (self.root / "addons/Example/tests/example_test.lua").touch()
        contexts = contextlib.ExitStack()
        self.addCleanup(contexts.close)
        contexts.enter_context(contextlib.redirect_stdout(io.StringIO()))

    def test_coverage_wraps_each_suite_and_reports_after_failures(self):
        with patch.object(run_tests, "run_suites", return_value=1) as lua, \
                patch.object(coverage, "report", return_value="summary") as report, \
                patch.object(run_tests.subprocess, "call") as repository:
            status = run_tests.main(["--coverage", "--coverage-dir", str(self.root / "cov")], root=self.root)
        self.assertEqual(status, 1)
        repository.assert_not_called()
        (suite,), jobs, timeout, _ = lua.call_args.args
        self.assertEqual((jobs, timeout), (1, 0), "coverage runs without the default timeout")
        self.assertEqual(suite.command[:3], ("luajit", str(coverage.TOOL), "run"))
        self.assertEqual(suite.command[4:], ("tests/example_test.lua",))
        (results,) = [call.args[1] for call in report.call_args_list]
        self.assertEqual(results, [(Path(suite.command[3]), self.root / "addons/Example")])

    def test_coverage_starts_the_slowest_suites_first_and_records_timings(self):
        tests = self.root / "addons/Example/tests"
        for name in ("fast", "slow", "new"):
            (tests / f"{name}_test.lua").touch()
        (self.root / "cov").mkdir()
        (self.root / "cov/timings.json").write_text(json.dumps({
            "Example/tests/fast_test.lua": 1, "Example/tests/slow_test.lua": 90, "Example/tests/example_test.lua": 5}))
        def run(suites, jobs, timeout, timings):
            for suite in suites:
                timings[suite.name] = 2.0
            return 0
        with patch.object(run_tests, "run_suites", side_effect=run) as lua, \
                patch.object(coverage, "report", return_value="summary"):
            run_tests.main(["--addons-only", "--coverage", "--coverage-dir", str(self.root / "cov")], root=self.root)
        order = [suite.name.rsplit("/", 1)[1] for suite in lua.call_args.args[0]]
        self.assertEqual(order, ["new_test.lua", "slow_test.lua", "example_test.lua", "fast_test.lua"])
        recorded = json.loads((self.root / "cov/timings.json").read_text())
        self.assertEqual(set(recorded.values()), {2.0})

    def test_coverage_requires_lua_suites(self):
        with patch.object(sys, "stderr", io.StringIO()), self.assertRaises(SystemExit):
            run_tests.main(["--repository-only", "--coverage"], root=self.root)


if __name__ == "__main__":
    unittest.main()
