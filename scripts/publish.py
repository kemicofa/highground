"""Publish an addon's tested build; never overwrite a published version or move its tag.

Each place a version goes is done once and recorded (scripts/addons.py):
- its GitHub release (<Addon>-vX.Y.Z; Highground: vX.Y.Z, the "Latest"
  release unless it is a beta or alpha, which are prereleases), as a draft
  until its files are uploaded;
- the CurseForge project in its TOCs ("## X-Curse-Project-ID"), through the
  upload API, then a tag (needs CURSEFORGE_TOKEN; skipped without it);
- the Wago project ("## X-Wago-ID"), then a tag (needs WAGO_API_KEY; skipped
  without it).
Uploads follow the GitHub release and only from its commit. A <tag>-pending tag
marks an upload in progress, so an upload whose tag was not created is never
sent again without a check.

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
import urllib.error

import addons
import build
import curseforge
import wago


class CommandError(subprocess.CalledProcessError):
    """A failed command whose message includes its error output."""

    def __str__(self):
        output = (self.stderr or "").strip()
        return f"{super().__str__()}\n{output}" if output else super().__str__()


def gh(*args):
    # gh reads its token from the environment; its arguments and errors don't contain it.
    result = subprocess.run(["gh", *args], capture_output=True, text=True)
    if result.returncode:
        raise CommandError(result.returncode, result.args, result.stdout, result.stderr)
    return result.stdout


def lookup(path):
    """GET a GitHub API path; None when it does not exist (HTTP 404)."""
    try:
        return json.loads(gh("api", path))
    except subprocess.CalledProcessError as error:
        if "(HTTP 404)" in error.stderr:
            return None
        raise


def find_release(repository, tag):
    """The release (draft or published) for tag, or None.

    GitHub's "Get a release by tag name" only finds published releases, so drafts
    come from the release list.
    """
    pages = json.loads(gh("api", "--paginate", "--slurp", f"repos/{repository}/releases?per_page=100"))
    found = [release for page in pages for release in page if release["tag_name"] == tag]
    if len(found) > 1:
        raise ValueError(f"Several releases use {tag}; delete the extra drafts before retrying")
    return found[0] if found else None


def create_tag(repository, tag, commit):
    gh("api", f"repos/{repository}/git/refs", "-f", f"ref=refs/tags/{tag}", "-f", f"sha={commit}")


def delete_tag(repository, tag):
    gh("api", "-X", "DELETE", f"repos/{repository}/git/refs/tags/{tag}")


def upload_once(repository, tag, commit, upload):
    """Call upload() unless tag records it, then create tag at commit.

    <tag>-pending exists while the outcome is unknown. It stays when the upload
    may have arrived but tag was not created; a retry then stops for a check.
    """
    if lookup(f"repos/{repository}/git/ref/tags/{tag}"):
        print(f"{tag} already published; leaving unchanged")
        return
    pending = f"{tag}-pending"
    if lookup(f"repos/{repository}/git/ref/tags/{pending}"):
        raise ValueError(f"An earlier upload may have finished without its {tag} tag. If the site has this "
                         f"version, create {tag} at {commit}. Then delete {pending} and retry.")
    create_tag(repository, pending, commit)
    try:
        upload()
    except (urllib.error.URLError, ValueError):
        # Nothing was uploaded: a check failed, the site refused it (HTTPError) or never got
        # the whole request. A connection lost while awaiting the reply keeps the pending tag.
        delete_tag(repository, pending)
        raise
    create_tag(repository, tag, commit)
    delete_tag(repository, pending)


def check(addon, version, commit, directory):
    """Validate the build in directory; returns (archive, checksums, notes) paths."""
    if addon.deprecated:
        raise ValueError(f"{addon.name} is deprecated; publish Highground instead")
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
    build.validate_archive(addon, archive)
    return archive, checksums, notes


def title(addon, version):
    """The release name: "Highground 3.3.0", or "Highground 3.3.0 alpha" for a beta or alpha."""
    return f"{addon.title} {version}" + (f" {addon.release_type}" if addon.prerelease else "")


def publish_curseforge(addon, repository, version, commit, directory, token):
    """Upload to CurseForge once per version; its CurseForge tag records it."""
    archive, _, notes = check(addon, version, commit, directory)
    if not addon.project:
        raise ValueError(f"{addon.name}: its TOCs need ## X-Curse-Project-ID")
    name = title(addon, version)

    def upload():
        ids = curseforge.game_version_ids(token, addon.game_versions)
        file_id = curseforge.upload(addon.project, token, archive, notes.read_text(), name, ids,
                                    release_type=addon.release_type)
        print(f"Uploaded {name} to CurseForge project {addon.project} as {addon.release_type}: file {file_id}")

    upload_once(repository, addon.curseforge_tag(version), commit, upload)


def publish_release(addon, repository, version, commit, directory):
    """Create the addon's GitHub release at commit, as a draft until its files are uploaded.

    Only the latest addon (Highground) becomes the repository's "Latest" release,
    and never with a beta or alpha: those are prereleases.
    """
    archive, checksums, notes = check(addon, version, commit, directory)
    tag = addon.tag(version)
    name = title(addon, version)
    latest = addon.latest and not addon.prerelease

    release = find_release(repository, tag)
    published = bool(release) and not release["draft"]
    if release and not published and release["target_commitish"] != commit:
        raise ValueError("Existing draft belongs to a different commit; resolve it before retrying")
    # CurseForge and Wago upload this build next, so a published release must be from this commit too.
    if published or lookup(f"repos/{repository}/git/ref/tags/{tag}"):
        tagged = lookup(f"repos/{repository}/commits/{tag}")
        if not tagged or tagged["sha"] != commit:
            raise ValueError(f"{tag} points to another commit, not {commit}; bump the version, or retry "
                             "the workflow run of the commit it was released from")
    if published:
        print(f"Already published; leaving unchanged: {release['html_url']}")
        return

    common = ("--repo", repository)
    kind = ("--prerelease",) if addon.prerelease else ()
    if not release:
        gh("release", "create", tag, *common, "--draft", "--target", commit, "--title", name,
           "--notes-file", str(notes), "--latest" if latest else "--latest=false", *kind)
    # Drafts can be resumed after an interrupted upload. Publication is last.
    gh("release", "upload", tag, str(archive), str(checksums), *common, "--clobber")
    gh("release", "edit", tag, *common, "--draft=false", "--title", name,
       "--notes-file", str(notes), *(["--latest"] if latest else []), *kind)
    print(gh("release", "view", tag, *common, "--json", "url", "--jq", ".url").strip())


def publish_wago(addon, repository, version, commit, directory, token):
    """Upload to Wago once per version; the wago-<tag> tag records it."""
    archive, _, notes = check(addon, version, commit, directory)

    stability = "stable" if addon.release_type == "release" else addon.release_type

    def upload():
        wago.upload(addon.wago, token, archive, notes.read_text(), version, addon.game_versions,
                    stability=stability)
        print(f"Uploaded {addon.title} {version} to Wago project {addon.wago} as {stability}")

    upload_once(repository, addon.wago_tag(version), commit, upload)


def publish(addon, repository, commit, directory, token="", wago_token=""):
    """Publish the addon's TOC version everywhere its TOCs say: GitHub release, CurseForge, Wago.

    The release goes first: it refuses a version released from another commit.
    """
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
