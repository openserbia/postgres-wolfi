#!/bin/sh
# SPDX-FileCopyrightText: 2026 OpenSerbia
# SPDX-License-Identifier: MIT
# Build-time only (bind-mounted by the Dockerfile, never copied into the image).
#
# usage: apk-purge.sh <package>...
#
# Removes installed apk packages that something else still *declares* a
# dependency on — which `apk del` refuses to do — together with every dependency
# that becomes orphaned as a result. Both the package's files AND its record in
# the installed-package database go, so Trivy, syft and `apk info` see exactly
# what is on disk: no phantom package in the SBOM, no CVE reported against a
# library that is not there.
#
# A dependency is only pruned when ALL of these hold: no surviving package still
# depends on anything it provides, it is not in /etc/apk/world (asked for
# explicitly), and it is not an install_if package (pulled in by a rule, not a
# dependency edge). Anything else is left alone.
#
# Fails closed: after purging, every ELF binary and shared object under /usr is
# resolved with the dynamic loader, and any unresolved library fails the build.
# A purge that removed something still needed can therefore never ship.
set -eu

[ "$#" -gt 0 ] || { echo "usage: $0 <package>..." >&2; exit 2; }

DB=/usr/lib/apk/db/installed
FILES=$(mktemp)

# The installed DB is a sequence of blank-line-separated records, one per
# package, with one `K:value` field per line (P name, D deps, p provides,
# i install_if, F directory, R file within the preceding F).
awk -v targets="$*" -v world=/etc/apk/world -v files="$FILES" -v out="$DB.new" '
function bare(t) { sub(/^!/, "", t); sub(/[<>=~].*/, "", t); return t }
function provides(r, t,   n, a, j) {
  if (name[r] == t) return 1
  n = split(prov[r], a, " ")
  for (j = 1; j <= n; j++) if (bare(a[j]) == t) return 1
  return 0
}
function needed(r,   s, n, a, j) {
  for (s = 1; s <= total; s++) {
    if (dead[s] || s == r) continue
    n = split(deps[s], a, " ")
    for (j = 1; j <= n; j++)
      if (a[j] !~ /^!/ && provides(r, bare(a[j]))) return 1
  }
  return 0
}
function purge(r,   n, a, j, s) {
  if (dead[r]) return
  dead[r] = 1
  print "apk-purge: removing " name[r] > "/dev/stderr"
  n = split(deps[r], a, " ")
  for (j = 1; j <= n; j++)
    for (s = 1; s <= total; s++)
      if (!dead[s] && !(name[s] in wanted) && !installif[s] \
          && provides(s, bare(a[j])) && !needed(s))
        purge(s)
}
BEGIN {
  while ((getline w < world) > 0) wanted[bare(w)] = 1
  RS = ""; FS = "\n"
}
{
  total = NR; rec[NR] = $0
  for (i = 1; i <= NF; i++) {
    k = substr($i, 1, 2); v = substr($i, 3)
    if (k == "P:") { name[NR] = v; index_of[v] = NR }
    else if (k == "D:") deps[NR] = v
    else if (k == "p:") prov[NR] = v
    else if (k == "i:") installif[NR] = 1
  }
}
END {
  n = split(targets, t, " ")
  for (j = 1; j <= n; j++) {
    if (!(t[j] in index_of)) { print "apk-purge: not installed: " t[j] > "/dev/stderr"; exit 1 }
    purge(index_of[t[j]])
  }
  for (r = 1; r <= total; r++) {
    if (!dead[r]) { printf "%s\n\n", rec[r] > out; continue }
    m = split(rec[r], line, "\n"); dir = ""
    for (i = 1; i <= m; i++) {
      k = substr(line[i], 1, 2); v = substr(line[i], 3)
      if (k == "F:") dir = v
      else if (k == "R:") print "/" dir "/" v > files
    }
  }
}
' "$DB"

xargs rm -f < "$FILES"
rm -f "$FILES"
mv "$DB.new" "$DB"

# Fail-closed guard: no surviving ELF may reference a library that is gone.
# A missing direct dependency makes `ld.so --list` abort with "cannot open shared
# object file"; a missing transitive one is listed as "not found". Statically
# linked binaries (gosu) crash it outright, so only those two messages count.
ldso=
for l in /lib/ld-linux-*.so.*; do [ -e "$l" ] && { ldso=$l; break; }; done
[ -n "$ldso" ] || { echo "apk-purge: no glibc dynamic loader found" >&2; exit 1; }
missing=$(
  find /usr/bin /usr/sbin /usr/lib /usr/libexec -type f \( -perm -u+x -o -name '*.so*' \) 2>/dev/null |
    while IFS= read -r f; do
      [ "$(head -c 4 "$f" | tail -c 3)" = ELF ] || continue
      if { ("$ldso" --list "$f" 2>&1) 2>/dev/null || :; } \
          | grep -qE 'not found|cannot open shared object file'; then echo "$f"; fi
    done
)
if [ -n "$missing" ]; then
  echo "apk-purge: unresolved shared libraries after purge in:" >&2
  echo "$missing" >&2
  exit 1
fi
