"""Ruleset provisioning stays repeatable and posts only the requested templates."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import support  # Adds scripts to sys.path.
import discord_bounties as bounty


class BountyDiscordTests(unittest.TestCase):
    def test_templates_fit_discord_and_explain_audiences_and_proof(self):
        for rule in bounty.RULESETS:
            for proof in (False, True):
                text = bounty.template(rule, proof)
                self.assertLessEqual(len(text), 2000)
                self.assertIn(rule, text)
                self.assertIn("private and guild", text.lower())
                self.assertNotIn("@everyone", text)
                self.assertIn("screenshot", text.lower()) if proof else self.assertIn("HGB2-GLOBAL", text)

    def test_reapplying_does_not_duplicate_channels_or_old_pinned_templates(self):
        channels, messages, writes = [], {}, []
        sequence = 100

        def api(method, route, token, payload=None):
            nonlocal sequence
            self.assertEqual(token, "test-token")
            if method != "GET":
                writes.append((method, route))
            if route == "/users/@me":
                return {"id": bounty.BOT, "bot": True}
            if route == f"/guilds/{bounty.GUILD}":
                return {"name": "Highground"}
            if route == f"/guilds/{bounty.GUILD}/channels":
                if method == "GET":
                    return copy.deepcopy(channels)
                sequence += 1
                channel = dict(payload, id=str(sequence))
                channels.append(channel)
                return copy.deepcopy(channel)
            parts = route.split("/")
            channel = parts[2]
            if method == "GET" and "?limit=" in route:
                return []  # The original template is now older than the last 100 messages.
            if method == "POST":
                self.assertEqual(payload["allowed_mentions"], {"parse": []})
                sequence += 1
                msg = dict(payload, id=str(sequence), author={"id": bounty.BOT}, pinned=False)
                messages[(channel, msg["id"])] = msg
                return copy.deepcopy(msg)
            if method == "PUT":
                messages[(channel, parts[-1])]["pinned"] = True
                return None
            if method == "GET":
                return copy.deepcopy(messages[(channel, parts[-1])])
            self.fail(f"Unexpected mutation: {method} {route}")

        with tempfile.TemporaryDirectory() as temporary, patch.object(bounty, "request", side_effect=api):
            destination = Path(temporary) / "channels.json"
            with patch.object(bounty, "DESTINATION", destination), patch("builtins.print"):
                first = bounty.apply("test-token")
                self.assertEqual(len(channels), 9)
                self.assertEqual(len(messages), 8)
                self.assertEqual(set(first["rulesets"]), set(bounty.RULESETS))
                self.assertTrue(all(message["pinned"] for message in messages.values()))
                before = len(writes)
                second = bounty.apply("test-token")
                self.assertEqual(first, second)
                self.assertEqual(len(writes), before, "repeat is entirely read-only")
                self.assertEqual(json.loads(destination.read_text()), first)


if __name__ == "__main__":
    unittest.main()
