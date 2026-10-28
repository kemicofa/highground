"""May this addon publish its current version? Shared files keep the addons in step.

Every addon embeds the HighgroundKit library (libs/), and Highground imports
each standalone addon's src/ (features/<name>/). For each other addon, the
files both packages hold are shared. When a shared file changed since the other
addon's last release, this addon waits until the other one has a new version
too, so both ship the same code. Changes only one addon packages need only that
addon's release.

  python3 scripts/release_check.py ADDON [--github-output FILE]
Prints the verdict; writes publish=true|false and status=STATUS to FILE. Exit 0
either way. An unlisted addon (no project anywhere) never publishes and never
holds the others back: it has no release to keep in step.
"""
import argparse
from collections import namedtuple
from pathlib import Path
import re
import subprocess

import addons
import build

PUBLISH, WAITING, PUBLISHED, UNLISTED = "publish", "waiting", "published", "unlisted"  # verdict statuses
Verdict = namedtuple("Verdict", "status reason")


def git(*args):
    return subprocess.run(["git", *args], cwd=addons.ROOT, check=True, capture_output=True, text=True).stdout


def last_tag(addon):
    """Newest published tag of this addon, or None."""
    prefix = addon.tag_prefix
    tags = [t for t in git("tag", "--list", f"{prefix}*").split()
            if re.fullmatch(re.escape(prefix) + addons.VERSION, t)]
    tags.sort(key=lambda t: [int(n) for n in t[len(prefix):].split(".")])
    return tags[-1] if tags else None


def published(addon, version):
    """Every place the addon goes has its tag: GitHub release, CurseForge, Wago."""
    tags = set()
    if addon.github_release:
        tags.add(addon.tag(version))
    if addon.project:
        tags.add(addon.curseforge_tag(version))
    if addon.wago:
        tags.add(addon.wago_tag(version))
    return bool(tags) and all(git("tag", "--list", t).strip() for t in tags)


def sources(addon):
    """Repository paths of the files an addon's package holds (links resolved)."""
    root = addon.path.parent.parent.resolve()
    return {(addon.path / rel).resolve().relative_to(root).as_posix() for rel in build.package_files(addon)}


def changed_since(tag, paths):
    if not paths:
        return []
    if not tag:
        return sorted(paths)
    return [p for p in git("diff", "--name-only", tag, "HEAD", "--", *sorted(paths)).split() if p in paths]


def decide(addon, versions, unpublished, shared_changed):
    """Pure verdict for addon.

    versions: {addon: version}; unpublished: {addon: bool}; shared_changed:
    {other addon: files it shares with addon that changed since its last tag}.
    """
    if not unpublished[addon]:
        return Verdict(PUBLISHED, f"{addon} {versions[addon]} is already published")
    waiting = [other for other in versions
               if other != addon and shared_changed.get(other) and not unpublished[other]]
    if waiting:
        names = ", ".join(waiting)
        files = sorted({f for o in waiting for f in shared_changed[o]})
        more = f" (and {len(files) - 3} more)" if len(files) > 3 else ""
        return Verdict(WAITING, f"{addon} {versions[addon]} waits for {names}: shared files changed since "
                                f"{names}'s last release ({', '.join(files[:3])}{more}). "
                                f"Bump {names} too so both ship the same code.")
    return Verdict(PUBLISH, f"{addon} {versions[addon]} can be published")


def check(name, found):
    """Verdict for addon name among found ({name: Addon}), from the git tags and history."""
    if not found[name].listed:
        return Verdict(UNLISTED, f"{name} {found[name].version} has no CurseForge or Wago project yet; "
                                 "add ## X-Curse-Project-ID or ## X-Wago-ID to its TOCs to publish it")
    versions = {n: a.version for n, a in found.items()}
    unpublished = {n: not published(a, versions[n]) for n, a in found.items()}
    mine = sources(found[name])
    shared_changed = {other: changed_since(last_tag(a), mine & sources(a))
                      for other, a in found.items() if other != name}
    return decide(name, versions, unpublished, shared_changed)


def main():
    found = addons.load()
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("addon", choices=found)
    parser.add_argument("--github-output", type=Path)
    args = parser.parse_args()
    verdict = check(args.addon, found)
    print(("::warning::" if verdict.status == WAITING else "::notice::") + verdict.reason)
    if args.github_output:
        with args.github_output.open("a", encoding="utf-8") as out:
            out.write(f"publish={'true' if verdict.status == PUBLISH else 'false'}\nstatus={verdict.status}\n")


if __name__ == "__main__":
    main()
