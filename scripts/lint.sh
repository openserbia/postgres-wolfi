#!/bin/sh
# SPDX-FileCopyrightText: 2026 OpenSerbia
# SPDX-License-Identifier: MIT
#
# Same checks as .github/workflows/lint.yml. shellcheck comes from PATH
# (devbox pin 0.11.0 locally, the runner image in CI). hadolint is the pinned
# v2.15.1 release, cached under .hadolint/ after its sha256 matches.
# docker-entrypoint.sh is vendored and is not linted.
set -eu

root=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
cd "$root"

shellcheck test/*.sh scripts/*.sh .github/scripts/*.sh
./test/trivy-gate.sh
./test/dep-history.sh

version=v2.15.1
case $(uname -m) in
  x86_64) asset=hadolint-linux-x86_64; sha=c7187db94eeeeca956519a6af171adc31453941a1e777961f6e680f697c8c507 ;;
  aarch64) asset=hadolint-linux-arm64; sha=f6198ef8090f404dbb771abfee086eb8c48ac177f30da7fd3510aca35b344b5d ;;
  *)
    echo "lint: unsupported arch $(uname -m); hadolint pin is linux x86_64 or arm64" >&2
    exit 1
    ;;
esac

cache=$root/.hadolint
bin=$cache/hadolint-$version-$asset
mkdir -p "$cache"
if ! echo "$sha  $bin" | sha256sum -c - >/dev/null 2>&1; then
  tmp=$(mktemp "$cache/hadolint.XXXXXX")
  trap 'rm -f "$tmp"' EXIT
  curl -fsSL -o "$tmp" "https://github.com/hadolint/hadolint/releases/download/$version/$asset"
  echo "$sha  $tmp" | sha256sum -c -
  chmod +x "$tmp"
  mv "$tmp" "$bin"
  trap - EXIT
fi
"$bin" Dockerfile
