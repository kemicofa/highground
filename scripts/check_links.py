"""Check relative links and anchors in the repository's Markdown files.

External URLs are not fetched. A relative link must name an existing file or
directory without passing through a symlink (GitHub cannot follow them), and a
Markdown anchor must match a heading or an explicit HTML id/name.

    python3 scripts/check_links.py              # every tracked Markdown file
    python3 scripts/check_links.py README.md docs
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
SKIPPED_DIRS = {".git", "dist", "node_modules", "graphify-out", "worktrees"}

FENCE = re.compile(r"^\s{0,3}(`{3,}|~{3,})")
HEADING = re.compile(r"^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$")
INLINE_CODE = re.compile(r"(`+)(.+?)\1")
INLINE_LINK = re.compile(r"!?\[(?:[^\[\]]|\[[^\[\]]*\])*\]\(\s*(<[^>]*>|[^\s()]*(?:\([^\s()]*\)[^\s()]*)*)(?:\s+[\"'(][^)]*)?\)")
REFERENCE = re.compile(r"^\s{0,3}\[[^\]]+\]:\s*(<[^>]*>|\S+)")
HTML_ID = re.compile(r"<[a-zA-Z][^>]*\s(?:id|name)\s*=\s*[\"']([^\"']+)[\"']")
SCHEME = re.compile(r"^[a-zA-Z][a-zA-Z0-9+.-]*:")


def slug(text: str) -> str:
    """GitHub's heading anchor: drop markup and punctuation, lowercase, spaces to hyphens."""
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = text.lower().replace("*", "")
    return re.sub(r"[^\w\- ]", "", text).replace(" ", "-")


def strip_code(line: str) -> str:
    return INLINE_CODE.sub(lambda match: " " * len(match.group(0)), line)


def scan(path: Path) -> tuple[list[tuple[int, str]], set[str]]:
    """Return (line, target) for each link outside code, plus the file's anchors."""
    links: list[tuple[int, str]] = []
    anchors: set[str] = set()
    counts: dict[str, int] = {}
    fence = None
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        opened = FENCE.match(line)
        if fence:
            if opened and opened.group(1)[0] == fence[0] and len(opened.group(1)) >= len(fence):
                fence = None
            continue
        if opened:
            fence = opened.group(1)
            continue
        anchors.update(HTML_ID.findall(line))
        heading = HEADING.match(line)
        if heading:
            base = slug(heading.group(2))
            seen = counts.get(base, 0)
            counts[base] = seen + 1
            anchors.add(base if seen == 0 else f"{base}-{seen}")
        text = strip_code(line)
        reference = REFERENCE.match(text)
        if reference:
            links.append((number, reference.group(1)))
        links.extend((number, match.group(1)) for match in INLINE_LINK.finditer(text))
    return links, anchors


def symlink_in(path: Path, root: Path) -> Path | None:
    """First symlink between root and path, or None."""
    try:
        parts = path.relative_to(root).parts
    except ValueError:
        return None
    current = root
    for part in parts:
        current = current / part
        if current.is_symlink():
            return current
    return None


def markdown_files(root: Path, selected: list[str]) -> list[Path]:
    if not selected:
        try:
            output = subprocess.check_output(
                ["git", "-C", str(root), "ls-files", "-z", "--", "*.md"], stderr=subprocess.DEVNULL)
            return sorted(root / name for name in output.decode().split("\0") if name)
        except (OSError, subprocess.CalledProcessError):
            selected = ["."]
    files: set[Path] = set()
    for name in selected:
        path = (root / name) if not Path(name).is_absolute() else Path(name)
        if path.is_dir():
            files.update(found for found in path.rglob("*.md")
                         if not SKIPPED_DIRS.intersection(found.relative_to(path).parts))
        elif path.suffix == ".md":
            files.add(path)
    return sorted(files)


def check(root: Path, selected: list[str] | None = None) -> list[str]:
    root = root.resolve()
    files = markdown_files(root, selected or [])
    anchors: dict[Path, set[str]] = {}
    links: dict[Path, list[tuple[int, str]]] = {}
    for path in files:
        if path.exists():
            links[path], anchors[path] = scan(path)
    problems = []
    for path, found in links.items():
        shown = path.relative_to(root).as_posix() if path.is_relative_to(root) else str(path)
        for number, raw in found:
            target = raw[1:-1] if raw.startswith("<") else raw
            if not target or SCHEME.match(target) or target.startswith("//"):
                continue
            location, _, anchor = target.partition("#")
            location = unquote(location.split("?", 1)[0])
            if location.startswith("/"):
                destination = root / location.lstrip("/")
            else:
                destination = path.parent / location if location else path
            normalized = Path(os.path.normpath(destination))
            if not normalized.exists():
                problems.append(f"{shown}:{number}: missing {target}")
                continue
            link = symlink_in(normalized, root)
            if link:
                problems.append(f"{shown}:{number}: {target} passes through symlink "
                                f"{link.relative_to(root).as_posix()}; link its source path")
                continue
            if anchor and normalized.suffix == ".md" and normalized.is_file():
                normalized = normalized.resolve()
                if normalized not in anchors:
                    anchors[normalized] = scan(normalized)[1]
                if unquote(anchor).lower() not in anchors[normalized]:
                    problems.append(f"{shown}:{number}: no heading for #{anchor} in {target or shown}")
    return problems


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("paths", nargs="*", help="Markdown files or directories (default: tracked files)")
    parser.add_argument("--root", type=Path, default=ROOT, help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    problems = check(args.root, args.paths)
    for problem in problems:
        print(problem)
    if problems:
        print(f"{len(problems)} broken link(s).", file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
