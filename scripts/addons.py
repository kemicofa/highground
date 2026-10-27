"""The repository's addons and their release facts, read from files that already exist.

Each folder in addons/ with a TOC file is an addon. Its TOCs give the title
("## Title"), version ("## Version"), CurseForge project ("## X-Curse-Project-ID")
and extra package files ("## X-Package-Files").

The addon named by .pkgmeta "package-as" is the webhook addon: it publishes a
GitHub release tagged vX.Y.Z and the repository's CurseForge webhook builds its
file from that release. Every other addon uploads its ZIP to CurseForge with the
upload API and gets a plain tag <Folder>-vX.Y.Z (no GitHub release, which would
fire the webhook).

  python3 scripts/addons.py   # prints the manifest as JSON
"""
from dataclasses import dataclass
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
VERSION = r"(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)"  # major.minor.patch


def tocs(path):
    """The addon's TOC files, by name."""
    return sorted(Path(path).glob("*.toc"))


def toc_field(toc, name):
    """Every value of the "## Name: value" field in one TOC file."""
    return re.findall(rf"^## {re.escape(name)}:\s*(.*?)\s*$", Path(toc).read_text(), re.M)


def field(path, name):
    """A TOC field that has the same value in every TOC of the addon, or None when absent."""
    values = {(toc_field(toc, name) or [None])[0] for toc in tocs(path)}
    if len(values) != 1:
        raise ValueError(f"{Path(path).name}: every TOC needs the same {name}")
    return values.pop()


def version(path):
    """The addon's major.minor.patch version; every TOC must hold the same one."""
    versions = set()
    for toc in tocs(path):
        found = toc_field(toc, "Version")
        if len(found) != 1 or not re.fullmatch(VERSION, found[0]):
            raise ValueError(f"{toc.name} must contain one major.minor.patch version")
        versions.add(found[0])
    if len(versions) != 1:
        raise ValueError(f"{Path(path).name}: client TOC versions must match")
    return versions.pop()


def webhook_addon(root=ROOT):
    """The addon .pkgmeta packages ("package-as"), or None without a .pkgmeta."""
    pkgmeta = Path(root) / ".pkgmeta"
    if not pkgmeta.exists():
        return None
    found = re.search(r"^package-as:\s*(\S+)\s*$", pkgmeta.read_text(), re.M)
    return found[1] if found else None


@dataclass(frozen=True)
class Addon:
    """One addon folder. TOC facts are read when asked for, so edits show at once."""

    name: str  # folder name, also the ZIP's top folder
    path: Path
    webhook: bool  # published via GitHub release and the CurseForge webhook

    @property
    def title(self):
        return field(self.path, "Title") or self.name

    @property
    def version(self):
        return version(self.path)

    @property
    def project(self):
        """CurseForge project ID, or None."""
        return field(self.path, "X-Curse-Project-ID")

    @property
    def tag_prefix(self):
        return "v" if self.webhook else f"{self.name}-v"

    def tag(self, version=None):
        return self.tag_prefix + (version or self.version)

    def zip_name(self, version=None):
        return f"{self.name}-{version or self.version}.zip"

    def artifact(self, version=None):
        """The CI artifact holding the tested build."""
        return f"{self.name}-{version or self.version}"

    def dist(self, output):
        """Where build.py writes this addon inside an output folder."""
        return Path(output) / self.name


def load(root=ROOT):
    """Every addon in root/addons, by folder name."""
    root = Path(root)
    hook = webhook_addon(root)
    return {p.name: Addon(p.name, p, p.name == hook)
            for p in sorted((root / "addons").iterdir()) if p.is_dir() and tocs(p)}


def main():
    manifest = {name: {"title": a.title, "version": a.version, "curseforge": a.project,
                       "publish": "github-release" if a.webhook else "curseforge-api",
                       "tag": a.tag(), "zip": a.zip_name(), "artifact": a.artifact(),
                       "dist": a.dist("dist").as_posix()}
                for name, a in load().items()}
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
