"""Exercise the hook's staged/unstaged boundary in real temporary Git indexes."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class PerformanceCheckTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="highground-hook-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.git("init", "--quiet")
        for name in ("scripts/check_performance.py", ".githooks/pre-commit"):
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, target)
        for addon in ("Highground", "HighgroundReputation"):
            suite = self.root / "addons" / addon / "tests/performance_test.lua"
            suite.parent.mkdir(parents=True)
            suite.write_text('dofile("runtime.lua")\n')
            (suite.parent.parent / "runtime.lua").write_text("return true\n")
        self.git("add", ".")
        self.runtime = self.root / "addons/Highground/runtime.lua"

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.root), *args], check=True, capture_output=True)

    def check(self, *args):
        return subprocess.run([sys.executable, "scripts/check_performance.py", *args],
                              cwd=self.root, capture_output=True, text=True)

    def test_unstaged_fix_does_not_hide_staged_regression(self):
        self.runtime.write_text('error("staged regression")\n')
        self.git("add", "addons/Highground/runtime.lua")
        self.runtime.write_text("return true\n")
        result = self.check("--staged")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("staged regression", result.stderr)
        self.assertEqual(self.runtime.read_text(), "return true\n")

    def test_unstaged_failure_does_not_contaminate_passing_index(self):
        self.runtime.write_text('error("unrelated unfinished work")\n')
        before = self.git("diff", "--cached").stdout
        result = self.check("--staged")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(before, self.git("diff", "--cached").stdout)
        self.assertIn("unrelated unfinished work", self.runtime.read_text())

    def test_documentation_only_change_skips_runtime_suites(self):
        # Populate HEAD without running hooks, then stage only a document.
        self.git("-c", "user.name=Hook Test", "-c", "user.email=hook@example.invalid", "commit", "-qm", "fixture")
        self.runtime.write_text('error("must not execute")\n')
        (self.root / "README.md").write_text("Documentation only\n")
        self.git("add", "README.md")
        result = self.check("--staged")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("no staged runtime", result.stdout)

    def test_installed_hook_blocks_commit_and_preserves_other_hooks(self):
        self.git("config", "core.hooksPath", ".local-hooks")
        hooks = self.root / ".local-hooks"
        hooks.mkdir()
        (hooks / "pre-push").write_text("existing hook\n")
        installed = self.check("--install-hook")
        self.assertEqual(installed.returncode, 0, installed.stderr)
        self.assertEqual(self.check("--install-hook").returncode, 0, "installation is idempotent")
        self.assertEqual((hooks / "pre-push").read_text(), "existing hook\n")
        self.runtime.write_text('error("commit must fail")\n')
        self.git("add", "addons/Highground/runtime.lua")
        result = subprocess.run(["git", "-c", "user.name=Hook Test", "-c", "user.email=hook@example.invalid",
                                 "commit", "-qm", "blocked"], cwd=self.root, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("commit must fail", result.stderr)
        (hooks / "pre-commit").write_text("custom hook\n")
        self.assertNotEqual(self.check("--install-hook").returncode, 0)
        self.assertEqual((hooks / "pre-commit").read_text(), "custom hook\n")


if __name__ == "__main__":
    unittest.main()
