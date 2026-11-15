#!/bin/sh
# SPDX-FileCopyrightText: 2026 OpenSerbia
# SPDX-License-Identifier: MIT
#
# usage: dep-count.sh <sbom.cdx.json> <run-id> <YYYY-MM-DD> <arch> <digest> <major>
#
# Print one TSV row for the Wolfi packages syft recorded in a CycloneDX SBOM:
# run_id, date, major, arch, package count, postgresql-N version, digest.
# A package is a component whose purl is pkg:apk/…. The version comes from the
# purl of postgresql-<major> itself, not the -client or -contrib packages.
# Syft writes compact JSON on one line; pretty-printed input works too.
set -eu

if [ "$#" -ne 6 ]; then
  echo "usage: $0 <sbom.cdx.json> <run-id> <YYYY-MM-DD> <arch> <digest> <major>" >&2
  exit 2
fi

sbom=$1
run_id=$2
day=$3
arch=$4
digest=$5
major=$6

case $run_id in
  *[!0-9]*|'') echo "dep-count: run id must be digits" >&2; exit 2 ;;
esac
case $day in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
  *) echo "dep-count: date must be YYYY-MM-DD" >&2; exit 2 ;;
esac
case $arch in
  amd64|arm64) ;;
  *) echo "dep-count: arch must be amd64 or arm64" >&2; exit 2 ;;
esac
case $digest in
  sha256:*) hex=${digest#sha256:} ;;
  *) echo "dep-count: digest must be sha256 and 64 hex chars" >&2; exit 2 ;;
esac
case $hex in
  *[!0-9a-f]*|'') echo "dep-count: digest must be sha256 and 64 hex chars" >&2; exit 2 ;;
esac
if [ "${#hex}" -ne 64 ]; then
  echo "dep-count: digest must be sha256 and 64 hex chars" >&2
  exit 2
fi
case $major in
  *[!0-9]*|'') echo "dep-count: major must be digits" >&2; exit 2 ;;
esac

if [ ! -f "$sbom" ]; then
  echo "dep-count: SBOM not found: $sbom" >&2
  exit 2
fi

row=$(awk -v major="$major" '
function take(m,    i, p, name, ver) {
  i = index(m, "pkg:apk/")
  if (i == 0) return
  p = substr(m, i)
  sub(/".*/, "", p)
  sub(/^pkg:apk\/[^\/]*\//, "", p)
  name = p
  sub(/[@?].*/, "", name)
  ver = ""
  if (index(p, "@") > 0) {
    ver = p
    sub(/^[^@]*@/, "", ver)
    sub(/\?.*/, "", ver)
  }
  pkgs++
  if (name == "postgresql-" major) pg = ver
}
# syft writes the whole SBOM on ONE line, so walk every purl on the line, not
# just the first. Anchor on the "purl" key: syft bom-ref values also start with
# pkg:apk/ and would count each package twice.
{
  s = $0
  while (match(s, /"purl"[[:space:]]*:[[:space:]]*"pkg:apk\/[^"]*"/)) {
    take(substr(s, RSTART, RLENGTH))
    s = substr(s, RSTART + RLENGTH)
  }
}
END {
  if (pkgs < 1 || pg == "") exit 1
  print pkgs "\t" pg
}
' "$sbom") || {
  echo "dep-count: SBOM has no postgresql-$major apk package" >&2
  exit 1
}

printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$run_id" "$day" "$major" "$arch" "$row" "$digest"
