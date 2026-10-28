"""The shared-files rule (scripts/release_check.py) that keeps the addons in step."""
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from support import TempTestCase, release_check

PUBLISH, WAITING, PUBLISHED = release_check.PUBLISH, release_check.WAITING, release_check.PUBLISHED
BUILDER = "addons/HighgroundMacros/src/macros/Builder.lua"


class DecideTests(unittest.TestCase):
    versions = {"Highground": "2.27.0", "HighgroundMacros": "0.2.0"}

    def status(self, addon, unpublished, shared_changed):
        return release_check.decide(addon, self.versions, unpublished, shared_changed).status

    def test_shared_change_with_both_bumped_publishes_both(self):
        new = {"Highground": True, "HighgroundMacros": True}
        self.assertEqual(self.status("Highground", new, {"HighgroundMacros": [BUILDER]}), PUBLISH)
        self.assertEqual(self.status("HighgroundMacros", new, {"Highground": [BUILDER]}), PUBLISH)

    def test_shared_change_with_one_bumped_waits_for_the_other(self):
        verdict = release_check.decide("HighgroundMacros", self.versions,
                                       {"Highground": False, "HighgroundMacros": True}, {"Highground": [BUILDER]})
        self.assertEqual(verdict.status, WAITING)
        self.assertIn("waits for Highground", verdict.reason)
        self.assertIn(BUILDER, verdict.reason)
        self.assertEqual(self.status("Highground", {"Highground": True, "HighgroundMacros": False},
                                     {"HighgroundMacros": [BUILDER]}), WAITING)

    def test_changes_one_addon_alone_packages_publish_it_alone(self):
        self.assertEqual(self.status("Highground", {"Highground": True, "HighgroundMacros": False},
                                     {"HighgroundMacros": []}), PUBLISH)
        self.assertEqual(self.status("HighgroundMacros", {"Highground": False, "HighgroundMacros": True},
                                     {"Highground": []}), PUBLISH)

    def test_published_version_is_left_alone(self):
        old = {"Highground": False, "HighgroundMacros": False}
        self.assertEqual(self.status("Highground", old, {"HighgroundMacros": [BUILDER]}), PUBLISHED)


class SharedFilesTests(TempTestCase):
    def test_shared_files_are_what_both_packages_hold(self):
        src = {name: release_check.sources(a) for name, a in self.manifest.items()}
        shared = src["Highground"] & src["HighgroundMacros"]
        self.assertIn(BUILDER, shared)
        self.assertIn("libs/HighgroundKit/ui/kit/Dialog.lua", shared)
        self.assertNotIn("addons/Highground/core/Scoring.lua", shared, "Highground only")
        self.assertNotIn("addons/HighgroundMacros/Main.lua", shared, "Macros only")

    def test_shared_files_are_computed_per_pair(self):
        # A and B share "ab", which changed since B's release. No file is in all
        # three packages, so one intersection over every addon would miss it.
        found = {name: SimpleNamespace(name=name, version="1.0.0", listed=True) for name in "ABC"}
        files = {"A": {"ab", "ac", "a"}, "B": {"ab", "b"}, "C": {"ac", "c"}}
        changed = {"ab", "b", "c"}
        with patch.object(release_check, "sources", side_effect=lambda a: files[a.name]), \
                patch.object(release_check, "published", side_effect=lambda a, v: a.name != "A"), \
                patch.object(release_check, "last_tag", side_effect=lambda a: f"{a.name}-v1.0.0"), \
                patch.object(release_check, "changed_since", side_effect=lambda tag, paths: sorted(paths & changed)):
            verdict = release_check.check("A", found)
        self.assertEqual(verdict.status, WAITING)
        self.assertTrue(verdict.reason.startswith("A 1.0.0 waits for B:"), verdict.reason)

    def test_wago_addon_is_published_only_with_its_wago_tag(self):
        addon = SimpleNamespace(tag=lambda v: f"v{v}", github_release=True, project=None, wago="id",
                                curseforge_tag=lambda v: f"curseforge-v{v}",
                                wago_tag=lambda v: f"wago-v{v}")
        for tags, expected in (({"v1.0.0"}, False), ({"v1.0.0", "wago-v1.0.0"}, True)):
            with self.subTest(tags=tags), \
                    patch.object(release_check, "git", side_effect=lambda *a: a[2] if a[2] in tags else ""):
                self.assertEqual(release_check.published(addon, "1.0.0"), expected)
        plain = SimpleNamespace(tag=lambda v: f"X-v{v}", curseforge_tag=lambda v: f"X-v{v}", github_release=False,
                                project="1", wago=None)
        with patch.object(release_check, "git", return_value="X-v1.0.0"):
            self.assertTrue(release_check.published(plain, "1.0.0"))

    def test_unlisted_addon_never_publishes_and_never_blocks(self):
        found = {name: SimpleNamespace(name=name, version="0.1.0", listed=name != "U", github_release=False,
                                       project=None if name == "U" else "1", wago=None,
                                       tag=lambda v, n=name: f"{n}-v{v}", curseforge_tag=lambda v, n=name: f"{n}-v{v}")
                 for name in ("A", "U")}
        verdict = release_check.check("U", found)
        self.assertEqual(verdict.status, release_check.UNLISTED)
        self.assertIn("X-Curse-Project-ID", verdict.reason)
        with patch.object(release_check, "sources", return_value={"shared"}), \
                patch.object(release_check, "git", return_value=""), \
                patch.object(release_check, "last_tag", return_value=None), \
                patch.object(release_check, "changed_since", side_effect=lambda tag, paths: sorted(paths)):
            self.assertEqual(release_check.check("A", found).status, PUBLISH)


if __name__ == "__main__":
    unittest.main()
