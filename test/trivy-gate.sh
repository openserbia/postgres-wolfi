#!/bin/sh
# SPDX-FileCopyrightText: 2026 OpenSerbia
# SPDX-License-Identifier: MIT
# Fixture checks for scripts/trivy-gate.awk. No Trivy binary and no image.
set -eu

root=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
awkf=$root/scripts/trivy-gate.awk
fix=$root/test/trivy-gate
err=$(mktemp)
trap 'rm -f "$err"' EXIT

expect() {
  name="$1"
  want="$2"
  file="$3"
  needle="$4"
  got=0
  # A failing awk gate is the case under test. Save its status explicitly.
  set +e
  out=$(awk -f "$awkf" "$file" 2>"$err")
  got=$?
  set -e
  if [ "$got" -ne "$want" ]; then
    echo "FAIL $name: exit $got, want $want" >&2
    echo "$out" >&2
    cat "$err" >&2
    exit 1
  fi
  printf '%s\n' "$out" | grep -q -F -- "$needle" || {
    echo "FAIL $name: missing [$needle]" >&2
    echo "$out" >&2
    cat "$err" >&2
    exit 1
  }
  echo "ok $name"
}

expect high-only 0 "$fix/high-only.json" "trivy-gate: family=wolfi packages=2 critical=0 high=1"
expect high-only-line 0 "$fix/high-only.json" "HIGH vuln CVE-2024-2 libfoo 1.0 a title with a { brace"
expect critical-vuln 1 "$fix/critical-vuln.json" "CRITICAL vuln CVE-2024-1 libfoo 1.2.3"
expect critical-secret 1 "$fix/critical-secret.json" "CRITICAL secret aws-access-key-id AWS Access Key"
expect debian 1 "$fix/debian.json" "trivy-gate: family=debian packages=1 critical=0 high=0"
expect no-packages 1 "$fix/no-packages.json" "trivy-gate: family=wolfi packages=0 critical=0 high=0"
expect library-only 1 "$fix/library-only.json" "trivy-gate: family=wolfi packages=0 critical=0 high=0"
expect os-plus-library 0 "$fix/os-plus-library.json" "trivy-gate: family=wolfi packages=1 critical=0 high=0"
expect empty 1 "$fix/empty.json" "trivy-gate: family= packages=0 critical=0 high=0"

# stderr reasons for the failing cases
set +e
awk -f "$awkf" "$fix/critical-vuln.json" >/dev/null 2>"$err"
set -e
grep -q -F "1 CRITICAL finding(s)" "$err"
set +e
awk -f "$awkf" "$fix/debian.json" >/dev/null 2>"$err"
set -e
grep -q -F "OS family is debian, want wolfi" "$err"
set +e
awk -f "$awkf" "$fix/no-packages.json" >/dev/null 2>"$err"
set -e
grep -q -F "Wolfi OS package count is 0" "$err"
set +e
awk -f "$awkf" "$fix/empty.json" >/dev/null 2>"$err"
set -e
grep -q -F "0 OS family fields" "$err"
set +e
awk -f "$awkf" "$fix/truncated.json" >/dev/null 2>"$err"
got=$?
set -e
if [ "$got" -ne 1 ]; then
  echo "FAIL truncated: exit $got, want 1" >&2
  cat "$err" >&2
  exit 1
fi
grep -q -F "truncated or malformed" "$err" || {
  echo "FAIL truncated: missing malformed diagnostic" >&2
  cat "$err" >&2
  exit 1
}
echo "ok truncated"

echo "trivy-gate fixtures passed"
