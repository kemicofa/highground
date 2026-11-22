"""Check Highground command discovery, UI parity and generated docs, including the Git index."""
from __future__ import annotations

import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIRS = ("addons", "libs", "tools", "tests")
OLD_HOOK = b'''#!/bin/sh
set -eu
repository_root=$(git rev-parse --show-toplevel)
exec python3 "$repository_root/scripts/check_performance.py" --staged
'''
COMMAND_HOOK = b'''#!/bin/sh
set -eu
repository_root=$(git rev-parse --show-toplevel)
python3 "$repository_root/scripts/check_performance.py" --staged
# The Git hook is shared with older worktrees that predate this checker.
if [ -f "$repository_root/scripts/check_commands.py" ]; then
  python3 "$repository_root/scripts/check_commands.py" --staged
fi
'''


def git(root: Path, *args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(root), *args])


def relevant(name: str) -> bool:
    path = Path(name)
    return (path.parts[0] in SOURCE_DIRS and path.suffix in {"", ".lua", ".toc", ".xml", ".md"}
            or name in {"scripts/check_commands.py", ".githooks/pre-commit", "AGENTS.md"}
            or name.startswith(".agents/skills/highground-command-ui-review/"))


def run_checks(root: Path) -> int:
    if not shutil.which("luajit"):
        print("Command/UI checks require LuaJIT (Lua 5.1).", file=sys.stderr)
        return 1
    for suite in ("tests/docs_test.lua", "tests/command_catalog_test.lua"):
        result = subprocess.run(["luajit", suite], cwd=root / "addons/Highground")
        if result.returncode:
            print("Command/UI review failed. See .agents/skills/highground-command-ui-review/SKILL.md.", file=sys.stderr)
            return result.returncode
    return 0


def check_staged(root: Path) -> int:
    changed = git(root, "diff", "--cached", "--name-only", "-z").decode().split("\0")
    if not any(relevant(name) for name in changed if name):
        print("Command/UI checks: no relevant staged changes.")
        return 0
    print("Checking staged command ownership, UI controls and documentation.", flush=True)
    with tempfile.TemporaryDirectory(prefix="highground-commands-") as directory:
        files = git(root, "ls-files", "--cached", "-z", "--", *SOURCE_DIRS)
        subprocess.run(["git", "-C", str(root), "checkout-index", "-z", "--stdin", "--prefix=" + directory + "/"],
                       input=files, check=True)
        return run_checks(Path(directory))


def install_hook(root: Path) -> None:
    target = Path(git(root, "rev-parse", "--git-path", "hooks/pre-commit").decode().strip())
    if not target.is_absolute():
        target = root / target
    source = (root / ".githooks/pre-commit").read_bytes()
    if target.exists() or target.is_symlink():
        if target.read_bytes() not in (source, OLD_HOOK, COMMAND_HOOK):
            raise ValueError(f"Existing hook preserved: {target}. Integrate .githooks/pre-commit into it.")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(source)
    target.chmod(target.stat().st_mode | 0o111)
    print(f"Installed performance, command/UI and localization hook: {target}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--staged", action="store_true", help="check only the exact staged source")
    mode.add_argument("--install-hook", action="store_true", help="install or upgrade the known performance hook; preserve custom hooks")
    args = parser.parse_args()
    try:
        if args.install_hook:
            install_hook(ROOT)
            return 0
        return check_staged(ROOT) if args.staged else run_checks(ROOT)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Command/UI check: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
