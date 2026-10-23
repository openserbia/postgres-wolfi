# SPDX-FileCopyrightText: 2026 OpenSerbia
# SPDX-License-Identifier: MIT
# Read a Trivy 0.74 JSON report (json.MarshalIndent, one field per line) and
# decide the gate. Prints one line per HIGH or CRITICAL vulnerability or secret.
# Exit 0 only when the report is a Wolfi image, lists at least one OS package
# (a Packages entry whose result Class is os-pkgs), and contains no CRITICAL
# finding. HIGH is printed and does not fail. A library package does not count
# as an OS package. A truncated report, a missing OS family, or any family
# other than wolfi fails.

function field(line, key,    pat, i, n, c, esc, out) {
  pat = "\"" key "\":"
  i = index(line, pat)
  if (i == 0) return ""
  i += length(pat)
  n = length(line)
  while (i <= n && substr(line, i, 1) == " ") i++
  if (substr(line, i, 1) != "\"") return ""
  i++
  out = ""
  esc = 0
  for (; i <= n; i++) {
    c = substr(line, i, 1)
    if (esc) { out = out c; esc = 0; continue }
    if (c == "\\") { esc = 1; continue }
    if (c == "\"") return out
    out = out c
  }
  malformed = 1
  return ""
}

function push() {
  d++
  id[d] = ""
  pkg[d] = ""
  ver[d] = ""
  sev[d] = ""
  rule[d] = ""
  title[d] = ""
  cls[d] = ""
}

function pop(    s) {
  if (d < 1) { malformed = 1; return }
  s = sev[d]
  if (s == "CRITICAL" || s == "HIGH") {
    if (id[d] != "") {
      print s, "vuln", id[d], pkg[d], ver[d], title[d]
      if (s == "CRITICAL") critical++; else high++
    } else if (rule[d] != "") {
      print s, "secret", rule[d], title[d]
      if (s == "CRITICAL") critical++; else high++
    }
  }
  d--
}

function walk(line,    i, n, c, esc, ins) {
  n = length(line)
  esc = 0
  ins = 0
  for (i = 1; i <= n; i++) {
    c = substr(line, i, 1)
    if (ins) {
      if (esc) { esc = 0; continue }
      if (c == "\\") { esc = 1; continue }
      if (c == "\"") ins = 0
      continue
    }
    if (c == "\"") { ins = 1; continue }
    if (c == "{") push()
    else if (c == "}") pop()
    else if (c == "[") {
      ad++
      if (pending_pkg) { in_pkg = 1; pkg_ad = ad; pending_pkg = 0 }
    } else if (c == "]") {
      if (ad < 1) { malformed = 1; continue }
      ad--
      if (in_pkg && ad < pkg_ad) in_pkg = 0
    }
  }
  if (ins) malformed = 1
}

{
  if ($0 ~ /^[[:space:]]*"Family"[[:space:]]*:[[:space:]]*"/) {
    family_seen++
    family = field($0, "Family")
  }
  if (in_pkg && $0 ~ /^[[:space:]]*"Name"[[:space:]]*:[[:space:]]*"/) {
    if (field($0, "Name") != "") pkg_count++
  }
  if (d > 0) {
    v = field($0, "VulnerabilityID"); if (v != "") id[d] = v
    v = field($0, "PkgName"); if (v != "") pkg[d] = v
    v = field($0, "InstalledVersion"); if (v != "") ver[d] = v
    v = field($0, "Severity"); if (v != "") sev[d] = v
    v = field($0, "RuleID"); if (v != "") rule[d] = v
    v = field($0, "Title"); if (v != "") title[d] = v
    v = field($0, "Class"); if (v != "") cls[d] = v
  }
  pending_pkg = 0
  if ($0 ~ /^[[:space:]]*"Packages"[[:space:]]*:[[:space:]]*\[/ && cls[d] == "os-pkgs")
    pending_pkg = 1
  walk($0)
}

END {
  if (malformed || d != 0 || ad != 0) {
    print "trivy-gate: truncated or malformed JSON report" > "/dev/stderr"
    exit 1
  }
  printf "trivy-gate: family=%s packages=%d critical=%d high=%d\n", family, pkg_count, critical, high
  if (family_seen != 1) {
    printf "trivy-gate: report has %d OS family fields, want 1\n", family_seen > "/dev/stderr"
    exit 1
  }
  if (family != "wolfi") {
    print "trivy-gate: OS family is " family ", want wolfi" > "/dev/stderr"
    exit 1
  }
  if (pkg_count < 1) {
    print "trivy-gate: Wolfi OS package count is 0" > "/dev/stderr"
    exit 1
  }
  if (critical > 0) {
    print "trivy-gate: " critical " CRITICAL finding(s)" > "/dev/stderr"
    exit 1
  }
  exit 0
}
