"""Report on HighgroundApiProbe recordings (tools/apiprobe/HighgroundApiProbe).

Reads HighgroundApiProbeDB from WoW's SavedVariables file (written on /reload
or logout):

    python3 -I tools/apiprobe/report.py "<WoW>/WTF/Account/<account>/SavedVariables/HighgroundApiProbe.lua"

Prints (a) functions that returned readable values for an enemy unit inside a
PvP instance, by namespace; (b) the same functions in runs outside instances,
for contrast; (c) undocumented functions whose names suggest unit data.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
from bg_profile import Parser  # noqa: E402  (the SavedVariables reader)

KEYWORDS = ("Unit", "Health", "Aura", "Cast", "Range", "Position")
PVP = {"pvp", "arena"}


def load(path: Path) -> dict:
    saved = Parser(path.read_text(encoding="utf-8", errors="surrogateescape")).document()
    db = saved.get("HighgroundApiProbeDB")
    return db if isinstance(db, dict) else {}


def runs(db: dict) -> list[dict]:
    value = db.get("runs") or []
    return [run for run in (value.values() if isinstance(value, dict) else value) if isinstance(run, dict)]


def in_match(run: dict) -> bool:
    context = run.get("context") or {}
    return context.get("instanceType") in PVP and context.get("enemy") is True


def outside(run: dict) -> bool:
    return not (run.get("context") or {}).get("inInstance")


def returns(record: dict) -> list[dict]:
    value = record.get("r") or []
    return list(value.values()) if isinstance(value, dict) else list(value)


def readable(record: dict) -> bool:
    return bool(record.get("ok")) and any(not d.get("s") and d.get("t") != "nil" for d in returns(record))


def describe(record: dict) -> str:
    if not record.get("ok"):
        return "error: " + str(record.get("err", ""))
    parts = []
    for d in returns(record):
        kind = d.get("t", "?")
        if d.get("s"):
            parts.append(f"{kind}=SECRET")
        elif "v" in d:
            parts.append(f"{kind}={d['v']!r}")
        elif kind == "table":
            fields = d.get("f") or {}
            secret = sum(1 for f in fields.values() if isinstance(f, dict) and f.get("s"))
            parts.append(f"table[{d.get('k', 0)}]" + (f" ({secret} secret fields)" if secret else ""))
        else:
            parts.append(kind)
    return ", ".join(parts) or "(no returns)"


def namespace(name: str) -> str:
    return name.split(".", 1)[0] if "." in name else "_G"


def report(db: dict) -> str:
    lines = []
    match_runs = [run for run in runs(db) if in_match(run)]
    seen: dict[str, dict] = {}
    for run in match_runs:
        for name, record in (run.get("results") or {}).items():
            if isinstance(record, dict) and readable(record) and name not in seen:
                seen[name] = record
    lines.append(f"(a) Readable for an enemy unit in a PvP instance: {len(seen)} functions "
                 f"from {len(match_runs)} run(s)")
    grouped = defaultdict(list)
    for name in sorted(seen):
        grouped[namespace(name)].append(name)
    for group in sorted(grouped):
        lines.append(f"  {group}")
        for name in grouped[group]:
            tag = "" if seen[name].get("doc") else "  [undocumented]"
            lines.append(f"    {name}: {describe(seen[name])}{tag}")

    lines.append("")
    outside_runs = [run for run in runs(db) if outside(run)]
    lines.append(f"(b) The same functions outside instances: {len(outside_runs)} run(s)")
    for name in sorted(seen):
        for run in outside_runs:
            record = (run.get("results") or {}).get(name)
            if isinstance(record, dict):
                lines.append(f"    {name}: {describe(record)}")
                break

    lines.append("")
    listing = db.get("list") or {}
    undocumented = listing.get("undocumented") or []
    if isinstance(undocumented, dict):
        undocumented = list(undocumented.values())
    hits = sorted(name for name in undocumented if isinstance(name, str) and "_" not in name.split(".")[-1]
                  and any(word in name for word in KEYWORDS))
    lines.append(f"(c) Undocumented functions about units, health, auras, casts, range or position: {len(hits)}"
                 + ("" if listing else " (run /hgprobe list first)"))
    lines += [f"    {name}" for name in hits]
    return "\n".join(lines)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("saved", type=Path, help="SavedVariables/HighgroundApiProbe.lua")
    args = parser.parse_args(argv)
    if not args.saved.is_file():
        parser.error(f"not a file: {args.saved}")
    print(report(load(args.saved)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
