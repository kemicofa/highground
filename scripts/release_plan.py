"""Plan the whole release batch before any publisher starts.

Uses the shared-files checks and local release/upload tags. Only unpublished
addons enter the matrix; blocked releases or missing announcements fail the
whole plan. Already published versions need no publishing job, while the
workflow can still retry their combined announcement.

  python3 scripts/release_plan.py [--github-output FILE]
"""
import argparse
import json
from pathlib import Path

import addons
import discord_release
import release_check


def plan(found, announcement):
    """Return the publisher matrix after checking every addon's release state."""
    releases, errors = [], []
    for name, addon in found.items():
        verdict = release_check.check(name, found)
        print(verdict.reason)
        if verdict.status == release_check.WAITING:
            errors.append(verdict.reason)
        elif verdict.status == release_check.PUBLISH:
            if announcement["releases"].get(name) != addon.version:
                errors.append(f"Add {name} {addon.version} to docs/discord-release.json before publishing")
            releases.append({"addon": name, "artifact": addon.artifact()})
    if errors:
        raise ValueError("Release batch is not ready:\n" + "\n".join(errors))
    return {"include": releases}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--github-output", type=Path)
    args = parser.parse_args()
    found = addons.load()
    announcement = discord_release.load_plan(addons.ROOT / "docs" / "discord-release.json", found)
    matrix = plan(found, announcement)
    encoded = json.dumps(matrix, separators=(",", ":"))
    print(encoded)
    if args.github_output:
        with args.github_output.open("a", encoding="utf-8") as output:
            output.write(f"publish={'true' if matrix['include'] else 'false'}\nmatrix={encoded}\n")


if __name__ == "__main__":
    main()
