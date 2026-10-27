"""Publish a tested build; never overwrite a published release or move its tag.

Highground is tagged vX.Y.Z; other addons <Addon>-vX.Y.Z. With --curseforge PROJECT
(and the CURSEFORGE_TOKEN environment variable) the ZIP is also uploaded to that
CurseForge project before the release is published; without the token that addon
is skipped and nothing is created.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))  # scripts/curseforge.py, however this file is loaded
import curseforge  # noqa: E402

CURSEFORGE_MARK = "curseforge-file.txt"  # release asset: the upload already happened


def gh(*args):
    return subprocess.run(["gh", *args], check=True, capture_output=True, text=True).stdout


def lookup(path):
    try:
        return json.loads(gh("api", path))
    except subprocess.CalledProcessError as error:
        if "(HTTP 404)" in error.stderr:
            return None
        raise


def publish(repository, version, commit, directory, addon="Highground", curseforge_project=None,
            token=None, source=None):
    if not re.fullmatch(r"(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)", version):
        raise ValueError("Expected a major.minor.patch version")
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("Release target must be the full tested commit SHA")
    tag = f"v{version}" if addon == "Highground" else f"{addon}-v{version}"
    title = f"{'Highground Macros' if addon == 'HighgroundMacros' else addon} {version}"
    archive = directory / f"{addon}-{version}.zip"
    checksums = directory / "SHA256SUMS"
    notes = directory / "RELEASE_NOTES.md"
    expected = f"{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n"
    if checksums.read_text() != expected or not notes.read_text().strip():
        raise ValueError("Release artifacts or notes failed validation")

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
    if curseforge_project:
        uploaded = any(a.get("name") == CURSEFORGE_MARK for a in (release or {}).get("assets", []))
        if uploaded:
            print("Already on CurseForge (resumed draft); not uploading again")
        else:
            ids = curseforge.game_version_ids(token, curseforge.interface_versions(source))
            file_id = curseforge.upload(curseforge_project, token, archive, notes.read_text(), title, ids)
            with tempfile.TemporaryDirectory() as tmp:
                mark = Path(tmp) / CURSEFORGE_MARK
                mark.write_text(f"{file_id}\n")
                gh("release", "upload", tag, str(mark), *common, "--clobber")
            print(f"Uploaded to CurseForge project {curseforge_project}: file {file_id}")
    gh("release", "edit", tag, *common, "--draft=false", "--title", title,
       "--notes-file", str(notes))
    print(gh("release", "view", tag, *common, "--json", "url", "--jq", ".url").strip())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--dist", type=Path, default=Path("dist"))
    parser.add_argument("--addon", default="Highground")
    parser.add_argument("--curseforge", metavar="PROJECT", help="also upload to this CurseForge project")
    args = parser.parse_args()
    token = os.environ.get("CURSEFORGE_TOKEN", "")
    if args.curseforge and not token:
        print(f"{args.addon}: no CURSEFORGE_TOKEN secret; not publishing")
        return
    source = Path(__file__).resolve().parent.parent / "addons" / args.addon
    publish(args.repository, args.version, args.commit, args.dist, args.addon, args.curseforge, token, source)


if __name__ == "__main__":
    main()
