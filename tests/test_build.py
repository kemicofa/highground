"""Packaging (scripts/build.py): complete, reproducible ZIPs, and the rules that fail a build."""
import unittest
import zipfile
import struct

from support import ROOT, TempTestCase, addons, build


class PackageTests(TempTestCase):
    def test_standalone_groups_and_bundle_dependencies_stay_separate(self):
        required = set(addons.field(ROOT / 'addons' / 'Highground', 'Dependencies').replace(',', ' ').split())
        for suffix in ('Battlegrounds', 'Arena', 'Nearby', 'Bounties', 'Reputation', 'Macros'):
            name = 'Highground' + suffix
            for toc in addons.tocs(ROOT / 'addons' / name):
                self.assertIn('## Group: ' + name + '\n', toc.read_text())
            self.assertNotIn(name, required)
        self.assertEqual(required, {'HighgroundBountyData', 'HighgroundReputationData'})

    def test_addon_list_icons_are_packaged_in_their_own_folders(self):
        for directory in sorted((ROOT / 'addons').iterdir()):
            if not addons.tocs(directory):
                continue
            addon = addons.Addon(directory.name, directory)
            icon = addons.field(directory, 'IconTexture')
            self.assertTrue(icon, addon.name)
            prefix = f'Interface/AddOns/{addon.name}/'
            self.assertTrue(icon.replace('\\', '/').startswith(prefix))
            relative = icon.replace('\\', '/')[len(prefix):]
            self.assertIn(directory / relative, [directory / path for path in build.package_files(addon)])

    def test_highground_bundles_optional_module_switches_without_standalone_copies(self):
        addon = self.manifest['Highground']
        sources = build.package_sources(addon)
        for module in ('Battlegrounds', 'Arena', 'Nearby', 'Bounties', 'Reputation', 'Macros'):
            name = 'HighgroundModule' + module
            path = ROOT / 'addons' / name
            self.assertNotIn(name, self.manifest, 'module switches are not separately published')
            self.assertEqual(addons.field(path, 'Dependencies'), 'Highground')
            self.assertEqual(addons.field(path, 'Group'), 'Highground')
            self.assertEqual(addons.field(path, 'X-Highground-Module'), module.lower())
            self.assertIn(f'{name}/{name}.toc', sources)
            self.assertIn(f'{name}/Icon.tga', sources)
            self.assertNotIn(name, addons.field(addon.path, 'Dependencies'))
            self.assertFalse(any(p.startswith(f'Highground{module}/') for p in sources))

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
                             "docs/user-guide.md", "docs/reputation.md", "docs/macro-scripts.md",
                             "docs/battlegrounds.md", "docs/observations.md",
                             "docs/development.md", "docs/router.md", "docs/battleground-rules.md", "docs/simulations.md",
                             "libs/core/Router.lua", "libs/core/RouterNavigation.lua", "hub/Routes.lua",
                             "docs/curseforge.md", "docs/commands.md", "docs/design-system.md", "docs/ui-audit.md", "libs/media/OFL-jb.txt",
                             "libs/media/OFL-barlow.txt", "sounds/go.ogg", "sounds/lockon.ogg",
                             "features/bounties/sounds/bounty.ogg"):
                self.assertIn(f"Highground/{filename}", names)
            self.assertTrue(all(name.startswith(("Highground/", "HighgroundBountyData/", "HighgroundReputationData/", "HighgroundModule")) for name in names))
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
                             "libs/ui/kit/Header.lua", "libs/ui/kit/Windows.lua", "libs/ui/kit/Dialog.lua", "libs/media/JetBrainsMono-Bold.ttf",
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

    def test_transparent_brand_textures_ship_in_every_public_addon(self):
        for filename, size in (("HighgroundCrest.tga", 256), ("HighgroundIcon.tga", 64)):
            data = (ROOT / "libs/HighgroundKit/media" / filename).read_bytes()
            self.assertEqual(data[1:3], bytes((0, 2)), "uncompressed true-colour TGA without a colour map")
            self.assertEqual(struct.unpack_from("<HHB", data, 12), (size, size, 32))
            self.assertEqual(data[17] & 15, 8, "eight bits of alpha for the game renderer")
            start = 18 + data[0]
            self.assertGreaterEqual(len(data), start + size * size * 4)
            alpha = data[start + 3:start + size * size * 4:4]
            self.assertEqual(set(alpha[:size] + alpha[-size:] + alpha[::size] + alpha[size - 1::size]), {0},
                             "transparent margin on all four sides")
            self.assertIn(255, alpha, "opaque artwork remains")
            self.assertGreater(sum(a == 0 for a in alpha), size * size * 0.1, "no baked-in square background")
            for name, addon in self.manifest.items():
                with self.subTest(asset=filename, addon=name):
                    sources = build.package_sources(addon)
                    self.assertEqual(sources[f"{name}/libs/media/{filename}"].read_bytes(), data)
                    self.assertIn(f"{name}/libs/media/HighgroundCrest.txt", sources)

    def test_stealth_clients_bundle_both_sounds_and_their_source_notice(self):
        for name in ("Highground", "HighgroundNearby", "HighgroundBounties",
                     "HighgroundBattlegrounds", "HighgroundArena"):
            with self.subTest(addon=name):
                _, archive = build.build(self.manifest[name], self.output / name)
                with zipfile.ZipFile(archive) as package:
                    for sound in ("stealth-enter.ogg", "stealth-exit.ogg", "stealth.txt"):
                        data = package.read(f"{name}/libs/sounds/{sound}")
                        self.assertEqual(data, (ROOT / "libs/HighgroundKit/sounds" / sound).read_bytes())
                        if sound.endswith(".ogg"):
                            self.assertTrue(data.startswith(b"OggS"))
                    self.assertIn(f"{name}/libs/core/Stealth.lua", package.namelist())
                    if name in ("Highground", "HighgroundNearby", "HighgroundBounties"):
                        for sound in ("nearby.ogg", "nearby.txt"):
                            data = package.read(f"{name}/libs/sounds/{sound}")
                            self.assertEqual(data, (ROOT / "libs/HighgroundKit/sounds" / sound).read_bytes())
                            if sound.endswith(".ogg"):
                                self.assertTrue(data.startswith(b"OggS"))
                    if name in ("Highground", "HighgroundBattlegrounds", "HighgroundArena"):
                        self.assertIn(f"{name}/libs/pvp/Stealth.lua", package.namelist())

    def test_every_addon_has_a_validator(self):
        # Line limits, Lua compilation and accidental globals are checked per
        # addon by its tests/validate.py (built on tools/lint).
        for name, addon in self.manifest.items():
            with self.subTest(addon=name):
                self.assertTrue((addon.path / "tests" / "validate.py").exists())

    def test_every_ui_addon_loads_and_packages_shared_routing(self):
        modules = ("libs/core/Router.lua", "libs/core/RouterNavigation.lua", "libs/ui/kit/Navigation.lua")
        for name, addon in self.manifest.items():
            with self.subTest(addon=name):
                sources = build.package_sources(addon)
                for module in modules:
                    self.assertIn(f"{name}/{module}", sources)
                for toc in addons.tocs(addon.path):
                    entries = toc.read_text().splitlines()
                    self.assertLess(entries.index(modules[0]), entries.index(modules[1]))
                    self.assertLess(entries.index(modules[1]), entries.index("libs/ui/kit/Windows.lua"))
                    self.assertLess(entries.index("libs/ui/kit/Header.lua"), entries.index(modules[2]))
                if name in ("Highground", "HighgroundBounties", "HighgroundNearby"):
                    self.assertIn(f"{name}/libs/bounty/Navigation.lua", sources)
                if name in ("Highground", "HighgroundMacros"):
                    prefix = "features/macros/macros" if name == "Highground" else "src/macros"
                    self.assertIn(f"{name}/{prefix}/Navigation.lua", sources)

    def test_reputation_clients_bundle_native_services_and_one_data_owner(self):
        self.assertNotIn("HighgroundReputationData", self.manifest)
        source = ROOT / "addons/HighgroundReputation/src/reputation"
        for name, prefix in (("Highground", "features/reputation/reputation"), ("HighgroundReputation", "src/reputation")):
            _, path = build.build(self.manifest[name], self.output / name)
            with zipfile.ZipFile(path) as package:
                for file in source.glob("*.lua"):
                    self.assertEqual(package.read(f"{name}/{prefix}/{file.name}"), file.read_bytes())
                for module in ("Guild", "Organizations"):
                    self.assertEqual(package.read(f"{name}/libs/social/{module}.lua"),
                                     (ROOT / f"libs/HighgroundKit/social/{module}.lua").read_bytes())
                shared = package.read("HighgroundReputationData/HighgroundReputationData.toc").decode()
                self.assertIn("## SavedVariables: HighgroundReputationNetworkDB", shared)
                for toc in addons.tocs(self.manifest[name].path):
                    text = package.read(f"{name}/{toc.name}").decode()
                    self.assertIn("HighgroundReputationData", text)
                    self.assertNotIn("HighgroundReputationNetworkDB", text)

    def test_networking_clients_bundle_protocol_registry_after_the_transport(self):
        modules = ("libs/core/Network.lua", "libs/core/Protocols.lua", "libs/core/ProtocolTransport.lua")
        for name in ("Highground", "HighgroundBattlegrounds", "HighgroundBounties", "HighgroundNearby", "HighgroundReputation"):
            addon = self.manifest[name]
            with self.subTest(addon=name):
                sources = build.package_sources(addon)
                for module in modules:
                    self.assertEqual(sources[f"{name}/{module}"].read_bytes(),
                                     (ROOT / "libs/HighgroundKit" / module.removeprefix("libs/")).read_bytes())
                for toc in addons.tocs(addon.path):
                    entries = toc.read_text().splitlines()
                    self.assertLess(entries.index(modules[0]), entries.index(modules[1]))
                    self.assertLess(entries.index(modules[1]), entries.index(modules[2]))

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
