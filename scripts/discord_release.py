"""Post the reviewed release announcement after every listed addon is published.

Each addon's CI calls this last. Upload tags gate delivery; a discord-<digest>
tag records it. Discord history and an enforced nonce recover interrupted or
concurrent attempts without repeating the message.

  python3 scripts/discord_release.py --repository OWNER/REPO --check
  python3 scripts/discord_release.py --repository OWNER/REPO --commit SHA
"""
import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
import urllib.error

import addons
import publish
import uploads

PLAN = addons.ROOT / "docs" / "discord-release.json"
API = "https://discord.com/api/v10"
MAX_CONTENT = 2000


def load_plan(path, found):
    """Validate reviewed wording and bind it to the exact addon versions."""
    plan = json.loads(Path(path).read_text(encoding="utf-8"))
    if not isinstance(plan, dict) or set(plan) != {"releases", "changes", "notice"}:
        raise ValueError("Discord plan needs releases, changes and notice")
    releases, changes, notice = plan["releases"], plan["changes"], plan["notice"]
    if not isinstance(releases, dict) or not isinstance(changes, list) or not isinstance(notice, str):
        raise ValueError("Discord plan needs a release map, a list of changes and a text notice")
    if not releases:
        if changes or notice:
            raise ValueError("Discord wording needs at least one release")
        return plan
    for name, version in releases.items():
        if name not in found or version != found[name].version:
            raise ValueError(f"Discord release {name} {version} must match a public addon's TOCs")
    if not 1 <= len(changes) <= 5:
        raise ValueError("Discord announcement needs 1 to 5 short changes")
    for line in changes:
        if not isinstance(line, str) or not line.strip() or len(line) > 240 or "\n" in line or "\r" in line:
            raise ValueError("Each Discord change must be one line of 1 to 240 characters")
    if len(notice) > 300 or "\n" in notice or "\r" in notice:
        raise ValueError("Discord notice must be one line of at most 300 characters")
    return plan


def release_links(plan, found, repository):
    return {name: f"https://github.com/{repository}/releases/tag/{found[name].tag(version)}"
            for name, version in sorted(plan["releases"].items())}


def render(plan, found, repository):
    """One short message, with generated version labels and verified release destinations."""
    if not re.fullmatch(r"[\w.-]+/[\w.-]+", repository):
        raise ValueError("Expected repository OWNER/REPO")
    if not plan["releases"]:
        return ""
    lines = ["**Highground update**", "", *(f"- {line.strip()}" for line in plan["changes"])]
    if plan["notice"].strip():
        lines.extend(["", plan["notice"].strip()])
    lines.extend(["", "Downloads and full notes:"])
    for name, url in release_links(plan, found, repository).items():
        lines.append(f"[{found[name].title} {plan['releases'][name]}](<{url}>)")
    content = "\n".join(lines)
    if len(content) > MAX_CONTENT:
        raise ValueError(f"Discord announcement is {len(content)} characters; shorten it to {MAX_CONTENT}")
    return content


def delivery_key(plan, repository):
    identity = json.dumps([repository, plan["releases"]], sort_keys=True)
    return hashlib.sha256(identity.encode()).hexdigest()[:24]


def published_releases(plan, found, repository):
    """Return releases only once GitHub and all configured uploads have finished."""
    releases, waiting = [], []
    for name, version in sorted(plan["releases"].items()):
        addon = found[name]
        release = publish.lookup(f"repos/{repository}/releases/tags/{addon.tag(version)}")
        if not release or release["draft"]:
            waiting.append(addon.tag(version))
        else:
            releases.append(release)
        tags = []
        if addon.project:
            tags.append(addon.curseforge_tag(version))
        if addon.wago:
            tags.append(addon.wago_tag(version))
        for tag in tags:
            if not publish.lookup(f"repos/{repository}/git/ref/tags/{tag}"):
                waiting.append(tag)
    if waiting:
        print("Discord announcement waits for: " + ", ".join(waiting))
        return None
    return releases


