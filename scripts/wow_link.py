#!/usr/bin/env python3
"""Select one Git worktree for a local WoW installation; never publish paths."""

import argparse
from contextlib import contextmanager
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import uuid


CONFIG_KEY = "highground.foreverAddonsPath"
ADDON_NAME = re.compile(r"Highground[A-Za-z0-9]*\Z")


class LinkError(Exception):
    """A conflicting installation or selection that needs an explicit decision."""


def git(root, *args):
    result = subprocess.run(["git", "-C", str(root), *args], capture_output=True)
    if result.returncode:
        raise LinkError(os.fsdecode(result.stderr).strip() or "Git command failed")
    return os.fsdecode(result.stdout).strip()


def worktrees(root):
    records = git(root, "worktree", "list", "--porcelain", "-z").split("\0")
    return {Path(record[9:]).resolve() for record in records if record.startswith("worktree ")}


def absolute_link(path):
    """Read one link without following the shared active pointer."""
    return Path(os.path.abspath(path.parent / os.readlink(path)))


def replace_link(target, destination, staging):
    """Stage outside AddOns so temporary links cannot become duplicate addons."""
    temporary = staging / ("link-" + uuid.uuid4().hex)
    try:
        temporary.symlink_to(target, target_is_directory=True)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)


@contextmanager
def installation_lock(state):
    if state.is_symlink():
        raise LinkError(f"Installation state must be a real directory: {state}")
    state.mkdir(mode=0o700, parents=False, exist_ok=True)
    lock_path = state / "lock"
    if lock_path.is_symlink():
        raise LinkError(f"Installation lock must not be a symlink: {lock_path}")
    with lock_path.open("a+b") as handle:
        if os.name == "nt":
            import msvcrt
            handle.seek(0, os.SEEK_END)
            if handle.tell() == 0:
                handle.write(b"\0")
                handle.flush()
            handle.seek(0)
            try:
                msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
            except OSError as exc:
                raise LinkError("Another process is changing this installation; retry after it finishes") from exc
            try:
                yield
            finally:
                handle.seek(0)
                msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
        else:
            import fcntl
            try:
                fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as exc:
                raise LinkError("Another process is changing this installation; retry after it finishes") from exc
            try:
                yield
            finally:
                fcntl.flock(handle, fcntl.LOCK_UN)


def addon_names(root):
    folder = root / "addons"
    if not folder.is_dir():
        raise LinkError(f"No addon source directory in {root}")
    return {entry.name for entry in folder.iterdir()
            if ADDON_NAME.fullmatch(entry.name) and entry.is_dir()
            and (entry / (entry.name + ".toc")).is_file()}


def required_addons(root, names):
    """Include bundled Highground dependencies without enabling new standalones."""
    available = addon_names(root)
    result = set(names)
    pending = list(names)
    while pending:
        name = pending.pop()
        if name not in available:
            raise LinkError(f"Selected worktree is missing addon {name}: {root}")
        for toc in (root / "addons" / name).glob(name + "*.toc"):
            for line in toc.read_text(encoding="utf-8-sig").splitlines():
                match = re.match(r"##\s*(?:Dependencies|RequiredDeps|X-Bundled-Addons):\s*(.*)", line, re.I)
                if match:
                    for dependency in re.split(r"[\s,]+", match.group(1)):
                        if ADDON_NAME.fullmatch(dependency) and dependency not in result:
                            result.add(dependency)
                            pending.append(dependency)
    return result


def validate_source_links(root):
    """Shared code must resolve inside this worktree, not another agent's tree."""
    for source in (root / "addons", root / "libs"):
        if not source.is_dir():
            continue
        if source.is_symlink() and not source.resolve().is_relative_to(root):
            raise LinkError(f"Source directory leaves the selected worktree: {source}")
        for directory, directories, files in os.walk(source, followlinks=False):
            for name in directories + files:
                path = Path(directory) / name
                if not path.is_symlink():
                    continue
                try:
                    target = path.resolve(strict=True)
                except (OSError, RuntimeError) as exc:
                    raise LinkError(f"Broken source link: {path}") from exc
                if not target.is_relative_to(root):
                    raise LinkError(f"Source link leaves the selected worktree: {path} -> {target}")


def contains_highground(entry):
    if not entry.is_dir():
        return False
    for toc in entry.glob("*.toc"):
        if toc.name.startswith("Highground"):
            return True
        for line in toc.read_text(encoding="utf-8-sig", errors="replace").splitlines():
            if re.match(r"##\s*Title(?:-[A-Za-z]+)?:\s*(?:\|c[0-9a-fA-F]{8})?Highground\b", line):
                return True
    return False


