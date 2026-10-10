"""Build an installable Warboard ZIP using only Python's standard library."""
import argparse
import hashlib
from pathlib import Path
import re
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parent.parent
TOCS = ("Warboard.toc", "Warboard_Cata.toc")
VERSION = r"(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)"


def release_info(root):
    versions = []
    for toc in TOCS:
        found = re.findall(r"^## Version:\s*(\S+)\s*$", (root / toc).read_text(), re.M)
        if len(found) != 1 or not re.fullmatch(VERSION, found[0]):
            raise ValueError(f"{toc} must contain one major.minor.patch version")
        versions.extend(found)
    if versions[0] != versions[1]:
        raise ValueError("Retail and Cata TOC versions must match")
    version = versions[0]
    changelog = (root / "CHANGELOG.md").read_text(encoding="utf-8")
    headings = list(re.finditer(r"^## \[([^\]]+)\].*$", changelog, re.M))
    if not headings or headings[0][1] != version:
        raise ValueError(f"The first CHANGELOG.md release must be [{version}]")
    end = headings[1].start() if len(headings) > 1 else len(changelog)
    notes = changelog[headings[0].end():end].strip()
    if not notes or not re.search(r"^- \S", notes, re.M):
        raise ValueError("The current changelog needs release notes")
    return version, notes + "\n"


def package_files(root):
    files = set()

    def add(relative):
        relative = Path(str(relative).replace("\\", "/"))
        path = root / relative
        if relative.is_absolute() or ".." in relative.parts or not path.resolve().is_relative_to(root.resolve()):
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

    for filename in (*TOCS, "Bindings.xml", "README.md", "CHANGELOG.md", "LICENSE"):
        add(filename)
    for directory, extensions in (("media", {".ttf", ".txt"}), ("sounds", {".ogg"})):
        assets = sorted(p for p in (root / directory).rglob("*") if p.suffix in extensions)
        if not assets:
            raise ValueError(f"Missing runtime assets in {directory}")
        for path in assets:
            add(path.relative_to(root))
    return sorted(files)


def build(root, output):
    version, notes = release_info(root)
    files = package_files(root)
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"Warboard-{version}.zip"
    with zipfile.ZipFile(archive, "w") as package:
        for relative in files:
            # Fixed timestamps, order and modes make repeated builds reproducible.
            info = zipfile.ZipInfo(f"Warboard/{relative.as_posix()}", (1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            package.writestr(info, (root / relative).read_bytes(),
                             compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (output / "SHA256SUMS").write_text(f"{digest}  {archive.name}\n", encoding="utf-8")
    (output / "RELEASE_NOTES.md").write_text(notes, encoding="utf-8")
    return version, archive


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "dist")
    parser.add_argument("--github-output", type=Path)
    args = parser.parse_args()
    version, archive = build(ROOT, args.output_dir)
    if args.github_output:
        with args.github_output.open("a", encoding="utf-8") as output:
            output.write(f"version={version}\ntag=v{version}\n")
    print(f"Built {archive} ({archive.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
