"""Run deterministic performance budgets, optionally against the Git index."""
from __future__ import annotations

import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
SUITES = ("Highground", "HighgroundReputation")
SOURCE_DIRS = ("addons", "libs", "tools", "tests")


def git(root: Path, *args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(root), *args])


def affects_performance(name: str) -> bool:
    path = Path(name)
    return (path.parts[0] in SOURCE_DIRS and path.suffix in {"", ".lua", ".toc", ".xml"}
            or name in {"scripts/check_performance.py", ".githooks/pre-commit"})


def run_suites(root: Path) -> int:
    if not shutil.which("luajit"):
        print("Performance checks require LuaJIT (Lua 5.1).", file=sys.stderr)
        return 1
    for addon in SUITES:
        result = subprocess.run(["luajit", "tests/performance_test.lua"], cwd=root / "addons" / addon)
        if result.returncode:
            print("Performance check failed. See docs/performance.md for known regression patterns.", file=sys.stderr)
            return result.returncode
    return 0


def check_staged(root: Path) -> int:
    changed = git(root, "diff", "--cached", "--name-only", "-z").decode().split("\0")
    if not any(affects_performance(name) for name in changed if name):
        print("Performance checks: no staged runtime or performance-harness changes.")
        return 0
    print("Checking staged performance budgets: roster work, idle callbacks, allocations and UI reuse.", flush=True)
    # Export the index without stashing or touching the user's checkout. Only
    # runtime/test trees are needed; promotional/source artwork is excluded.
    with tempfile.TemporaryDirectory(prefix="highground-performance-") as directory:
        files = git(root, "ls-files", "--cached", "-z", "--", *SOURCE_DIRS)
        subprocess.run(["git", "-C", str(root), "checkout-index", "-z", "--stdin", "--prefix=" + directory + "/"],
                       input=files, check=True)
        return run_suites(Path(directory))


def install_hook(root: Path) -> None:
    # Preserve existing hooksPath/LFS hooks; install just the missing pre-commit.
    target = Path(git(root, "rev-parse", "--git-path", "hooks/pre-commit").decode().strip())
    if not target.is_absolute():
        target = root / target
    source = (root / ".githooks/pre-commit").read_bytes()
    if target.exists() or target.is_symlink():
        if target.read_bytes() != source:
            raise ValueError(f"Existing hook preserved: {target}. Add the command from .githooks/pre-commit to it.")
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(source)
    target.chmod(target.stat().st_mode | 0o111)
    print(f"Installed performance hook: {target}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--staged", action="store_true", help="test the exact staged source in a temporary snapshot")
    mode.add_argument("--install-hook", action="store_true", help="install pre-commit without replacing existing hooks")
    args = parser.parse_args()
    try:
        if args.install_hook:
            install_hook(ROOT)
            return 0
        return check_staged(ROOT) if args.staged else run_suites(ROOT)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Performance check: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
