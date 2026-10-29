"""Packaging (scripts/build.py): complete, reproducible ZIPs, and the rules that fail a build."""
import unittest
import zipfile

from support import ROOT, TempTestCase, addons, build


class PackageTests(TempTestCase):
    def test_package_is_complete_installable_and_reproducible(self):
        addon = self.manifest["Highground"]
        version, archive = build.build(addon, self.output)
        with zipfile.ZipFile(archive) as package:
            names = set(package.namelist())
            for filename in ("Highground.toc", "Highground_Cata.toc", "Bindings.xml",
                             "features/battlegrounds/map/Pins.lua", "features/battlegrounds/config/cata/Classes.lua",
                             "features/battlegrounds/config/retail/Classes.lua", "ui/Focus.lua",
                             "features/battlegrounds/rules/SpecInference.lua",
                             "features/battlegrounds/config/cata/Auras.lua",
                             "features/battlegrounds/config/cata/Kits.lua", "features/battlegrounds/core/Events.lua",
                             "commands/Dispatch.lua", "options/Profiles.lua", "features/battlegrounds/flags/Window.lua",
                             "features/battlegrounds/map/Pins.xml", "compat/cata/PaperDoll.lua", "README.md",
                             "CHANGELOG.md", "LICENSE", "docs/README.md", "docs/getting-started.md",
                             "docs/user-guide.md", "docs/battlegrounds.md", "docs/observations.md",
                             "docs/development.md", "docs/battleground-rules.md", "docs/simulations.md",
                             "docs/curseforge.md", "docs/commands.md", "docs/design-system.md", "libs/media/OFL-jb.txt",
                             "libs/media/OFL-barlow.txt", "sounds/go.ogg", "sounds/lockon.ogg",
                             "features/bounties/sounds/bounty.ogg"):
                self.assertIn(f"Highground/{filename}", names)
            self.assertTrue(all(name.startswith(("Highground/", "HighgroundBountyData/")) for name in names))
            self.assertIn("HighgroundBountyData/HighgroundBountyData.toc", names)
            self.assertFalse(any(name.endswith(".py") or "/tests/" in name or "/.git" in name for name in names))
            self.assertIsNone(package.testzip())
        original = archive.read_bytes()
        build.build(addon, self.output)
        self.assertEqual(original, archive.read_bytes())
        self.assertEqual(version, addon.version)
        self.assertNotIn("## [2.7.4]", (self.output / "RELEASE_NOTES.md").read_text())

    def test_shared_files_are_copied_into_the_macros_package(self):
        addon = self.manifest["HighgroundMacros"]
        self.assertTrue((addon.path / "libs").is_symlink())
        _, archive = build.build(addon, self.output)
        with zipfile.ZipFile(archive) as package:
            names = set(package.namelist())
            for filename in ("HighgroundMacros.toc", "HighgroundMacros_Cata.toc", "libs/standalone/Bootstrap.lua",
                             "Host.lua", "Main.lua", "src/macros/Builder.lua", "src/macros/Ranks.lua",
                             "libs/ui/kit/Dialog.lua", "libs/media/JetBrainsMono-Bold.ttf",
                             "README.md", "CHANGELOG.md", "LICENSE"):
                self.assertIn(f"HighgroundMacros/{filename}", names)
            for filename in ("src/macros/Host.lua", "src/macros/Highground.lua", "libs/core/State.lua", "shared"):
                self.assertNotIn(f"HighgroundMacros/{filename}", names)
            self.assertTrue(all(name.startswith("HighgroundMacros/") for name in names))
            self.assertEqual(package.read("HighgroundMacros/src/macros/Builder.lua"),
                             (ROOT / "addons" / "HighgroundMacros" / "src" / "macros" / "Builder.lua").read_bytes())

    def test_every_addon_ships_the_repository_license(self):
        for name, addon in self.manifest.items():
            with self.subTest(addon=name):
                self.assertEqual((addon.path / "LICENSE").read_text(), (ROOT / "LICENSE").read_text())

    def test_every_addon_has_a_validator(self):
        # Line limits, Lua compilation and accidental globals are checked per
        # addon by its tests/validate.py (built on tools/lint).
        for name, addon in self.manifest.items():
            with self.subTest(addon=name):
                self.assertTrue((addon.path / "tests" / "validate.py").exists())

    def test_bounty_clients_bundle_one_persistent_data_owner(self):
        self.assertNotIn("HighgroundBountyData", self.manifest, "data helper is not released independently")
        for name in ("Highground", "HighgroundBounties", "HighgroundNearby"):
            with self.subTest(addon=name):
                addon = self.manifest[name]
                _, archive = build.build(addon, self.output / name)
                with zipfile.ZipFile(archive) as package:
                    shared = package.read("HighgroundBountyData/HighgroundBountyData.toc").decode()
                    self.assertIn("## SavedVariables: HighgroundBountyNetworkDB", shared)
                    for toc in addons.tocs(addon.path):
                        text = package.read(f"{name}/{toc.name}").decode()
                        self.assertIn("## Dependencies: HighgroundBountyData", text)
                        self.assertNotIn("HighgroundBountyNetworkDB", text, "only helper owns its SavedVariables file")
                    self.assertIn(f"{name}/libs/bounty/PublicStore.lua", package.namelist())


