<!--
SPDX-FileCopyrightText: 2026 OpenSerbia
SPDX-License-Identifier: MIT
-->
# Security Policy

`postgres-wolfi` is a security-hardened PostgreSQL container image. Reducing the
attack surface of the official image is the whole point of the project, so
security reports are taken seriously and handled promptly.

## Reporting a vulnerability

**Do not open a public GitHub Issue for a security vulnerability.**

Report privately using **[GitHub Security Advisories](https://github.com/openserbia/postgres-wolfi/security/advisories/new)**
("Report a vulnerability"). If you cannot use that, email
**charnyshevich.job@gmail.com** with subject `postgres-wolfi security`.

Please include:

- the affected image tag (`:NN-latest` or `:NN-YYYYMMDD`, e.g. `:18-latest`) and digest if known;
- a description of the issue and its impact;
- reproduction steps or a proof of concept where possible.

### What is in scope

This project's own artifacts: the `Dockerfile`, build/release CI, the image
assembly (user/permission model, packages selected), and the signing/SBOM
pipeline. Vulnerabilities in **upstream** components (PostgreSQL, Wolfi packages,
`gosu`) should be reported to those projects; we will pull their fixes in the
next weekly rebuild and, for CRITICALs, out of band.

## Response process

1. **Acknowledge** the report within **14 days** (typically much sooner).
2. **Triage** and confirm/refute, assigning a severity (CVSS-based).
3. **Fix**: rebuild from patched upstreams and/or change the image assembly.
   We aim to remediate confirmed medium-or-higher issues well within **60 days**;
   CRITICALs are handled out of the weekly cadence.
4. **Disclose** via a GitHub Security Advisory and a `CHANGELOG.md` entry, and
   **credit the reporter** unless they ask to remain anonymous.

## What you can and cannot expect (security model)

**You can expect:**

- A glibc PostgreSQL image — majors **16, 17, 18**, each its own tag line — with
  **no `perl`** and a minimal Wolfi package set, rebuilt **weekly** so
  daily-patched Wolfi packages flow through.
- A **Trivy-gated** build that **fails on CRITICAL** OS/library vulnerabilities;
  HIGH findings are reported (non-gating) for visibility.
- A **CycloneDX SBOM** (`sbom.cdx.json`) attested to each image, so you can audit
  every package and version.
- **Keyless cosign signatures** (Sigstore / GitHub OIDC) on every pushed image —
  see the README for the `cosign verify` command. This counters tampering and
  man-in-the-middle on the delivery path (images are pulled from GHCR over TLS).
- The postmaster runs **non-root** as `postgres` (uid:gid `70:70`); the
  entrypoint drops privileges with `gosu`.

**You cannot expect:**

- Hardening of PostgreSQL *configuration* — `postgresql.conf`/`pg_hba.conf`,
  TLS termination, password policy, network exposure, and least-privilege roles
  are the **operator's** responsibility. This image ships PostgreSQL's defaults.
- Secrets management. `POSTGRES_PASSWORD` (or `_FILE`) handling follows the
  upstream entrypoint contract; protecting those secrets is on the deployer.
- A patched image for HIGH/MEDIUM CVEs *faster* than the weekly cadence (only
  CRITICALs are expedited).
- Backports to any major line outside the supported set (currently `16.x`,
  `17.x`, `18.x`).

## Supported versions

| Tag line                                  | Supported           |
|-------------------------------------------|---------------------|
| `:18-latest`, `:17-latest`, `:16-latest`  | ✅ rebuilt weekly   |
| `:NN-YYYYMMDD` (NN ∈ 16, 17, 18)          | ✅ pinned snapshots; rebuild/repull for fixes |
| any major older than 16, or a newer major before Wolfi ships it | ❌ not built |

## Assurance case

A structured argument for *why* these security claims hold, with links to the
evidence, is in [`docs/assurance-case.md`](docs/assurance-case.md).
