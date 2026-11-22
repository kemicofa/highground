"""Merge Lua coverage hits from tools/coverage.lua into a report on the runtime modules.

The test runner wraps each Lua suite with tools/coverage.lua when given
--coverage, then calls report() with each suite's hit file and working
directory. Runtime modules are the tracked Lua files under addons/ and
libs/ outside tests/ folders; modules no suite loads count as uncovered.
Executable lines and functions come from LuaJIT bytecode, so blank lines,
comments and a function's closing "end" are not counted.
"""
from __future__ import annotations

from dataclasses import dataclass, field
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "tools" / "coverage.lua"
NAMED = (
    re.compile(r"\bfunction\s+([\w.:]+)\s*\("),               # function A.b:c( / local function f(
    re.compile(r"([\w.]+|\[[^]]+\])\s*=\s*function\s*\("),    # A.b = function( / [key] = function(
    re.compile(r"""\(\s*["'](\w+)["']\s*,\s*function\s*\("""),  # SetScript("OnClick", function(
)


@dataclass
class Function:
    line: int
    last: int
    name: str
    lines: int = 0
    calls: int = 0


@dataclass
class FileCoverage:
    path: str
    executable: set[int] = field(default_factory=set)
    hit: set[int] = field(default_factory=set)
    functions: list[Function] = field(default_factory=list)

    @property
    def percent(self) -> float:
        return 100.0 * len(self.hit) / len(self.executable) if self.executable else 100.0

    @property
    def missed(self) -> int:
        return len(self.executable) - len(self.hit)


def command(suite_command: tuple[str, ...], out: Path) -> tuple[str, ...]:
    """A suite's command ("luajit", script, args...) wrapped to record hits in out."""
    if suite_command[0] != "luajit":
        raise ValueError(f"Coverage needs a LuaJIT suite: {suite_command}")
    return ("luajit", str(TOOL), "run", str(out), *suite_command[1:])


def runtime_files(root: Path = ROOT) -> list[str]:
    """Tracked runtime Lua modules, repository-relative."""
    names = subprocess.check_output(["git", "ls-files", "-z", "--", "*.lua"], cwd=root).decode().split("\0")
    result = []
    for name in names:
        parts = PurePosixPath(name).parts
        if name and parts[0] in {"addons", "libs"} and "tests" not in parts and not (root / name).is_symlink():
            result.append(name)
    return sorted(result)


def merge(results: list[tuple[Path, Path]], root: Path = ROOT) -> tuple[dict, dict]:
    """Line and function-call counts per repository-relative path, from (hit file, cwd) pairs."""
    lines: dict[str, dict[int, int]] = {}
    calls: dict[str, dict[int, int]] = {}
    real_root = Path(os.path.realpath(root))
    resolved: dict[tuple[Path, str], str | None] = {}
    for out, cwd in results:
        if not out.is_file():
            continue  # a suite that crashed before writing still fails the run
        for row in out.read_text(encoding="utf-8", errors="replace").splitlines():
            kind, source, number, count = row.split("\t")
            key = (cwd, source)
            if key not in resolved:
                path = Path(os.path.realpath(Path(cwd) / source))
                resolved[key] = path.relative_to(real_root).as_posix() if path.is_relative_to(real_root) else None
            if resolved[key] is None:
                continue
            target = (lines if kind == "L" else calls).setdefault(resolved[key], {})
            target[int(number)] = target.get(int(number), 0) + int(count)
    return lines, calls


def function_name(text: str, line: int) -> str:
    for pattern in NAMED:
        if match := pattern.search(text):
            return match.group(1)
    return f"<anonymous:{line}>"


