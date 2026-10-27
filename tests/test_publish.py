"""Publication (scripts/publish.py): GitHub and CurseForge writes are mocked."""
import subprocess
import unittest
from unittest.mock import patch

from support import COMMIT, TempTestCase, build, curseforge, publish


class PublishTestCase(TempTestCase):
    def built(self, name):
        """Build an addon into the temporary output; returns (addon, version, its dist folder)."""
        addon = self.manifest[name]
        directory = addon.dist(self.output)
        version, _ = build.build(addon, directory)
        return addon, version, directory


class GitHubReleaseTests(PublishTestCase):
    """The webhook addon: a GitHub release, created as a draft at the tested commit."""

    def setUp(self):
        super().setUp()
        self.addon = next(a for a in self.manifest.values() if a.webhook)
        self.addon, self.version, self.directory = self.built(self.addon.name)

    def run_publish(self, responses):
        with patch.object(publish, "lookup", side_effect=responses), \
                patch.object(publish, "gh", return_value="https://example.test/release\n") as gh:
            publish.publish(self.addon, "owner/repo", COMMIT, self.directory)
        return [call.args for call in gh.call_args_list]

    def test_new_release_uploads_before_publication_at_tested_commit(self):
        calls = self.run_publish([None, None])
        self.assertEqual([call[1] for call in calls], ["create", "upload", "edit", "view"])
        self.assertEqual(calls[0][2], self.addon.tag())
        self.assertIn("--draft", calls[0])
        self.assertEqual(calls[0][calls[0].index("--target") + 1], COMMIT)
        self.assertEqual(calls[0][calls[0].index("--title") + 1], f"{self.addon.title} {self.version}")
        self.assertIn("--draft=false", calls[2])

    def test_published_release_is_untouched_on_rerun(self):
        self.assertEqual(self.run_publish([{"draft": False, "html_url": "https://example.test/release"}]), [])

    def test_matching_draft_resumes_without_recreating_release(self):
        calls = self.run_publish([{"draft": True, "target_commitish": COMMIT}, None])
        self.assertEqual([call[1] for call in calls], ["upload", "edit", "view"])

    def test_conflicting_tag_or_draft_cannot_be_overwritten(self):
        for responses in ([None, {"object": {}}, {"sha": "b" * 40}],
                          [{"draft": True, "target_commitish": "b" * 40}]):
            with self.subTest(responses=responses), self.assertRaises(ValueError), \
                    patch.object(publish, "lookup", side_effect=responses), patch.object(publish, "gh") as gh:
                publish.publish(self.addon, "owner/repo", COMMIT, self.directory)
            gh.assert_not_called()

    def test_corrupt_artifact_never_contacts_github(self):
        (self.directory / self.addon.zip_name()).write_bytes(b"broken archive")
        with patch.object(publish, "lookup") as lookup, self.assertRaisesRegex(ValueError, "validation"):
            publish.publish(self.addon, "owner/repo", COMMIT, self.directory)
        lookup.assert_not_called()

    def test_short_commit_is_refused(self):
        with patch.object(publish, "lookup") as lookup, self.assertRaisesRegex(ValueError, "full tested commit"):
            publish.publish(self.addon, "owner/repo", "abc123", self.directory)
        lookup.assert_not_called()

    def test_upload_failure_leaves_release_as_draft(self):
        with patch.object(publish, "lookup", side_effect=[None, None]), patch.object(publish, "gh") as gh:
            gh.side_effect = ["", subprocess.CalledProcessError(1, "upload")]
            with self.assertRaises(subprocess.CalledProcessError):
                publish.publish(self.addon, "owner/repo", COMMIT, self.directory)
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


class CurseForgeTests(PublishTestCase):
    """Other addons: CurseForge upload API, then a plain tag; never a GitHub release."""

    def setUp(self):
        super().setUp()
        self.addon, self.version, self.directory = self.built("HighgroundMacros")

    def test_game_versions_come_from_the_tocs(self):
        names = curseforge.interface_versions(self.addon)
        for name in ("12.1.0", "1.60.1", "1.15.9", "2.5.6", "4.4.2"):
            self.assertIn(name, names)
        self.assertEqual(len(names), len(set(names)))

    def test_upload_to_curseforge_then_a_plain_tag_and_no_github_release(self):
        # A GitHub release would fire the Highground CurseForge webhook.
        with patch.object(publish, "lookup", return_value=None), \
                patch.object(publish, "gh", return_value="") as gh, \
                patch.object(curseforge, "game_version_ids", return_value=[1, 2]) as ids, \
                patch.object(curseforge, "upload", return_value=99) as up:
            publish.publish(self.addon, "owner/repo", COMMIT, self.directory, "tok")
        up.assert_called_once()
        project, token, archive, notes, title, versions = up.call_args.args
        self.assertEqual((project, token, versions), (self.addon.project, "tok", [1, 2]))
        self.assertEqual(archive.name, self.addon.zip_name())
        self.assertEqual(title, f"Highground Macros {self.version}")
        self.assertEqual(notes, (self.directory / "RELEASE_NOTES.md").read_text())
        self.assertIn("12.1.0", ids.call_args.args[1])
        calls = [call.args for call in gh.call_args_list]
        self.assertEqual(len(calls), 1, "only the tag")
        self.assertEqual(calls[0][:2], ("api", "repos/owner/repo/git/refs"))
        self.assertIn(f"ref=refs/tags/HighgroundMacros-v{self.version}", calls[0])
        self.assertIn(f"sha={COMMIT}", calls[0])
        self.assertFalse(any("release" in c for c in calls), "no GitHub release")

    def test_tagged_version_is_not_uploaded_again(self):
        with patch.object(publish, "lookup", return_value={"object": {}}), \
                patch.object(publish, "gh") as gh, patch.object(curseforge, "upload") as up:
            publish.publish(self.addon, "owner/repo", COMMIT, self.directory, "tok")
        up.assert_not_called()
        gh.assert_not_called()

    def test_without_token_nothing_is_published(self):
        argv = ["publish.py", "HighgroundMacros", "--repository", "o/r", "--commit", COMMIT]
        with patch.dict("os.environ", {"CURSEFORGE_TOKEN": ""}), patch("sys.argv", argv), \
                patch.object(publish, "lookup") as lookup, patch.object(publish, "gh") as gh, \
                patch.object(curseforge, "upload") as up:
            publish.main()
        for mock in (lookup, gh, up):
            mock.assert_not_called()


if __name__ == "__main__":
    unittest.main()
