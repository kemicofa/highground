#!/usr/bin/env bash
# Every addon's own checks (run from its folder), then the repository's
# packaging and release tests.
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v luajit >/dev/null 2>&1; then
  echo "Tests require LuaJIT (Lua 5.1 semantics, matching WoW)." >&2
  exit 1
fi
for addon in addons/*/; do
  [ -d "$addon/tests" ] || continue
  echo "== ${addon%/}"
  (
    cd "$addon"
    if [ -f tests/validate.py ]; then python3 tests/validate.py; fi
    for test in tests/*_test.lua; do
      luajit "$test"
    done
  )
done
python3 -m unittest discover -s tests -p 'test_*.py'
