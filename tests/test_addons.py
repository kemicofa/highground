"""The addon manifest (scripts/addons.py) reads its facts from the TOCs and .pkgmeta."""
import re
import unittest

from support import ROOT, TempTestCase, addons


class ManifestTests(TempTestCase):
    def test_every_addon_folder_is_listed(self):
        folders = sorted(p.name for p in (ROOT / "addons").iterdir() if p.is_dir() and any(p.glob("*.toc")))
        self.assertEqual(sorted(self.manifest), folders)

    def test_one_webhook_addon_from_pkgmeta(self):
        package_as = re.search(r"^package-as:\s*(\S+)", (ROOT / ".pkgmeta").read_text(), re.M)[1]
        self.assertEqual([n for n, a in self.manifest.items() if a.webhook], [package_as])

    def test_tags_and_names_follow_the_publish_path(self):
        for name, addon in self.manifest.items():
            with self.subTest(addon=name):
                version = addon.version
                self.assertEqual(addon.tag(), ("v" if addon.webhook else f"{name}-v") + version)
                self.assertEqual(addon.zip_name(), f"{name}-{version}.zip")
                self.assertEqual(addon.artifact(), f"{name}-{version}")
                self.assertEqual(addon.dist("out").as_posix(), f"out/{name}")

    def test_titles_and_projects_come_from_the_tocs(self):
        for name, addon in self.manifest.items():
            with self.subTest(addon=name):
                toc = (addon.path / f"{name}.toc").read_text()
                self.assertIn(f"## Title: {addon.title}\n", toc)
                if addon.project:
                    self.assertIn(f"## X-Curse-Project-ID: {addon.project}\n", toc)
                else:
                    self.assertNotIn("## X-Curse-Project-ID", toc)

    def test_unknown_or_missing_webhook_addon_fails(self):
        root = self.copy_addons()["Highground"].path.parent.parent
        pkgmeta = root / ".pkgmeta"
        pkgmeta.write_text(pkgmeta.read_text().replace("package-as: Highground", "package-as: Highgrund"))
        with self.assertRaisesRegex(ValueError, "not a folder"):
            addons.load(root)
        pkgmeta.unlink()
        with self.assertRaisesRegex(ValueError, "package-as"):
            addons.load(root)

    def test_differing_toc_fields_fail(self):
        addon = self.copy_addons()["Highground"]
        cata = addon.path / "Highground_Cata.toc"
        cata.write_text(cata.read_text().replace("## Title: Highground", "## Title: Other"))
        with self.assertRaisesRegex(ValueError, "same Title"):
            addon.title


if __name__ == "__main__":
    unittest.main()
