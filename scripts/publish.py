"""Publish an addon's tested build; never overwrite a published version or move its tag.

Each place a version goes is done once and recorded (scripts/addons.py):
- a GitHub release vX.Y.Z for the addon with "## X-GitHub-Release: true"
  (Highground), as a draft until its files are uploaded;
- the CurseForge project in its TOCs ("## X-Curse-Project-ID"), through the
  upload API, then a tag (needs CURSEFORGE_TOKEN; skipped without it);
- the Wago project ("## X-Wago-ID"), then a tag (needs WAGO_API_KEY; skipped
  without it).
An unlisted addon (none of these) is not published.

  python3 scripts/publish.py ADDON --repository OWNER/REPO --commit SHA [--dist DIR]
The version is the one in the addon's TOCs; DIR defaults to dist/<Addon>.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

import addons
import curseforge
import wago


def gh(*args):
    return subprocess.run(["gh", *args], check=True, capture_output=True, text=True).stdout


def lookup(path):
    """GET a GitHub API path; None when it does not exist (HTTP 404)."""
    try:
        return json.loads(gh("api", path))
    except subprocess.CalledProcessError as error:
        if "(HTTP 404)" in error.stderr:
            return None
        raise


def check(addon, version, commit, directory):
    """Validate the build in directory; returns (archive, checksums, notes) paths."""
    if not re.fullmatch(addons.VERSION, version):
        raise ValueError("Expected a major.minor.patch version")
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("Release target must be the full tested commit SHA")
    archive = directory / addon.zip_name(version)
    checksums = directory / "SHA256SUMS"
    notes = directory / "RELEASE_NOTES.md"
    expected = f"{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n"
    if checksums.read_text() != expected or not notes.read_text().strip():
        raise ValueError("Release artifacts or notes failed validation")
    return archive, checksums, notes


def publish_curseforge(addon, repository, version, commit, directory, token):
    """Upload to CurseForge once per version; its CurseForge tag records it."""
    archive, _, notes = check(addon, version, commit, directory)
    if not addon.project:
        raise ValueError(f"{addon.name}: its TOCs need ## X-Curse-Project-ID")
    tag = addon.curseforge_tag(version)
    if lookup(f"repos/{repository}/git/ref/tags/{tag}"):
        print(f"{tag} already published; leaving unchanged")
        return
    title = f"{addon.title} {version}"
    ids = curseforge.game_version_ids(token, addon.game_versions)
    file_id = curseforge.upload(addon.project, token, archive, notes.read_text(), title, ids)
    print(f"Uploaded {title} to CurseForge project {addon.project}: file {file_id}")
    gh("api", f"repos/{repository}/git/refs", "-f", f"ref=refs/tags/{tag}", "-f", f"sha={commit}")


def publish_release(addon, repository, version, commit, directory):
    """Create the GitHub release vX.Y.Z at commit, as a draft until its files are uploaded."""
    archive, checksums, notes = check(addon, version, commit, directory)
    tag = addon.tag(version)
    title = f"{addon.title} {version}"

    release = lookup(f"repos/{repository}/releases/tags/{tag}")
    if release and not release["draft"]:
        print(f"Already published; leaving unchanged: {release['html_url']}")
        return
    if release and release["target_commitish"] != commit:
        raise ValueError("Existing draft belongs to a different commit; resolve it before retrying")
    ref = lookup(f"repos/{repository}/git/ref/tags/{tag}")
    if ref:
        tagged = lookup(f"repos/{repository}/commits/{tag}")
        if not tagged or tagged["sha"] != commit:
            raise ValueError("Existing tag points to another commit; bump the version instead")

    common = ("--repo", repository)
    if not release:
        gh("release", "create", tag, *common, "--draft", "--target", commit,
           "--title", title, "--notes-file", str(notes))
    # Drafts can be resumed after an interrupted upload. Publication is last.
    gh("release", "upload", tag, str(archive), str(checksums), *common, "--clobber")
    gh("release", "edit", tag, *common, "--draft=false", "--title", title,
       "--notes-file", str(notes))
    print(gh("release", "view", tag, *common, "--json", "url", "--jq", ".url").strip())


def publish_wago(addon, repository, version, commit, directory, token):
    """Upload to Wago once per version; the wago-<tag> tag records it."""
    archive, _, notes = check(addon, version, commit, directory)
    tag = addon.wago_tag(version)
    if lookup(f"repos/{repository}/git/ref/tags/{tag}"):
        print(f"{tag} already published; leaving unchanged")
        return
    wago.upload(addon.wago, token, archive, notes.read_text(), version, addon.game_versions)
    print(f"Uploaded {addon.title} {version} to Wago project {addon.wago}")
    gh("api", f"repos/{repository}/git/refs", "-f", f"ref=refs/tags/{tag}", "-f", f"sha={commit}")


def publish(addon, repository, commit, directory, token="", wago_token=""):
    """Publish the addon's TOC version everywhere its TOCs say: GitHub release, CurseForge, Wago."""
    if not addon.listed:
        print(f"{addon.name}: no CurseForge or Wago project yet; not publishing")
        return
    if addon.github_release:
        publish_release(addon, repository, addon.version, commit, directory)
    if addon.project and token:
        publish_curseforge(addon, repository, addon.version, commit, directory, token)
    elif addon.project:
        print(f"{addon.name}: no CURSEFORGE_TOKEN secret; not uploading to CurseForge")
    if addon.wago and wago_token:
        publish_wago(addon, repository, addon.version, commit, directory, wago_token)
    elif addon.wago:
        print(f"{addon.name}: no WAGO_API_KEY secret; not uploading to Wago")


def main():
    found = addons.load()
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("addon", choices=found)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--dist", type=Path, help="the tested build (default: dist/<Addon>)")
    args = parser.parse_args()
    addon = found[args.addon]
    publish(addon, args.repository, args.commit, args.dist or addon.dist(addons.ROOT / "dist"),
            os.environ.get("CURSEFORGE_TOKEN", ""), os.environ.get("WAGO_API_KEY", ""))


if __name__ == "__main__":
    main()
