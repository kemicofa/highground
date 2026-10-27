"""Build installable addon ZIPs (every addon in addons/, or the ones named) with Python's standard library.

Each addon is a folder in addons/ with one or more TOC files. A ZIP holds the
files its TOCs load (and their XML includes) plus the globs listed in the TOC
field "## X-Package-Files". Paths may go through a link inside the
repository (WarboardMacros/shared -> ../Warboard): the package gets copies.
"""
import argparse
import hashlib
from pathlib import Path
import re
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parent.parent
VERSION = r"(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)"
RELEASED = "Warboard"  # the addon CI publishes as a GitHub release (tag vX.Y.Z)

SUMMARY_MAX = 200  # CurseForge truncates the project summary past about this length


def addons(root=ROOT):
    """Addon folders in addons/, by name."""
    return {p.name: p for p in sorted((root / "addons").iterdir()) if p.is_dir() and any(p.glob("*.toc"))}


def tocs(addon):
    return sorted(addon.glob("*.toc"))


def field(addon, name):
    """A "## Name: value" field, the same in every TOC of the addon, or None."""
    values = set()
    for toc in tocs(addon):
        found = re.findall(rf"^## {re.escape(name)}:\s*(.*?)\s*$", toc.read_text(), re.M)
        values.add(found[0] if found else None)
    if len(values) != 1:
        raise ValueError(f"{addon.name}: every TOC needs the same {name}")
    return values.pop()


def release_info(addon):
    name = addon.name
    versions = []
    for toc in tocs(addon):
        found = re.findall(r"^## Version:\s*(\S+)\s*$", toc.read_text(), re.M)
        if len(found) != 1 or not re.fullmatch(VERSION, found[0]):
            raise ValueError(f"{toc.name} must contain one major.minor.patch version")
        versions.extend(found)
    if len(set(versions)) != 1:
        raise ValueError(f"{name}: client TOC versions must match")
    version = versions[0]
    changelog = (addon / "CHANGELOG.md").read_text(encoding="utf-8")
    headings = list(re.finditer(r"^## \[([^\]]+)\].*$", changelog, re.M))
    if not headings or headings[0][1] != version:
        raise ValueError(f"The first {name}/CHANGELOG.md release must be [{version}]")
    # A CurseForge project's description must be refreshed for every release.
    if field(addon, "X-Curse-Project-ID"):
        description = addon / "docs" / "curseforge.md"
        text = description.read_text(encoding="utf-8") if description.exists() else ""
        marker = re.search(rf"<!-- {re.escape(name)} (\d+\.\d+\.\d+) -->", text)
        if not marker or marker.group(1) != version:
            raise ValueError(f"docs/curseforge.md must describe {version}: update it and its <!-- {name} {version} --> line")
        summary = re.search(r"## Summary.*?```\n(.*?)\n```", text, re.S)
        if not summary or not 0 < len(summary.group(1)) <= SUMMARY_MAX:
            raise ValueError(f"docs/curseforge.md needs a summary of 1 to {SUMMARY_MAX} characters (CurseForge cuts longer ones)")
    end = headings[1].start() if len(headings) > 1 else len(changelog)
    notes = changelog[headings[0].end():end].strip()
    if not notes or not re.search(r"^- \S", notes, re.M):
        raise ValueError("The current changelog needs release notes")
    return version, notes + "\n"


def package_files(addon):
    files = set()
    repo = addon.resolve().parent.parent

    def add(relative):
        relative = Path(str(relative).replace("\\", "/"))
        path = addon / relative
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

    for toc in tocs(addon):
        add(toc.name)
    for pattern in (field(addon, "X-Package-Files") or "").split():
        matches = sorted(p for p in addon.glob(pattern) if p.is_file())
        if not matches:
            raise ValueError(f"{addon.name}: nothing matches X-Package-Files {pattern}")
        for path in matches:
            add(path.relative_to(addon))
    return sorted(files)


def build(addon, output):
    version, notes = release_info(addon)
    files = package_files(addon)
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"{addon.name}-{version}.zip"
    with zipfile.ZipFile(archive, "w") as package:
        for relative in files:
            # Fixed timestamps, order and modes make repeated builds reproducible.
            info = zipfile.ZipInfo(f"{addon.name}/{relative.as_posix()}", (1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            package.writestr(info, (addon / relative).read_bytes(),
                             compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (output / "SHA256SUMS").write_text(f"{digest}  {archive.name}\n", encoding="utf-8")
    (output / "RELEASE_NOTES.md").write_text(notes, encoding="utf-8")
    return version, archive


def main():
    found = addons()
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("names", nargs="*", metavar="ADDON",
                        help=f"addons to build (default: all of {', '.join(found)})")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "dist",
                        help="each addon builds into OUTPUT_DIR/<addon>/")
    parser.add_argument("--github-output", type=Path)
    args = parser.parse_args()
    unknown = [name for name in args.names if name not in found]
    if unknown:
        parser.error(f"unknown addon: {', '.join(unknown)}")
    built = {}
    for name in args.names or found:
        version, archive = build(found[name], args.output_dir / name)
        built[name] = version
        print(f"Built {archive} ({archive.stat().st_size:,} bytes)")
    if args.github_output and RELEASED in built:
        with args.github_output.open("a", encoding="utf-8") as output:
            output.write(f"version={built[RELEASED]}\ntag=v{built[RELEASED]}\n")


if __name__ == "__main__":
    main()
