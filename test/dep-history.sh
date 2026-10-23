#!/bin/sh
# SPDX-FileCopyrightText: 2026 OpenSerbia
# SPDX-License-Identifier: MIT
# Fixture checks for the package-count history. No syft binary and no image.
set -eu

root=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
count=$root/scripts/dep-count.sh
hist=$root/scripts/dep-history.sh
pub=$root/scripts/publish-dep-history.sh

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "FAIL $*" >&2
  exit 1
}

need() {
  printf '%s\n' "$2" | grep -q -F -- "$1" || fail "$3: missing [$1]"
}

hex() {
  awk -v c="$1" 'BEGIN { for (i = 0; i < 64; i++) printf "%s", c }'
}

digest() {
  printf 'sha256:%s' "$(hex "$1")"
}

Da=$(digest a)
Db=$(digest b)
Dc=$(digest c)
Dd=$(digest d)
De=$(digest e)
Df=$(digest f)
Dg=$(digest 0)
Dh=$(digest 1)
Di=$(digest 2)

cat > "$tmp/sbom.json" <<EOF
{
  "bomFormat": "CycloneDX",
  "components": [
    { "type": "operating-system", "name": "wolfi", "version": "20230201" },
    { "type": "library", "name": "bash", "purl": "pkg:apk/wolfi/bash@5.2.37-r2?arch=x86_64&distro=wolfi" },
    { "type": "library", "name": "postgresql-18", "purl": "pkg:apk/wolfi/postgresql-18@18.6-r6?arch=x86_64" },
    { "type": "library", "name": "postgresql-18-client", "purl": "pkg:apk/wolfi/postgresql-18-client@9.9.9-r0?arch=x86_64" },
    { "type": "library", "name": "libc6", "purl": "pkg:deb/debian/libc6@2.41-r0?arch=amd64" },
    { "description": "see pkg:apk/wolfi/decoy@1.0" }
  ]
}
EOF

got=$("$count" "$tmp/sbom.json" 300 2026-10-13 amd64 "$Df" 18)
want=$(printf '300\t2026-10-13\t18\tamd64\t3\t18.6-r6\t%s' "$Df")
[ "$got" = "$want" ] || fail "dep-count row: [$got]"
echo "ok dep-count"

cat > "$tmp/no-pg.json" <<'EOF'
{ "components": [ { "purl": "pkg:apk/wolfi/bash@5.2.37-r2" }, { "purl": "pkg:apk/wolfi/postgresql-17@17.10-r1" } ] }
EOF
set +e
"$count" "$tmp/no-pg.json" 300 2026-10-13 amd64 "$Df" 18 >"$tmp/out" 2>"$tmp/err"
got=$?
set -e
[ "$got" -eq 1 ] || fail "no postgresql exit $got"
need "no postgresql-18" "$(cat "$tmp/err")" "no postgresql"
echo "ok dep-count rejects a sbom without postgresql-18"

set +e
"$count" "$tmp/missing.json" 300 2026-10-13 amd64 "$Df" 18 >"$tmp/out" 2>"$tmp/err"
got=$?
set -e
[ "$got" -eq 2 ] || fail "missing sbom exit $got"
echo "ok dep-count missing sbom"

set +e
"$count" "$tmp/sbom.json" 300 2026-10-13 x86_64 "$Df" 18 >"$tmp/out" 2>"$tmp/err"
got=$?
set -e
[ "$got" -eq 2 ] || fail "bad arch exit $got"
echo "ok dep-count bad arch"

short=sha256:$(hex a | awk 'BEGIN { ORS = "" } { print substr($0, 1, 62) }')
set +e
"$count" "$tmp/sbom.json" 300 2026-10-13 amd64 "$short" 18 >"$tmp/out" 2>"$tmp/err"
got=$?
set -e
[ "$got" -eq 2 ] || fail "short digest exit $got"
echo "ok dep-count short digest"

