"""Scope checks for Lua 5.1 source: unused locals, shadowing and per-frame allocations.

A small tokenizer and recursive-descent parser tracking only names and scopes,
for code LuaJIT compiles. Each finding is (line, rule, name, message).

- unused: a local or local function never read (recursion aside); parameters,
  loop variables and names starting with "_" are exempt.
- shadow: a local or parameter that hides another of the same name visible
  at that point (including upvalues); "self" and "_" names are exempt.
- hot-alloc: a table constructor, closure, string concatenation or string
  building call (format, concat, tostring, gsub, rep) inside a function the
  file registers as an OnUpdate handler. A heuristic: the allocation may sit
  in a branch that rarely runs, and callees are not followed.

Checker.declared maps file-level locals to their line, for lint.py's check of
global reads before such a declaration (calling a local function too early).
"""
from __future__ import annotations

import re

KEYWORDS = {"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local",
            "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"}
TOKEN = re.compile(r"""
    (?P<space>[ \t\r\f\v]+) | (?P<newline>\n)
  | (?P<long>--\[(?P<ceq>=*)\[ | \[(?P<seq>=*)\[)
  | (?P<comment>--[^\n]*)
  | (?P<string>"(?:\\(?:\n|.)|[^"\\\n])*"|'(?:\\(?:\n|.)|[^'\\\n])*')
  | (?P<number>0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)
  | (?P<name>[A-Za-z_]\w*)
  | (?P<op>\.\.\.|\.\.|==|~=|<=|>=|[-+*/%^\#<>=(){}\[\];:,.])
""", re.X)
UNARY = {"-", "not", "#"}
BINARY = {"+", "-", "*", "/", "%", "^", "..", "==", "~=", "<", "<=", ">", ">=", "and", "or"}
STRING_BUILDERS = {"format", "concat", "tostring", "gsub", "rep", "strjoin", "strconcat"}


def tokenize(text: str) -> list[tuple[str, str, int]]:
    """(kind, value, line) tokens without whitespace or comments; kind is name, keyword, string, number or op."""
    tokens, position, line = [], 0, 1
    while position < len(text):
        match = TOKEN.match(text, position)
        if not match:
            raise SyntaxError(f"line {line}: unexpected {text[position]!r}")
        kind, value = match.lastgroup, match.group()
        if kind == "long" or kind in {"ceq", "seq"}:
            equals = match.group("ceq") if match.group("ceq") is not None else match.group("seq")
            close = text.find("]" + equals + "]", match.end())
            if close < 0:
                raise SyntaxError(f"line {line}: unfinished long string or comment")
            value = text[position:close + len(equals) + 2]
            if not value.startswith("--"):
                tokens.append(("string", value, line))
            line += value.count("\n")
            position = close + len(equals) + 2
            continue
        if kind == "newline":
            line += 1
        elif kind == "name":
            tokens.append(("keyword" if value in KEYWORDS else "name", value, line))
        elif kind in {"string", "number", "op"}:
            tokens.append((kind, value, line))
            line += value.count("\n")
        position = match.end()
    tokens.append(("eof", "<eof>", line))
    return tokens


class Variable:
    def __init__(self, name: str, line: int, kind: str, function: int):
        self.name, self.line, self.kind, self.function, self.read = name, line, kind, function, False
        self.defining = False  # inside its own body: recursion alone does not use a local function


