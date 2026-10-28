"""The repository's layout rule: one library, each addon owns its code, only Highground imports addons.

- Every addon links libs -> ../../libs/HighgroundKit (the library, not an addon).
- A standalone addon loads only libs/, its own src/ and its own files.
- Highground alone imports other addons: features/<name> -> ../../<Addon>/src.
- No other links in addons/.
"""
import os
import unittest

from support import ROOT, addons

KIT = "../../libs/HighgroundKit"


class LayoutTests(unittest.TestCase):
    def setUp(self):
        self.manifest = addons.load()

    def test_library_is_not_an_addon(self):
        self.assertTrue((ROOT / "libs" / "HighgroundKit" / "standalone" / "Bootstrap.lua").is_file())
        self.assertFalse(list((ROOT / "libs").rglob("*.toc")), "the library has no TOC")

    def test_every_addon_embeds_the_library(self):
        for name, addon in self.manifest.items():
            with self.subTest(addon=name):
                link = addon.path / "libs"
                self.assertTrue(link.is_symlink())
                self.assertEqual(os.readlink(link), KIT)

    def test_standalone_addons_load_only_the_library_and_their_own_code(self):
        for name, addon in self.manifest.items():
            if name == "Highground":
                continue
            for toc in addons.tocs(addon.path):
                with self.subTest(toc=toc.name):
                    for line in toc.read_text().splitlines():
                        entry = line.strip()
                        if not entry or entry.startswith("#"):
                            continue
                        self.assertNotIn("..", entry)
                        self.assertFalse(entry.startswith(("features/", "shared/")), entry)
                        if "/" in entry:
                            self.assertTrue(entry.startswith(("libs/", "src/")), entry)

    def test_only_highground_imports_other_addons(self):
        expected = {}
        for name, addon in self.manifest.items():
            for path, _, files in os.walk(addon.path):
                for entry in [*files, *os.listdir(path)]:
                    link = os.path.join(path, entry)
                    if os.path.islink(link) and os.path.relpath(link, addon.path) != "libs":
                        expected.setdefault(name, set()).add((os.path.relpath(link, addon.path), os.readlink(link)))
        imports = expected.pop("Highground", set())
        self.assertEqual(expected, {}, "only Highground links to other addons")
        for relative, target in imports:
            self.assertTrue(relative.startswith("features/"), relative)
            folder = target.split("/")[2]
            self.assertIn(folder, self.manifest)
            self.assertEqual(target, f"../../{folder}/src")


if __name__ == "__main__":
    unittest.main()
