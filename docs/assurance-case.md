<!--
SPDX-FileCopyrightText: 2026 OpenSerbia
SPDX-License-Identifier: MIT
-->
# Assurance case

A structured security argument for `postgres-wolfi`, with each claim tied to
concrete, checkable evidence in this repo (or to artifacts the pipeline emits).
It is the *why these claims hold* companion to [`SECURITY.md`](../SECURITY.md);
for *how the image is assembled* see [`docs/ARCHITECTURE.md`](ARCHITECTURE.md).

Paths below are repo-relative. Where an item is an external artifact (a pushed
image, a signature, an SBOM attestation) the verification command is given.

## Top claim

> `postgres-wolfi` materially reduces image attack surface and supply-chain risk
> relative to the official `postgres:18` image, and ships only artifacts that
> consumers can independently verify.

This decomposes into seven sub-claims. The top claim holds to the extent that
all seven hold; the [residual risks](#residual-risks--out-of-scope) section
states plainly where it does not.

## Sub-claims

### 1. Reduced attack surface

**Argument.** The image starts from `cgr.dev/chainguard/wolfi-base` and installs
a deliberately small package set — `postgresql-${PG_MAJOR}` (the major is a build
arg; CI builds 16/17/18), its `-client` and `-contrib`, plus `gosu`, `tzdata`,
and `bash`. Critically there is **no `perl`**:
`perl` is the source of the unfixable Debian CRITICALs in `postgres:18`, and it
is simply not present here. Fewer packages means fewer executables, fewer
libraries, and a smaller CVE-bearing surface than the Debian-based official
image.

**Evidence.**
- [`Dockerfile`](../Dockerfile) — the single `apk add --no-cache` line is the
  complete package set; the comment block documents why each package is present
  and that `perl` is intentionally absent.
- [`README.md`](../README.md) — states the glibc / no-`perl` / minimal-set
  rationale.
- Independently checkable against the per-package SBOM (sub-claim 4): the
  inventory contains no `perl` entry.

### 2. Fresh patches

**Argument.** Wolfi packages are daily-patched upstream. A static image would
drift; this one does not, because CI rebuilds from scratch **weekly** (Monday
06:17 UTC), plus on every push to `main` and on manual dispatch. Each rebuild
re-pulls the current Wolfi packages, so daily upstream fixes reach each
`:NN-latest` line (16/17/18) within at most a week, and CRITICALs are handled
out of band per the security policy.

**Evidence.**
- [`.github/workflows/build.yml`](../.github/workflows/build.yml) — `on.schedule`
  cron `17 6 * * 1`, plus `workflow_dispatch` and `push: [main]`.
- [`SECURITY.md`](../SECURITY.md) — "Supported versions" table (the `:NN-latest`
  lines rebuilt weekly) and the response process (CRITICALs expedited off-cadence).

### 3. No shipped CRITICALs

**Argument.** A rebuild is only allowed to publish if it is clean of CRITICAL
OS/library vulnerabilities. The Trivy scan runs with `--exit-code 1
--severity CRITICAL`, so any CRITICAL fails the `scan` task, which fails the CI
step, which stops the run **before** the push step. HIGH is scanned and reported
in the same task but is non-gating (see residual risks).

**Evidence.**
- [`Taskfile.yml`](../Taskfile.yml) — `scan` task: first command is the
  CRITICAL gate (`trivy image --exit-code 1 --severity CRITICAL …`); second
  reports HIGH without `--exit-code`.
- [`.github/workflows/build.yml`](../.github/workflows/build.yml) — the
  "Scan (CRITICAL gate) + SBOM + smoke" step runs `devbox run -- task scan …`
  and sits *above* the "Push" step, so a non-zero exit blocks publication.

### 4. Auditability

**Argument.** Consumers can enumerate exactly what is in the image. The pipeline
generates a CycloneDX SBOM with `syft` and then `cosign attest`s it to the image
**by digest**, so the package inventory travels with the artifact and is
retrievable and verifiable after the fact — not just an ephemeral CI log.

**Evidence.**
- [`Taskfile.yml`](../Taskfile.yml) — `sbom` task:
  `syft … -o cyclonedx-json=sbom.cdx.json`.
- [`.github/workflows/build.yml`](../.github/workflows/build.yml) — the SBOM is
  produced **per-arch** in the scan/sbom/smoke step, uploaded as a per-arch build
  artifact, and the "Sign + attest per-arch" step runs
  `cosign attest --yes --type cyclonedx --predicate sbom.cdx.json "$DIGEST"`
  against each arch image's digest.
- Retrieve the attested SBOM from a pulled image (any `:NN-latest`/`:NN-YYYYMMDD`
  tag, ideally by `@sha256:…` digest):

  ```bash
  cosign verify-attestation ghcr.io/openserbia/postgres-wolfi:18-latest \
    --type cyclonedx \
    --certificate-identity-regexp 'https://github.com/openserbia/postgres-wolfi/.github/workflows/build.yml@.*' \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com
  ```

### 5. Integrity / anti-tamper

**Argument.** Pushed images are signed with `cosign` keyless signing (Sigstore /
GitHub OIDC) — there is no long-lived private key to leak; the signature is
bound to the workflow identity that produced it. Signing is done **by digest**,
so the signature attests the exact bytes pulled, defeating tampering and
man-in-the-middle substitution on the delivery path (GHCR is also served over
TLS). Anyone can verify before running.

**Evidence.**
- [`README.md`](../README.md) — "Verify the signature" section gives the exact
  `cosign verify` command (certificate-identity-regexp pinned to this repo's
  `build.yml`, issuer `token.actions.githubusercontent.com`).
- [`.github/workflows/build.yml`](../.github/workflows/build.yml) — the
  "Sign + attest per-arch (by digest …)" step in the build job resolves each arch
  image's digest and runs `cosign sign --yes "$DIGEST"`, and the `manifest` job's
  "Sign manifest list" step signs the multi-arch index digest;
  `permissions: id-token: write` enables the OIDC keyless flow.

### 6. Least privilege at runtime

**Argument.** The postmaster does not run as root. The image creates a dedicated
`postgres` user/group at `uid:gid 70:70`; the (vendored) entrypoint starts as
root only to fix `$PGDATA` ownership, then `gosu`-drops to `postgres` for the
long-running process. This is not merely intended — the smoke test asserts it on
the running container by failing if *any* process runs as uid 0.

**Evidence.**
- [`Dockerfile`](../Dockerfile) — `addgroup -g 70` / `adduser -u 70` create the
  `postgres` user; `$PGDATA` is `install`ed `-o postgres -g postgres -m 0700`.
- [`test/smoke.sh`](../test/smoke.sh) — the "no process runs as root (layer-1
  drop)" check counts root processes via `docker top … | awk '$2==0'` and fails
  the build if the count is non-zero.

