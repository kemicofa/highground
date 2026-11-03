#!/usr/bin/env bash
# Repository test runner. For each addon (all of addons/, or the ones named):
# its own validator and Lua tests, run from its folder. Then the repository's
# Python tests for packaging, release and cross-addon integration.
# CI separates addon tests from repository tests so each suite runs once.
#   bash tests/run.sh                           # every addon and repository tests
#   bash tests/run.sh Highground                # one addon and repository tests
#   bash tests/run.sh --addons-only Highground  # only this addon's tests
#   bash tests/run.sh --repository-only         # only repository tests
set -euo pipefail
cd "$(dirname "$0")/.."
mode=all
case "${1:-}" in
  --addons-only) mode=addons; shift ;;
  --repository-only) mode=repository; shift ;;
esac
if [ "$mode" = repository ] && [ "$#" -ne 0 ]; then
  echo "--repository-only does not accept addon names" >&2
  exit 1
fi
if ! command -v luajit >/dev/null 2>&1; then
  echo "Tests require LuaJIT (Lua 5.1 semantics, matching WoW)." >&2
  exit 1
fi
if [ "$mode" = repository ]; then
  addons=()
elif [ "$#" -eq 0 ]; then
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
if [ "$mode" != addons ]; then
  echo "== packaging, release and cross-addon integration"
  python3 -m unittest discover -s tests -p 'test_*.py'
fi
