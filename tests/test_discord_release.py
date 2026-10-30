"""Release announcements: all GitHub/Discord writes are mocked."""
from contextlib import ExitStack
import io
import json
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

from support import COMMIT, publish
import discord_release as discord


class AnnouncementTests(unittest.TestCase):
    def setUp(self):
        self.addons = {
            "Highground": SimpleNamespace(title="Highground", version="2.31.0", project="1", wago="wago",
                                          tag=lambda v: "v" + v, curseforge_tag=lambda v: "curseforge-v" + v,
                                          wago_tag=lambda v: "wago-v" + v),
            "HighgroundMacros": SimpleNamespace(title="Highground Macros", version="0.4.0", project="2", wago=None,
                                                tag=lambda v: "HighgroundMacros-v" + v,
                                                curseforge_tag=lambda v: "curseforge-HighgroundMacros-v" + v),
        }
        self.plan = {"releases": {name: a.version for name, a in self.addons.items()},
                     "changes": ["Added repair and sell-junk macro presets.", "Fixed stale enemy map pins."],
                     "notice": "Restart the game after updating; /reload is not enough."}
        self.repository = "owner/repo"
        self.key = discord.delivery_key(self.plan, self.repository)
        self.marker = f"repos/{self.repository}/git/ref/tags/discord-{self.key}"
        self.release = {"draft": False, "published_at": "2026-10-30T10:00:00Z"}

    def load(self, plan):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "announcement.json"
            path.write_text(json.dumps(plan))
            return discord.load_plan(path, self.addons)

    def lookup(self, path):
        if path == self.marker:
            return None
        if "/releases/tags/" in path:
            return self.release
        return {"object": {"sha": COMMIT}}

    def mock_delivery(self):
        stack = ExitStack()
        self.addCleanup(stack.close)
        lookup = stack.enter_context(patch.object(publish, "lookup", side_effect=self.lookup))
        gh = stack.enter_context(patch.object(publish, "gh", return_value=""))
        request = stack.enter_context(patch.object(discord, "request", side_effect=[
            {"type": 5, "guild_id": "100"}, {"id": "bot"}, [], {"id": "300"}]))
        stack.enter_context(patch.dict(discord.os.environ, {}, clear=True))
        return lookup, gh, request

    def announce(self, **overrides):
        args = {"plan": self.plan, "found": self.addons, "repository": self.repository,
                "commit": COMMIT, "token": "test-token", "channel": "200"}
        return discord.announce(**(args | overrides))

    def test_preview_has_changes_exact_versions_links_and_restart_notice(self):
        content = discord.render(self.load(self.plan), self.addons, self.repository)
        for change in self.plan["changes"]:
            self.assertEqual(content.count(change), 1)
        for name, url in discord.release_links(self.plan, self.addons, self.repository).items():
            self.assertIn(f"[{self.addons[name].title} {self.addons[name].version}](<{url}>)", content)
        self.assertIn(self.plan["notice"], content)
        self.assertLessEqual(len(content), 2000)

    def test_stale_unknown_or_missing_release_versions_are_rejected(self):
        for releases in ({"Highground": "2.30.0"}, {"HighgroundBountyData": "1.0.0"},
                         {"Highground": None}, {}):
            with self.subTest(releases=releases), self.assertRaises(ValueError):
                self.load(self.plan | {"releases": releases})

    def test_invalid_or_long_wording_is_rejected(self):
        for changes in ([], ["x"] * 6, [" "], ["x" * 241], ["one\ntwo"], [None], "a change"):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                self.load(self.plan | {"changes": changes})
        with self.assertRaises(ValueError):
            self.load(self.plan | {"notice": "x" * 301})
        with self.assertRaises(ValueError):
            discord.render(self.plan | {"changes": ["x" * 2000]}, self.addons, self.repository)

    def test_empty_plan_never_contacts_either_service(self):
        plan = self.load({"releases": {}, "changes": [], "notice": ""})
        lookup, gh, request = self.mock_delivery()
        self.assertIsNone(self.announce(plan=plan))
        lookup.assert_not_called()
        gh.assert_not_called()
        request.assert_not_called()

    def test_preview_cli_is_offline_and_requires_a_new_addon_when_requested(self):
        with patch.object(discord, "load_plan", return_value=self.plan), \
                patch.object(discord.addons, "load", return_value=self.addons), \
                patch.object(discord, "announce") as announce, \
                patch("sys.argv", ["discord_release.py", "--repository", self.repository, "--check"]):
            discord.main()
            announce.assert_not_called()
        with patch.object(discord, "load_plan", return_value={"releases": {}}), \
                patch("sys.argv", ["discord_release.py", "--repository", self.repository, "--check",
                                   "--require-addon", "Highground"]), self.assertRaisesRegex(ValueError, "before publishing"):
            discord.main()

    def test_waits_for_all_releases_and_uploads_before_contacting_discord(self):
        missing_paths = ["releases/tags/HighgroundMacros-v0.4.0",
                         "git/ref/tags/curseforge-HighgroundMacros-v0.4.0", "git/ref/tags/wago-v2.31.0"]
        for missing in missing_paths:
            with self.subTest(missing=missing):
                lookup, gh, request = self.mock_delivery()
                lookup.side_effect = lambda path: None if path.endswith(missing) else self.lookup(path)
                self.assertIsNone(self.announce())
                gh.assert_not_called()
                request.assert_not_called()

    def test_draft_release_is_not_announced(self):
        self.release["draft"] = True
        _, gh, request = self.mock_delivery()
        self.assertIsNone(self.announce())
        gh.assert_not_called()
        request.assert_not_called()

    def test_one_combined_message_is_sent_before_recording_delivery(self):
        _, gh, request = self.mock_delivery()
        def record(*args):
            self.assertEqual(request.call_args.args[0], "POST")
            self.assertIn(f"ref=refs/tags/discord-{self.key}", args)
        gh.side_effect = record
        self.assertEqual(self.announce(), "https://discord.com/channels/100/200/300")
        posts = [call.args for call in request.call_args_list if call.args[0] == "POST"]
        self.assertEqual(len(posts), 1)
        payload = posts[0][3]
        self.assertEqual(payload["content"], discord.render(self.plan, self.addons, self.repository))
        self.assertEqual(payload["allowed_mentions"], {"parse": []})
        self.assertEqual(payload["flags"], 4)
        self.assertTrue(payload["enforce_nonce"])
        self.assertLessEqual(len(payload["nonce"]), 25)
        gh.assert_called_once()

    def test_delivery_key_ignores_wording_and_map_order_but_changes_with_version(self):
        reordered = dict(reversed(list(self.plan["releases"].items())))
        self.assertEqual(discord.delivery_key(self.plan | {"changes": ["Reworded"], "releases": reordered},
                                              self.repository), self.key)
        self.assertNotEqual(discord.delivery_key(self.plan | {"releases": {"Highground": "2.32.0"}},
                                                 self.repository), self.key)

    def test_recorded_announcement_is_not_sent_again(self):
        lookup, gh, request = self.mock_delivery()
        lookup.side_effect = lambda path: {"object": {"sha": COMMIT}}
        self.assertIsNone(self.announce())
        gh.assert_not_called()
        request.assert_not_called()

    def test_unrecorded_message_is_recovered_from_history_without_posting(self):
        _, gh, request = self.mock_delivery()
        existing = {"id": "300", "author": {"id": "bot"}, "timestamp": "2026-10-30T10:01:00Z",
                    "content": discord.render(self.plan, self.addons, self.repository)}
        request.side_effect = [{"type": 5, "guild_id": "100"}, {"id": "bot"}, [existing]]
        self.assertEqual(self.announce(), "https://discord.com/channels/100/200/300")
        self.assertFalse(any(call.args[0] == "POST" for call in request.call_args_list))
        gh.assert_called_once()

    def test_history_is_paginated_and_does_not_match_another_author(self):
        content = discord.render(self.plan, self.addons, self.repository)
        messages = [{"id": str(i), "author": {"id": "someone"}, "content": content,
                     "timestamp": "2026-10-30T10:02:00Z"} for i in range(400, 500)]
        existing = messages[0] | {"id": "300", "author": {"id": "bot"}}
        with patch.object(discord, "request", side_effect=[{"id": "bot"}, messages, [existing]]) as request:
            result = discord.find_message("200", "token", set(discord.release_links(self.plan, self.addons,
                                           self.repository).values()), discord.timestamp(self.release["published_at"]))
        self.assertEqual(result, existing)
        self.assertIn("before=400", request.call_args.args[1])

    def test_discord_failure_never_records_delivery(self):
        _, gh, request = self.mock_delivery()
        request.side_effect = RuntimeError("Discord unavailable")
        with self.assertRaises(RuntimeError):
            self.announce()
        gh.assert_not_called()

    def test_recording_failure_can_retry_and_a_concurrent_marker_is_accepted(self):
        for saved in (False, True):
            with self.subTest(saved=saved):
                lookup, gh, _ = self.mock_delivery()
                gh.side_effect = subprocess.CalledProcessError(1, "gh")
                checks = iter([None, {"object": {"sha": COMMIT}} if saved else None])
                lookup.side_effect = lambda path: next(checks) if path == self.marker else self.lookup(path)
                if saved:
                    self.assertEqual(self.announce(), "https://discord.com/channels/100/200/300")
                else:
                    with self.assertRaises(subprocess.CalledProcessError):
                        self.announce()

    def test_missing_configuration_or_non_server_channel_fails_without_posting(self):
        for settings in ({"token": ""}, {"channel": ""}, {"commit": "short"}):
            with self.subTest(settings=settings):
                _, gh, request = self.mock_delivery()
                with self.assertRaises(ValueError):
                    self.announce(**settings)
                gh.assert_not_called()
                request.assert_not_called()
        _, gh, request = self.mock_delivery()
        request.side_effect = [{"type": 1}]
        with self.assertRaises(ValueError):
            self.announce()
        gh.assert_not_called()


