"""Classify the complete PR diff; unknown paths always require tests."""
from __future__ import annotations

import argparse
from pathlib import PurePosixPath
import subprocess


def documentation_only(path: str) -> bool:
    parts = PurePosixPath(path).parts
    if path in {"README.md", "AGENTS.md", "LICENSE", ".github/pull_request_template.md"}:
        return True
    if path.endswith(".md"):
        if parts[0] in {"docs", ".agents", ".claude"}:
            return True
        if len(parts) >= 3 and parts[0] == "addons":
            return parts[2] in {"README.md", "AGENTS.md", "docs"}
    return False


def requires_tests(base: str, head: str) -> bool:
    # Disable rename detection so moving code into docs still reports its deletion.
    # NUL delimiters preserve spaces, newlines and arbitrary Git filename bytes.
    changed = subprocess.check_output([
        "git", "diff", "--name-only", "--no-renames", "-z", f"{base}...{head}", "--",
    ])
    return any(not documentation_only(path.decode("utf-8", "surrogateescape"))
               for path in changed.split(b"\0") if path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("base")
    parser.add_argument("head")
    args = parser.parse_args()
    print(f"run_tests={str(requires_tests(args.base, args.head)).lower()}")
