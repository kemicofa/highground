"""Verify staged isolation and hook installation using disposable Git repositories."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class CommandCheckTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="highground-command-hook-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.git("init", "--quiet")
        for name in ("scripts/check_commands.py", "scripts/check_performance.py", ".githooks/pre-commit"):
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, target)
        for addon in ("Highground", "HighgroundReputation"):
            folder = self.root / "addons" / addon / "tests"
            folder.mkdir(parents=True)
            (folder / "performance_test.lua").write_text("return true\n")
        for suite in ("docs_test.lua", "command_catalog_test.lua"):
            (self.root / "addons/Highground/tests" / suite).write_text('dofile("catalog.lua")\n')
        self.catalog = self.root / "addons/Highground/catalog.lua"
        self.catalog.write_text("return true\n")
        self.git("add", ".")

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.root), *args], check=True, capture_output=True)

    def check(self, *args):
        return subprocess.run([sys.executable, "scripts/check_commands.py", *args], cwd=self.root, capture_output=True, text=True)

    def test_staged_failure_is_not_hidden_by_an_unstaged_fix(self):
        self.catalog.write_text('error("missing UI equivalent")\n')
        self.git("add", ".")
        self.catalog.write_text("return true\n")
        before = self.git("diff", "--cached").stdout
        result = self.check("--staged")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing UI equivalent", result.stderr)
        self.assertEqual(before, self.git("diff", "--cached").stdout)
        self.assertEqual(self.catalog.read_text(), "return true\n")

    def test_unstaged_work_does_not_contaminate_passing_index(self):
        self.catalog.write_text('error("unrelated work")\n')
        result = self.check("--staged")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("unrelated work", self.catalog.read_text())

    def test_hook_upgrade_preserves_other_hooks_and_blocks_failure(self):
        self.git("config", "core.hooksPath", ".local-hooks")
        hooks = self.root / ".local-hooks"
        hooks.mkdir()
        old = '#!/bin/sh\nset -eu\nrepository_root=$(git rev-parse --show-toplevel)\nexec python3 "$repository_root/scripts/check_performance.py" --staged\n'
        (hooks / "pre-commit").write_text(old)
        (hooks / "pre-push").write_text("keep me\n")
        self.assertEqual(self.check("--install-hook").returncode, 0)
        self.assertEqual(self.check("--install-hook").returncode, 0)
        self.assertEqual((hooks / "pre-push").read_text(), "keep me\n")
        self.catalog.write_text('error("uncovered command")\n'); self.git("add", ".")
        result = subprocess.run(["git", "-c", "user.name=Hook test", "-c", "user.email=test@example.invalid", "commit", "-qm", "blocked"], cwd=self.root, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("uncovered command", result.stderr)
        (hooks / "pre-commit").write_text("custom hook\n")
        self.assertNotEqual(self.check("--install-hook").returncode, 0)
        self.assertEqual((hooks / "pre-commit").read_text(), "custom hook\n")


if __name__ == "__main__":
    unittest.main()
