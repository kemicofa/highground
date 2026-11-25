"""Highground owns its features; only the reusable library is linked in."""
import os
import unittest

from support import ROOT, addons

LANGUAGES = ("deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW")


class LayoutTests(unittest.TestCase):
    def test_only_highground_is_a_public_addon(self):
        self.assertEqual(set(addons.load(include_deprecated=True)), {"Highground"})
        expected = {"Highground", "HighgroundBountyData", "HighgroundReputationData"}
        expected.update("HighgroundModule" + name for name in
                        ("Arena", "Battlegrounds", "Bounties", "Macros", "Nearby", "Reputation"))
        expected.update("HighgroundLocale" + code[0].upper() + code[1:] for code in LANGUAGES)
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

    def test_bundle_folders_link_only_license_declared_icon_and_their_catalog(self):
        for directory in (ROOT / "addons").iterdir():
            if directory.name == "Highground":
                continue
            # A language addon (HighgroundLocaleDeDE) loads its catalog (deDE) from the locale folder.
            name = directory.name
            catalog = name[-4:-2].lower() + name[-2:] if name.startswith("HighgroundLocale") else None
            allowed = {"LICENSE", "Icon.tga"} | ({f"{catalog}.lua"} if catalog else set())
            for path in directory.rglob("*"):
                if path.is_symlink():
                    self.assertIn(path.name, allowed)
                    self.assertTrue(path.is_file(), str(path))
                    if path.suffix == ".lua":
                        self.assertEqual(os.readlink(path), f"../../libs/HighgroundKit/locale/{catalog}.lua")


if __name__ == "__main__":
    unittest.main()
