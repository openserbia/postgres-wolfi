#!/bin/sh
# SPDX-FileCopyrightText: 2026 OpenSerbia
# SPDX-License-Identifier: MIT
#
# usage:
#   dep-history.sh merge <old.tsv> <new.tsv>
#   dep-history.sh render <history.tsv>
#
# merge prints a TSV. A later row with the same run id, major, and arch
# replaces the earlier one. render prints the metrics-branch page: one
# amd64 chart per major, then a table of recent publishes.
#
# DEP_HISTORY_REPOSITORY, when it is owner/name, turns the Run column into
# a link to that repository's Actions run. Unset, the run id is plain text.
set -eu
export LC_ALL=C

if [ "$#" -lt 1 ]; then
  echo "usage: $0 merge|render ..." >&2
  exit 2
fi

valid_row() {
  # No {n} interval expressions: mawk 1.3.4 builds that predate them treat
  # the braces as literal characters and would reject every real row.
  awk '
    function digits(s, n) {
      return length(s) == n && s !~ /[^0-9]/
    }
    function is_date(s) {
      return length(s) == 10 && digits(substr(s, 1, 4), 4) &&
        substr(s, 5, 1) == "-" && digits(substr(s, 6, 2), 2) &&
        substr(s, 8, 1) == "-" && digits(substr(s, 9, 2), 2)
    }
    function is_digest(s,    h) {
      if (substr(s, 1, 7) != "sha256:") return 0
      h = substr(s, 8)
      return length(h) == 64 && h !~ /[^0-9a-f]/
    }
    BEGIN { FS = "\t"; bad = 0 }
    /^#/ || NF == 0 { next }
    NF != 7 { bad = 1; exit 1 }
    $1 ~ /[^0-9]/ || $1 == "" || !is_date($2) { bad = 1; exit 1 }
    $3 ~ /[^0-9]/ || $3 == "" || $5 ~ /[^0-9]/ || $5 == "" { bad = 1; exit 1 }
    $4 != "amd64" && $4 != "arm64" { bad = 1; exit 1 }
    $6 !~ /^[0-9A-Za-z._+-]+$/ || !is_digest($7) { bad = 1; exit 1 }
    END { if (bad) exit 1 }
  ' "$1"
}

merge() {
  old=$1
  new=$2
  valid_row "$old"
  valid_row "$new"
  tmp=$(mktemp)
  awk '
    BEGIN { FS = OFS = "\t" }
    /^#/ || NF == 0 { next }
    { row[$1 "\t" $3 "\t" $4] = $0 }
    END { for (k in row) print row[k] }
  ' "$old" "$new" > "$tmp"
  {
    printf '%s\n' '# run_id date major arch packages postgres digest'
    sort -t "$(printf '\t')" -k2,2 -k1,1n -k3,3n -k4,4 "$tmp"
  }
  rm -f "$tmp"
}

