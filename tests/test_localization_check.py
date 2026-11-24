"""Exercise localization gates and hook upgrades in disposable Git repositories."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
VALID = 'local L = ...; assert(L:Register("frFR", { greeting = "Bonjour {name}" }))\n'
INVALID = 'local L = ...; assert(L:Register("frFR", { greeting = "Bonjour {missing}" }))\n'
COMMAND_HOOK = '''#!/bin/sh
set -eu
repository_root=$(git rev-parse --show-toplevel)
python3 "$repository_root/scripts/check_performance.py" --staged
# The Git hook is shared with older worktrees that predate this checker.
if [ -f "$repository_root/scripts/check_commands.py" ]; then
  python3 "$repository_root/scripts/check_commands.py" --staged
fi
'''


class LocalizationCheckTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="highground-localization-hook-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.git("init", "--quiet")
        for name in ("scripts/check_localization.py", "scripts/check_commands.py",
                     "scripts/check_performance.py", ".githooks/pre-commit"):
            self.write(name, (ROOT / name).read_text())
        self.write("addons/Highground/libs/locale/Library.lua",
                   (ROOT / "libs/HighgroundKit/locale/Library.lua").read_text())
        self.write("addons/Highground/tests/locale_library_test.lua", '''
local L = dofile("libs/locale/Library.lua").New("enUS")
assert(L:Register("enUS", { greeting = "Hello {name}" }))
assert(loadfile("translation.lua"))(L)
L:SetLocale("frFR")
assert(type(L:Format("greeting", { name = "Test" })) == "string")
''')
        for filename in ("performance_test.lua", "reputation_performance_test.lua"):
            self.write(f"addons/Highground/tests/{filename}", "return true\n")
        for suite in ("docs_test.lua", "command_catalog_test.lua"):
            self.write(f"addons/Highground/tests/{suite}", "return true\n")
        self.write("LICENSE", "Fixture license\n")
        (self.root / "addons/Highground/LICENSE").symlink_to("../../LICENSE")
        self.write("tests/test_localization.py", '''
from pathlib import Path
import unittest
class CatalogFiles(unittest.TestCase):
    def test_snapshot_contains_tools_and_catalog(self):
        self.assertTrue(Path("scripts/check_localization.py").is_file())
        self.assertTrue(Path("addons/Highground/translation.lua").is_file())
        self.assertEqual(Path("addons/Highground/LICENSE").read_text().strip(), "Fixture license")
''')
        self.translation = self.write("addons/Highground/translation.lua", VALID)
        self.git("add", ".")

    def write(self, name, content):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.root), *args], check=True, capture_output=True)

    def check(self, *args):
        return subprocess.run([sys.executable, "scripts/check_localization.py", *args],
                              cwd=self.root, text=True, capture_output=True)

    def test_staged_broken_placeholder_cannot_be_hidden_by_unstaged_fix(self):
        self.translation.write_text(INVALID)
        self.git("add", ".")
        self.translation.write_text(VALID)
        before = self.git("diff", "--cached").stdout
        result = self.check("--staged")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("placeholder mismatch", result.stderr)
        self.assertEqual(before, self.git("diff", "--cached").stdout)
        self.assertEqual(self.translation.read_text(), VALID)

    def test_unstaged_failure_does_not_contaminate_valid_index(self):
        self.translation.write_text(INVALID)
        result = self.check("--staged")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.translation.read_text(), INVALID)
        self.assertNotEqual(self.check().returncode, 0, "working-tree mode must see the failure")

    def test_staged_checker_itself_is_used(self):
        path = self.root / "scripts/check_localization.py"
        original = path.read_text()
        path.write_text('raise SystemExit("staged checker failure")\n')
        self.git("add", ".")
        path.write_text(original)
        result = self.check("--staged")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("staged checker failure", result.stderr)

    def test_repository_integration_failure_blocks_check(self):
        self.write("tests/test_localization.py", 'raise RuntimeError("broken manifest")\n')
        self.git("add", ".")
        result = self.check("--staged")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("broken manifest", result.stderr)

    def test_unrelated_documentation_skips_localization_suites(self):
        self.git("-c", "user.name=Hook test", "-c", "user.email=test@example.invalid", "commit", "-qm", "baseline")
        self.write("README.md", "Documentation only\n")
        self.git("add", "README.md")
        self.translation.write_text(INVALID)
        result = self.check("--staged")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("no relevant staged changes", result.stdout)

    def test_upgrade_shared_command_hook_and_block_bad_translation_commit(self):
        self.git("config", "core.hooksPath", ".local-hooks")
        self.write(".local-hooks/pre-commit", COMMAND_HOOK)
        other = self.write(".local-hooks/pre-push", "keep this custom hook\n")
        for _ in range(2):
            result = self.check("--install-hook")
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(other.read_text(), "keep this custom hook\n")
        self.translation.write_text(INVALID)
        self.git("add", "addons/Highground/translation.lua")
        result = subprocess.run(
            ["git", "-c", "user.name=Hook test", "-c", "user.email=test@example.invalid", "commit", "-qm", "blocked"],
            cwd=self.root, text=True, capture_output=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("placeholder mismatch", result.stderr)

    def test_custom_hook_is_preserved(self):
        self.git("config", "core.hooksPath", ".local-hooks")
        hook = self.write(".local-hooks/pre-commit", "custom checks\n")
        result = self.check("--install-hook")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(hook.read_text(), "custom checks\n")


if __name__ == "__main__":
    unittest.main()
