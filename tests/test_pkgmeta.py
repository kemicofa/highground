"""The CurseForge webhook package (.pkgmeta) must equal the scripts/build.py package."""
import subprocess
import unittest

from support import ROOT, TempTestCase, build


def ignores(lines):
    """The paths of .pkgmeta's "ignore:" list."""
    found, listing = [], False
    for line in lines:
        if line.startswith("ignore:"):
            listing = True
        elif listing and line.strip().startswith("- "):
            found.append(line.strip()[2:])
        elif listing and line.strip() and not line.startswith(" "):
            listing = False
    return found


class PkgmetaTests(TempTestCase):
    def setUp(self):
        super().setUp()
        self.meta = (ROOT / ".pkgmeta").read_text().splitlines()
        self.addon = next(a for a in self.manifest.values() if a.webhook)
        self.prefix = self.addon.path.relative_to(ROOT).as_posix()  # addons/Highground

    def test_webhook_moves_the_addon_folder_to_the_top_with_its_changelog(self):
        self.assertIn(f"package-as: {self.addon.name}", self.meta)
        self.assertIn(f"  {self.addon.name}/{self.prefix}: {self.addon.name}", self.meta)
        self.assertIn(f"  filename: {self.prefix}/CHANGELOG.md", self.meta)

    def test_webhook_package_matches_build_package(self):
        # The webhook packages tracked files minus the ignore list and moves the
        # addon folder to the top; it must ship exactly what build.py ships and
        # nothing from outside the addon folder.
        patterns = ignores(self.meta)
        tracked = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True,
                                 check=True).stdout.splitlines()
        kept = {p for p in tracked if not any(p == i or p.startswith(i + "/") for i in patterns)}
        outside = sorted(p for p in kept if not p.startswith(self.prefix + "/"))
        self.assertEqual(outside, [], f"only {self.prefix} is packaged: add these to .pkgmeta ignore")
        webhook = {p[len(self.prefix) + 1:] for p in kept}
        self.assertEqual(webhook, {p.as_posix() for p in build.package_files(self.addon)})

    def test_other_addons_are_ignored(self):
        patterns = ignores(self.meta)
        for name, addon in self.manifest.items():
            if not addon.webhook:
                self.assertIn(addon.path.relative_to(ROOT).as_posix(), patterns)


if __name__ == "__main__":
    unittest.main()