class BuildFailureTests(TempTestCase):
    """Each rule fails the build before a ZIP is written. Runs on copies of addons/."""

    def setUp(self):
        super().setUp()
        self.copies = self.copy_addons()
        self.addon = self.copies["Highground"]
        self.version = self.addon.version

    def assertBuildFails(self, pattern, addon=None):
        with self.assertRaisesRegex(ValueError, pattern):
            build.build(addon or self.addon, self.output)
        self.assertFalse(self.output.exists())

    def test_mismatched_client_versions_fail(self):
        path = self.addon.path / "Highground_Cata.toc"
        path.write_text(path.read_text().replace(f"## Version: {self.version}", "## Version: 0.0.1"))
        self.assertBuildFails("versions must match")

    def test_missing_or_empty_current_changelog_fails(self):
        for text in ("# Changelog\n## [0.0.1]\n- Old release\n", f"# Changelog\n## [{self.version}]\n"):
            with self.subTest(text=text):
                (self.addon.path / "CHANGELOG.md").write_text(text)
                self.assertBuildFails("CHANGELOG|changelog")

    def test_stale_curseforge_description_fails_for_every_curseforge_addon(self):
        for name, addon in self.copies.items():
            if not addon.project:
                continue
            with self.subTest(addon=name):
                path = addon.path / "docs" / "curseforge.md"
                path.write_text(path.read_text().replace(f"<!-- {name} {addon.version} -->",
                                                         f"<!-- {name} 0.0.1 -->"))
                self.assertBuildFails("curseforge.md must describe", addon)

    def test_long_curseforge_summary_fails(self):
        path = self.addon.path / "docs" / "curseforge.md"
        text = path.read_text()
        start = text.index("```\n", text.index("## Summary")) + 4
        path.write_text(text[:start] + "x" * (build.SUMMARY_MAX + 1) + text[text.index("\n```", start):])
        self.assertBuildFails("summary")

    def test_missing_xml_dependency_fails(self):
        (self.addon.path / "features/battlegrounds/map/Pins.lua").unlink()  # through the link
        self.assertBuildFails("Missing package file: features/battlegrounds/map/Pins.lua")

    def test_manifest_cannot_escape_addon_directory(self):
        path = self.addon.path / "Highground.toc"
        path.write_text(path.read_text() + "\n../outside.lua\n")
        self.assertBuildFails("escapes the addon")

    def test_bundled_dependency_cannot_escape_addons_directory(self):
        for toc in addons.tocs(self.addon.path):
            toc.write_text(toc.read_text().replace("## X-Bundled-Addons: HighgroundBountyData", "## X-Bundled-Addons: ../outside"))
        self.assertBuildFails("Invalid bundled addon")


if __name__ == "__main__":
    unittest.main()
