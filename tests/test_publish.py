"""Publication (scripts/publish.py): GitHub and CurseForge writes are mocked."""
import json
import subprocess
import unittest
import unittest.mock
from unittest.mock import patch
import urllib.error

from support import COMMIT, TempTestCase, addons, build, curseforge, publish, wago

REPO = "repos/owner/repo"
OTHER = "b" * 40


def release(tag, commit, draft=False):
    return {"tag_name": tag, "draft": draft, "target_commitish": commit, "html_url": f"https://example.test/{tag}"}


class FakeGitHub:
    """Answers gh like GitHub does. "Get a release by tag name" finds only published
    releases; the release list has drafts too. Publishing a draft creates its tag."""

    def __init__(self, releases=(), tags=None, fail=()):
        self.releases = [dict(r) for r in releases]
        self.tags = dict(tags or {})  # tag -> commit
        self.fail = set(fail)  # tags that cannot be created, or "release upload"
        self.calls, self.writes = [], []

    @staticmethod
    def error(message):
        return publish.CommandError(1, ["gh"], "", f"gh: {message}\n")

    def commands(self):
        return [call[1] for call in self.calls if call[0] == "release"]

    def __call__(self, *args):
        self.calls.append(args)
        if args[0] == "release":
            return self.release(args[1], args[2], args[3:])
        args = args[1:]
        if args[:2] == ("-X", "DELETE"):
            tag = args[2].removeprefix(f"{REPO}/git/refs/tags/")
            if tag not in self.tags:
                raise self.error("Reference does not exist (HTTP 422)")
            del self.tags[tag]
            self.writes.append(("delete", tag))
            return ""
        if args[:2] == ("--paginate", "--slurp"):
            assert args[2] == f"{REPO}/releases?per_page=100", args
            pages = [self.releases[i:i + 2] for i in range(0, len(self.releases), 2)]  # two per page
            return json.dumps(pages or [[]])
        path, fields = args[0], dict(value.split("=", 1) for value in args[2::2])
        if fields:
            assert path == f"{REPO}/git/refs", path
            tag = fields["ref"].removeprefix("refs/tags/")
            if tag in self.fail:
                raise self.error("Server Error (HTTP 500)")
            if tag in self.tags:
                raise self.error("Reference already exists (HTTP 422)")
            self.tags[tag] = fields["sha"]
            self.writes.append(("create", tag))
            return "{}"
        rest = path.removeprefix(f"{REPO}/")
        kind, _, name = rest.rpartition("/")
        if kind == "releases/tags":
            found = [r for r in self.releases if r["tag_name"] == name and not r["draft"]]
            if found:
                return json.dumps(found[0])
        elif kind == "git/ref/tags" and name in self.tags:
            return json.dumps({"ref": f"refs/tags/{name}", "object": {"sha": self.tags[name]}})
        elif kind == "commits":
            if name in self.tags:
                return json.dumps({"sha": self.tags[name]})
            raise self.error(f"No commit found for SHA: {name} (HTTP 422)")
        raise self.error("Not Found (HTTP 404)")

    def release(self, command, tag, rest):
        found = [r for r in self.releases if r["tag_name"] == tag]  # gh finds drafts by tag too
        if command == "create":
            assert not found
            self.releases.append(release(tag, rest[rest.index("--target") + 1], draft=True))
            return ""
        if not found:
            raise self.error("release not found")
        if command == "upload" and "release upload" in self.fail:
            raise self.error("Bad Gateway (HTTP 502)")
        if command == "edit" and "--draft=false" in rest:
            found[0]["draft"] = False
            self.tags.setdefault(tag, found[0]["target_commitish"])
        return found[0]["html_url"] + "\n" if command == "view" else ""


class PublishTestCase(TempTestCase):
    def setUp(self):
        super().setUp()
        # A full release unless a test says otherwise, whatever the TOCs say today.
        self.kind = patch.object(addons.Addon, "release_type", new_callable=unittest.mock.PropertyMock,
                                 return_value="release")
        self.kind.start()
        self.addCleanup(self.kind.stop)

    def as_release_type(self, kind):
        self.kind.stop()
        self.kind = patch.object(addons.Addon, "release_type", new_callable=unittest.mock.PropertyMock,
                                 return_value=kind)
        self.kind.start()

    def built(self, name):
        """Build an addon into the temporary output; returns (addon, version, its dist folder)."""
        addon = self.manifest[name]
        directory = addon.dist(self.output)
        version, _ = build.build(addon, directory)
        return addon, version, directory


