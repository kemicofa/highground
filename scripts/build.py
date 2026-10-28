"""Build installable addon ZIPs (every addon in addons/, or the ones named) with Python's standard library.

A ZIP holds the files an addon's TOCs load (and their XML includes) plus the
globs listed in the TOC field "## X-Package-Files". Paths may go through a link
inside the repository (libs -> ../../libs/HighgroundKit, Highground's
features/<name> -> ../../<Addon>/src): the package gets copies. Each addon builds into OUTPUT_DIR/<Addon>/: the ZIP, SHA256SUMS and
RELEASE_NOTES.md (the first section of its CHANGELOG.md).
"""
import argparse
import hashlib
from pathlib import Path
import re
import xml.etree.ElementTree as ET
import zipfile

import addons

SUMMARY_MAX = 200  # CurseForge truncates the project summary past about this length


def release_info(addon):
    """Check the addon is releasable; returns (version, release notes)."""
    version = addon.version
    changelog = (addon.path / "CHANGELOG.md").read_text(encoding="utf-8")
    headings = list(re.finditer(r"^## \[([^\]]+)\].*$", changelog, re.M))
    if not headings or headings[0][1] != version:
        raise ValueError(f"The first {addon.name}/CHANGELOG.md release must be [{version}]")
    # A CurseForge project's description must be refreshed for every release.
    if addon.project:
        description = addon.path / "docs" / "curseforge.md"
        text = description.read_text(encoding="utf-8") if description.exists() else ""
        marker = re.search(rf"<!-- {re.escape(addon.name)} ({addons.VERSION}) -->", text)
        if not marker or marker.group(1) != version:
            raise ValueError(f"docs/curseforge.md must describe {version}: "
                             f"update it and its <!-- {addon.name} {version} --> line")
        summary = re.search(r"## Summary.*?```\n(.*?)\n```", text, re.S)
        if not summary or not 0 < len(summary.group(1)) <= SUMMARY_MAX:
            raise ValueError(f"docs/curseforge.md needs a summary of 1 to {SUMMARY_MAX} characters "
                             "(CurseForge cuts longer ones)")
    end = headings[1].start() if len(headings) > 1 else len(changelog)
    notes = changelog[headings[0].end():end].strip()
    if not notes or not re.search(r"^- \S", notes, re.M):
        raise ValueError("The current changelog needs release notes")
    return version, notes + "\n"


def package_files(addon):
    """Paths (relative to the addon folder) of every file its ZIP holds."""
    files = set()
    base = addon.path
    repo = base.resolve().parent.parent

    def add(relative):
        relative = Path(str(relative).replace("\\", "/"))
        path = base / relative
        if relative.is_absolute() or ".." in relative.parts or not path.resolve().is_relative_to(repo):
            raise ValueError(f"Package path escapes the addon: {relative}")
        if not path.is_file():
            raise ValueError(f"Missing package file: {relative}")
        if relative in files:
            return
        files.add(relative)
        if path.suffix == ".toc":
            for line in path.read_text().splitlines():
                line = line.strip()
                if line and not line.startswith("#"):
                    add(relative.parent / line.replace("\\", "/"))
        elif path.suffix == ".xml":
            for node in ET.parse(path).iter():
                if node.tag.rsplit("}", 1)[-1] in {"Script", "Include"} and "file" in node.attrib:
                    add(relative.parent / node.attrib["file"].replace("\\", "/"))

    for toc in addons.tocs(base):
        add(toc.name)
    for pattern in (addons.field(base, "X-Package-Files") or "").split():
        matches = sorted(p for p in base.glob(pattern) if p.is_file())
        if not matches:
            raise ValueError(f"{addon.name}: nothing matches X-Package-Files {pattern}")
        for path in matches:
            add(path.relative_to(base))
    return sorted(files)


def build(addon, output):
    """Write the ZIP, SHA256SUMS and RELEASE_NOTES.md into output; returns (version, ZIP path)."""
    version, notes = release_info(addon)
    files = package_files(addon)
    output.mkdir(parents=True, exist_ok=True)
    archive = output / addon.zip_name(version)
    with zipfile.ZipFile(archive, "w") as package:
        for relative in files:
            # Fixed timestamps, order and modes make repeated builds reproducible.
            info = zipfile.ZipInfo(f"{addon.name}/{relative.as_posix()}", (1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            package.writestr(info, (addon.path / relative).read_bytes(),
                             compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (output / "SHA256SUMS").write_text(f"{digest}  {archive.name}\n", encoding="utf-8")
    (output / "RELEASE_NOTES.md").write_text(notes, encoding="utf-8")
    return version, archive


def main():
    found = addons.load()
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("names", nargs="*", metavar="ADDON",
                        help=f"addons to build (default: all of {', '.join(found)})")
    parser.add_argument("--output-dir", type=Path, default=addons.ROOT / "dist",
                        help="each addon builds into OUTPUT_DIR/<Addon>/")
    parser.add_argument("--github-output", type=Path,
                        help="with one ADDON: append its version, tag and artifact name to this file")
    args = parser.parse_args()
    unknown = [name for name in args.names if name not in found]
    if unknown:
        parser.error(f"unknown addon: {', '.join(unknown)}")
    if args.github_output and len(args.names) != 1:
        parser.error("--github-output needs exactly one ADDON")
    for name in args.names or found:
        addon = found[name]
        version, archive = build(addon, addon.dist(args.output_dir))
        print(f"Built {archive} ({archive.stat().st_size:,} bytes)")
    if args.github_output:
        with args.github_output.open("a", encoding="utf-8") as output:
            output.write(f"version={version}\ntag={addon.tag(version)}\nartifact={addon.artifact(version)}\n")


if __name__ == "__main__":
    main()