class Checker:
    def __init__(self, text: str):
        self.tokens, self.index = tokenize(text), 0
        self.scopes: list[dict[str, Variable]] = []
        self.functions = 1               # nesting depth of function bodies, counting the chunk
        self.hot: list[bool] = [False]  # per function body: registered as OnUpdate
        self.findings: list[tuple[int, str, str, str]] = []
        self.declared: dict[str, int] = {}
        self.free: set[str] = set()  # names used as globals
        self.handlers = self.update_handlers()

    def peek(self, offset: int = 0) -> tuple[str, str, int]:
        return self.tokens[min(self.index + offset, len(self.tokens) - 1)]

    def check(self, value: str) -> bool:
        kind, current, _ = self.peek()
        return current == value and kind in {"keyword", "op"}

    def accept(self, value: str) -> bool:
        if self.check(value):
            self.index += 1
            return True
        return False

    def expect(self, value: str) -> None:
        if not self.accept(value):
            kind, current, line = self.peek()
            raise SyntaxError(f"line {line}: expected {value!r} near {current!r}")

    def name(self) -> tuple[str, int]:
        kind, value, line = self.peek()
        if kind != "name":
            raise SyntaxError(f"line {line}: expected a name near {value!r}")
        self.index += 1
        return value, line

    def update_handlers(self) -> set[str]:
        """Names passed as OnUpdate scripts: SetScript("OnUpdate", Name) or HookScript."""
        names = set()
        values = [value for _, value, _ in self.tokens]
        for i, value in enumerate(values[:-6]):
            if value in {"SetScript", "HookScript"} and values[i + 1] == "(" \
                    and values[i + 2][1:-1] == "OnUpdate" and values[i + 3] == ",":
                j = i + 4
                while values[j + 1] == "." and j + 2 < len(values):
                    j += 2
                if self.tokens[j][0] == "name" and values[j + 1] == ")":
                    names.add(values[j])
        return names

    def open(self) -> None:
        self.scopes.append({})

    def close(self) -> None:  # reports unused locals as their scope ends
        for variable in self.scopes.pop().values():
            self.finish(variable)

    def finish(self, variable: Variable) -> None:
        if not variable.read and variable.kind in {"local", "function"} and not variable.name.startswith("_"):
            what = "local function" if variable.kind == "function" else "local"
            self.findings.append((variable.line, "unused", variable.name, f"unused {what} '{variable.name}'"))

    def declare(self, name: str, line: int, kind: str) -> Variable:
        if not name.startswith("_") and name != "self":
            for scope in reversed(self.scopes):
                outer = scope.get(name)
                if outer:
                    where = "an upvalue" if outer.function < self.functions else "a local"
                    self.findings.append((line, "shadow", name, f"'{name}' shadows {where} from line {outer.line}"))
                    break
        scope = self.scopes[-1]
        if len(self.scopes) == 1:
            self.declared.setdefault(name, line)
        if name in scope:
            self.finish(scope[name])
        scope[name] = Variable(name, line, kind, self.functions)
        return scope[name]

    def resolve(self, name: str, read: bool = True) -> None:
        for scope in reversed(self.scopes):
            if name in scope:
                if read and not scope[name].defining:
                    scope[name].read = True
                return
        self.free.add(name)

    def allocation(self, line: int, what: str) -> None:
        if self.hot and self.hot[-1]:
            self.findings.append((line, "hot-alloc", what, f"{what} in an OnUpdate handler allocates every frame"))

    def chunk(self) -> list[tuple[int, str, str, str]]:
        self.open()
        self.block()
        if self.peek()[0] != "eof":
            raise SyntaxError(f"line {self.peek()[2]}: unexpected {self.peek()[1]!r}")
        self.close()
        return sorted(self.findings)

    def closing(self) -> bool:
        return self.peek()[0] == "eof" or any(self.check(word) for word in ("end", "else", "elseif", "until"))

    def block(self) -> None:
        while not self.closing():
            if self.accept("return"):
                if not (self.closing() or self.check(";")):
                    self.explist()
                self.accept(";")
                return
            self.statement()
            self.accept(";")

    def scoped_block(self, closing: str | None = None) -> None:
        self.open()
        self.block()
        self.close()
        if closing:
            self.expect(closing)

    def statement(self) -> None:
        if self.accept("local"):
            if self.accept("function"):
                name, line = self.name()
                variable = self.declare(name, line, "function")
                variable.defining = True
                self.body(line, hot=name in self.handlers)
                variable.defining = False
                return
            names = [self.name()]
            while self.accept(","):
                names.append(self.name())
            if self.accept("="):
                self.explist()
            for name, at in names:
                self.declare(name, at, "local")
        elif self.accept("function"):
            name, at = self.name()
            self.resolve(name)
            last, method = name, False
            while self.check(".") or self.check(":"):
                method = self.check(":")
                self.index += 1
                last = self.name()[0]
                if method:
                    break
            self.body(at, method=method, hot=last in self.handlers)
        elif self.accept("if"):
            self.expression()
            self.expect("then")
            self.scoped_block()
            while self.accept("elseif"):
                self.expression()
                self.expect("then")
                self.scoped_block()
            if self.accept("else"):
                self.scoped_block()
            self.expect("end")
        elif self.accept("while"):
            self.expression()
            self.expect("do")
            self.scoped_block("end")
        elif self.accept("do"):
            self.scoped_block("end")
        elif self.accept("for"):
            names = [self.name()]
            if self.accept("="):
                self.explist()
            else:
                while self.accept(","):
                    names.append(self.name())
                self.expect("in")
                self.explist()
            self.expect("do")
            self.open()
            for name, at in names:
                self.declare(name, at, "loop")
            self.block()
            self.close()
            self.expect("end")
        elif self.accept("repeat"):
            # The until condition sees the loop body's locals.
            self.open()
            self.block()
            self.expect("until")
            self.expression()
            self.close()
        elif not self.accept("break"):
            self.expression_statement()

    def expression_statement(self) -> None:
        targets = [self.suffixed(assignment=True)]
        while self.accept(","):
            targets.append(self.suffixed(assignment=True))
        if self.accept("="):
            self.explist()

    def body(self, line: int, method: bool = False, hot: bool = False) -> None:
        self.functions += 1
        self.hot.append(hot)
        self.open()
        if method:
            self.declare("self", line, "parameter")
        self.expect("(")
        while not self.check(")"):
            if self.accept("..."):
                break
            name, at = self.name()
            self.declare(name, at, "parameter")
            if not self.accept(","):
                break
        self.expect(")")
        self.block()
        self.expect("end")
        self.close()
        self.hot.pop()
        self.functions -= 1

    def explist(self) -> None:
        self.expression()
        while self.accept(","):
            self.expression()

    def expression(self) -> None:
        while self.peek()[1] in UNARY and self.peek()[0] in {"op", "keyword"}:
            self.index += 1
        self.simple()
        while self.peek()[1] in BINARY and self.peek()[0] in {"op", "keyword"}:
            _, operator, line = self.peek()
            self.index += 1
            if operator == "..":
                self.allocation(line, "string concatenation")
            while self.peek()[1] in UNARY and self.peek()[0] in {"op", "keyword"}:
                self.index += 1
            self.simple()

    def simple(self) -> None:
        kind, value, line = self.peek()
        if kind in {"number", "string"} or value in {"nil", "true", "false", "..."}:
            self.index += 1
        elif self.check("{"):
            self.table()
        elif self.accept("function"):
            self.allocation(line, "closure")
            self.body(line, hot=self.handler_argument())
        else:
            self.suffixed()

    def handler_argument(self) -> bool:
        """Whether the function literal just opened is SetScript("OnUpdate", function ...)'s handler."""
        values = [self.tokens[self.index - n][1] for n in range(2, 6)] if self.index >= 5 else []
        return values[:3] == [",", '"OnUpdate"', "("] or values[:3] == [",", "'OnUpdate'", "("]

    def table(self) -> None:
        _, _, line = self.peek()
        self.expect("{")
        self.allocation(line, "table constructor")
        while not self.check("}"):
            if self.accept("["):
                self.expression()
                self.expect("]")
                self.expect("=")
                self.expression()
            elif self.peek()[0] == "name" and self.peek(1)[1] == "=" and self.peek(1)[0] == "op":
                self.index += 2
                self.expression()
            else:
                self.expression()
            if not (self.accept(",") or self.accept(";")):
                break
        self.expect("}")

    def suffixed(self, assignment: bool = False) -> None:
        kind, value, line = self.peek()
        if kind == "name":
            self.index += 1
            plain = True
        elif self.accept("("):
            self.expression()
            self.expect(")")
            plain, value = False, None
        else:
            raise SyntaxError(f"line {line}: unexpected {value!r}")
        first, read, last = value, not assignment, value
        while True:
            if self.accept("."):
                last = self.name()[0]
            elif self.accept("["):
                self.expression()
                self.expect("]")
                last = None
            elif self.accept(":"):
                last, at = self.name()
                self.call(last, at)
            elif self.check("(") or self.check("{") or self.peek()[0] == "string":
                self.call(last, self.peek()[2])
                last = None
            else:
                break
            read = True  # indexing or calling a variable reads it
        if plain and first:
            self.resolve(first, read=read or not (self.check("=") or self.check(",")))

    def call(self, name: str | None, line: int) -> None:
        if name in STRING_BUILDERS:
            self.allocation(line, f"{name}()")
        self.arguments()

    def arguments(self) -> None:
        if self.peek()[0] == "string":
            self.index += 1
        elif self.check("{"):
            self.table()
        else:
            self.expect("(")
            if not self.check(")"):
                self.explist()
            self.expect(")")


def analyse(text: str) -> tuple[list[tuple[int, str, str, str]], dict[str, int]]:
    """One file's findings, sorted by line, and the first line declaring each local name."""
    checker = Checker(text)
    return checker.chunk(), checker.declared


def check(text: str) -> list[tuple[int, str, str, str]]:
    return analyse(text)[0]
