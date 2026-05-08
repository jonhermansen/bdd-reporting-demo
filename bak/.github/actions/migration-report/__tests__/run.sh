#!/usr/bin/env bash
# Golden tests for migration-report.
# For each fixture/<name>/, run the jq script against pre.ctrf.json and
# post.ctrf.json, then diff stdout against expected.md.
#
# To regenerate goldens after an intentional rendering change:
#   UPDATE_GOLDEN=1 ./run.sh
set -euo pipefail

cd "$(dirname "$0")"
ROOT="$(cd ../../../.. && pwd)"
JQ_SCRIPT="$(cd .. && pwd)/migration.jq"

pass=0
fail=0
failed_cases=()

for fixture in fixtures/*/; do
  name="$(basename "$fixture")"
  pre="$fixture/pre.ctrf.json"
  post="$fixture/post.ctrf.json"
  expected="$fixture/expected.md"

  if [ ! -f "$pre" ] || [ ! -f "$post" ] || [ ! -f "$expected" ]; then
    echo "SKIP $name (missing pre/post/expected)"
    continue
  fi

  actual="$(jq -nr --slurpfile pre "$pre" --slurpfile post "$post" -f "$JQ_SCRIPT")"

  if [ "${UPDATE_GOLDEN:-0}" = "1" ]; then
    printf '%s\n' "$actual" > "$expected"
    echo "UPDATED $name"
    continue
  fi

  if diff -u <(printf '%s\n' "$actual") "$expected" > /tmp/migration-report-diff.$$ 2>&1; then
    echo "PASS $name"
    pass=$((pass+1))
  else
    echo "FAIL $name"
    cat /tmp/migration-report-diff.$$
    rm -f /tmp/migration-report-diff.$$
    fail=$((fail+1))
    failed_cases+=("$name")
  fi
done

echo
echo "Results: $pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
  echo "Failed cases: ${failed_cases[*]}"
  exit 1
fi
