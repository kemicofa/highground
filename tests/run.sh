#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v luajit >/dev/null 2>&1; then
  echo "Tests require LuaJIT (Lua 5.1 semantics, matching WoW)." >&2
  exit 1
fi
python3 tests/validate.py
for test in tests/*_test.lua; do
  luajit "$test"
done
