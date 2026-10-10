"""Publish a tested build; never overwrite a published release or move its tag."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def gh(*args):
    return subprocess.run(["gh", *args], check=True, capture_output=True, text=True).stdout


def lookup(path):
    try:
        return json.loads(gh("api", path))
    except subprocess.CalledProcessError as error:
        if "(HTTP 404)" in error.stderr:
            return None
        raise


def publish(repository, version, commit, directory):
    if not re.fullmatch(r"(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)", version):
        raise ValueError("Expected a major.minor.patch version")
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("Release target must be the full tested commit SHA")
    tag = f"v{version}"
    archive = directory / f"Warboard-{version}.zip"
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
           "--title", f"Warboard {version}", "--notes-file", str(notes))
    # Drafts can be resumed after an interrupted upload. Publication is last.
    gh("release", "upload", tag, str(archive), str(checksums), *common, "--clobber")
    gh("release", "edit", tag, *common, "--draft=false", "--title", f"Warboard {version}",
       "--notes-file", str(notes))
    print(gh("release", "view", tag, *common, "--json", "url", "--jq", ".url").strip())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--dist", type=Path, default=Path("dist"))
    args = parser.parse_args()
    publish(args.repository, args.version, args.commit, args.dist)


if __name__ == "__main__":
    main()