class DiscordHTTPTests(unittest.TestCase):
    def test_bot_authentication_and_payload_encoding(self):
        with patch.object(discord.uploads, "request", return_value={"id": "1"}) as request:
            discord.request("POST", "/channels/200/messages", "test-token", {"content": "Update"})
        method, url, headers, body = request.call_args.args
        self.assertEqual((method, url), ("POST", "https://discord.com/api/v10/channels/200/messages"))
        self.assertEqual(headers["Authorization"], "Bot test-token")
        self.assertEqual(json.loads(body), {"content": "Update"})

    def test_rate_limit_retries_the_same_payload_and_nonce(self):
        error = HTTPError("https://discord.com", 429, "rate limited", {}, io.BytesIO(b'{"retry_after": 0.5}'))
        with patch.object(discord.uploads, "request", side_effect=[error, {"id": "1"}]) as request, \
                patch.object(discord.time, "sleep") as sleep:
            self.assertEqual(discord.request("POST", "/channels/200/messages", "token", {"nonce": "stable"}), {"id": "1"})
        sleep.assert_called_once_with(0.5)
        self.assertEqual(request.call_args_list[0], request.call_args_list[1])

    def test_authentication_errors_do_not_retry_or_expose_response_bodies(self):
        error = HTTPError("https://discord.com", 401, "unauthorized", {}, io.BytesIO(b'sensitive response'))
        with patch.object(discord.uploads, "request", side_effect=error) as request, \
                self.assertRaisesRegex(RuntimeError, r"^Discord returned HTTP 401; rerun the workflow after resolving it$"):
            discord.request("POST", "/channels/200/messages", "token", {"content": "Update"})
        request.assert_called_once()


if __name__ == "__main__":
    unittest.main()