def analyse(files: list[str], lines: dict, calls: dict, root: Path = ROOT) -> list[FileCoverage]:
    """Coverage for each runtime file from its bytecode and the merged hits."""
    output = subprocess.run(["luajit", str(TOOL), "lines", *files], cwd=root, check=True,
                            capture_output=True, text=True).stdout
    result = {name: FileCoverage(name) for name in files}
    spans: dict[str, list[tuple[int, int]]] = {}
    for row in output.splitlines():
        kind, name, *numbers = row.split("\t")
        if kind == "L":
            result[name].executable.add(int(numbers[0]))
        else:
            spans.setdefault(name, []).append((int(numbers[0]), int(numbers[1])))
    for name, coverage in result.items():
        hits = lines.get(name, {})
        coverage.hit = {line for line in coverage.executable if hits.get(line)}
        source = (root / name).read_text(encoding="utf-8", errors="replace").splitlines()
        called = calls.get(name, {})
        for first, last in spans.get(name, []):
            text = source[first - 1] if 0 < first <= len(source) else ""
            body = {line for line in coverage.executable if first <= line <= last}
            coverage.functions.append(Function(first, last, function_name(text, first), len(body),
                                               called.get(first, 0)))
    return sorted(result.values(), key=lambda c: (-c.missed, c.path))


def outermost_uncalled(coverage: FileCoverage) -> list[Function]:
    """Uncalled functions outside other uncalled functions; their size includes nested code."""
    uncalled = [fn for fn in coverage.functions if not fn.calls]
    return [fn for fn in uncalled if not any(
        other.line <= fn.line and fn.last <= other.last and (other.line, other.last) != (fn.line, fn.last)
        for other in uncalled)]


def report(directory: Path, results: list[tuple[Path, Path]], root: Path = ROOT, top: int = 30) -> str:
    """Writes coverage.txt and coverage.json to directory; returns a short summary."""
    lines, calls = merge(results, root)
    files = analyse(runtime_files(root), lines, calls, root)
    executable = sum(len(f.executable) for f in files)
    hit = sum(len(f.hit) for f in files)
    functions = [(f, fn) for f in files for fn in f.functions]
    uncalled = sorted(((f, fn) for f in files for fn in outermost_uncalled(f)),
                      key=lambda p: (-p[1].lines, p[0].path, p[1].line))
    called = sum(1 for _, fn in functions if fn.calls)
    total = (f"Runtime Lua coverage: {hit}/{executable} lines ({100.0 * hit / max(executable, 1):.1f}%), "
             f"{called}/{len(functions)} functions called, {len(files)} files")
    detail = [total, "", "Files by uncovered lines (missed, line %, uncalled/functions):"]
    for f in files:
        uncovered = sum(1 for fn in f.functions if not fn.calls)
        detail.append(f"{f.missed:6d} {f.percent:5.1f}% {uncovered:4d}/{len(f.functions):<4d} {f.path}")
    detail += ["", "Uncalled functions by size (executable lines, including nested functions):"]
    detail += [f"{fn.lines:6d} {f.path}:{fn.line} {fn.name}" for f, fn in uncalled]
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "coverage.txt").write_text("\n".join(detail) + "\n", encoding="utf-8")
    data = [{"path": f.path, "lines": len(f.executable), "hit": len(f.hit), "percent": round(f.percent, 1),
             "missedLines": sorted(f.executable - f.hit),
             "functions": [{"name": fn.name, "line": fn.line, "last": fn.last, "lines": fn.lines, "calls": fn.calls}
                           for fn in f.functions]} for f in files]
    (directory / "coverage.json").write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8")
    summary = [total, f"Least covered files (of {len(files)}):"]
    summary += [f"  {f.missed:5d} missed {f.percent:5.1f}% {f.path}" for f in files[:top] if f.missed]
    summary.append(f"Largest uncalled functions, including nested code (of {len(uncalled)}):")
    summary += [f"  {fn.lines:5d} lines {f.path}:{fn.line} {fn.name}" for f, fn in uncalled[:top]]
    summary.append(f"Full report: {directory / 'coverage.txt'}")
    return "\n".join(summary)