printf '%s\n' '# run_id date major arch packages postgres digest' > "$tmp/empty.tsv"
{
  printf '%s\n' '# comment'
  printf '100\t2026-10-06\t18\tamd64\t60\t18.6-r4\t%s\n' "$Da"
  printf '100\t2026-10-06\t18\tarm64\t60\t18.6-r4\t%s\n' "$Db"
  printf '100\t2026-10-06\t16\tamd64\t58\t16.14-r1\t%s\n' "$Dc"
} > "$tmp/old.tsv"
{
  printf '200\t2026-10-06\t18\tamd64\t55\t18.6-r5\t%s\n' "$Dd"
  printf '200\t2026-10-06\t18\tarm64\t54\t18.6-r5\t%s\n' "$De"
  printf '300\t2026-10-13\t18\tamd64\t52\t18.6-r6\t%s\n' "$Df"
  printf '300\t2026-10-13\t18\tarm64\t52\t18.6-r9\t%s\n' "$Dg"
  printf '300\t2026-10-13\t16\tamd64\t57\t16.14-r1\t%s\n' "$Dh"
  printf '300\t2026-10-13\t17\tamd64\t57\t17.10-r1\t%s\n' "$Di"
} > "$tmp/new.tsv"

"$hist" merge "$tmp/old.tsv" "$tmp/new.tsv" > "$tmp/merged.tsv"
{
  printf '%s\n' '# run_id date major arch packages postgres digest'
  printf '100\t2026-10-06\t16\tamd64\t58\t16.14-r1\t%s\n' "$Dc"
  printf '100\t2026-10-06\t18\tamd64\t60\t18.6-r4\t%s\n' "$Da"
  printf '100\t2026-10-06\t18\tarm64\t60\t18.6-r4\t%s\n' "$Db"
  printf '200\t2026-10-06\t18\tamd64\t55\t18.6-r5\t%s\n' "$Dd"
  printf '200\t2026-10-06\t18\tarm64\t54\t18.6-r5\t%s\n' "$De"
  printf '300\t2026-10-13\t16\tamd64\t57\t16.14-r1\t%s\n' "$Dh"
  printf '300\t2026-10-13\t17\tamd64\t57\t17.10-r1\t%s\n' "$Di"
  printf '300\t2026-10-13\t18\tamd64\t52\t18.6-r6\t%s\n' "$Df"
  printf '300\t2026-10-13\t18\tarm64\t52\t18.6-r9\t%s\n' "$Dg"
} > "$tmp/merged.want"
diff -u "$tmp/merged.want" "$tmp/merged.tsv" || fail "merge output"
echo "ok merge"

{
  printf '100\t2026-10-06\t18\tamd64\t60\t18.6-r4\t%s\n' "$Da"
  printf '100\t2026-10-06\t18\tamd64\t61\t18.6-r7\t%s\n' "$Db"
} > "$tmp/dup.tsv"
"$hist" merge "$tmp/empty.tsv" "$tmp/dup.tsv" > "$tmp/dup.out"
need "61" "$(cat "$tmp/dup.out")" "duplicate run replaces"
if [ "$(grep -c '18.6-r4' "$tmp/dup.out")" -ne 0 ]; then
  fail "duplicate run kept the old row"
fi
echo "ok merge duplicate run"

set +e
"$hist" merge "$tmp/empty.tsv" "$tmp/sbom.json" >"$tmp/out" 2>"$tmp/err"
got=$?
set -e
[ "$got" -ne 0 ] || fail "bad row was accepted"
echo "ok merge rejects a bad row"

page=$("$hist" render "$tmp/merged.tsv")
printf '%s\n' "$page" | grep '^## PostgreSQL' > "$tmp/heads"
printf '%s\n' '## PostgreSQL 16' '## PostgreSQL 17' '## PostgreSQL 18' > "$tmp/heads.want"
diff -u "$tmp/heads.want" "$tmp/heads" || fail "chart order"
need '    x-axis ["10-06", "10-13"]' "$page" "pg16 axis"
need '    y-axis "packages" 56 --> 59' "$page" "pg16 y"
need '    line [58, 57]' "$page" "pg16 line"
need '    x-axis ["10-13"]' "$page" "pg17 axis"
need '    y-axis "packages" 56 --> 58' "$page" "pg17 y"
need '    line [57]' "$page" "pg17 line"
need '    x-axis ["10-06", "10-06.2", "10-13"]' "$page" "pg18 axis"
need '    y-axis "packages" 51 --> 61' "$page" "pg18 y"
need '    line [60, 55, 52]' "$page" "pg18 line"
need '| 2026-10-13 | 300 | 16 | 57 | - | 16.14-r1 |' "$page" "table 300/16"
need '| 2026-10-13 | 300 | 17 | 57 | - | 17.10-r1 |' "$page" "table 300/17"
need '| 2026-10-13 | 300 | 18 | 52 | 52 | 18.6-r6 |' "$page" "table 300/18"
need '| 2026-10-06 | 200 | 18 | 55 | 54 | 18.6-r5 |' "$page" "table 200"
need '| 2026-10-06 | 100 | 16 | 58 | - | 16.14-r1 |' "$page" "table 100/16"
need '| 2026-10-06 | 100 | 18 | 60 | 60 | 18.6-r4 |' "$page" "table 100/18"
if printf '%s\n' "$page" | grep -q -F '18.6-r9'; then
  fail "table used the arm64 postgresql version"
