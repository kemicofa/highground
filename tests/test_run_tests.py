"""The parallel runner must preserve coverage, isolation and failing exit statuses."""
import contextlib
import io
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

from support import ROOT
import run_tests


class RunnerTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.addon = self.root / "addons" / "Example"
        (self.addon / "tests").mkdir(parents=True)
        self.stdout, self.stderr = io.StringIO(), io.StringIO()
        contexts = contextlib.ExitStack()
        self.addCleanup(contexts.close)
        contexts.enter_context(contextlib.redirect_stdout(self.stdout))
        contexts.enter_context(contextlib.redirect_stderr(self.stderr))

    def test_bounded_concurrency_runs_every_suite_and_reports_failures(self):
        source = '''
import json, os, pathlib, sys, time
name = sys.argv[1]
def event(kind):
    with open("events.jsonl", "a") as log:
        log.write(json.dumps([kind, name]) + "\\n")
event("start")
pathlib.Path(name + ".started").touch()
if name in ("a", "b"):
    # A rendezvous verifies real concurrency without a timing speed threshold.
    other = "b" if name == "a" else "a"
    deadline = time.monotonic() + 5
    while not pathlib.Path(other + ".started").exists():
        if time.monotonic() > deadline:
            sys.exit("workers did not overlap")
        time.sleep(0.01)
time.sleep(0.05)
print(name + " stdout")
print(name + " stderr", file=sys.stderr)
event("end")
sys.exit(7 if name == "b" else 0)
'''
        suites = [run_tests.Suite(name, self.root, (sys.executable, "-u", "-c", source, name))
                  for name in ("a", "b", "c", "d", "e")]
        self.assertEqual(run_tests.run_suites(suites, 2), 1)
        active, started, finished = set(), set(), set()
        maximum = 0
        for line in (self.root / "events.jsonl").read_text().splitlines():
            event, name = json.loads(line)
            if event == "start":
                self.assertNotIn(name, started)
                started.add(name)
                active.add(name)
                maximum = max(maximum, len(active))
            else:
                active.remove(name)
                finished.add(name)
        self.assertEqual(maximum, 2)
        self.assertEqual(started, {suite.name for suite in suites})
        self.assertEqual(finished, started)
        for name in started:
            self.assertIn(f"{name} stdout\n{name} stderr\n", self.stdout.getvalue())
        self.assertIn("4 passed, 1 failed", self.stdout.getvalue())
        self.assertIn("FAILED: b", self.stderr.getvalue())

    def test_serial_suites_succeed_in_order(self):
        suites = [run_tests.Suite(name, self.root, (sys.executable, "-c", f"print('{name}')"))
                  for name in ("first", "second")]
        self.assertEqual(run_tests.run_suites(suites, 1), 0)
        self.assertLess(self.stdout.getvalue().index("PASS first"), self.stdout.getvalue().index("PASS second"))
        self.assertIn("2 passed, 0 failed", self.stdout.getvalue())

    def test_simulation_discovery_covers_every_registered_group_once(self):
        addon = ROOT / "addons/Highground"
        groups = subprocess.check_output(["luajit", "tests/simulation_test.lua", "--list-groups"],
                                         cwd=addon, text=True).splitlines()
        scenarios = {path.stem for path in (addon / "tests/simulation/scenarios").glob("*.lua")}
        self.assertEqual(len(groups), len(set(groups)))
        self.assertEqual(set(groups), scenarios)
        suites = run_tests.lua_suites(addon, True)
        simulations = [suite for suite in suites if suite.command[1] == "tests/simulation_test.lua"]
        self.assertEqual([suite.command[2] for suite in simulations], groups)
        ordinary = {path.name for path in (addon / "tests").glob("*_test.lua")} - {"simulation_test.lua"}
        self.assertEqual({Path(suite.command[1]).name for suite in suites if len(suite.command) == 2}, ordinary)
        self.assertEqual(len(suites), len(groups) + len(ordinary))
        serial = run_tests.lua_suites(addon, False)
        self.assertEqual(len(serial), len(ordinary) + 1)
        self.assertTrue(all(len(suite.command) == 2 for suite in serial))

    def test_invalid_group_discovery_fails_instead_of_skipping_tests(self):
        for output in ("", "match\nmatch\n", "\n"):
            with self.subTest(output=output), patch.object(run_tests.subprocess, "check_output", return_value=output):
                with self.assertRaisesRegex(ValueError, "Simulation group discovery"):
                    run_tests.lua_suites(ROOT / "addons/Highground", True)

    def test_validation_failure_prevents_lua_and_repository_tests(self):
        (self.addon / "tests/validate.py").write_text("raise SystemExit(3)\n")
        with patch.object(run_tests, "run_suites") as lua, patch.object(run_tests.subprocess, "call") as repository:
            with self.assertRaises(subprocess.CalledProcessError):
                run_tests.main(["--jobs", "2"], root=self.root)
        lua.assert_not_called()
        repository.assert_not_called()

    def test_modes_run_repository_once_and_only_after_lua_success(self):
        (self.addon / "tests/example_test.lua").touch()
        cases = [([], 0, 1, 1), (["--addons-only"], 0, 1, 0), (["--repository-only"], 0, 0, 1),
                 ([], 1, 1, 0)]
        for args, lua_status, lua_calls, repository_calls in cases:
            with self.subTest(args=args, status=lua_status), \
                    patch.object(run_tests, "run_suites", return_value=lua_status) as lua, \
                    patch.object(run_tests.subprocess, "call", return_value=0) as repository:
                self.assertEqual(run_tests.main(args, root=self.root), lua_status)
                self.assertEqual(lua.call_count, lua_calls)
                self.assertEqual(repository.call_count, repository_calls)

    def test_invalid_arguments_fail_before_running_tests(self):
        cases = [["--jobs", "0"], ["--jobs", "-1"], ["--jobs", "many"],
                 ["--repository-only", "Example"], ["../outside"], ["Example", "Example"],
                 ["--repository-only", "--addons-only"]]
        for args in cases:
            with self.subTest(args=args), patch.object(run_tests, "run_suites") as lua:
                with self.assertRaises(SystemExit) as error:
                    run_tests.main(args, root=self.root)
                self.assertNotEqual(error.exception.code, 0)
                lua.assert_not_called()

    @unittest.skipUnless(os.name == "posix", "POSIX signals")
    def test_cancellation_terminates_and_reaps_the_worker(self):
        child = ("import os,pathlib,time; p=pathlib.Path('worker.tmp'); p.write_text(str(os.getpid())); "
                 "p.rename('worker.pid'); time.sleep(30)")
        driver = """
import pathlib, signal, sys
sys.path.insert(0, sys.argv[1])
import run_tests
signal.signal(signal.SIGTERM, signal.default_int_handler)
try:
    run_tests.run_suites([run_tests.Suite('waiting', pathlib.Path.cwd(), (sys.executable, '-c', sys.argv[2]))], 2)
except KeyboardInterrupt:
    sys.exit(130)
"""
        process = subprocess.Popen([sys.executable, "-c", driver, str(ROOT / "scripts"), child],
                                   cwd=self.root, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 5
            while not (self.root / "worker.pid").exists():
                if time.monotonic() > deadline or process.poll() is not None:
                    self.fail("worker did not start")
                time.sleep(0.01)
            worker = int((self.root / "worker.pid").read_text())
            process.terminate()
            _, stderr = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 130, stderr)
            with self.assertRaises(ProcessLookupError):
                os.kill(worker, 0)
        finally:
            if process.poll() is None:
                process.kill()
            process.communicate(timeout=5)


if __name__ == "__main__":
    unittest.main()
