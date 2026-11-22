"""Run addon validators, isolated Lua suites and repository tests with the standard library."""
from __future__ import annotations

import argparse
from dataclasses import dataclass, replace
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
# Seconds before a hung Lua suite is stopped. The unsplit simulation suite
# (--jobs 1) takes about two minutes; other suites take under 20 seconds.
DEFAULT_TIMEOUT = 600


@dataclass(frozen=True)
class Suite:
    name: str
    directory: Path
    command: tuple[str, ...]


def lua_suites(addon: Path, split_simulations: bool) -> list[Suite]:
    """Discover every Lua suite; the simulation runner owns its group list."""
    suites = []
    for path in sorted((addon / "tests").glob("*_test.lua")):
        relative = path.relative_to(addon).as_posix()
        command = ("luajit", relative)
        name = f"{addon.name}/{relative}"
        if split_simulations and addon.name == "Highground" and path.name == "simulation_test.lua":
            groups = subprocess.check_output(
                [*command, "--list-groups"], cwd=addon, text=True,
            ).splitlines()
            if not groups or len(groups) != len(set(groups)) or any(not group.strip() for group in groups):
                raise ValueError("Simulation group discovery must return a nonempty, unique list")
            suites.extend(Suite(f"{name} [{group}]", addon, (*command, group)) for group in groups)
        else:
            suites.append(Suite(name, addon, command))
    return suites


def failure_lines(output: str, limit: int = 10) -> list[str]:
    """The harness's "FAIL label: name" lines, else the interpreter's error, else the last line."""
    lines = [line for line in output.splitlines() if line.startswith("FAIL ")]
    if not lines:
        lines = [line for line in output.splitlines() if line.startswith(("luajit: ", "lua: "))]
    if not lines:
        lines = [line for line in output.splitlines() if line.strip()][-1:]
    return lines[:limit] + ([f"... {len(lines) - limit} more"] if len(lines) > limit else [])


def run_suites(suites: list[Suite], jobs: int, timeout: float | None = None) -> int:
    """Bound subprocesses and buffer each suite's output so failures stay readable.

    A suite running longer than timeout seconds is stopped and fails. The
    summary repeats each failed suite's failing tests after all output.
    """
    if jobs < 1:
        raise ValueError("jobs must be at least 1")
    pending = iter(suites)
    running = {}
    failed = []
    durations = []
    started = time.perf_counter()
    print(f"== {len(suites)} Lua suites, up to {jobs} workers", flush=True)
    try:
        while True:
            while len(running) < jobs:
                suite = next(pending, None)
                if suite is None:
                    break
                output = tempfile.TemporaryFile(mode="w+", encoding="utf-8")
                try:
                    process = subprocess.Popen(suite.command, cwd=suite.directory,
                                               stdout=output, stderr=subprocess.STDOUT)
                except BaseException:
                    output.close()
                    raise
                running[process] = (suite, output, time.perf_counter())
            if not running:
                break
            now = time.perf_counter()
            expired = [process for process, (_, _, begun) in running.items()
                       if timeout and process.poll() is None and now - begun > timeout]
            for process in expired:
                process.kill()
                process.wait()
            finished = [process for process in running if process.poll() is not None]
            if not finished:
                time.sleep(0.02)
                continue
            for process in finished:
                suite, output, suite_started = running.pop(process)
                elapsed = time.perf_counter() - suite_started
                durations.append((elapsed, suite.name))
                status = "TIMEOUT" if process in expired else "FAIL" if process.returncode else "PASS"
                print(f"== {status} {suite.name} ({elapsed:.2f}s)")
                with output:
                    output.seek(0)
                    text = output.read()
                sys.stdout.write(text)
                if process in expired:
                    print(f"Stopped after {timeout:g}s (--timeout).")
                sys.stdout.flush()
                if process.returncode:
                    lines = [f"stopped after {timeout:g}s"] if process in expired else failure_lines(text)
                    failed.append((suite.name, lines))
    finally:
        # Ctrl-C, CI cancellation and launch errors must not leave Lua workers running.
        for process in running:
            if process.poll() is None:
                process.terminate()
        for process, (_, output, _) in running.items():
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            output.close()
    elapsed = time.perf_counter() - started
    if len(durations) > 5:
        slowest = ", ".join(f"{name} ({seconds:.1f}s)" for seconds, name in sorted(durations, reverse=True)[:5])
        print(f"Slowest: {slowest}")
    print(f"Lua suites: {len(suites) - len(failed)} passed, {len(failed)} failed ({elapsed:.2f}s)", flush=True)
    for name, lines in failed:
        print(f"FAILED: {name}", file=sys.stderr)
        for line in lines:
            print(f"    {line}", file=sys.stderr)
    return int(bool(failed))