class GitHubReleaseTests(PublishTestCase):
    """The GitHub-release addon (Highground): a release created as a draft at the tested commit."""

    def setUp(self):
        super().setUp()
        self.addon = next(a for a in self.manifest.values() if a.latest)
        self.addon, self.version, self.directory = self.built(self.addon.name)
        self.tag = self.addon.tag()

    def run_publish(self, github, *tokens):
        with patch.object(publish, "gh", github), \
                patch.object(curseforge, "game_version_ids", return_value=[1]), \
                patch.object(curseforge, "upload", return_value=99) as cf, \
                patch.object(wago, "upload") as up:
            try:
                publish.publish(self.addon, "owner/repo", COMMIT, self.directory, *tokens)
            finally:
                self.uploads = cf.call_count + up.call_count
        return github

    def test_new_release_uploads_before_publication_at_tested_commit(self):
        github = self.run_publish(FakeGitHub())
        self.assertEqual(github.commands(), ["create", "upload", "edit", "view"])
        create = next(call for call in github.calls if call[:2] == ("release", "create"))
        self.assertEqual(create[2], self.tag)
        self.assertIn("--draft", create)
        self.assertEqual(create[create.index("--target") + 1], COMMIT)
        self.assertEqual(create[create.index("--title") + 1], f"{self.addon.title} {self.version}")
        self.assertIn("--draft=false", next(call for call in github.calls if call[:2] == ("release", "edit")))
        self.assertEqual(github.tags, {self.tag: COMMIT})
        self.assertEqual(self.uploads, 0, "no CurseForge token or Wago key given")

    def test_alpha_is_a_prerelease_and_never_the_latest_release(self):
        self.as_release_type("alpha")
        github = self.run_publish(FakeGitHub())
        create = next(call for call in github.calls if call[:2] == ("release", "create"))
        edit = next(call for call in github.calls if call[:2] == ("release", "edit"))
        self.assertEqual(create[create.index("--title") + 1], f"{self.addon.title} {self.version} alpha")
        self.assertIn("--prerelease", create)
        self.assertIn("--latest=false", create)
        self.assertIn("--prerelease", edit)
        self.assertNotIn("--latest", edit)

    def test_published_release_is_untouched_on_rerun(self):
        github = self.run_publish(FakeGitHub([release(self.tag, COMMIT)], {self.tag: COMMIT}))
        self.assertEqual((github.commands(), github.writes), ([], []))

    def test_release_from_another_commit_stops_its_uploads(self):
        # The same version published from an earlier commit: this build must not reach the sites.
        github = FakeGitHub([release(self.tag, OTHER)], {self.tag: OTHER})
        with self.assertRaisesRegex(ValueError, "another commit"):
            self.run_publish(github, "tok", "key")
        self.assertEqual((github.commands(), github.writes, self.uploads), ([], [], 0))

    def test_matching_draft_resumes_without_recreating_release(self):
        # "Get a release by tag name" answers 404 for a draft; the release list finds it.
        others = [release(f"v0.0.{n}", OTHER) for n in range(3)]
        github = self.run_publish(FakeGitHub([*others, release(self.tag, COMMIT, draft=True)]))
        self.assertEqual(github.commands(), ["upload", "edit", "view"])
        self.assertEqual(github.tags, {self.tag: COMMIT})

    def test_conflicting_tag_or_draft_cannot_be_overwritten(self):
        cases = {"tag elsewhere": FakeGitHub(tags={self.tag: OTHER}),
                 "draft elsewhere": FakeGitHub([release(self.tag, OTHER, draft=True)]),
                 "two drafts": FakeGitHub([release(self.tag, COMMIT, draft=True)] * 2)}
        for name, github in cases.items():
            with self.subTest(name), self.assertRaises(ValueError):
                self.run_publish(github)
            self.assertEqual((github.commands(), github.writes), ([], []))

    def test_corrupt_artifact_never_contacts_github(self):
        (self.directory / self.addon.zip_name()).write_bytes(b"broken archive")
        with patch.object(publish, "gh") as gh, self.assertRaisesRegex(ValueError, "validation"):
            publish.publish(self.addon, "owner/repo", COMMIT, self.directory)
        gh.assert_not_called()

    def test_short_commit_is_refused(self):
        with patch.object(publish, "gh") as gh, self.assertRaisesRegex(ValueError, "full tested commit"):
            publish.publish(self.addon, "owner/repo", "abc123", self.directory)
        gh.assert_not_called()

    def test_upload_failure_leaves_release_as_draft(self):
        github = FakeGitHub(fail={"release upload"})
        with self.assertRaises(subprocess.CalledProcessError):
            self.run_publish(github)
        self.assertEqual(github.commands(), ["create", "upload"])
        self.assertEqual([r["draft"] for r in github.releases], [True])
        self.assertEqual(github.tags, {})

    def test_lookup_treats_only_404_as_missing(self):
        for status in (404, 403, 500):
            error = subprocess.CalledProcessError(1, "gh", stderr=f"gh: error (HTTP {status})")
            with self.subTest(status=status), patch.object(publish, "gh", side_effect=error):
                if status == 404:
                    self.assertIsNone(publish.lookup("repos/owner/repo/releases/tags/v1.0.0"))
                else:
                    with self.assertRaises(subprocess.CalledProcessError):
                        publish.lookup("repos/owner/repo/releases/tags/v1.0.0")

    def test_gh_errors_show_its_error_output(self):
        for status in (404, 403):
            failed = subprocess.CompletedProcess(["gh", "api", "x"], 1, "", f"gh: Some error (HTTP {status})\n")
            with self.subTest(status=status), patch.object(publish.subprocess, "run", return_value=failed):
                if status == 404:
                    self.assertIsNone(publish.lookup("x"))
                else:
                    with self.assertRaises(subprocess.CalledProcessError) as raised:
                        publish.lookup("x")
                    self.assertIn("returned non-zero exit status 1.\ngh: Some error (HTTP 403)", str(raised.exception))