render() {
  src=$1
  valid_row "$src"
  awk '
    BEGIN { FS = "\t" }
    /^#/ || NF == 0 { next }
    {
      n++
      run[n] = $1
      day[n] = $2
      major[n] = $3
      arch[n] = $4
      pkgs[n] = $5
      pg[n] = $6
    }
    END {
      print "<!--"
      print "SPDX-FileCopyrightText: 2026 OpenSerbia"
      print "SPDX-License-Identifier: MIT"
      print "-->"
      print "# Package count"
      print ""
      print "Each point is one published rebuild of `ghcr.io/openserbia/postgres-wolfi`."
      print "The number is how many CycloneDX components have a `pkg:apk` purl."
      print "The count comes from the SBOM attested to that image. Charts are linux/amd64."
      print "A rebuild on the same day stays as its own point. The chart shows the"
      print "last 24 points. `history.tsv` on this branch is the source. The workflow"
      print "rewrites this page from that file."
      print ""

      mcount = 0
      for (i = 1; i <= n; i++) {
        if (arch[i] != "amd64") continue
        found = 0
        for (j = 1; j <= mcount; j++) if (majors[j] == major[i]) found = 1
        if (!found) {
          mcount++
          majors[mcount] = major[i]
        }
      }
      for (a = 2; a <= mcount; a++) {
        v = majors[a]
        b = a - 1
        while (b >= 1 && (majors[b] + 0) > (v + 0)) {
          majors[b + 1] = majors[b]
          b--
        }
        majors[b + 1] = v
      }
      if (mcount == 0) {
        print "No published image has been counted yet."
        exit 0
      }

      for (mi = 1; mi <= mcount; mi++) {
        m = majors[mi]
        c = 0
        for (i = 1; i <= n; i++) {
          if (major[i] != m || arch[i] != "amd64") continue
          c++
          ord[c] = i
        }
        start = 1
        if (c > 24) start = c - 23
        k = 0
        min = 0
        max = 0
        for (t = start; t <= c; t++) {
          i = ord[t]
          k++
          d = substr(day[i], 6)
          seen = 0
          for (u = 1; u < k; u++) if (labraw[u] == d) seen++
          labraw[k] = d
          if (seen > 0) lab[k] = d "." (seen + 1)
          else lab[k] = d
          val[k] = pkgs[i] + 0
          if (k == 1 || val[k] < min) min = val[k]
          if (k == 1 || val[k] > max) max = val[k]
        }
        nk = k
        min--
        max++
        if (mi > 1) print ""
        printf "## PostgreSQL %s\n\n", m
        print "```mermaid"
        print "xychart-beta"
        printf "    title \"PostgreSQL %s amd64 packages\"\n", m
        printf "    x-axis ["
        for (k = 1; k <= nk; k++) {
          if (k > 1) printf ", "
          printf "\"%s\"", lab[k]
        }
        print "]"
        printf "    y-axis \"packages\" %d --> %d\n", min, max
        printf "    line ["
        for (k = 1; k <= nk; k++) {
          if (k > 1) printf ", "
          printf "%d", val[k]
        }
        print "]"
        print "```"
      }

      print ""
      print "## Recent publishes"
      print ""
      print "amd64 and arm64 are counted separately. The PostgreSQL column is the"
      print "version of the `postgresql-<major>` package on amd64."
      print ""
      print "| Date | Run | Major | amd64 | arm64 | PostgreSQL |"
      print "|------|-----|-------|-------|-------|------------|"

      repo = ENVIRON["DEP_HISTORY_REPOSITORY"]
      link = (repo ~ /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/)
      rc = 0
      for (i = n; i >= 1; i--) {
        have = 0
        for (j = 1; j <= rc; j++) if (runs[j] == run[i]) have = 1
        if (have) continue
        rc++
        runs[rc] = run[i]
        if (rc == 8) break
      }
      for (r = 1; r <= rc; r++) {
        id = runs[r]
        for (i = 1; i <= n; i++) {
          if (run[i] != id || arch[i] != "amd64") continue
          arm = "-"
          for (j = 1; j <= n; j++) {
            if (run[j] == id && major[j] == major[i] && arch[j] == "arm64")
              arm = pkgs[j]
          }
          runcell = id
          if (link) runcell = "[" id "](https://github.com/" repo "/actions/runs/" id ")"
          printf "| %s | %s | %s | %s | %s | %s |\n", day[i], runcell, major[i], pkgs[i], arm, pg[i]
        }
      }
    }
  ' "$src"
}

cmd=$1
shift
case $cmd in
  merge)
    [ "$#" -eq 2 ] || { echo "usage: $0 merge <old.tsv> <new.tsv>" >&2; exit 2; }
    merge "$1" "$2"
    ;;
  render)
    [ "$#" -eq 1 ] || { echo "usage: $0 render <history.tsv>" >&2; exit 2; }
    render "$1"
    ;;
  *)
    echo "usage: $0 merge|render ..." >&2
    exit 2
    ;;
esac