fi
echo "ok render"

DEP_HISTORY_REPOSITORY=openserbia/postgres-wolfi
export DEP_HISTORY_REPOSITORY
linked=$("$hist" render "$tmp/merged.tsv")
unset DEP_HISTORY_REPOSITORY
need '[300](https://github.com/openserbia/postgres-wolfi/actions/runs/300)' "$linked" "run link"
echo "ok render run link"

empty_page=$("$hist" render "$tmp/empty.tsv")
need 'No published image has been counted yet.' "$empty_page" "empty page"
if printf '%s\n' "$empty_page" | grep -q xychart; then
  fail "empty history drew a chart"
fi
echo "ok render empty"

{
  printf '%s\n' '# run_id date major arch packages postgres digest'
  i=1
  while [ "$i" -le 25 ]; do
    day=$(printf '2026-01-%02d' "$i")
    pkgs=$((100 + i))
    printf '%s\t%s\t18\tamd64\t%s\t18.6-r6\t%s\n' "$i" "$day" "$pkgs" "$Da"
    i=$((i + 1))
  done
} > "$tmp/window.tsv"
window=$("$hist" render "$tmp/window.tsv")
line=$(printf '%s\n' "$window" | grep '^    line \[')
need '    line [102,' "$line" "window drops the oldest point"
printf '%s\n' "$line" | grep -q '125]$' || fail "window does not end at the newest point"
commas=$(printf '%s\n' "$line" | awk -F, '{ print NF - 1 }')
[ "$commas" -eq 23 ] || fail "window point count is $((commas + 1)), want 24"
need '    y-axis "packages" 101 --> 126' "$window" "window y"
if printf '%s\n' "$window" | grep -q '    line \[101,'; then
  fail "window kept point 101"
fi
echo "ok render keeps the newest 24"

# Publish onto a local bare repo. No GitHub token and no network.
bare=$tmp/bare
git init --bare -q "$bare"
git --git-dir="$bare" symbolic-ref HEAD refs/heads/main
src=$tmp/src
git init -q -b main "$src"
mkdir -p "$src/docs"
echo 'main readme' > "$src/README.md"
echo 'not metrics' > "$src/docs/keep.txt"
git -C "$src" add README.md docs/keep.txt
git -C "$src" -c user.email=test@example.com -c user.name=tester -c commit.gpgsign=false \
  commit -q -m init
git -C "$src" push -q "$bare" HEAD:main
remote="file://${bare}"

row_file() {
  dir=$1
  printf '%s\n' "$2" > "$dir/row.tsv"
}

counts=$tmp/counts
mkdir -p "$counts/a" "$counts/b"
row_file "$counts/a" "$(printf '100\t2026-10-06\t18\tamd64\t60\t18.6-r4\t%s' "$Da")"
row_file "$counts/b" "$(printf '200\t2026-10-06\t18\tamd64\t55\t18.6-r5\t%s' "$Dd")"

env -u GITHUB_TOKEN \
  GITHUB_REPOSITORY=openserbia/postgres-wolfi \
  DEP_HISTORY_REMOTE="$remote" \
  DEP_HISTORY_PUSH_URL="$remote" \
  "$pub" "$counts" >"$tmp/pub.out"
need 'pushed metrics' "$(cat "$tmp/pub.out")" "first publish"

git clone -q -b metrics "$bare" "$tmp/metrics"
names=$(git -C "$tmp/metrics" ls-tree -r --name-only HEAD | LC_ALL=C sort)
want=$(printf '%s\n' README.md history.tsv | LC_ALL=C sort)
[ "$names" = "$want" ] || fail "metrics tree is [$names]"
need '    line [60, 55]' "$(cat "$tmp/metrics/README.md")" "published chart"
need '[100](https://github.com/openserbia/postgres-wolfi/actions/runs/100)' \
  "$(cat "$tmp/metrics/README.md")" "published run link"
if grep -q -F 'not metrics' "$tmp/metrics/README.md"; then
  fail "metrics README kept a file from main"
