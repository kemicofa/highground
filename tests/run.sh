#!/usr/bin/env bash
# Repository test runner. For each addon (all of addons/, or the ones named):
# its own validator and Lua tests, run from its folder. Then the repository's
# Python tests for packaging and release (tests/test_*.py), which are quick.
# CI runs one addon per workflow, so each addon's tests run once per push.
#   bash tests/run.sh               # every addon
#   bash tests/run.sh Highground    # one addon
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v luajit >/dev/null 2>&1; then
  echo "Tests require LuaJIT (Lua 5.1 semantics, matching WoW)." >&2
  exit 1
fi
if [ "$#" -eq 0 ]; then
  addons=(addons/*/)
else
  addons=()
  for name in "$@"; do
    [ -d "addons/$name" ] || { echo "Unknown addon: $name" >&2; exit 1; }
    addons+=("addons/$name/")
  done
fi
for addon in "${addons[@]}"; do
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
echo "== packaging and release"
python3 -m unittest discover -s tests -p 'test_*.py'
