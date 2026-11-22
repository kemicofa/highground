"""Regression coverage for PR selection and its required CI gate."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('ci_changes', ROOT / 'scripts/ci_changes.py')
changes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(changes)


class ChangesTests(unittest.TestCase):
    def test_documentation_paths(self):
        for path in ('README.md', 'AGENTS.md', 'LICENSE', 'docs/releases.md',
                     '.github/pull_request_template.md', '.agents/skills/review/SKILL.md',
                     'addons/Highground/README.md', 'addons/Highground/docs/commands.md'):
            with self.subTest(path=path):
                self.assertTrue(changes.documentation_only(path))

    def test_runtime_and_unknown_paths_require_tests(self):
        for path in ('addons/Highground/Main.lua', 'libs/HighgroundKit/core/Chat.lua',
                     'tests/test_ci_changes.py', '.github/workflows/ci.yml',
                     'scripts/build.py', 'assets/addon-logos/logo.png',
                     'addons/Highground/CHANGELOG.md', 'addons/Highground/Highground.toc',
                     'docs/example.lua', '.agents/helper.py', 'new-file.md'):
            with self.subTest(path=path):
                self.assertFalse(changes.documentation_only(path))

    def test_complete_diff_handles_deletion_rename_and_unusual_filenames(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            real_output = subprocess.check_output
            def git(*args):
                return real_output(['git', '-C', directory, *args], stderr=subprocess.DEVNULL).decode().strip()
            def commit():
                git('add', '-A')
                git('-c', 'user.name=Test', '-c', 'user.email=test@example.test', 'commit', '-qm', 'fixture')
                return git('rev-parse', 'HEAD')
            git('init', '-q')
            (root / 'code.lua').write_text('return true\n')
            base = commit()
            (root / 'README.md').write_text('Documentation\n')
            docs = commit()
            def output(command):
                return real_output([command[0], '-C', directory, *command[1:]])
            with patch.object(changes.subprocess, 'check_output', side_effect=output):
                self.assertFalse(changes.requires_tests(base, docs))
                (root / 'code.lua').rename(root / 'AGENTS.md')
                renamed = commit()
                self.assertTrue(changes.requires_tests(base, renamed))
                git('reset', '--hard', docs)
                (root / 'strange\n name.lua').write_text('return false\n')
                code = commit()
                (root / 'README.md').write_text('Later documentation edit\n')
                latest = commit()
                self.assertTrue(changes.requires_tests(base, latest))
                git('reset', '--hard', docs)
                (root / 'code.lua').unlink()
                self.assertTrue(changes.requires_tests(base, commit()))

    def test_git_errors_fail_instead_of_skipping(self):
        with patch.object(changes.subprocess, 'check_output', side_effect=subprocess.CalledProcessError(1, 'git')):
            with self.assertRaises(subprocess.CalledProcessError):
                changes.requires_tests('missing', 'HEAD')

    def test_required_gate_accepts_only_intended_skips(self):
        workflow = (ROOT / '.github/workflows/ci.yml').read_text()
        gate = workflow.split('      - name: Require every check to pass\n', 1)[1]
        script = gate.split('        run: |\n', 1)[1].split('      - uses:', 1)[0]
        script = '\n'.join(line[10:] for line in script.splitlines())
        cases = [
            ('success', 'false', 'pull_request', 'skipped', 'skipped', True),
            ('success', 'true', 'pull_request', 'success', 'success', True),
            ('success', 'true', 'push', 'success', 'success', True),
            ('success', 'true', 'workflow_dispatch', 'success', 'success', True),
            ('failure', 'false', 'pull_request', 'skipped', 'skipped', False),
            ('skipped', '', 'pull_request', 'skipped', 'skipped', False),
            ('success', '', 'pull_request', 'skipped', 'skipped', False),
            ('success', 'true', 'pull_request', 'success', 'skipped', False),
            ('success', 'true', 'pull_request', 'failure', 'success', False),
            ('success', 'true', 'pull_request', 'success', 'cancelled', False),
            ('success', 'false', 'pull_request', 'failure', 'skipped', False),
            ('success', 'false', 'push', 'skipped', 'skipped', False),
        ]
        for changed, run, event, repository, addon, success in cases:
            with self.subTest(case=(changed, run, event, repository, addon)):
                result = subprocess.run(['bash', '-eu', '-c', script], capture_output=True,
                    env=dict(CHANGES_RESULT=changed, RUN_TESTS=run, EVENT_NAME=event,
                             REPOSITORY_RESULT=repository, ADDON_RESULT=addon))
                self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
