"""Check localization catalogs, fallback, references and hosts, optionally against the Git index."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIRS = ("addons", "libs", "tools", "tests", "scripts")


def git(root: Path, *args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(root), *args])


def relevant(name: str) -> bool:
    path = Path(name)
    return (path.parts[0] in SOURCE_DIRS and path.suffix in {"", ".lua", ".toc", ".xml", ".py"}
            or name in {".githooks/pre-commit", "AGENTS.md", "docs/localization.md",
                        ".github/pull_request_template.md"}
            or name.startswith(".agents/skills/highground-localization-review/"))


def run_checks(root: Path) -> int:
    if not shutil.which("luajit"):
        print("Localization checks require LuaJIT (Lua 5.1).", file=sys.stderr)
        return 1
    # CI runs these same suites through the normal addon/repository runners.
    checks = (
        (["luajit", "tests/locale_library_test.lua"], root / "addons/Highground"),
        ([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_localization.py", "-v"], root),
    )
    for command, directory in checks:
        result = subprocess.run(command, cwd=directory, env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"})
        if result.returncode:
            print("Localization check failed. See .agents/skills/highground-localization-review/SKILL.md.", file=sys.stderr)
            return result.returncode
    return 0


def check_staged(root: Path) -> int:
    changed = git(root, "diff", "--cached", "--name-only", "-z").decode().split("\0")
    if not any(relevant(name) for name in changed if name):
        print("Localization checks: no relevant staged changes.")
        return 0
    print("Checking staged localization catalogs, fallback, references and hosts.", flush=True)
    with tempfile.TemporaryDirectory(prefix="highground-localization-") as directory:
        # Packaging follows repository symlinks, including shared root files
        # such as LICENSE. Export the complete index to preserve those targets.
        files = git(root, "ls-files", "--cached", "-z")
        subprocess.run(["git", "-C", str(root), "checkout-index", "-z", "--stdin", "--prefix=" + directory + "/"],
                       input=files, check=True)
        # Run the staged checker as well as staged data and tests. No stash,
        # reset, or working-tree fixes can change what this commit validates.
        snapshot = Path(directory)
        return subprocess.run([sys.executable, str(snapshot / "scripts/check_localization.py")],
                              cwd=snapshot, env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"}).returncode


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--staged", action="store_true", help="check the exact staged source, including the checker")
    mode.add_argument("--install-hook", action="store_true", help="install all shared checks; preserve custom hooks")
    args = parser.parse_args()
    try:
        if args.install_hook:
            from check_commands import install_hook
            install_hook(ROOT)
            return 0
        return check_staged(ROOT) if args.staged else run_checks(ROOT)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Localization check: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
