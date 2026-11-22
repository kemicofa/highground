#!/usr/bin/env bash
# Repository test runner. For each addon (all of addons/, or the ones named):
# its own validator and Lua tests, run from its folder. Then the repository's
# Python tests for packaging, release and cross-addon integration.
# CI separates addon tests from repository tests so each suite runs once.
#   bash tests/run.sh                           # every addon and repository tests
#   bash tests/run.sh Highground                # one addon and repository tests
#   bash tests/run.sh --addons-only Highground  # only this addon's tests
#   bash tests/run.sh --repository-only         # only repository tests
#   bash tests/run.sh --jobs 4                  # up to four Lua suites at once
#   bash tests/run.sh --addons-only --coverage  # Lua coverage report in coverage/ (slow)
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 scripts/run_tests.py "$@"
