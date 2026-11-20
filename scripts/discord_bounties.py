"""Create Highground's ruleset bounty boards and proof channels, without duplicates.

Preview: python3 scripts/discord_bounties.py
Apply:   python3 scripts/discord_bounties.py --apply --env-file PATH
The token is read locally and is never written to the repository or printed.
"""
import argparse
import json
import os
from pathlib import Path
import shlex

from discord_release import request

GUILD = "1565497559231893608"
BOT = "1565498238906146868"
RULESETS = ("PvE", "PvP", "RP", "RP-PvP")
DESTINATION = Path(__file__).resolve().parents[1] / "docs/discord-bounties.json"


def template(rule, proof=False):
    if proof:
        return f"""**{rule} — global bounty proof template**
Post proof for a globally shared bounty here. Keep private and guild bounties in their own audience; do not post them on this server.

1. Link the original global bounty post and identify the contribution/poster.
2. Attach the screenshot from WoW's Screenshots folder. The wanted poster's checkmark means WoW confirmed that screenshot was saved; it does not verify the kill.
3. For a preferred finish (fall damage, drowning, Mind Control, etc.), include a clip showing the setup and death. A corpse screenshot alone cannot prove the method or killing blow.
4. Use a separate timestamp and proof for each kill. In-game honor credit can include assists. The poster reviews each claim and records approval/payment in Highground.

Copy and fill in:
```
Original global bounty post:
Contribution ID / poster:
Target (full character name):
Hunter (full character name):
Game / region / realm / faction:
Ruleset: {rule}
Kill number (e.g. 2 of 5):
Kill date/time + timezone / location:
Evidence (killing blow, honor credit, or manual report):
Preferred finish and clip timestamp, if applicable:
Gold per approved kill / separately agreed bonus:
Screenshot / video attachment:
```
Gold is paid by players through the game. Posting proof does not guarantee payment. Do not reuse one death for multiple kill slots on the same contribution."""
    return f"""**{rule} — globally shared bounty board**
Use this channel only for **GLOBAL** bounties. Private and guild exports must stay with their intended audience.

Create a Shared bounty in Highground, then choose **Post global bounty** and copy its **HGB2-GLOBAL** import code. Paste that code below so hunters can import it even while you are offline. Hunters: open the bounty board → More tools → Import bounty, paste the code, review the target, audience, expiry and terms, then import.

Copy and fill in:
```
Target (full character name):
Poster (character name):
Game / region / realm / faction:
Ruleset: {rule}
Gold per approved kill:
Requested kills / maximum total gold:
Preferred finishes (optional; any selected method):
Separately agreed bonus, if any:
Expiry (date/time + timezone):
GLOBAL import code:
```
Attach the import code as text if Discord's message limit is reached. Link proof submissions back to this post. When the bounty is filled, withdrawn or changed, edit your post and replace any outdated code.

An offline import is the poster's stated offer, not verified funding or proof of identity. Claims need the poster's review; reconnect within the 15-minute claim window to deliver a new in-game report. Highground never holds or transfers gold."""


def token_from(path):
    if path is None:
        return os.environ.get("DISCORD_BOT_TOKEN", "")
    values = {}
    for line in path.read_text().splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            key, value = line.removeprefix("export ").split("=", 1)
            parts = shlex.split(value)
            values[key.strip()] = parts[0] if parts else ""
    return values.get("DISCORD_BOT_TOKEN", "")


def apply(token):
    me = request("GET", "/users/@me", token)
    guild = request("GET", f"/guilds/{GUILD}", token)
    if me["id"] != BOT or not me.get("bot") or guild["name"] != "Highground":
        raise ValueError("Expected Highground Steward in the Highground server")
    channels = request("GET", f"/guilds/{GUILD}/channels", token)
    # View, send, attach evidence, read history and use public discussion threads.
    allow = sum(1 << bit for bit in (10, 11, 14, 15, 16, 35, 38))
    permissions = [{"id": GUILD, "type": 0, "allow": str(allow), "deny": "0"}]

    def ensure(name, kind, parent=None, topic=None):
        matches = [c for c in channels if c["name"] == name and c["type"] == kind
                   and c.get("parent_id") == parent]
        if len(matches) > 1:
            raise ValueError(f"Duplicate {name} channels; select the intended one before applying")
        if matches:
            return matches[0]
        body = {"name": name, "type": kind, "permission_overwrites": permissions}
        if parent:
            body.update(parent_id=parent, topic=topic, rate_limit_per_user=10)
        result = request("POST", f"/guilds/{GUILD}/channels", token, body)
        channels.append(result)
        return result

    category = ensure("BOUNTIES", 4)
    previous = json.loads(DESTINATION.read_text()) if DESTINATION.exists() else {}
    result = {"guild_id": GUILD, "category_id": category["id"], "rulesets": previous.get("rulesets", {}).copy()}
    for rule in RULESETS:
        links = {}
        for proof in (False, True):
            key = "proof" if proof else "board"
            name = ("bounty-proofs-" if proof else "bounties-") + rule.lower()
            channel = ensure(name, 0, category["id"],
                             f"{rule} global bounties {'proofs' if proof else 'and offline import codes'}. Use the pinned template. No private or guild bounties.")
            channel_id = channel["id"]
            content = template(rule, proof)
            assert len(content) <= 2000
            message_id = previous.get("rulesets", {}).get(rule, {}).get(key + "_template")
            messages = request("GET", f"/channels/{channel_id}/messages?limit=100", token)
            message = next((m for m in messages if m["author"]["id"] == BOT
                            and (m["id"] == message_id or m["content"].startswith(content.splitlines()[0]))), None)
            if message is None and message_id:
                message = request("GET", f"/channels/{channel_id}/messages/{message_id}", token)
                if message["author"]["id"] != BOT:
                    raise ValueError("The stored template does not belong to Highground Steward")
            if message is None:
                message = request("POST", f"/channels/{channel_id}/messages", token,
                                  {"content": content, "allowed_mentions": {"parse": []}, "flags": 4})
            elif message["content"] != content:
                message = request("PATCH", f"/channels/{channel_id}/messages/{message['id']}", token,
                                  {"content": content, "allowed_mentions": {"parse": []}})
            if not message.get("pinned"):
                request("PUT", f"/channels/{channel_id}/messages/pins/{message['id']}", token)
            verified = request("GET", f"/channels/{channel_id}/messages/{message['id']}", token)
            if not verified.get("pinned") or verified["content"] != content:
                raise RuntimeError(f"Template verification failed for {name}")
            links[key], links[key + "_template"] = channel_id, message["id"]
            print(f"Ready: https://discord.com/channels/{GUILD}/{channel_id}")
        result["rulesets"][rule] = links
        DESTINATION.write_text(json.dumps(result, indent=2) + "\n")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--env-file", type=Path)
    args = parser.parse_args()
    if args.apply:
        token = token_from(args.env_file)
        if not token:
            raise ValueError("A DISCORD_BOT_TOKEN is required")
        apply(token)
    else:
        for rule in RULESETS:
            for proof in (False, True):
                body = template(rule, proof)
                assert len(body) <= 2000
                print(body + "\n")


if __name__ == "__main__":
    main()
