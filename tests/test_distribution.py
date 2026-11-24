"""The supported bundle remains complete while legacy hosts cannot ship."""
import json
import subprocess
import sys
from unittest.mock import patch

from support import COMMIT, ROOT, TempTestCase, addons, build, curseforge, publish, release_check
import discord_release
import release_plan


RETIRED = ("Arena", "Battlegrounds", "Bounties", "Macros", "Nearby", "Reputation")


class DistributionTests(TempTestCase):
    def test_release_discovery_excludes_deprecated_and_internal_addons(self):
        self.assertEqual(list(addons.load()), ["Highground"])
        self.assertEqual(list(self.manifest), ["Highground"], "no retired source hosts remain")
        for name, addon in self.manifest.items():
            self.assertEqual(addon.deprecated, name != "Highground")

    def test_inconsistent_deprecation_between_clients_fails_discovery(self):
        copies = self.copy_addons()
        addon = copies["Highground"]
        toc = addon.path / "Highground_Cata.toc"
        toc.write_text(toc.read_text() + "\n## X-Deprecated: true\n")
        with self.assertRaisesRegex(ValueError, "same X-Deprecated"):
            addons.load(addon.path.parent.parent)

    def test_default_build_produces_only_the_complete_highground_bundle(self):
        subprocess.run([sys.executable, "scripts/build.py", "--output-dir", str(self.output)],
                       cwd=ROOT, check=True, capture_output=True, text=True)
        self.assertEqual([p.name for p in self.output.iterdir()], ["Highground"])
        addon = addons.load()["Highground"]
        build.validate_archive(addon, addon.dist(self.output) / addon.zip_name())
        folders = {name.split("/")[0] for name in build.package_sources(addon)}
        self.assertEqual(folders, {"Highground", "HighgroundBountyData", "HighgroundReputationData",
                                  *("HighgroundModule" + suffix for suffix in
                                    ("Arena", "Battlegrounds", "Bounties", "Macros", "Nearby", "Reputation"))})

    def test_explicit_standalone_build_and_release_commands_are_rejected(self):
        for name in ("Highground" + suffix for suffix in RETIRED):
            for script, args in (("build.py", ["--output-dir", str(self.output)]),
                                 ("release_check.py", []),
                                 ("publish.py", ["--repository", "owner/repo", "--commit", COMMIT])):
                with self.subTest(addon=name, command=script):
                    result = subprocess.run([sys.executable, f"scripts/{script}", name, *args],
                                            cwd=ROOT, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                    self.assertIn("Highground", result.stderr)
        self.assertFalse(self.output.exists())

    def test_legacy_publish_functions_reject_before_reading_artifacts_or_contacting_services(self):
        with patch.object(publish, "lookup") as lookup, patch.object(publish, "gh") as gh, \
                patch.object(curseforge, "upload") as upload:
            for addon in [self.copy_addons()["Highground"]]:
                for toc in addons.tocs(addon.path):
                    toc.write_text(toc.read_text() + "\n## X-Deprecated: true\n")
                for method, extra in ((publish.publish_release, []),
                                      (publish.publish_curseforge, ["token"]),
                                      (publish.publish_wago, ["token"])):
                    with self.subTest(addon=addon.name, method=method.__name__), \
                            self.assertRaisesRegex(ValueError, "deprecated; publish Highground"):
                        method(addon, "owner/repo", addon.version, COMMIT, self.output, *extra)
            lookup.assert_not_called()
            gh.assert_not_called()
            upload.assert_not_called()

    def test_release_plan_never_requires_a_legacy_version_bump(self):
        found = addons.load()
        announcement = {"releases": {"Highground": found["Highground"].version}}
        with patch.object(release_check, "published", return_value=False) as published, \
                patch.object(release_check, "changed_since") as changed:
            matrix = release_plan.plan(found, announcement)
        self.assertEqual(matrix, {"include": [{"addon": "Highground", "artifact": found["Highground"].artifact()}]})
        published.assert_called_once_with(found["Highground"], found["Highground"].version)
        changed.assert_not_called()

    def test_new_announcements_cannot_promote_a_deprecated_distribution(self):
        path = self.temp / "announcement.json"
        for name in ("Highground", *("Highground" + suffix for suffix in RETIRED)):
            version = self.manifest["Highground"].version
            path.write_text(json.dumps({"releases": {name: version},
                                        "changes": ["Updated Highground."], "notice": ""}))
            if name != "Highground":
                with self.subTest(addon=name), self.assertRaisesRegex(ValueError, "must match a public addon"):
                    discord_release.load_plan(path, addons.load())
            else:
                self.assertEqual(discord_release.load_plan(path, addons.load())["releases"], {name: version})
