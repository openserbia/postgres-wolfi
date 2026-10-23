#!/bin/sh
# SPDX-FileCopyrightText: 2026 OpenSerbia
# SPDX-License-Identifier: MIT
#
# usage: publish-dep-history.sh <counts-dir>
#
# Read every row.tsv under counts-dir (one per published build leg), merge
# them into history.tsv on the metrics branch, and rewrite that branch's
# README.md. No rows is a no-op. An unchanged series is not pushed.
#
# The clone is anonymous. The token is used only on the push command.
# Commit identity is github-actions[bot], and only for this commit.
#
# Env:
#   GITHUB_REPOSITORY     owner/name, used when DEP_HISTORY_REMOTE is unset
#   GITHUB_TOKEN          required for the GitHub push
#   DEP_HISTORY_REMOTE    clone URL (tests). Default is the public GitHub URL
#   DEP_HISTORY_PUSH_URL  push URL (tests). Default is the token URL
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <counts-dir>" >&2
  exit 2
fi

counts=$1
if [ ! -d "$counts" ]; then
  echo "dep-history: counts dir not found: $counts" >&2
  exit 2
fi

root=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
hist=$root/scripts/dep-history.sh
export GIT_TERMINAL_PROMPT=0

is_repo() {
  printf '%s' "$1" | awk '
    BEGIN { found = 0 }
    /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/ { found = 1 }
    END { exit !found }
  '
}

work=
newtsv=
list=
empty=
cleanup() {
  cd /
  if [ -n "$work" ]; then rm -rf "$work"; fi
  if [ -n "$newtsv" ]; then rm -f "$newtsv"; fi
  if [ -n "$list" ]; then rm -f "$list"; fi
  if [ -n "$empty" ]; then rm -f "$empty"; fi
}
trap cleanup EXIT

list=$(mktemp)
# No pipe: under `set -e` a failing find would otherwise be hidden by sort.
find "$counts" -type f -name 'row.tsv' > "$list"
sort -o "$list" "$list"
if [ ! -s "$list" ]; then
  echo "dep-history: no count rows; nothing to publish"
  exit 0
fi

newtsv=$(mktemp)
while IFS= read -r f; do
  awk 'NF > 0 && $0 !~ /^#/' "$f" >> "$newtsv"
done < "$list"
if [ ! -s "$newtsv" ]; then
  echo "dep-history: no count rows; nothing to publish"
  exit 0
fi

remote=${DEP_HISTORY_REMOTE:-}
if [ -z "$remote" ]; then
  if ! is_repo "${GITHUB_REPOSITORY:-}"; then
    echo "dep-history: set DEP_HISTORY_REMOTE or GITHUB_REPOSITORY" >&2
    exit 2
  fi
  remote="https://github.com/${GITHUB_REPOSITORY}.git"
fi

work=$(mktemp -d)
git clone --depth 1 --quiet "$remote" "$work"
cd "$work"

if git ls-remote --exit-code --heads origin refs/heads/metrics >/dev/null 2>&1; then
  git fetch --depth 1 --quiet origin metrics
  git checkout --quiet -B metrics FETCH_HEAD
else
  git checkout --quiet --orphan metrics
  git rm -rfq .
fi

empty=$(mktemp)
printf '%s\n' '# run_id date major arch packages postgres digest' > "$empty"
if [ -f history.tsv ]; then
  old=history.tsv
else
  old=$empty
fi
"$hist" merge "$old" "$newtsv" > history.tsv.next
mv history.tsv.next history.tsv

if is_repo "${GITHUB_REPOSITORY:-}"; then
  DEP_HISTORY_REPOSITORY=$GITHUB_REPOSITORY
  export DEP_HISTORY_REPOSITORY
fi
"$hist" render history.tsv > README.md

git add -- history.tsv README.md
# An orphan branch has no HEAD yet, so a cached diff against HEAD would fail
# closed on the first publish. Treat "no commit yet" as "needs a commit".
if git rev-parse --verify --quiet HEAD >/dev/null && git diff --cached --quiet; then
  echo "dep-history: series unchanged"
  exit 0
fi

hooks=$(mktemp -d)
trap 'rm -rf "$hooks"; cleanup' EXIT
env \
  GIT_AUTHOR_NAME='github-actions[bot]' \
  GIT_AUTHOR_EMAIL='41898282+github-actions[bot]@users.noreply.github.com' \
  GIT_COMMITTER_NAME='github-actions[bot]' \
  GIT_COMMITTER_EMAIL='41898282+github-actions[bot]@users.noreply.github.com' \
  git -c core.hooksPath="$hooks" -c commit.gpgsign=false \
  commit -q -m 'chore: record Wolfi package counts'
rm -rf "$hooks"

push_url=${DEP_HISTORY_PUSH_URL:-}
if [ -z "$push_url" ]; then
  if ! is_repo "${GITHUB_REPOSITORY:-}"; then
    echo "dep-history: set DEP_HISTORY_PUSH_URL or GITHUB_REPOSITORY" >&2
    exit 2
  fi
  if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "dep-history: GITHUB_TOKEN is empty" >&2
    exit 2
  fi
  push_url="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
fi
git push --quiet "$push_url" HEAD:metrics
echo "dep-history: pushed metrics"