class Installation:
    def __init__(self, repository, addons_dir):
        self.repository = Path(git(repository, "rev-parse", "--show-toplevel")).resolve()
        self.registered = worktrees(self.repository)
        self.addons_dir = Path(addons_dir).expanduser().resolve()
        if not self.addons_dir.is_dir() or self.addons_dir.name.lower() != "addons":
            raise LinkError("Select an existing Interface/AddOns directory")
        if any(self.addons_dir.is_relative_to(root) for root in self.registered):
            raise LinkError("The game AddOns directory must be outside repository worktrees")
        self.state = self.addons_dir.parent / ".highground-worktree"
        self.active = self.state / "active"

    def target(self, name):
        return self.active / "addons" / name

    def inspect(self):
        if self.active.exists() and not self.active.is_symlink():
            raise LinkError(f"Selection pointer must be a symlink: {self.active}")
        selected = absolute_link(self.active).resolve() if self.active.is_symlink() else None
        sources = set()
        names = set()
        managed = set()
        available = addon_names(self.repository)
        if selected and selected.is_dir():
            available |= addon_names(selected)
        for entry in sorted(self.addons_dir.iterdir()):
            if entry.name not in available:
                if entry.name.lower().startswith("highground") or contains_highground(entry):
                    raise LinkError(f"Duplicate or unknown Highground addon: {entry}; move it outside AddOns")
                continue
            names.add(entry.name)
            if not entry.is_symlink():
                raise LinkError(f"Existing addon is a real directory, not a managed link: {entry}; move it outside AddOns")
            if absolute_link(entry) == self.target(entry.name):
                managed.add(entry.name)
                continue
            source = entry.resolve()
            root = source.parent.parent
            if source != root / "addons" / entry.name or root not in self.registered or not source.is_dir():
                raise LinkError(f"Addon link does not identify a registered worktree: {entry}")
            sources.add(root)
        if selected:
            sources.add(selected)
        if len(sources) > 1:
            raise LinkError("Highground addons point to different worktrees: " + ", ".join(map(str, sorted(sources))))
        current = next(iter(sources), None)
        return current, names, managed

    def _status(self):
        current, names, managed = self.inspect()
        result = {"addons_dir": str(self.addons_dir), "active_worktree": str(current) if current else None,
                  "mode": "managed" if self.active.is_symlink() else "legacy" if current else "unlinked",
                  "addons": sorted(names), "managed_addons": sorted(managed), "problems": []}
        if current:
            if current not in self.registered or not current.is_dir():
                result["problems"].append("Selected worktree is missing or is not registered in this repository")
            else:
                result["branch"] = git(current, "branch", "--show-current") or "(detached)"
                result["commit"] = git(current, "rev-parse", "--short", "HEAD")
                missing = required_addons(current, names | {"Highground"}) - names
                if missing:
                    result["problems"].append("Missing addon links: " + ", ".join(sorted(missing)))
                try:
                    validate_source_links(current)
                except LinkError as exc:
                    result["problems"].append(str(exc))
        elif names:
            result["problems"].append("Managed links have no active selection; activate a worktree to finish setup")
        return result

    def status(self):
        with installation_lock(self.state):
            return self._status()

    def activate(self, worktree, replace=None):
        requested = Path(worktree).expanduser().resolve()
        expected = Path(replace).expanduser().resolve() if replace is not None else None
        if requested not in self.registered:
            raise LinkError(f"Not a registered worktree of this repository: {requested}")
        with installation_lock(self.state):
            current, names, _ = self.inspect()
            if expected is not None and current != expected:
                raise LinkError(f"Selection changed: expected {expected}, found {current or 'no active worktree'}")
            if current is not None and current != requested and expected is None:
                raise LinkError(f"Testing slot belongs to {current}. After an explicit user-selected switch, pass --replace with that exact path")
            required = required_addons(requested, names | {"Highground"})
            validate_source_links(requested)
            # Adopt legacy links through their existing source before switching.
            # If interrupted, every working link still resolves to the old tree.
            if current is not None and not self.active.is_symlink():
                replace_link(current, self.active, self.state)
            for name in sorted(required):
                destination = self.addons_dir / name
                if destination.is_symlink() and absolute_link(destination) == self.target(name):
                    continue
                target = os.path.relpath(self.target(name), self.addons_dir)
                replace_link(target, destination, self.state)
            # One rename publishes the complete selection for every addon.
            if not self.active.is_symlink() or absolute_link(self.active) != requested:
                replace_link(requested, self.active, self.state)
            return self._status()


def configured_path(repository):
    result = subprocess.run(["git", "-C", str(repository), "config", "--local", "--get", CONFIG_KEY],
                            text=True, capture_output=True)
    if result.returncode or not result.stdout.strip():
        raise LinkError("Configure this installation first: wow_link.py configure --addons-dir PATH")
    return result.stdout.strip()


def show_status(status, as_json=False):
    if as_json:
        print(json.dumps(status, indent=2))
        return
    print("AddOns:", status["addons_dir"])
    print("Active worktree:", status["active_worktree"] or "none")
    if "branch" in status:
        print("Branch:", status["branch"], "(" + status["commit"] + ")")
    print("Links:", status["mode"], ", ".join(status["addons"]) or "none")
    for problem in status["problems"]:
        print("Needs attention:", problem)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    configure = commands.add_parser("configure", help="Store this machine's game path in local Git config")
    configure.add_argument("--addons-dir", required=True)
    status = commands.add_parser("status", help="Inspect the active testing worktree")
    status.add_argument("--json", action="store_true")
    activate = commands.add_parser("activate", help="Link this worktree without stealing another testing slot")
    activate.add_argument("--worktree", help="Registered worktree to select; defaults to the current checkout")
    activate.add_argument("--replace", metavar="EXPECTED_WORKTREE", help="Explicitly replace this exact current owner")
    activate.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    try:
        repository = Path(git(Path.cwd(), "rev-parse", "--show-toplevel"))
        if args.command == "configure":
            installation = Installation(repository, args.addons_dir)
            git(repository, "config", "--local", CONFIG_KEY, str(installation.addons_dir))
            print("Saved game path in local Git configuration:", installation.addons_dir)
            return 0
        installation = Installation(repository, configured_path(repository))
        if args.command == "activate":
            result = installation.activate(args.worktree or repository, args.replace)
        else:
            result = installation.status()
        show_status(result, args.json)
        return 1 if result["problems"] else 0
    except (LinkError, OSError, RuntimeError) as exc:
        if getattr(args, "json", False):
            print(json.dumps({"error": str(exc)}))
        else:
            print("wow_link:", exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
