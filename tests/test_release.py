"""Packaging and publication regressions; GitHub writes are mocked."""
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / f"{name}.py")
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


build = module("build")
publish = module("publish")


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "source"
        shutil.copytree(ROOT, self.root, ignore=shutil.ignore_patterns(".git", "dist", "__pycache__", "graphify-out"))
        self.output = Path(self.temp.name) / "dist"
        self.version, _ = build.release_info(self.root)
        self.commit = "a" * 40

    def test_curseforge_package_matches_github_package(self):
        # The CurseForge webhook packages tracked files minus .pkgmeta's ignore
        # list; it must ship exactly what scripts/build.py ships.
        meta = (ROOT / ".pkgmeta").read_text().splitlines()
        self.assertIn("package-as: Warboard", meta)
        ignores, listing = [], False
        for line in meta:
            if line.startswith("ignore:"):
                listing = True
            elif listing and line.strip().startswith("- "):
                ignores.append(line.strip()[2:])
            elif listing and line.strip() and not line.startswith(" "):
                listing = False
        # CurseForge's packager did not honor "sounds/*.py"; name files exactly.
        self.assertFalse([p for p in ignores if any(c in p for c in "*?[")], "use exact paths in .pkgmeta")
        tracked = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.split()
        def ignored(path):
            return any(path == pattern or path.startswith(pattern + "/") for pattern in ignores)
        curseforge = {path for path in tracked if not ignored(path)}
        github = {str(path) for path in build.package_files(ROOT)}
        self.assertEqual(curseforge, github)

    def test_package_is_complete_installable_and_reproducible(self):
        version, archive = build.build(self.root, self.output)
        with zipfile.ZipFile(archive) as package:
            names = set(package.namelist())
            for filename in ("Warboard.toc", "Warboard_Cata.toc", "Bindings.xml", "map/Pins.lua",
                             "config/cata/Classes.lua", "config/retail/Classes.lua", "ui/Focus.lua", "rules/SpecInference.lua",
                             "config/cata/Auras.lua", "config/cata/Kits.lua", "core/Events.lua",
                             "commands/Dispatch.lua", "options/Profiles.lua", "flags/Window.lua", "map/Pins.xml",
                             "compat/cata/PaperDoll.lua",
                             "README.md", "CHANGELOG.md", "LICENSE", "docs/README.md",
                             "docs/getting-started.md", "docs/user-guide.md", "docs/battlegrounds.md",
                             "docs/observations.md", "docs/development.md", "docs/battleground-rules.md",
                             "docs/releases.md", "docs/simulations.md", "docs/curseforge.md",
                             "media/OFL-jb.txt", "media/OFL-barlow.txt", "sounds/go.ogg", "sounds/lockon.ogg"):
                self.assertIn(f"Warboard/{filename}", names)
            self.assertTrue(all(name.startswith("Warboard/") for name in names))
            self.assertFalse(any(name.endswith(".py") or "/tests/" in name or "/.git" in name for name in names))
            self.assertIsNone(package.testzip())
        original = archive.read_bytes()
        build.build(self.root, self.output)
        self.assertEqual(original, archive.read_bytes())
        self.assertEqual(version, self.version)
        self.assertNotIn("## [2.7.4]", (self.output / "RELEASE_NOTES.md").read_text())

    def test_mismatched_client_versions_fail_before_building(self):
        path = self.root / "Warboard_Cata.toc"
        path.write_text(path.read_text().replace(f"## Version: {self.version}", "## Version: 0.0.1"))
        with self.assertRaisesRegex(ValueError, "versions must match"):
            build.build(self.root, self.output)
        self.assertFalse(self.output.exists())

    def test_missing_or_empty_current_changelog_fails(self):
        for text in ("# Changelog\n## [0.0.1]\n- Old release\n", f"# Changelog\n## [{self.version}]\n"):
            with self.subTest(text=text):
                (self.root / "CHANGELOG.md").write_text(text)
                with self.assertRaises(ValueError):
                    build.build(self.root, self.output)

    def test_stale_curseforge_description_fails(self):
        path = self.root / "docs" / "curseforge.md"
        path.write_text(path.read_text().replace(f"<!-- Warboard {self.version} -->", "<!-- Warboard 0.0.1 -->"))
        with self.assertRaisesRegex(ValueError, "curseforge.md must describe"):
            build.build(self.root, self.output)

    def test_missing_xml_dependency_fails(self):
        (self.root / "map/Pins.lua").unlink()
        with self.assertRaisesRegex(ValueError, "Missing package file: map/Pins.lua"):
            build.build(self.root, self.output)

    def test_manifest_cannot_escape_addon_directory(self):
        path = self.root / "Warboard.toc"
        path.write_text(path.read_text() + "\n../outside.lua\n")
        with self.assertRaisesRegex(ValueError, "escapes the addon"):
            build.build(self.root, self.output)

    def publish_with(self, responses):
        build.build(self.root, self.output)
        lookup = patch.object(publish, "lookup", side_effect=responses)
        commands = patch.object(publish, "gh", return_value="https://example.test/release\n")
        return lookup, commands

    def test_new_release_uploads_before_publication_at_tested_commit(self):
        lookup, commands = self.publish_with([None, None])
        with lookup, commands as gh:
            publish.publish("owner/repo", self.version, self.commit, self.output)
        calls = [call.args for call in gh.call_args_list]
        self.assertEqual([call[1] for call in calls], ["create", "upload", "edit", "view"])
        self.assertIn("--draft", calls[0])
        self.assertEqual(calls[0][calls[0].index("--target") + 1], self.commit)
        self.assertIn("--draft=false", calls[2])

    def test_published_release_is_untouched_on_rerun(self):
        lookup, commands = self.publish_with([{"draft": False, "html_url": "https://example.test/release"}])
        with lookup, commands as gh:
            publish.publish("owner/repo", self.version, self.commit, self.output)
        gh.assert_not_called()

    def test_matching_draft_resumes_without_recreating_release(self):
        lookup, commands = self.publish_with([{"draft": True, "target_commitish": self.commit}, None])
        with lookup, commands as gh:
            publish.publish("owner/repo", self.version, self.commit, self.output)
        self.assertEqual([call.args[1] for call in gh.call_args_list], ["upload", "edit", "view"])

    def test_conflicting_tag_or_draft_cannot_be_overwritten(self):
        for responses in ([None, {"object": {}}, {"sha": "b" * 40}],
                          [{"draft": True, "target_commitish": "b" * 40}]):
            with self.subTest(responses=responses):
                lookup, commands = self.publish_with(responses)
                with lookup, commands as gh, self.assertRaises(ValueError):
                    publish.publish("owner/repo", self.version, self.commit, self.output)
                gh.assert_not_called()

    def test_corrupt_artifact_never_contacts_github(self):
        _, archive = build.build(self.root, self.output)
        archive.write_bytes(b"broken archive")
        with patch.object(publish, "lookup") as lookup, self.assertRaisesRegex(ValueError, "validation"):
            publish.publish("owner/repo", self.version, self.commit, self.output)
        lookup.assert_not_called()

    def test_upload_failure_leaves_release_as_draft(self):
        lookup, commands = self.publish_with([None, None])
        with lookup, commands as gh:
            gh.side_effect = ["", subprocess.CalledProcessError(1, "upload")]
            with self.assertRaises(subprocess.CalledProcessError):
                publish.publish("owner/repo", self.version, self.commit, self.output)
        self.assertEqual([call.args[1] for call in gh.call_args_list], ["create", "upload"])

    def test_lookup_treats_only_404_as_missing(self):
        for status in (404, 403, 500):
            error = subprocess.CalledProcessError(1, "gh", stderr=f"gh: error (HTTP {status})")
            with self.subTest(status=status), patch.object(publish, "gh", side_effect=error):
                if status == 404:
                    self.assertIsNone(publish.lookup("repos/owner/repo/releases/tags/v1.0.0"))
                else:
                    with self.assertRaises(subprocess.CalledProcessError):
                        publish.lookup("repos/owner/repo/releases/tags/v1.0.0")


if __name__ == "__main__":
    unittest.main()
