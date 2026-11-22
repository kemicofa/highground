"""tools/lint: scope analysis, global-read checks, the baseline and the command line."""
import collections
import contextlib
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest
import unittest.mock

from support import ROOT

sys.dont_write_bytecode = True  # no __pycache__ in tools/lint
sys.path.insert(0, str(ROOT / "tools" / "lint"))
import lint  # noqa: E402
import scopes  # noqa: E402


def findings(source, rule=None):
    return [(line, name) for line, kind, name, _ in scopes.check(textwrap.dedent(source)) if rule in (None, kind)]


class ScopeTests(unittest.TestCase):
    def test_unused_locals_and_functions(self):
        source = """
            local used, unused = 1, 2
            local assigned = used
            assigned = 3
            local _ignored, _ = 4, 5
            local function helper() return used end
            local function recursive() return recursive() end
            local t = {}
            t.field = 1
            for i, v in pairs(t) do end
            local function handler(self, event, ...) end
            return handler
        """
        self.assertEqual(findings(source, "unused"), [(2, "unused"), (3, "assigned"), (6, "helper"),
                                                      (7, "recursive")])

    def test_scoping_follows_lua_rules(self):
        source = """
            local x = 1
            local function f()
              local x = x + 1
              return x
            end
            do local y = 2; print(y) end
            repeat local done = true until done
            local g = function() return g end
            if x then local z = 1 else print(z) end
            return f, g
        """
        self.assertEqual(findings(source, "unused"), [(10, "z")])
        self.assertEqual(findings(source, "shadow"), [(4, "x")])
        checker = scopes.Checker(textwrap.dedent(source))
        checker.chunk()
        # "local g = function() ... g ... end" and the else branch read globals.
        self.assertEqual(checker.free, {"print", "g", "z"})

    def test_shadowing_reports_upvalues_locals_and_redeclarations(self):
        source = """
            local frame, size = 1, 2
            function M:method(frame)
              local size = 3
              return function() local self = 1; return self, size end
            end
            local frame = frame
            return frame
        """
        messages = [message for _, kind, _, message in scopes.check(textwrap.dedent(source)) if kind == "shadow"]
        self.assertEqual(messages, ["'frame' shadows an upvalue from line 2", "'size' shadows an upvalue from line 2",
                                    "'frame' shadows a local from line 2"])

    def test_on_update_allocations(self):
        source = """
            local function Tick(self, elapsed)
              self.text:SetText(("%.1f"):format(elapsed))
            end
            f:SetScript("OnUpdate", Tick)
            f:HookScript("OnUpdate", function(self)
              local t = { self }
              local s = "a" .. tostring(self)
              C_Timer.After(1, function() return { "later" } end)
            end)
            f:SetScript("OnShow", function() return { "fine" } end)
            local function Other() return {} end
            return Other, t, s
        """
        self.assertEqual(findings(source, "hot-alloc"), [(3, "format()"), (7, "table constructor"),
                                                         (8, "string concatenation"), (8, "tostring()"),
                                                         (9, "closure")])

    def test_tokenizer_skips_comments_and_strings(self):
        source = """
            --[==[ local commented ]] still a comment ]==]
            local text = "-- not a comment \\" local quoted"
            local long = [[
            local inside ]]
            -- local trailing
            return text, long
        """
        self.assertEqual(scopes.check(textwrap.dedent(source)), [])
        with self.assertRaises(SyntaxError):
            scopes.check("local s = [[ unfinished")

    def test_free_names_match_luajit_globals_for_every_runtime_module(self):
        files = lint.runtime_modules()
        self.assertGreater(len(files), 100)
        names = collections.defaultdict(set)
        for flag in ([], ["--reads"]):
            output = subprocess.check_output(["luajit", str(lint.GLOBALS_SCANNER), *flag, *files], cwd=ROOT, text=True)
            for row in output.splitlines():
                location, name = row.rsplit(": ", 1)
                names[location.rsplit(":", 1)[0]].add(name)
        for name in files:
            with self.subTest(file=name):
                checker = scopes.Checker((ROOT / name).read_text(encoding="utf-8"))
                checker.chunk()
                self.assertEqual(checker.free, names[name])


class GlobalReadTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)

    def errors(self, source, baseline=frozenset()):
        (self.root / "file.lua").write_text(textwrap.dedent(source))
        with self.assertRaises(AssertionError) as raised:
            lint.check_scopes(self.root, ["file.lua"], set(baseline))
        return [line.strip() for line in str(raised.exception).splitlines()[1:]]

    def test_reads_of_out_of_scope_locals_and_unknown_lowercase_names_fail(self):
        source = """
            local GetTime = GetTime
            local function first() return second() end
            local function second() return GetTime() + tinsert + wipe + strsplit end
            local value = valeu
            local function third()
              error("builtin")
            end
            local function fourth() local error = 1; return error end
            return first, second, value, third, fourth
        """
        self.assertEqual(self.errors(source), [
            "file.lua:3: global 'second' read before the file-level local on line 4",
            "file.lua:5: unknown lowercase global 'valeu' (missing local?)"])

    def test_interpreter_globals_are_allowed_only_outside_runtime_code(self):
        source = "local file = io.open(arg[1])\nreturn file\n"
        (self.root / "tests").mkdir()
        (self.root / "tests/helper.lua").write_text(source)
        lint.check_scopes(self.root, ["tests/helper.lua"], set())
        self.assertEqual(self.errors(source), ["file.lua:1: unknown lowercase global 'arg' (missing local?)",
                                               "file.lua:1: unknown lowercase global 'io' (missing local?)"])

    def test_baseline_keeps_known_unused_locals_only(self):
        source = "local known, fresh = 1, 2\nreturn 1\n"
        path = lint.repository_path(self.root, "file.lua")
        self.assertEqual(self.errors(source, {(path, "unused", "known")}), ["file.lua:1: unused local 'fresh'"])
        lint.check_scopes(self.root, ["file.lua"], {(path, "unused", "known"), (path, "unused", "fresh")})

    def test_baseline_entries_are_well_formed(self):
        # Entries fixed on other branches only warn (see --strict), so this
        # checks the format rather than that every entry still occurs.
        entries = lint.load_baseline()
        self.assertTrue(entries)
        for entry in entries:
            with self.subTest(entry=entry):
                self.assertEqual(len(entry), 3)
                self.assertEqual(entry[1], "unused")
                self.assertTrue(entry[0].endswith(".lua") and not Path(entry[0]).is_absolute())

    def test_stale_baseline_entries_warn_unless_strict(self):
        (self.root / "file.lua").write_text("return 1\n")
        path = lint.repository_path(self.root, "file.lua")
        analysis = lint.analyse(self.root, ["file.lua"])
        self.assertEqual(lint.stale_entries(self.root, analysis, {(path, "unused", "gone")}),
                         [f"baseline.txt: stale: {path} unused gone no longer occurs; remove it"])
        baseline = lint.load_baseline() | {("addons/X.lua", "unused", "y")}
        for flags, status in (([], 0), (["--strict"], 1)):
            with self.subTest(flags=flags), contextlib.redirect_stdout(io.StringIO()) as out, \
                    contextlib.redirect_stderr(io.StringIO()), \
                    unittest.mock.patch.object(lint, "load_baseline", return_value=baseline):
                self.assertEqual(lint.main(flags), status)
                self.assertEqual("stale: addons/X.lua" in out.getvalue(), not flags)

    def test_command_line_reports_warnings_and_fails_on_errors(self):
        good, bad = self.root / "good.lua", self.root / "bad.lua"
        good.write_text(textwrap.dedent("""
            local _, ns = ...
            local f = CreateFrame("Frame")
            f:SetScript("OnUpdate", function(self) self.text:SetText(("%d"):format(GetTime())) end)
            f.title:SetText("Literal title") -- f.title:SetText("commented")
            f.hint:SetText(ns.Locale:Get("hint.key"))
        """))
        bad.write_text("return misspelled\n")
        stdout, stderr = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            self.assertEqual(lint.main([str(good)]), 0)
            self.assertEqual(lint.main(["--errors-only", str(bad)]), 1)
        warnings = [line.split(": ", 1)[1] for line in stdout.getvalue().splitlines() if line.startswith("warning:")]
        self.assertEqual(warnings, [f"{good}:4: hot-alloc: format() in an OnUpdate handler allocates every frame",
                                    f"{good}:5: ui-literal: literal UI text; use ns.Locale"])
        self.assertIn("bad.lua:1: unknown lowercase global 'misspelled'", stderr.getvalue())

    def test_code_outside_lua_5_1_fails_with_its_location(self):
        (self.root / "jump.lua").write_text("for i = 1, 2 do\n  goto skip\n  ::skip::\nend\n")
        with self.assertRaisesRegex(AssertionError, "jump.lua: not Lua 5.1: line 3"):
            lint.check_scopes(self.root, ["jump.lua"], set())

    def test_command_line_accepts_folders_and_rejects_unknown_paths(self):
        (self.root / "nested").mkdir()
        (self.root / "nested/one.lua").write_text("local unused = 1\n")
        (self.root / "two.lua").write_text("return 2\n")
        stdout, stderr = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            self.assertEqual(lint.main([str(self.root)]), 1)
            for args in (["--all", str(self.root)], [str(self.root / "missing.lua")]):
                with self.subTest(args=args), self.assertRaises(SystemExit):
                    lint.main(args)
        self.assertIn("2 files: 1 errors", stdout.getvalue())
        self.assertIn("one.lua:1: unused local 'unused'", stderr.getvalue())

    def test_validator_and_default_command_line_pass_on_the_repository(self):
        result = subprocess.run([sys.executable, "tools/lint/lint.py", "--errors-only"], cwd=ROOT,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertRegex(result.stdout, r"\d{3} files: 0 errors")

if __name__ == "__main__":
    unittest.main()
