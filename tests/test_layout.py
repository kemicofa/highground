"""Highground owns its features; only the reusable library is linked in."""
import os
import unittest

from support import ROOT, addons


class LayoutTests(unittest.TestCase):
    def test_only_highground_is_a_public_addon(self):
        self.assertEqual(set(addons.load(include_deprecated=True)), {"Highground"})
        expected = {"Highground", "HighgroundBountyData", "HighgroundReputationData"}
        expected.update("HighgroundModule" + name for name in
                        ("Arena", "Battlegrounds", "Bounties", "Macros", "Nearby", "Reputation"))
        self.assertEqual({p.name for p in (ROOT / "addons").iterdir() if p.is_dir()}, expected)

    def test_library_is_not_an_addon_or_a_legacy_host(self):
        kit = ROOT / "libs/HighgroundKit"
        self.assertTrue((kit / "core/Util.lua").is_file())
        self.assertFalse(list((ROOT / "libs").rglob("*.toc")), "the library has no TOC")
        self.assertFalse((kit / "standalone").exists(), "legacy bootstrap is retired")
        link = ROOT / "addons/Highground/libs"
        self.assertTrue(link.is_symlink())
        self.assertEqual(os.readlink(link), "../../libs/HighgroundKit")

    def test_features_are_owned_directories_without_external_source_links(self):
        features = ROOT / "addons/Highground/features"
        self.assertEqual({p.name for p in features.iterdir()},
                         {"arena", "battlegrounds", "bounties", "macros", "nearby", "reputation"})
        for directory in features.iterdir():
            self.assertTrue(directory.is_dir())
            self.assertFalse(directory.is_symlink(), str(directory))
        for path in features.rglob("*"):
            self.assertFalse(path.is_symlink(), str(path))

    def test_bundle_folders_link_only_license_and_declared_icon(self):
        for directory in (ROOT / "addons").iterdir():
            if directory.name == "Highground":
                continue
            for path in directory.rglob("*"):
                if path.is_symlink():
                    self.assertIn(path.name, {"LICENSE", "Icon.tga"})
                    self.assertTrue(path.is_file(), str(path))


if __name__ == "__main__":
    unittest.main()