class CurseForgeTests(PublishTestCase):
    """Highground: GitHub release followed by the CurseForge upload and its tag."""

    def setUp(self):
        super().setUp()
        self.addon, self.version, self.directory = self.built("Highground")
        self.tag = self.addon.curseforge_tag()

    def test_game_versions_come_from_the_tocs(self):
        names = self.addon.game_versions
        for name in ("12.1.0", "1.60.1", "4.4.2"):
            self.assertIn(name, names)
        self.assertEqual(len(names), len(set(names)))

    def test_github_release_then_curseforge_upload_then_its_tag(self):
        github = FakeGitHub()
        with patch.object(publish, "gh", github), \
                patch.object(curseforge, "game_version_ids", return_value=[1, 2]) as ids, \
                patch.object(curseforge, "upload", return_value=99) as up:
            publish.publish(self.addon, "owner/repo", COMMIT, self.directory, "tok")
        up.assert_called_once()
        project, token, archive, notes, title, versions = up.call_args.args
        self.assertEqual((project, token, versions), (self.addon.project, "tok", [1, 2]))
        self.assertEqual(archive.name, self.addon.zip_name())
        self.assertEqual(title, f"Highground {self.version}")
        self.assertEqual(notes, (self.directory / "RELEASE_NOTES.md").read_text())
        self.assertIn("12.1.0", ids.call_args.args[1])
        self.assertEqual(github.commands(), ["create", "upload", "edit", "view"], "GitHub release first")
        create = github.calls[[c[:2] for c in github.calls].index(("release", "create"))]
        self.assertEqual(create[2], f"v{self.version}")
        self.assertIn("--latest", create, "Highground stays the Latest release")
        self.assertEqual(github.writes, [("create", f"{self.tag}-pending"), ("create", self.tag),
                                         ("delete", f"{self.tag}-pending")])
        self.assertEqual(github.tags, {f"v{self.version}": COMMIT, self.tag: COMMIT})

    def test_alpha_uploads_as_an_alpha_file(self):
        self.as_release_type("alpha")
        with patch.object(publish, "gh", FakeGitHub()), \
                patch.object(curseforge, "game_version_ids", return_value=[1]), \
                patch.object(curseforge, "upload", return_value=99) as up:
            publish.publish(self.addon, "owner/repo", COMMIT, self.directory, "tok")
        self.assertEqual(up.call_args.args[4], f"Highground {self.version} alpha")
        self.assertEqual(up.call_args.kwargs["release_type"], "alpha")

    def test_upload_request_names_its_release_type(self):
        archive = self.directory / self.addon.zip_name()
        for kind in ("release", "alpha"):
            with self.subTest(kind=kind), patch.object(curseforge, "request", return_value={"id": 7}) as req:
                curseforge.upload(self.addon.project, "tok", archive, "notes", "Highground", [1], release_type=kind)
                body = req.call_args.args[3]
                self.assertIn(f'"releaseType": "{kind}"'.encode(), body)

    def published(self, **tags):
        """GitHub as after the release was published at COMMIT."""
        release_tag = self.addon.tag()
        return FakeGitHub([release(release_tag, COMMIT)], {release_tag: COMMIT, **tags})

    def run_publish(self, github, upload):
        with patch.object(publish, "gh", github), \
                patch.object(curseforge, "game_version_ids", return_value=[1]), \
                patch.object(curseforge, "upload", upload):
            publish.publish(self.addon, "owner/repo", COMMIT, self.directory, "tok")

    def test_uploaded_version_is_not_uploaded_again(self):
        github = self.published(**{self.tag: COMMIT})
        up = unittest.mock.Mock()
        self.run_publish(github, up)
        up.assert_not_called()
        self.assertEqual((github.commands(), github.writes), ([], []))

    def test_upload_whose_tag_failed_is_not_repeated(self):
        github = self.published()
        github.fail.add(self.tag)
        up = unittest.mock.Mock(return_value=99)
        with self.assertRaisesRegex(subprocess.CalledProcessError, "HTTP 500"):
            self.run_publish(github, up)
        self.assertEqual(up.call_count, 1)
        self.assertIn(f"{self.tag}-pending", github.tags)
        github.fail.clear()
        with self.assertRaisesRegex(ValueError, f"create {self.tag} at {COMMIT}"):
            self.run_publish(github, up)
        self.assertEqual(up.call_count, 1, "a retry never uploads blindly")
        # The check found the file: record it as the error says, then retry.
        github.tags[self.tag] = COMMIT
        del github.tags[f"{self.tag}-pending"]
        self.run_publish(github, up)
        self.assertEqual(up.call_count, 1)

    def test_upload_that_never_arrived_can_be_retried(self):
        refused = urllib.error.HTTPError("https://wow.curseforge.com/api", 500, "Server Error", {}, None)
        self.addCleanup(refused.close)
        cases = [(refused, False), (urllib.error.URLError("connection refused"), False),
                 (ValueError("no game versions"), False), (TimeoutError("reply lost"), True)]
        for error, unknown in cases:
            with self.subTest(error=error):
                github = self.published()
                with self.assertRaises(type(error)):
                    self.run_publish(github, unittest.mock.Mock(side_effect=error))
                self.assertNotIn(self.tag, github.tags)
                self.assertEqual(f"{self.tag}-pending" in github.tags, unknown)
                if not unknown:
                    up = unittest.mock.Mock(return_value=99)
                    self.run_publish(github, up)
                    up.assert_called_once()
                    self.assertIn(self.tag, github.tags)

    def test_without_token_only_the_github_release(self):
        argv = ["publish.py", "Highground", "--repository", "owner/repo", "--commit", COMMIT,
                "--dist", str(self.directory)]
        github = FakeGitHub()
        with patch.dict("os.environ", {"CURSEFORGE_TOKEN": "", "WAGO_API_KEY": ""}), patch("sys.argv", argv), \
                patch.object(publish, "gh", github), patch.object(curseforge, "upload") as up:
            publish.main()
        up.assert_not_called()
        self.assertEqual(github.commands(), ["create", "upload", "edit", "view"])


