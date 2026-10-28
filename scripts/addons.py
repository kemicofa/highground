"""The repository's addons and their release facts, read from their TOC files.

Each folder in addons/ with a TOC file is an addon. Its TOCs give the title
("## Title"), version ("## Version"), game versions ("## Interface"), CurseForge
project ("## X-Curse-Project-ID"), Wago project ("## X-Wago-ID") and extra
package files ("## X-Package-Files").

Where a version goes:
- a GitHub release, for every addon: tagged <Folder>-vX.Y.Z, or vX.Y.Z for
  the addon with "## X-GitHub-Latest: true" (Highground), which is also the
  repository's "Latest" release;
- a CurseForge project: an upload through the CurseForge API, recorded by the
  tag curseforge-<its tag>;
- a Wago project: an upload to Wago, recorded by the tag wago-<its tag>.

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


def game_versions(path):
    """Game versions from the TOCs' "## Interface" lines: 120105 -> "12.1.5", 40402 -> "4.4.2"."""
    names = []
    for toc in tocs(path):
        for number in re.findall(r"\d+", " ".join(toc_field(toc, "Interface")[:1])):
            n = int(number)
            name = f"{n // 10000}.{n // 100 % 100}.{n % 100}"
            if name not in names:
                names.append(name)
    return names


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


@dataclass(frozen=True)
class Addon:
    """One addon folder. TOC facts are read when asked for, so edits show at once."""

    name: str  # folder name, also the ZIP's top folder
    path: Path

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
    def wago(self):
        """Wago Addons project ID, or None."""
        return field(self.path, "X-Wago-ID")

    @property
    def latest(self):
        """The repository's main addon ("## X-GitHub-Latest: true"): tag vX.Y.Z, the "Latest" release."""
        return (field(self.path, "X-GitHub-Latest") or "").lower() == "true"

    @property
    def game_versions(self):
        return game_versions(self.path)

    @property
    def tag_prefix(self):
        return "v" if self.latest else f"{self.name}-v"

    def tag(self, version=None):
        return self.tag_prefix + (version or self.version)

    def curseforge_tag(self, version=None):
        """The tag that marks a version as uploaded to CurseForge."""
        return "curseforge-" + self.tag(version)

    def wago_tag(self, version=None):
        """The tag that marks a version as uploaded to Wago: wago-<tag>."""
        return "wago-" + self.tag(version)

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
    return {p.name: Addon(p.name, p) for p in sorted((root / "addons").iterdir()) if p.is_dir() and tocs(p)}


def main():
    manifest = {name: {"title": a.title, "version": a.version, "curseforge": a.project, "wago": a.wago,
                       "publish": [c for c, on in (("github-release", True), ("curseforge", a.project),
                                                    ("wago", a.wago)) if on],
                       "tag": a.tag(), "zip": a.zip_name(), "artifact": a.artifact(),
                       "dist": a.dist("dist").as_posix()}
                for name, a in load().items()}
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