fi
ident=$(git -C "$tmp/metrics" log -1 --format='%an%n%ae%n%cn%n%ce%n%s')
want_ident=$(printf '%s\n' \
  'github-actions[bot]' \
  '41898282+github-actions[bot]@users.noreply.github.com' \
  'github-actions[bot]' \
  '41898282+github-actions[bot]@users.noreply.github.com' \
  'chore: record Wolfi package counts')
[ "$ident" = "$want_ident" ] || fail "commit identity [$ident]"
if git -C "$tmp/metrics" log -1 --format='%B' | grep -E -q 'Co-Authored-By|Claude-Session|Generated by'; then
  fail "commit message has an authorship trailer"
fi
echo "ok publish creates metrics"

before=$(git --git-dir="$bare" rev-parse refs/heads/metrics)
env -u GITHUB_TOKEN \
  GITHUB_REPOSITORY=openserbia/postgres-wolfi \
  DEP_HISTORY_REMOTE="$remote" \
  DEP_HISTORY_PUSH_URL="$remote" \
  "$pub" "$counts" >"$tmp/pub.out"
need 'series unchanged' "$(cat "$tmp/pub.out")" "second publish"
after=$(git --git-dir="$bare" rev-parse refs/heads/metrics)
[ "$before" = "$after" ] || fail "unchanged series was pushed"
echo "ok publish skips an unchanged series"

mkdir -p "$tmp/counts2"
row_file "$tmp/counts2" "$(printf '100\t2026-10-06\t18\tamd64\t61\t18.6-r7\t%s' "$Db")"
env -u GITHUB_TOKEN \
  GITHUB_REPOSITORY=openserbia/postgres-wolfi \
  DEP_HISTORY_REMOTE="$remote" \
  DEP_HISTORY_PUSH_URL="$remote" \
  "$pub" "$tmp/counts2" >"$tmp/pub.out"
need 'pushed metrics' "$(cat "$tmp/pub.out")" "replacement publish"
git -C "$tmp/metrics" pull -q "$bare" metrics
need '61' "$(cat "$tmp/metrics/history.tsv")" "replaced count"
if [ "$(grep -c '18.6-r4' "$tmp/metrics/history.tsv")" -ne 0 ]; then
  fail "publish kept the replaced row"
fi
need '55' "$(cat "$tmp/metrics/history.tsv")" "older row survived replacement"
echo "ok publish replaces a duplicate run"

bare2=$tmp/bare2
git init --bare -q "$bare2"
git --git-dir="$bare2" symbolic-ref HEAD refs/heads/main
git -C "$src" push -q "$bare2" HEAD:main
remote2="file://${bare2}"
mkdir -p "$tmp/badcounts"
printf 'not-a-row\n' > "$tmp/badcounts/row.tsv"
set +e
env -u GITHUB_TOKEN \
  GITHUB_REPOSITORY=openserbia/postgres-wolfi \
  DEP_HISTORY_REMOTE="$remote2" \
  DEP_HISTORY_PUSH_URL="$remote2" \
  "$pub" "$tmp/badcounts" >"$tmp/out" 2>"$tmp/err"
got=$?
set -e
[ "$got" -ne 0 ] || fail "bad count row was published"
if git --git-dir="$bare2" rev-parse --verify --quiet refs/heads/metrics >/dev/null; then
  fail "bad count row created metrics"
fi
echo "ok publish rejects a bad row"

mkdir -p "$tmp/emptycounts"
env -u GITHUB_TOKEN \
  DEP_HISTORY_REMOTE="$remote2" \
  DEP_HISTORY_PUSH_URL="$remote2" \
  "$pub" "$tmp/emptycounts" >"$tmp/pub.out"
need 'no count rows' "$(cat "$tmp/pub.out")" "empty publish"
if git --git-dir="$bare2" rev-parse --verify --quiet refs/heads/metrics >/dev/null; then
  fail "empty counts created metrics"
fi
echo "ok publish with no rows"

if [ -z "${DEP_HISTORY_AWK_PASS:-}" ]; then
  if awk 'BEGIN { exit !(PROCINFO["version"] ~ /./) }'; then
    other=$(command -v mawk 2>/dev/null || true)
  else
    other=$(command -v gawk 2>/dev/null || true)
  fi
  if [ -n "${other:-}" ]; then
    shim=$(mktemp -d)
    ln -s "$other" "$shim/awk"
    echo "dep-history: again with $other"
    DEP_HISTORY_AWK_PASS=1 PATH="$shim:$PATH" "$0"
    status=$?
    rm -rf "$shim"
    exit "$status"
  fi
fi
