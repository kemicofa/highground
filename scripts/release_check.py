"""May this addon publish its current version? Shared files keep the addons in step.

Highground Macros ships files from Highground's folder (shared/ -> ../Highground):
the macro tools, the UI kit, themes and utilities. When any shared file changed
since an addon's last release, releasing the other addon needs a new version of
that one too, so both ship the same code. Changes only one addon packages need
only that addon's release.

  python3 scripts/release_check.py ADDON [--github-output FILE]
Prints the verdict; writes publish=true|false to FILE. Exit 0 either way.
"""
import argparse
from pathlib import Path
import re
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build  # noqa: E402

ROOT = build.ROOT


def tag_prefix(addon):
    return "v" if addon == build.RELEASED else f"{addon}-v"


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True, text=True).stdout


def last_tag(addon):
    """Newest published tag of this addon, or None."""
    prefix = tag_prefix(addon)
    tags = [t for t in git("tag", "--list", f"{prefix}*").split() if re.fullmatch(re.escape(prefix) + build.VERSION, t)]
    tags.sort(key=lambda t: [int(n) for n in t[len(prefix):].split(".")])
    return tags[-1] if tags else None


def published(addon, version):
    return bool(git("tag", "--list", f"{tag_prefix(addon)}{version}").strip())


def sources(addon_dir):
    """Repository paths of the files an addon's package holds (links resolved)."""
    return {(addon_dir / rel).resolve().relative_to(ROOT.resolve()).as_posix() for rel in build.package_files(addon_dir)}


def changed_since(tag, paths):
    if not paths:
        return []
    if not tag:
        return sorted(paths)
    return [p for p in git("diff", "--name-only", tag, "HEAD", "--", *sorted(paths)).split() if p in paths]


def decide(addon, versions, unpublished, shared_changed):
    """Pure verdict. versions: {addon: version}; unpublished: {addon: bool};
    shared_changed: {addon: [shared files changed since that addon's last tag]}.
    Returns (publish, reason)."""
    if not unpublished[addon]:
        return False, f"{addon} {versions[addon]} is already published"
    waiting = [other for other in versions
               if other != addon and shared_changed.get(other) and not unpublished[other]]
    if waiting:
        names = ", ".join(waiting)
        files = sorted({f for o in waiting for f in shared_changed[o]})
        more = f" (and {len(files) - 3} more)" if len(files) > 3 else ""
        return False, (f"{addon} {versions[addon]} waits for {names}: shared files changed since {names}'s last "
                       f"release ({', '.join(files[:3])}{more}). Bump {names} too so both ship the same code.")
    return True, f"{addon} {versions[addon]} can be published"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("addon")
    parser.add_argument("--github-output", type=Path)
    args = parser.parse_args()
    found = build.addons()
    src = {name: sources(d) for name, d in found.items()}
    versions = {name: build.release_info(d)[0] for name, d in found.items()}
    unpublished = {name: not published(name, v) for name, v in versions.items()}
    shared = set.intersection(*src.values()) if len(src) > 1 else set()
    shared_changed = {name: changed_since(last_tag(name), shared) for name in found}
    ok, reason = decide(args.addon, versions, unpublished, shared_changed)
    waiting = not ok and "waits for" in reason
    print(("::warning::" if waiting else "::notice::") + reason)
    if args.github_output:
        with args.github_output.open("a", encoding="utf-8") as out:
            out.write(f"publish={'true' if ok else 'false'}\n")


if __name__ == "__main__":
    main()
