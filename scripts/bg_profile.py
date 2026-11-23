"""Report on battleground recordings made with /hg bg profiler.

Reads HighgroundDB.bgProfiles from WoW's SavedVariables file (written on
/reload or logout):

    python3 scripts/bg_profile.py "<WoW>/WTF/Account/<account>/SavedVariables/Highground.lua"
    python3 scripts/bg_profile.py FILE --session 2 --timeline --kinds wave,me,gy
    python3 scripts/bg_profile.py FILE --json > profile.json

Rows are "<seconds since start> <kind> <text>"; the kinds are described in
addons/Highground/docs/saved-data.md.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import json
import os
from pathlib import Path
import re
import statistics
import sys

TOKEN = re.compile(r"""
    (?P<space>\s+|--[^\n]*)
  | (?P<string>"(?:\\.|\\\n|[^"\\])*")
  | (?P<number>-?(?:0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?|inf|nan))
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<symbol>[{}\[\]=,;])
""", re.VERBOSE)
ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v",
           "\\": "\\", '"': '"', "'": "'", "\n": "\n"}


def unquote(literal: str) -> str:
    out, data, i = bytearray(), literal[1:-1], 0
    while i < len(data):
        ch = data[i]
        if ch != "\\":
            out += ch.encode("utf-8", "surrogateescape")
            i += 1
            continue
        nxt = data[i + 1]
        digits = re.match(r"\d{1,3}", data[i + 1:])
        if digits:
            out.append(int(digits.group()) & 0xFF)
            i += 1 + len(digits.group())
        else:
            out += ESCAPES.get(nxt, nxt).encode("utf-8", "surrogateescape")
            i += 2
    return out.decode("utf-8", "replace")


def tokens(text: str):
    pos = 0
    while pos < len(text):
        match = TOKEN.match(text, pos)
        if not match:
            raise ValueError(f"unexpected {text[pos:pos + 20]!r} at {pos}")
        pos = match.end()
        kind = match.lastgroup
        if kind != "space":
            yield kind, match.group()
    yield "end", ""


class Parser:
    """The Lua table subset WoW writes to SavedVariables."""

    def __init__(self, text: str):
        self.tokens = list(tokens(text))
        self.i = 0

    def peek(self, offset=0):
        return self.tokens[self.i + offset]

    def take(self, value=None):
        kind, text = self.tokens[self.i]
        if value is not None and text != value:
            raise ValueError(f"expected {value!r}, found {text!r}")
        self.i += 1
        return kind, text

    def document(self) -> dict:
        out = {}
        while self.peek()[0] != "end":
            _, name = self.take()
            self.take("=")
            out[name] = self.value()
        return out

    def value(self):
        kind, text = self.take()
        if kind == "string":
            return unquote(text)
        if kind == "number":
            if "x" in text or "X" in text:
                return int(text, 16)
            return float(text) if re.search(r"[.eEni]", text) else int(text)
        if text in ("true", "false"):
            return text == "true"
        if text == "nil":
            return None
        if text == "{":
            return self.table()
        raise ValueError(f"unexpected {text!r}")

    def table(self):
        fields, index = {}, 1
        while self.peek()[1] != "}":
            if self.peek()[1] == "[":
                self.take("[")
                key = self.value()
                self.take("]")
                self.take("=")
                fields[key] = self.value()
            elif self.peek()[0] == "name" and self.peek(1)[1] == "=":
                key = self.take()[1]
                self.take("=")
                fields[key] = self.value()
            else:
                fields[index] = self.value()
                index += 1
            if self.peek()[1] in (",", ";"):
                self.take()
        self.take("}")
        if fields and all(isinstance(k, int) for k in fields) and sorted(fields) == list(range(1, len(fields) + 1)):
            return [fields[k] for k in range(1, len(fields) + 1)]
        return fields if fields else []


def load_sessions(path: Path) -> list[dict]:
    saved = Parser(path.read_text(encoding="utf-8", errors="surrogateescape")).document()
    db = saved.get("HighgroundDB")
    sessions = db.get("bgProfiles") if isinstance(db, dict) else None
    return [s for s in sessions or [] if isinstance(s, dict)]


ROW = re.compile(r"^(-?\d+(?:\.\d+)?) (\S+) ?(.*)$")
FIELD = re.compile(r"(\w+)=(\S+)")


def rows(session: dict):
    for row in session.get("rows") or []:
        match = ROW.match(row) if isinstance(row, str) else None
        if match:
            yield float(match.group(1)), match.group(2), match.group(3)


def fields(text: str) -> dict:
    """key=value pairs; a trailing gy= keeps its spaces (graveyard names)."""
    out = dict(FIELD.findall(text))
    if " gy=" in text:
        out["gy"] = text.rsplit(" gy=", 1)[1]
    return out


def number(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def clock(seconds: float) -> str:
    return f"{int(seconds // 60)}:{int(seconds % 60):02d}"


def errors_line(values: list[float]) -> str:
    if not values:
        return "none measured"
    absolute = [abs(v) for v in values]
    return (f"n={len(values)} mean|err|={statistics.mean(absolute):.1f}s max|err|={max(absolute):.1f}s "
            f"within 1.5s={sum(a <= 1.5 for a in absolute)}/{len(values)}")


WAVE = re.compile(r"^(\S+) (\S) (.*?) ?at=")


def resurrection(session: dict) -> list[str]:
    out, by_conf, by_gy, misses = [], defaultdict(list), defaultdict(list), []
    rez, jumps, clocks, advice = [], Counter(), [], 0
    for t, kind, text in rows(session):
        f = fields(text)
        if kind == "wave":
            match = WAVE.match(text)
            conf = match.group(1) if match else text.split(" ", 1)[0]
            err = number(f.get("err"))
            by_conf[conf].append(err)
            if match:
                by_gy[conf, f"{match.group(2)} {match.group(3) or '(no graveyard)'}"].append(err)
            if err is not None and abs(err) > 1.5:
                misses.append(f"  {clock(t)} {text}")
        elif kind == "me" and text.startswith("rez "):
            rez.append((t, f))
        elif kind == "gy":
            gy = text.split(" next=")[0].rstrip()
            jumps[gy if " " in gy else f"{gy} (no graveyard)"] += 1
        elif kind == "clock":
            clocks.append(f"  {clock(t)} {text}")
        elif kind == "advice":
            advice += 1
    out.append("Resurrection")
    for t, f in rez:
        out.append(f"  your rez {clock(t)}: dead {f.get('after')}s at {f.get('gy', '-')}; "
                   f"vs game countdown {f.get('healerErr')}s, vs Highground's clock {f.get('gyErr')}s")
    gy_errors = [e for e in (number(f.get("gyErr")) for _, f in rez) if e is not None]
    out.append(f"  your rez vs Highground's clock: {errors_line(gy_errors)}")
    for conf, values in sorted(by_conf.items()):
        measured = [v for v in values if v is not None]
        out.append(f"  waves {conf}: {len(values)} seen; prediction before them: {errors_line(measured)}")
        # Per graveyard: one clock mixing several graveyards shows up here.
        for (gy_conf, name), gy_values in sorted(by_gy.items()):
            if gy_conf == conf:
                gy_measured = [v for v in gy_values if v is not None]
                out.append(f"    {name}: {len(gy_values)} seen; {errors_line(gy_measured)}")
    if misses:
        out.append("  predictions off by more than 1.5s:")
        out.extend(misses[:12])
    for name, count in jumps.most_common():
        out.append(f"  clock changes {name}: {count}")
    out.extend(clocks[:12])
    out.append(f"  'die now' advice given: {advice}")
    return out


def bases(session: dict) -> list[str]:
    out, assault_at, captures = ["Bases"], {}, []
    for t, kind, text in rows(session):
        if kind != "node":
            continue
        name = text.split(" owner=")[0]
        f = fields(text)
        owner, assault = f.get("owner", "-"), f.get("assault", "-")
        if name in assault_at and assault != assault_at[name][2]:
            started, predicted, team, before = assault_at.pop(name)
            head = f"  {name}: {team} assault at {clock(started)}"
            if assault != "-":
                captures.append(f"{head} taken over by {assault} after {t - started:.0f}s")
            elif owner == before and owner != "-":
                captures.append(f"{head} defended by {owner} after {t - started:.0f}s")
            else:
                captures.append(f"{head} captured after {t - started:.0f}s "
                                f"(timer said {predicted if predicted is not None else '-'}s), owner {owner}")
        if assault != "-" and name not in assault_at:
            assault_at[name] = (t, number(f.get("capLeft")), assault, owner)
    out.extend(captures or ["  no assaults seen"])
    return out


def prediction(session: dict) -> list[str]:
    out, last = ["Score prediction (objective window WIN row)"], None
    for t, kind, text in rows(session):
        if kind == "obj":
            for part in text.split(" | "):
                bits = part.split(":")
                if bits[0] == "WIN" and len(bits) >= 4 and bits[1] != last:
                    last = bits[1]
                    out.append(f"  {clock(t)} predicts {bits[1]}: {':'.join(bits[2:-1])}")
        elif kind == "match" and text.startswith("complete"):
            out.append(f"  {clock(t)} match {text}")
    return out if len(out) > 1 else out + ["  no prediction shown"]


def chat(session: dict) -> list[str]:
    english = str(session.get("locale") or "enUS").startswith("en")
    templates, untranslated = Counter(), Counter()
    for _, kind, text in rows(session):
        if kind != "chat":
            continue
        shape = re.sub(r"\d+", "#", text)
        templates[shape] += 1
        channel = text.split(" ", 1)[0]
        if not english and channel in ("A", "H", "N") and " => " not in text:
            untranslated[shape] += 1
    out = ["Chat (numbers as #)"]
    out.extend(f"  {count:3d}x {shape}" for shape, count in templates.most_common(25))
    if untranslated:
        out.append("  battleground lines with no English form (translation tables missed them):")
        out.extend(f"  {count:3d}x {shape}" for shape, count in untranslated.most_common(25))
    return out


def world(session: dict) -> list[str]:
    widgets, pois, vignettes, comms, flags = {}, {}, Counter(), [], Counter()
    for t, kind, text in rows(session):
        if kind == "widget":
            widgets[text.split(" ", 1)[0]] = text
        elif kind == "poi" and not text.endswith(" gone"):
            pois[text.split(" at=")[0]] = True
        elif kind == "vignette":
            vignettes[text[2:]] += 1
        elif kind == "comms":
            comms.append(f"  {clock(t)} {text}")
        elif kind == "flag":
            flags[text.split("=")[0]] += 1
    out = ["World state"]
    out.extend(f"  widget {text}" for text in widgets.values())
    out.extend(f"  poi {key}" for key in pois)
    out.extend(f"  vignette {key} ({count} changes)" for key, count in vignettes.items())
    out.extend(f"  flag changes {key}: {count}" for key, count in flags.items())
    out.extend(comms)
    return out


def performance(session: dict) -> list[str]:
    stages = session.get("stages") or {}
    out = ["Highground stage time (guarded callbacks)"]
    ranked = sorted(((name, row) for name, row in stages.items() if isinstance(row, dict)),
                    key=lambda item: -(item[1].get("ms") or 0))
    for name, row in ranked[:12]:
        calls, ms = row.get("calls") or 0, row.get("ms") or 0
        out.append(f"  {name:40.40s} {ms:9.1f} ms  {calls:7d} calls  avg {ms / max(calls, 1):.3f}  max {row.get('maxMS') or 0:.1f}")
    errors = session.get("errors") or []
    out.append(f"Errors: {len(errors)}")
    out.extend(f"  {e}" for e in errors)
    return out


def header(session: dict, number_: int) -> list[str]:
    m = session.get("map") or {}
    counts = session.get("counts") or {}
    duration = session.get("duration")
    kinds = ", ".join(f"{k} {v}" for k, v in sorted(counts.items(), key=lambda kv: -kv[1]))
    return [f"Session {number_}: {m.get('name', '?')} ({m.get('id', '?')}, {m.get('kind', '?')}, {m.get('mode', '?')}) "
            f"{session.get('date', '?')}",
            f"  {session.get('game')}/{session.get('client')} {session.get('locale')} build {session.get('build')} "
            f"Highground {session.get('addon')}",
            f"  length {clock(duration) if isinstance(duration, (int, float)) else 'open'}, stopped: {session.get('stop', 'still open')}, "
            f"rows {len(session.get('rows') or [])}, dropped {session.get('dropped', 0)}",
            f"  rows by kind: {kinds}"]


def report(session: dict, number_: int = 1) -> str:
    sections = [header(session, number_), resurrection(session), bases(session), prediction(session),
                chat(session), world(session), performance(session)]
    return "\n\n".join("\n".join(section) for section in sections)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("path", nargs="?", default=os.environ.get("HIGHGROUND_SAVED"),
                        help="SavedVariables/Highground.lua (default: $HIGHGROUND_SAVED)")
    parser.add_argument("--session", type=int, default=1, help="1 = newest (default), 0 = all")
    parser.add_argument("--timeline", action="store_true", help="print the rows instead of the report")
    parser.add_argument("--kinds", help="with --timeline: comma-separated kinds to keep")
    parser.add_argument("--json", action="store_true", help="print the sessions as JSON")
    args = parser.parse_args(argv)
    if not args.path:
        parser.error("give the SavedVariables file or set HIGHGROUND_SAVED")
    sessions = load_sessions(Path(args.path))
    if not sessions:
        print("No battleground recordings. Record one with /hg bg profiler start, then /reload.", file=sys.stderr)
        return 1
    if args.session < 0 or args.session > len(sessions):
        parser.error(f"--session must be 0..{len(sessions)}")
    chosen = list(enumerate(sessions, 1)) if args.session == 0 else [(args.session, sessions[args.session - 1])]
    if args.json:
        print(json.dumps([s for _, s in chosen], indent=1, ensure_ascii=False))
        return 0
    kinds = set(args.kinds.split(",")) if args.kinds else None
    for index, session in chosen:
        if args.timeline:
            for t, kind, text in rows(session):
                if not kinds or kind in kinds:
                    print(f"{clock(t):>6} {kind:8s} {text}")
        else:
            print(report(session, index))
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