def run_with_coverage(suites: list[Suite], jobs: int, directory: Path, root: Path,
                      timeout: float | None = None) -> int:
    """Runs the suites under tools/coverage.lua, then reports even when one fails."""
    import lua_coverage  # scripts/ is on the path when run as a script or through tests/support.py
    hits = directory / "hits"
    shutil.rmtree(hits, ignore_errors=True)
    hits.mkdir(parents=True)
    outputs = [(hits / f"{index:04d}.tsv", suite.directory) for index, suite in enumerate(suites)]
    wrapped = [replace(suite, command=lua_coverage.command(suite.command, out))
               for suite, (out, _) in zip(suites, outputs)]
    status = run_suites(wrapped, jobs, timeout)
    print(lua_coverage.report(directory, outputs, root), flush=True)
    return status


def seconds(value: str) -> float:
    try:
        number = float(value)
    except ValueError:
        raise argparse.ArgumentTypeError("timeout must be a number of seconds") from None
    if number < 0:
        raise argparse.ArgumentTypeError("timeout must not be negative")
    return number


def positive_jobs(value: str) -> int:
    try:
        jobs = int(value)
    except ValueError:
        raise argparse.ArgumentTypeError("jobs must be a positive integer") from None
    if jobs < 1:
        raise argparse.ArgumentTypeError("jobs must be a positive integer")
    return jobs


def main(argv: list[str] | None = None, root: Path = ROOT) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--addons-only", action="store_true", help="skip repository Python tests")
    mode.add_argument("--repository-only", action="store_true", help="skip addon validators and Lua tests")
    parser.add_argument("--jobs", type=positive_jobs, default=1, metavar="N",
                        help="maximum concurrent Lua suites (default: 1); splits simulations when above 1")
    parser.add_argument("--timeout", type=seconds, metavar="SECONDS",
                        help=f"stop a Lua suite after this long (default: {DEFAULT_TIMEOUT}, none with --coverage; 0: none)")
    parser.add_argument("--coverage", action="store_true",
                        help="record Lua line and function coverage (slow); see scripts/lua_coverage.py")
    parser.add_argument("--coverage-dir", type=Path, default=root / "coverage", metavar="DIR",
                        help="where --coverage writes coverage.txt and coverage.json (default: coverage/)")
    parser.add_argument("addons", nargs="*", metavar="ADDON")
    args = parser.parse_args(argv)
    if args.repository_only and args.addons:
        parser.error("--repository-only does not accept addon names")
    if args.repository_only and args.coverage:
        parser.error("--coverage measures Lua suites; it does not apply to --repository-only")
    available = {path.name: path for path in (root / "addons").iterdir() if path.is_dir()}
    unknown = set(args.addons) - available.keys()
    if unknown:
        parser.error(f"Unknown addon: {', '.join(sorted(unknown))}")
    if len(args.addons) != len(set(args.addons)):
        parser.error("addon names must not be repeated")
    if not shutil.which("luajit"):
        parser.error("Tests require LuaJIT (Lua 5.1 semantics, matching WoW).")
    selected = [] if args.repository_only else args.addons or sorted(available)
    suites = []
    for name in selected:
        addon = available[name]
        if not (addon / "tests").is_dir():
            continue
        print(f"== addons/{name}: validation", flush=True)
        if (addon / "tests/validate.py").is_file():
            subprocess.run([sys.executable, "tests/validate.py"], cwd=addon, check=True)
        suites.extend(lua_suites(addon, split_simulations=args.jobs > 1))
    timeout = args.timeout if args.timeout is not None else 0 if args.coverage else DEFAULT_TIMEOUT
    if args.coverage and suites:
        status = run_with_coverage(suites, args.jobs, args.coverage_dir, root, timeout)
    else:
        status = run_suites(suites, args.jobs, timeout) if suites else 0
    if status:
        return 1
    if not args.addons_only:
        print("== packaging, release and cross-addon integration", flush=True)
        return subprocess.call([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py"],
                               cwd=root)
    return 0


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, signal.default_int_handler)
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Test runner: {error}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("Test runner interrupted; Lua workers stopped.", file=sys.stderr)
        sys.exit(130)