### 7. Hardened delivery process

**Argument.** The pipeline that produces these artifacts is itself constrained.
Every third-party GitHub Action is **SHA-pinned** with a version comment (not a
moveable tag), so a compromised or retagged upstream action cannot silently
enter the build. CI tooling (`trivy`, `syft`, `cosign`, `go-task`) is pinned via
`devbox` and a committed lockfile, and is run as the project's own CLIs rather
than via marketplace tool-wrapper actions. OpenSSF Scorecard runs weekly on a
GitHub-hosted runner and publishes results for outside review.

**Evidence.**
- [`.github/workflows/build.yml`](../.github/workflows/build.yml) and
  [`.github/workflows/scorecard.yml`](../.github/workflows/scorecard.yml) —
  every `uses:` is `@<40-char-sha>  # vX.Y.Z`; `build.yml` declares minimal
  top-level `permissions` and runs tooling via `devbox run`.
- [`devbox.lock`](../devbox.lock) — pins the exact tool versions resolved from
  [`devbox.json`](../devbox.json).
- [`scorecard.yml`](../.github/workflows/scorecard.yml) — `ossf/scorecard-action`
  with `publish_results: true`, on a GitHub-hosted `ubuntu-latest` runner (not a
  self-hosted build runner); the Scorecard badge is in the README.

## Residual risks / out of scope

Stated plainly, so the top claim is not over-read:

- **PostgreSQL configuration hardening is the operator's job.**
  `postgresql.conf` / `pg_hba.conf`, TLS, password policy, network exposure, and
  least-privilege roles are *not* configured by this image — it ships
  PostgreSQL's defaults. The assurance case covers the image, not the cluster
  you run from it. See the "You cannot expect" list in
  [`SECURITY.md`](../SECURITY.md).
- **HIGH severity is reported, not gated.** The Trivy CRITICAL gate (sub-claim 3)
  blocks CRITICALs only; HIGH findings are surfaced for visibility but do **not**
  fail the build. A clean build can still ship HIGH-rated CVEs.
- **Bus factor is currently 1.** There is a single active maintainer
  (GitHub `OCharnyshevich`). Conventional Commits, DCO sign-off, and private
  vulnerability reporting are in place, but there is no second independent
  reviewer today; the described review model is the intent, not a current
  guarantee. Treat single-maintainer continuity as a real risk.
- **Phase-2 rootless is not yet shipped.** The container still starts as root to
  fix `$PGDATA` ownership before dropping to `postgres` (sub-claim 6). The
  fully-rootless `USER postgres` variant is planned but not yet delivered, so the
  brief root window at startup remains in scope.
- **Upstream trust is inherited.** Wolfi packages, PostgreSQL itself, and `gosu`
  are trusted as upstreams; this project re-ships their fixes on the weekly
  cadence but does not independently audit their source. Report upstream
  vulnerabilities to those projects (see [`SECURITY.md`](../SECURITY.md)).

## See also

- [`SECURITY.md`](../SECURITY.md) — reporting, response process, security model.
- [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) — how the image is built and why.