class WagoTests(PublishTestCase):
    """An addon with ## X-Wago-ID: uploaded to Wago after its release, once per version."""

    KNOWN = {"retail": ["12.1.0", "12.1.5"], "forever": ["1.60.1"], "cata": ["4.4.2"], "classic": ["1.15.8"]}

    def setUp(self):
        super().setUp()
        self.addon = next(a for a in self.manifest.values() if a.wago)
        self.addon, self.version, self.directory = self.built(self.addon.name)

    def run_publish(self, github):
        with patch.object(publish, "gh", github), \
                patch.object(publish, "publish_release") as release, \
                patch.object(wago, "upload") as up:
            publish.publish(self.addon, "owner/repo", COMMIT, self.directory, "", "key")
        release.assert_called_once()
        return up

    def test_patches_go_to_the_game_wago_lists_them_under(self):
        fields = wago.patches(self.KNOWN, ["12.1.0", "12.1.5", "1.60.1", "4.4.2", "9.9.9"])
        self.assertEqual(fields, {"supported_retail_patches": ["12.1.0", "12.1.5"],
                                  "supported_forever_patches": ["1.60.1"], "supported_cata_patches": ["4.4.2"]})
        with self.assertRaisesRegex(ValueError, "None of the TOC game versions"):
            wago.patches(self.KNOWN, ["9.9.9"])

    def test_highground_ships_to_its_wago_project(self):
        self.assertEqual(self.manifest["Highground"].wago, "b6Xy3OKp")
        self.assertEqual(self.addon.wago_tag(), f"wago-{self.addon.tag()}")
        fields = wago.patches(self.KNOWN, self.addon.game_versions)
        self.assertEqual(set(fields), {"supported_retail_patches", "supported_forever_patches",
                                       "supported_cata_patches"})

    def test_upload_after_the_release_then_a_wago_tag(self):
        github = FakeGitHub()
        up = self.run_publish(github)
        project, token, archive, notes, label, versions = up.call_args.args
        self.assertEqual((project, token, label), ("b6Xy3OKp", "key", self.version))
        self.assertEqual(archive.name, self.addon.zip_name())
        self.assertEqual(notes, (self.directory / "RELEASE_NOTES.md").read_text())
        self.assertEqual(versions, self.addon.game_versions)
        self.assertEqual(github.tags, {f"wago-v{self.version}": COMMIT})
        self.assertEqual(github.writes[1], ("create", f"wago-v{self.version}"))

    def test_tagged_version_is_not_uploaded_again(self):
        github = FakeGitHub(tags={self.addon.wago_tag(): COMMIT})
        self.run_publish(github).assert_not_called()
        self.assertEqual(github.writes, [])

    def test_upload_failure_leaves_no_tag(self):
        github = FakeGitHub()
        refused = urllib.error.HTTPError("https://addons.wago.io/api", 500, "Server Error", {}, None)
        self.addCleanup(refused.close)
        with patch.object(publish, "gh", github), patch.object(publish, "publish_release"), \
                patch.object(wago, "upload", side_effect=refused), self.assertRaises(urllib.error.HTTPError):
            publish.publish(self.addon, "owner/repo", COMMIT, self.directory, "", "key")
        self.assertEqual(github.tags, {})

    def test_upload_request(self):
        with patch.object(wago, "known_patches", return_value=self.KNOWN), \
                patch.object(wago.uploads, "request", return_value={"id": "x"}) as req:
            wago.upload("b6Xy3OKp", "key", self.directory / self.addon.zip_name(), "notes", "1.2.3", ["12.1.0"])
        method, url, headers, body = req.call_args.args
        self.assertEqual((method, url), ("POST", "https://addons.wago.io/api/projects/b6Xy3OKp/version"))
        self.assertEqual(headers["Authorization"], "Bearer key")
        self.assertIn(b'"supported_retail_patches": ["12.1.0"]', body)
        self.assertIn(b'"stability": "stable"', body)
        self.assertIn(b'"label": "1.2.3"', body)

    def test_alpha_uploads_with_alpha_stability(self):
        self.as_release_type("alpha")
        github = FakeGitHub()
        up = self.run_publish(github)
        self.assertEqual(up.call_args.kwargs["stability"], "alpha")
        self.assertEqual(up.call_args.args[4], f"{self.version}-alpha", "Wago labels the alpha apart from the release")
        self.assertEqual(github.tags, {f"wago-v{self.version}-alpha": COMMIT})
        with patch.object(wago, "known_patches", return_value=self.KNOWN), \
                patch.object(wago.uploads, "request", return_value={"id": "x"}) as req:
            wago.upload("b6Xy3OKp", "key", self.directory / self.addon.zip_name(), "notes", "1.2.3", ["12.1.0"],
                        stability="alpha")
        self.assertIn(b'"stability": "alpha"', req.call_args.args[3])

    def test_requests_name_themselves(self):
        # Wago answers Python's default User-Agent with HTTP 403.
        response = unittest.mock.MagicMock()
        response.__enter__.return_value.read.return_value = b"{}"
        with patch.object(wago.uploads.urllib.request, "urlopen", return_value=response) as urlopen:
            wago.uploads.request("GET", "https://addons.wago.io/api/data/game", {"Accept": "application/json"})
        agent = urlopen.call_args.args[0].get_header("User-agent")
        self.assertTrue(agent.startswith("highground-release"), agent)

    def test_a_reply_that_is_not_json_is_still_a_success(self):
        # Wago's upload succeeds with a non-JSON body; only HTTP errors fail.
        for body, expected in ((b"ok", "ok"), (b"", None), (b'{"id": 1}', {"id": 1})):
            response = unittest.mock.MagicMock()
            response.__enter__.return_value.read.return_value = body
            with self.subTest(body=body), patch.object(wago.uploads.urllib.request, "urlopen", return_value=response):
                self.assertEqual(wago.uploads.request("POST", "https://addons.wago.io/x", {}), expected)


if __name__ == "__main__":
    unittest.main()
