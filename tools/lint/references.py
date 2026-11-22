"""Resolve module aliases in Lua tokens so member references can be matched across files.

Addon files alias shared tables (local P, U = ns.Peers, ns.Util; local M = {}
followed by ns.Modules = M). A member access such as P.Status resolves to
"ns.Peers.Status"; an access through a parameter, call result or other
unknown value (self:Status(), Get().Status) resolves to (None, "Status") and
may reach any member of that name. Used by dead.py; tokens come from
scopes.tokenize.
"""
from __future__ import annotations

from collections import Counter

ENDS = {"(", "[", ":", "{", "."}


def dotted(tokens: list, i: int) -> tuple[list[str], int]:
    """Names of a plain NAME(.NAME)* path starting at i, and the index after it."""
    if tokens[i][0] != "name":
        return [], i
    parts = [tokens[i][1]]
    while tokens[i + 1][1] == "." and tokens[i + 2][0] == "name":
        parts.append(tokens[i + 2][1])
        i += 2
    return parts, i + 1


def closing(tokens: list, i: int) -> int:
    """Index after the bracket that closes the one at i."""
    depth = 0
    for j in range(i, len(tokens)):
        if tokens[j][1] in {"(", "[", "{"} and tokens[j][0] == "op":
            depth += 1
        elif tokens[j][1] in {")", "]", "}"} and tokens[j][0] == "op":
            depth -= 1
            if depth == 0:
                return j + 1
    return len(tokens)


class Resolver:
    def __init__(self, path: str, tokens: list, free: set[str]):
        self.path, self.tokens, self.free = path, tokens, free
        self.aliases: dict[str, str | None] = {"ns": "ns"}
        self.collect()

    def canonical(self, parts: list[str]) -> str | None:
        root = parts[0]
        if root in self.aliases:
            base = self.aliases[root]
        elif root in self.free:
            base = root  # a global table such as C_Timer
        else:
            return None  # a parameter or other local value
        return None if base is None else ".".join([base, *parts[1:]])

    def bind(self, name: str, value: str | None) -> None:
        if name == "ns":
            return  # always the addon namespace (local _, ns = ...)
        # One name aliasing two different tables in a file is ambiguous.
        if name in self.aliases and self.aliases[name] != value:
            value = None
        self.aliases[name] = value

    def collect(self) -> None:
        tokens = self.tokens
        for i, (kind, value, _) in enumerate(tokens):
            if value == "local" and kind == "keyword" and tokens[i + 1][0] == "name":
                names, j = [tokens[i + 1][1]], i + 2
                while tokens[j][1] == "," and tokens[j + 1][0] == "name":
                    names.append(tokens[j + 1][1])
                    j += 2
                if tokens[j][1] != "=":
                    continue
                j += 1
                for name in names:
                    parts, after = dotted(tokens, j)
                    if parts and tokens[after][1] not in ENDS and tokens[after][0] != "string":
                        self.bind(name, self.canonical(parts))
                    elif tokens[j][1] == "{":
                        self.bind(name, f"{self.path}#{name}")
                        after = closing(tokens, j)
                    else:
                        # A value we do not follow (a call, such as setmetatable):
                        # treat it as this file's own table. Later names stay unknown.
                        self.bind(name, f"{self.path}#{name}")
                        for other in names[names.index(name) + 1:]:
                            self.bind(other, None)
                        break
                    if tokens[after][1] != ",":
                        break
                    j = after + 1
        # ns.Peers = P publishes a file's table under a shared name.
        for i in range(len(tokens) - 3):
            if tokens[i][0] == "name" and (i == 0 or tokens[i - 1][1] not in {".", ":", "local"}):
                target, after = dotted(tokens, i)
                if len(target) > 1 and tokens[after][1] == "=" and tokens[after + 1][0] == "name":
                    source, end = dotted(tokens, after + 1)
                    own = self.aliases.get(source[0], "")
                    if len(source) == 1 and tokens[end][1] not in ENDS and (own is None or own.startswith(self.path + "#")):
                        resolved = self.canonical(target)
                        if resolved and "#" not in resolved:  # shared names only, not Class.__index
                            self.aliases[source[0]] = resolved

    def table(self, parts: list[str]) -> str:
        """Canonical table for a definition; unknown roots stay private to this file."""
        return self.canonical(parts) or f"{self.path}#{'.'.join(parts)}"

    def accesses(self) -> Counter:
        """(canonical table or None, member) for every .member and :member access."""
        found, tokens = Counter(), self.tokens
        for i, (kind, value, _) in enumerate(tokens):
            if value in {".", ":"} and kind == "op" and tokens[i + 1][0] == "name" and i and (
                    tokens[i - 1][1] in {")", "]", "}"} and tokens[i - 1][0] == "op" or tokens[i - 1][0] == "string"):
                found[(None, tokens[i + 1][1])] += 1  # member of a call result, index or literal
            if kind != "name" or i and tokens[i - 1][1] in {".", ":"} and tokens[i - 1][0] == "op":
                continue
            parts, k = [value], i
            while tokens[k + 1][1] in {".", ":"} and tokens[k + 1][0] == "op" and tokens[k + 2][0] == "name":
                member = tokens[k + 2][1]
                found[(self.canonical(parts), member)] += 1
                if tokens[k + 1][1] == ":":
                    break
                parts.append(member)
                k += 2
        return found