def request(method, path, token, payload=None):
    headers = {"Authorization": f"Bot {token}", "Content-Type": "application/json",
               "User-Agent": "DiscordBot (https://github.com/kemicofa/highground, 1.0)"}
    body = json.dumps(payload).encode() if payload is not None else None
    for attempt in range(3):
        try:
            return uploads.request(method, API + path, headers, body)
        except urllib.error.HTTPError as error:
            with error:
                if error.code == 429 and attempt < 2:
                    delay = float(json.loads(error.read()).get("retry_after", 1))
                    if 0 <= delay <= 30:
                        time.sleep(delay)
                        continue
            # Do not echo credentials or response bodies into CI logs.
            raise RuntimeError(f"Discord returned HTTP {error.code}; rerun the workflow after resolving it") from None


def timestamp(value):
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def find_message(channel, token, links, since):
    """Recover a sent message if the workflow stopped before recording its tag."""
    bot_id = request("GET", "/users/@me", token)["id"]
    before = ""
    while True:
        messages = request("GET", f"/channels/{channel}/messages?limit=100{before}", token)
        if not messages:
            return None
        for message in messages:
            urls = set(re.findall(r"https://github\.com/[^\s<>)]*/releases/tag/[^\s<>)]*",
                                  message.get("content", "")))
            if message["author"]["id"] == bot_id and urls == links:
                return message
        oldest = min(messages, key=lambda message: int(message["id"]))
        if timestamp(oldest["timestamp"]) < since or len(messages) < 100:
            return None
        before = "&before=" + oldest["id"]


def announce(plan, found, repository, commit, token, channel):
    content = render(plan, found, repository)
    if not content:
        print("No Discord announcement prepared; no release scheduled")
        return None
    if not re.fullmatch(r"[0-9a-f]{40}", commit or ""):
        raise ValueError("Discord delivery needs the full workflow commit SHA")
    key = delivery_key(plan, repository)
    tag = "discord-" + key
    marker = f"repos/{repository}/git/ref/tags/{tag}"
    if publish.lookup(marker):
        print(f"Discord announcement already delivered ({tag})")
        return None
    releases = published_releases(plan, found, repository)
    if releases is None:
        return None
    if not token or not re.fullmatch(r"[0-9]+", channel):
        raise ValueError("Set DISCORD_BOT_TOKEN and DISCORD_ANNOUNCEMENTS_CHANNEL_ID in GitHub")
    destination = request("GET", f"/channels/{channel}", token)
    if destination["type"] not in (0, 5) or not destination.get("guild_id"):
        raise ValueError("Discord destination must be a server text or announcement channel")
    links = set(release_links(plan, found, repository).values())
    since = min(timestamp(release["published_at"]) for release in releases)
    message = find_message(channel, token, links, since)
    if message is None:
        message = request("POST", f"/channels/{channel}/messages", token,
                          {"content": content, "allowed_mentions": {"parse": []},
                           "flags": 4, "nonce": key, "enforce_nonce": True})
    url = f"https://discord.com/channels/{destination['guild_id']}/{channel}/{message['id']}"
    try:
        publish.gh("api", f"repos/{repository}/git/refs", "-f", f"ref=refs/tags/{tag}", "-f", f"sha={commit}")
    except subprocess.CalledProcessError:
        # Another addon's finishing workflow may have recorded this same delivery.
        if not publish.lookup(marker):
            raise
    print(f"Discord announcement: {url}")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with Path(os.environ["GITHUB_STEP_SUMMARY"]).open("a", encoding="utf-8") as summary:
            summary.write(f"\n[Discord announcement]({url})\n\n{content}\n")
    return url


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--commit", default=os.environ.get("GITHUB_SHA"))
    parser.add_argument("--plan", type=Path, default=PLAN)
    parser.add_argument("--check", action="store_true", help="validate and preview without network requests")
    parser.add_argument("--require-addon", help="require this addon in the announcement before publishing it")
    args = parser.parse_args()
    found = addons.load()
    plan = load_plan(args.plan, found)
    if args.require_addon and args.require_addon not in plan["releases"]:
        raise ValueError(f"Add {args.require_addon} to docs/discord-release.json before publishing")
    if args.check:
        print(render(plan, found, args.repository) or "No Discord announcement prepared; no release scheduled")
    else:
        announce(plan, found, args.repository, args.commit, os.environ.get("DISCORD_BOT_TOKEN", ""),
                 os.environ.get("DISCORD_ANNOUNCEMENTS_CHANNEL_ID", ""))


if __name__ == "__main__":
    main()
