#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 OpenSerbia
# SPDX-License-Identifier: MIT
#
# Probe Wolfi for a PostgreSQL major newer than anything the build matrix covers,
# and open ONE tracking issue when a complete, installable package set appears.
#
# Standing up a new `:NN-*` line is gated entirely on Wolfi publishing a
# `postgresql-NN` apk — until it exists, `apk add postgresql-NN` 404s and the
# matrix leg is perma-red (see docs/ROADMAP.md, "PostgreSQL 19 line").
#
# Env:
#   GH_TOKEN           required to file the issue (not needed for a dry run)
#   PROBE_DRY_RUN=1    print the issue instead of creating it
#   PROBE_BASE_IMAGE   override the probed base image (testing only)
set -euo pipefail

# Overridable so the failure paths can be exercised in a test.
WOLFI_BASE="${PROBE_BASE_IMAGE:-cgr.dev/chainguard/wolfi-base:latest}"
DRY_RUN="${PROBE_DRY_RUN:-0}"

# The highest major the build matrix already covers. Parsed from build.yml so
# this probe never needs editing when the matrix moves.
built_max=$(grep -oE '^[[:space:]]*pg: \[[^]]*\]' .github/workflows/build.yml \
  | head -1 | grep -oE '[0-9]+' | sort -n | tail -1)
if [ -z "$built_max" ]; then
  echo "::error::could not parse the \`pg:\` matrix out of build.yml — probe cannot tell what is new"
  exit 1
fi
echo "highest major currently built: $built_max"

# Ask Wolfi exactly the way the Dockerfile does, so the answer reflects the repo
# wolfi-base actually resolves rather than a mirror's guess.
majors=$(docker run --rm "$WOLFI_BASE" \
  sh -c 'apk update >/dev/null 2>&1; apk search postgresql 2>/dev/null' \
  | grep -oE '^postgresql-[0-9]+' | grep -oE '[0-9]+$' | sort -un || true)

# Silence must never read as "nothing new" — an empty result means the pull, the
# index refresh or the search broke, so fail loudly instead of reporting calm.
if [ -z "$majors" ]; then
  echo "::error::probe found NO postgresql packages in Wolfi at all — treating as a broken probe, not as 'no new major'"
  exit 1
fi
echo "wolfi publishes majors: $(echo "$majors" | tr '\n' ' ')"

new=""
for m in $majors; do
  [ "$m" -gt "$built_max" ] || continue
  # The Dockerfile installs the base, -client AND -contrib packages. A partial
  # set still 404s the leg, so only a complete trio counts as actionable.
  found=$(docker run --rm "$WOLFI_BASE" \
    sh -c "apk update >/dev/null 2>&1; apk search -x postgresql-$m postgresql-$m-client postgresql-$m-contrib 2>/dev/null" \
    | grep -cE "^postgresql-$m(-client|-contrib)?-[0-9]" || true)
  if [ "$found" -ge 3 ]; then
    new="$new $m"
  else
    echo "major $m is in Wolfi but the package set is incomplete ($found/3) — not actionable yet"
  fi
done
new="${new# }"   # trim the accumulator's leading space

if [ -z "$new" ]; then
  echo "nothing newer than $built_max is installable — no issue to file"
  exit 0
fi

title="PostgreSQL $(echo "$new" | tr ' ' ',') now installable in Wolfi — add to the build matrix"

body=$(cat <<EOF
Wolfi now publishes a complete \`postgresql-NN\`, \`-client\` and \`-contrib\`
package set for major(s) **$new**, which is newer than the highest major this
repo builds ($built_max). The blocker described in
[\`docs/ROADMAP.md\`](docs/ROADMAP.md) is therefore cleared.

Filed automatically by \`.github/workflows/pg-major-probe.yml\`.

### Adding the line is more than the one-liner the roadmap suggests

Both matrices in \`build.yml\` need the new major — adding it to only the first
builds the images but never publishes a manifest list for them:

- [ ] \`.github/workflows/build.yml\` — \`build\` job matrix (\`pg:\`)
- [ ] \`.github/workflows/build.yml\` — \`manifest\` job matrix (\`pg:\`)
- [ ] \`.github/workflows/build.yml\` — the majors named in the header comment

The supported-majors list is also written out in prose in several places:

- [ ] \`README.md\`
- [ ] \`SECURITY.md\` — including the "Supported versions" table
- [ ] \`CONTRIBUTING.md\`
- [ ] \`GOVERNANCE.md\`
- [ ] \`Dockerfile\` — header comment
- [ ] \`docs/ARCHITECTURE.md\`
- [ ] \`docs/releasing.md\`
- [ ] \`docs/assurance-case.md\`
- [ ] \`docs/bestpractices-badge.md\`
- [ ] \`docs/ROADMAP.md\` — move the item out of "Long-term / externally gated"
- [ ] \`CHANGELOG.md\` — new entry

### Decide the support window first

This repo carries three majors while upstream supports five. Adding a major
either widens that window or means dropping the oldest; \`SECURITY.md\` is where
that policy lives. Settle it before the bump rather than during.
EOF
)

if [ "$DRY_RUN" = "1" ]; then
  echo "--- DRY RUN, would open issue ---"
  echo "TITLE: $title"
  echo "$body"
  exit 0
fi

# One issue, not one per week: bail if this exact issue is already open.
existing=$(gh issue list --state open --limit 200 --json number,title \
  --jq ".[] | select(.title == \"$title\") | .number" | head -1)
if [ -n "$existing" ]; then
  echo "already tracked in #$existing — nothing to do"
  exit 0
fi

gh issue create --title "$title" --body "$body"
echo "opened: $title"
