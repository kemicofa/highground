"""Real filesystem/Git tests for exclusive, portable game worktree selection."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import wow_link


class WorktreeLinkTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="highground-link-test-")
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)
        self.repository = self.folder / "source project"
        self.repository.mkdir()
        self.git("init", "-b", "main")
        self.git("config", "user.name", "Link Tests")
        self.git("config", "user.email", "tests@example.invalid")
        hooks = self.folder / "empty-hooks"
        hooks.mkdir()
        self.git("config", "core.hooksPath", str(hooks))
        for name in ("Highground", "HighgroundBountyData", "HighgroundReputationData", "HighgroundMacros"):
            addon = self.repository / "addons" / name
            addon.mkdir(parents=True)
            metadata = "## Title: " + name + "\n"
            if name == "Highground":
                metadata += "## Dependencies: HighgroundBountyData, HighgroundReputationData\n"
            (addon / (name + ".toc")).write_text(metadata + "Main.lua\n")
            (addon / "Main.lua").write_text("-- fixture\n")
        library = self.repository / "libs" / "HighgroundKit"
        library.mkdir(parents=True)
        (library / "Core.lua").write_text("-- shared fixture\n")
        (self.repository / "addons/Highground/libs").symlink_to("../../libs/HighgroundKit", target_is_directory=True)
        self.git("add", ".")
        self.git("commit", "-m", "fixture")
        self.feature = self.folder / "source project-feature"
        self.other = self.folder / "source project-other"
        self.git("worktree", "add", "-b", "feature", str(self.feature))
        self.git("worktree", "add", "-b", "other", str(self.other))
        self.addons = self.folder / "WoW Forever" / "Interface" / "AddOns"
        self.addons.mkdir(parents=True)
        self.installation = wow_link.Installation(self.repository, self.addons)

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.repository), *args], check=True,
                              text=True, capture_output=True).stdout.strip()

    def cli(self, *args, cwd=None):
        return subprocess.run([sys.executable, str(ROOT / "scripts/wow_link.py"), *args],
                              cwd=cwd or self.repository, text=True, capture_output=True)

    def configure(self):
        result = self.cli("configure", "--addons-dir", str(self.addons), cwd=self.feature)
        self.assertEqual(result.returncode, 0, result.stderr)

    def legacy(self, root=None, names=("Highground", "HighgroundBountyData", "HighgroundMacros")):
        for name in names:
            (self.addons / name).symlink_to((root or self.repository) / "addons" / name, target_is_directory=True)

    def assert_sources(self, root, names=None):
        for entry in self.addons.iterdir():
            if names is None or entry.name in names:
                self.assertEqual(entry.resolve(), root / "addons" / entry.name)

    def test_configuration_is_local_shared_and_does_not_activate(self):
        self.configure()
        self.assertEqual(self.git("config", "--local", "--get", wow_link.CONFIG_KEY), str(self.addons))
        self.assertEqual(self.git("status", "--porcelain"), "")
        self.assertEqual(list(self.addons.iterdir()), [])
        result = self.cli("status", "--json", cwd=self.other)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIsNone(json.loads(result.stdout)["active_worktree"])

    def test_unconfigured_cli_explains_required_setup(self):
        result = self.cli("status", "--json")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Configure", json.loads(result.stdout)["error"])

    def test_first_activation_links_dependencies_but_not_new_standalones(self):
        result = self.installation.activate(self.feature)
        self.assertEqual(result["active_worktree"], str(self.feature))
        self.assertEqual(result["problems"], [])
        self.assertEqual(set(result["addons"]), {"Highground", "HighgroundBountyData", "HighgroundReputationData"})
        self.assertFalse((self.addons / "HighgroundMacros").exists())
        self.assert_sources(self.feature)
        self.assertTrue((self.addons / "Highground/libs/Core.lua").is_file())
        self.assertEqual((self.addons / "Highground/libs").resolve(), self.feature / "libs/HighgroundKit")

    def test_same_worktree_activation_is_idempotent(self):
        self.installation.activate(self.feature)
        before = self.installation.active.lstat().st_ino
        self.installation.activate(self.feature)
        self.assertEqual(before, self.installation.active.lstat().st_ino)
        self.assert_sources(self.feature)

    def test_different_worktree_cannot_steal_selection(self):
        self.installation.activate(self.feature)
        with self.assertRaisesRegex(wow_link.LinkError, "belongs to"):
            self.installation.activate(self.other)
        self.assert_sources(self.feature)

    def test_explicit_switch_updates_all_addons_through_unchanged_links(self):
        self.legacy()
        self.installation.activate(self.repository)
        before = {entry.name: os.readlink(entry) for entry in self.addons.iterdir()}
        self.installation.activate(self.feature, replace=self.repository)
        self.assertEqual(before, {entry.name: os.readlink(entry) for entry in self.addons.iterdir()})
        self.assert_sources(self.feature)
        self.assertTrue((self.addons / "HighgroundMacros").is_symlink())

    def test_stale_replace_refuses_to_overwrite_new_owner(self):
        self.installation.activate(self.repository)
        self.installation.activate(self.feature, replace=self.repository)
        with self.assertRaisesRegex(wow_link.LinkError, "Selection changed"):
            self.installation.activate(self.other, replace=self.repository)
        self.assert_sources(self.feature)

    def test_legacy_install_is_adopted_and_missing_data_dependency_added(self):
        self.legacy()
        before = self.installation.status()
        self.assertEqual(before["mode"], "legacy")
        self.assertIn("HighgroundReputationData", before["problems"][0])
        after = self.installation.activate(self.repository)
        self.assertEqual(after["mode"], "managed")
        self.assertEqual(after["problems"], [])
        self.assert_sources(self.repository)

    def test_legacy_adoption_and_switch_never_exposes_mixed_sources(self):
        self.legacy()
        real_replace = wow_link.replace_link
        observations = []

        def observe(target, destination, staging):
            real_replace(target, destination, staging)
            roots = {entry.resolve().parent.parent for entry in self.addons.iterdir() if entry.exists()}
            observations.append(roots)

        with mock.patch.object(wow_link, "replace_link", side_effect=observe):
            self.installation.activate(self.feature, replace=self.repository)
        self.assertTrue(observations)
        self.assertTrue(all(len(roots) == 1 for roots in observations), observations)
        self.assert_sources(self.feature)

    def test_mixed_legacy_sources_fail_before_replacing_links(self):
        self.legacy(names=("Highground",))
        self.legacy(self.feature, names=("HighgroundBountyData",))
        before = {entry.name: os.readlink(entry) for entry in self.addons.iterdir()}
        with self.assertRaisesRegex(wow_link.LinkError, "different worktrees"):
            self.installation.activate(self.repository)
        self.assertEqual(before, {entry.name: os.readlink(entry) for entry in self.addons.iterdir()})
        self.assertFalse(self.installation.active.exists())

    def test_real_install_is_never_overwritten(self):
        real = self.addons / "Highground"
        real.mkdir()
        sentinel = real / "user-file"
        sentinel.write_text("keep")
        with self.assertRaisesRegex(wow_link.LinkError, "real directory"):
            self.installation.activate(self.feature)
        self.assertEqual(sentinel.read_text(), "keep")

    def test_duplicate_alias_is_rejected(self):
        (self.addons / "OldCopy").symlink_to(self.repository / "addons/Highground", target_is_directory=True)
        with self.assertRaisesRegex(wow_link.LinkError, "Duplicate"):
            self.installation.activate(self.feature)
        self.assertFalse((self.addons / "Highground").exists())

    def test_renamed_duplicate_toc_is_rejected(self):
        duplicate = self.addons / "Backup"
        duplicate.mkdir()
        (duplicate / "Backup.toc").write_text("## Title: Highground\n")
        with self.assertRaisesRegex(wow_link.LinkError, "Duplicate"):
            self.installation.activate(self.feature)

    def test_unrelated_addons_are_untouched(self):
        unrelated = self.addons / "OtherAddon"
        unrelated.mkdir()
        (unrelated / "OtherAddon.toc").write_text("## Title: Other Addon\n")
        self.installation.activate(self.feature)
        self.assertTrue(unrelated.is_dir() and not unrelated.is_symlink())

    def test_unregistered_directory_is_not_a_valid_source(self):
        with self.assertRaisesRegex(wow_link.LinkError, "Not a registered worktree"):
            self.installation.activate(self.folder)
        self.assertEqual(list(self.addons.iterdir()), [])

    def test_missing_dependency_does_not_change_selection(self):
        self.installation.activate(self.repository)
        toc = self.feature / "addons/Highground/Highground.toc"
        toc.write_text(toc.read_text() + "## Dependencies: HighgroundMissing\n")
        with self.assertRaisesRegex(wow_link.LinkError, "missing addon HighgroundMissing"):
            self.installation.activate(self.feature, replace=self.repository)
        self.assert_sources(self.repository)

    def test_foreign_source_symlink_does_not_change_selection(self):
        self.installation.activate(self.repository)
        link = self.feature / "addons/Highground/libs"
        link.unlink()
        link.symlink_to(self.repository / "libs/HighgroundKit", target_is_directory=True)
        with self.assertRaisesRegex(wow_link.LinkError, "leaves the selected worktree"):
            self.installation.activate(self.feature, replace=self.repository)
        self.assert_sources(self.repository)

    def test_broken_source_symlink_is_rejected(self):
        (self.feature / "libs/broken").symlink_to("missing")
        with self.assertRaisesRegex(wow_link.LinkError, "Broken source link"):
            self.installation.activate(self.feature)
        self.assertEqual(list(self.addons.iterdir()), [])

    def test_partial_legacy_conversion_keeps_old_source_and_can_resume(self):
        self.legacy()
        real_replace = wow_link.replace_link

        def fail(target, destination, staging):
            if destination.name == "HighgroundBountyData":
                raise OSError("simulated interruption")
            real_replace(target, destination, staging)

        with mock.patch.object(wow_link, "replace_link", side_effect=fail):
            with self.assertRaisesRegex(OSError, "simulated"):
                self.installation.activate(self.feature, replace=self.repository)
        self.assert_sources(self.repository)
        self.installation.activate(self.feature, replace=self.repository)
        self.assert_sources(self.feature)

    def test_failed_pointer_switch_keeps_old_selection(self):
        self.installation.activate(self.repository)
        real_replace = wow_link.replace_link

        def fail(target, destination, staging):
            if destination == self.installation.active:
                raise OSError("simulated pointer failure")
            real_replace(target, destination, staging)

        with mock.patch.object(wow_link, "replace_link", side_effect=fail):
            with self.assertRaisesRegex(OSError, "pointer failure"):
                self.installation.activate(self.feature, replace=self.repository)
        self.assert_sources(self.repository)

    def test_interrupted_first_install_can_resume(self):
        (self.addons / "Highground").symlink_to(self.installation.target("Highground"), target_is_directory=True)
        self.assertTrue(self.installation.status()["problems"])
        self.installation.activate(self.feature)
        self.assert_sources(self.feature)

    def test_missing_old_worktree_can_be_replaced_explicitly(self):
        self.installation.activate(self.feature)
        self.git("worktree", "remove", str(self.feature))
        fresh = wow_link.Installation(self.repository, self.addons)
        self.assertTrue(fresh.status()["problems"])
        fresh.activate(self.repository, replace=self.feature)
        self.assert_sources(self.repository)

    def test_installation_lock_rejects_another_process(self):
        self.configure()
        with wow_link.installation_lock(self.installation.state):
            result = self.cli("activate", "--worktree", str(self.feature), "--json")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Another process", json.loads(result.stdout)["error"])
        self.assertEqual(list(self.addons.iterdir()), [])

    def test_concurrent_switches_allow_only_one_expected_owner_replacement(self):
        self.configure()
        self.installation.activate(self.repository)
        commands = [[sys.executable, str(ROOT / "scripts/wow_link.py"), "activate", "--worktree", str(root),
                     "--replace", str(self.repository), "--json"] for root in (self.feature, self.other)]
        processes = [subprocess.Popen(command, cwd=self.repository, text=True,
                                      stdout=subprocess.PIPE, stderr=subprocess.PIPE) for command in commands]
        outputs = [process.communicate(timeout=15) for process in processes]
        self.assertEqual(sorted(process.returncode for process in processes), [0, 1], outputs)
        current = Path(self.installation.status()["active_worktree"])
        self.assertIn(current, {self.feature, self.other})
        self.assert_sources(current)

    def test_different_clone_respects_existing_testing_owner(self):
        self.installation.activate(self.feature)
        clone = self.folder / "another clone"
        self.git("clone", str(self.repository), str(clone))
        other_installation = wow_link.Installation(clone, self.addons)
        with self.assertRaisesRegex(wow_link.LinkError, "belongs to"):
            other_installation.activate(clone)
        other_installation.activate(clone, replace=self.feature)
        self.assert_sources(clone)


if __name__ == "__main__":
    unittest.main()
