#!/bin/sh
# SPDX-FileCopyrightText: 2026 OpenSerbia
# SPDX-License-Identifier: MIT
#
# usage: trivy-gate.sh <image-ref>
#
# One Trivy scan of the image, then scripts/trivy-gate.awk decides the gate.
# Fails when Trivy itself fails, when the report is not a Wolfi image with at
# least one OS package, or when any CRITICAL vulnerability or secret is present.
# HIGH findings are printed and do not fail the build.
#
# The cache directory is per image ref under .trivycache/, so concurrent matrix
# legs on one runner do not share ~/.cache/trivy. The vulnerability DB is still
# updated on every run. A repo .trivyignore is not read: the gate passes an
# ignore file that is never created, and a missing file makes Trivy apply no
# ignores. Unfixed CRITICALs still fail (there is no --ignore-unfixed).
set -eu

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "usage: $0 <image-ref>" >&2
  exit 2
fi
ref=$1

root=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
safe=$(printf '%s' "$ref" | tr -c 'A-Za-z0-9._-' '_')
cache="$root/.trivycache/$safe"
report=$(mktemp)

# Flags on the command line win, but drop env that would weaken this scan if a
# future Trivy build prefers the environment.
unset TRIVY_CACHE_DIR TRIVY_EXIT_CODE TRIVY_IGNOREFILE TRIVY_IGNORE_UNFIXED \
  TRIVY_OFFLINE_SCAN TRIVY_SEVERITY TRIVY_SKIP_DB_UPDATE TRIVY_QUIET || true

mkdir -p "$cache"
trap 'rm -f "$report"' EXIT

trivy image \
  --cache-dir "$cache" \
  --scanners vuln,secret \
  --pkg-types os,library \
  --disable-telemetry \
  --skip-version-check \
  --list-all-pkgs \
  --severity UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL \
  --exit-code 0 \
  --ignorefile "$cache/no-ignore" \
  --timeout 10m \
  --format json \
  --output "$report" \
  "$ref"

if [ ! -s "$report" ]; then
  echo "trivy-gate: Trivy wrote an empty report" >&2
  exit 1
fi

awk -f "$root/scripts/trivy-gate.awk" "$report"
