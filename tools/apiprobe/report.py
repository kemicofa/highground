"""Report on HighgroundApiProbe recordings (tools/apiprobe/HighgroundApiProbe).

Reads HighgroundApiProbeDB from WoW's SavedVariables file (written on /reload
or logout):

    python3 -I tools/apiprobe/report.py "<WoW>/WTF/Account/<account>/SavedVariables/HighgroundApiProbe.lua"

Prints (a) functions that returned readable values for an enemy unit inside a
PvP instance, by namespace; (b) the same functions in runs outside instances,
for contrast; (c) undocumented functions whose names suggest unit data;
(d) /hgprobe world snapshots side by side, with place and combat state;
(e) PARTY_KILL and UNIT_DEATH counts.
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


def items(value) -> list:
    """A saved array: a list, or a dict when the parser couldn't tell."""
    return list(value.values()) if isinstance(value, dict) else list(value or [])


def runs(db: dict) -> list[dict]:
    return [run for run in items(db.get("runs")) if isinstance(run, dict)]


def in_match(run: dict) -> bool:
    context = run.get("context") or {}
    return context.get("instanceType") in PVP and context.get("enemy") is True


def outside(run: dict) -> bool:
    return not (run.get("context") or {}).get("inInstance")


def returns(record: dict) -> list[dict]:
    return items(record.get("r"))


def readable(record: dict) -> bool:
    return bool(record.get("ok")) and any(not d.get("s") and d.get("t") != "nil" for d in returns(record))


SCALARS = {"number", "string", "boolean"}


def value(d: dict, fields: bool = False) -> str:
    """One described return. With fields, tables also show their readable and
    secret field counts, or the fields themselves when there are few (x, y)."""
    kind = d.get("t", "?")
    if d.get("s"):
        return f"{kind}=SECRET"
    if "v" in d:
        return f"{kind}={d['v']!r}"
    if kind != "table":
        return kind
    described = d.get("f") or {}
    described = described if isinstance(described, dict) else {}
    secret = sum(1 for f in described.values() if isinstance(f, dict) and f.get("s"))
    text = f"table[{d.get('k', 0)}]"
    if not fields:
        return text + (f" ({secret} secret fields)" if secret else "")
    scalars = {name: f for name, f in described.items() if isinstance(f, dict) and f.get("t") in SCALARS}
    if 0 < len(scalars) <= 4:
        return text + " {" + ", ".join(f"{name}={'SECRET' if f.get('s') else repr(f.get('v'))}"
                                       for name, f in sorted(scalars.items())) + "}"
    readable = sum(1 for f in scalars.values() if not f.get("s"))
    return text + f" ({readable} readable, {secret} secret fields)"


def describe(record: dict, fields: bool = False) -> str:
    if record.get("missing"):
        return "missing"
    if not record.get("ok"):
        return "error: " + str(record.get("err", ""))
    return ", ".join(value(d, fields) for d in returns(record)) or "(no returns)"


def namespace(name: str) -> str:
    return name.split(".", 1)[0] if "." in name else "_G"


def place(context: dict) -> str:
    inside = context.get("inInstance")
    where = context.get("instanceType") if inside is True else "world" if inside is False else "?"
    return f"{where}, {'in combat' if context.get('combat') is True else 'out of combat'}"


def target(context: dict) -> str:
    if context.get("exists") is not True:
        return "none"
    side = {True: "enemy", False: "friendly"}.get(context.get("enemy"), "?")
    kind = {True: "player", False: "NPC"}.get(context.get("player"), "unit")
    return f"{side} {kind}"


def world(db: dict) -> list[str]:
    """Each /hgprobe world read across snapshots, in the order first taken."""
    snapshots = [s for s in items(db.get("world")) if isinstance(s, dict)]
    lines = [f"(d) Open-world snapshots (/hgprobe world): {len(snapshots)}"]
    calls, by_snapshot = [], []
    for index, snapshot in enumerate(snapshots, 1):
        context = snapshot.get("context") or {}
        plates = [p for p in items(context.get("nameplates")) if isinstance(p, str)]
        lines.append(f"  [{index}] {context.get('date', '?')} {place(context)}; target: {target(context)}; "
                     f"zone: {context.get('zone', '?')}; enemy nameplates: {', '.join(plates) or 'none'}")
        reads = {}
        for record in items(snapshot.get("reads")):
            if isinstance(record, dict) and isinstance(record.get("call"), str):
                reads[record["call"]] = record
                if record["call"] not in calls:
                    calls.append(record["call"])
        by_snapshot.append(reads)
    for call in calls:
        cells = [f"[{index}] " + (describe(reads[call], True) if call in reads else "-")
                 for index, reads in enumerate(by_snapshot, 1)]
        lines.append(f"    {call}: " + "  ".join(cells))
    return lines


def kills(db: dict) -> list[str]:
    """PARTY_KILL and UNIT_DEATH per place, from the listener."""
    events = db.get("kills") if isinstance(db.get("kills"), dict) else {}
    registered = None  # from the latest snapshot that recorded it
    for snapshot in items(db.get("world")):
        recorded = (snapshot.get("context") or {}).get("events") if isinstance(snapshot, dict) else None
        if isinstance(recorded, dict):
            registered = recorded
    lines = ["(e) Kill events (PARTY_KILL, UNIT_DEATH)" + (
        "; registered: " + ", ".join(f"{e} {'yes' if ok else 'no'}" for e, ok in sorted(registered.items()))
        if isinstance(registered, dict) else "")]
    for event in sorted(events):
        places = events[event] if isinstance(events[event], dict) else {}
        for where in sorted(places):
            b = places[where] if isinstance(places[where], dict) else {}
            last = ", ".join(value(d) for d in items(b.get("last")) if isinstance(d, dict))
            lines.append(f"    {event} {where}: {b.get('n', 0)} ({b.get('plain', 0)} readable, "
                         f"{b.get('secret', 0)} with secret arguments, {b.get('combat', 0)} in combat); "
                         f"last: {last or '(no arguments)'}")
    if not events:
        lines.append("    none recorded")
    return lines


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
    lines += [""] + world(db) + [""] + kills(db)
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
