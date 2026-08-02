# postgres-wolfi

[![build](https://github.com/openserbia/postgres-wolfi/actions/workflows/build.yml/badge.svg)](https://github.com/openserbia/postgres-wolfi/actions/workflows/build.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/openserbia/postgres-wolfi/badge)](https://scorecard.dev/viewer/?uri=github.com/openserbia/postgres-wolfi)
[![cosign signed](https://img.shields.io/badge/cosign-signed-blueviolet?logo=sigstore&logoColor=white)](#verify-the-signature)
[![image size](https://ghcr-badge.egpl.dev/openserbia/postgres-wolfi/size?tag=18-latest&label=image%20size&color=blue)](https://github.com/openserbia/postgres-wolfi/pkgs/container/postgres-wolfi)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
<!-- TODO: register at bestpractices.dev, then replace PROJECT_ID and uncomment -->
<!-- [![OpenSSF Best Practices](https://www.bestpractices.dev/projects/PROJECT_ID/badge)](https://www.bestpractices.dev/projects/PROJECT_ID) -->

A self-built **PostgreSQL** container image — majors **16, 17, 18**, each on its
own tag line — on [Chainguard Wolfi](https://github.com/wolfi-dev)
(glibc, **no `perl`**, daily-patched packages). Built to escape the unfixable
Debian `perl` CRITs in the official `postgres:18` image while staying free
(no Chainguard subscription) and self-owned. Rebuilt weekly, Trivy-gated on
CRITICAL, cosign-signed, with a CycloneDX SBOM.

## Image

`ghcr.io/openserbia/postgres-wolfi`

Each supported major publishes exactly one tag (`NN` ∈ `16`, `17`, `18`):

| Reference        | Meaning                                                                                                          |
|------------------|------------------------------------------------------------------------------------------------------------------|
| `:NN-latest`     | Rolling — newest build of the **NN.x** line (only ever moves across *minor* bugfix releases, never a major jump) |
| `@sha256:…`      | Immutable — pin / rollback to an exact build                                                                      |

So `:18-latest`, `:17-latest`, and `:16-latest` track each line independently.
There is intentionally **no `:latest`** and **no bare `:NN`** — a database must
never be pulled by an unbounded floating tag.

There are no dated tags: **pin by digest.** The digest is the canonical identity
of a build — it is what cosign signs and what the SBOM is attested to — so a tag
would only ever be a second, weaker name for it. Resolve the current digest with:

```bash
docker buildx imagetools inspect ghcr.io/openserbia/postgres-wolfi:18-latest \
  --format '{{.Manifest.Digest}}'
```

then deploy `ghcr.io/openserbia/postgres-wolfi@sha256:…` and record that digest.

Every tag is a **multi-arch manifest list** (`linux/amd64` + `linux/arm64`),
each architecture built and smoke-tested natively; `docker pull` resolves to your
platform automatically.

```bash
docker pull ghcr.io/openserbia/postgres-wolfi:18-latest
```

## Runtime

- **PostgreSQL 16.x / 17.x / 18.x** (whichever tag line you pull), postmaster runs
  **non-root** as user `postgres` (**uid:gid `70:70`**).
  The entrypoint starts as root, fixes `$PGDATA` ownership, then `gosu`-drops to `postgres`.
- Drop-in env contract with the official image (`POSTGRES_PASSWORD`, `POSTGRES_USER`,
  `POSTGRES_DB`, `PGDATA`, `/docker-entrypoint-initdb.d`) — the entrypoint is vendored
  from docker-library/postgres.
- `PGDATA=/var/lib/postgresql/data`, default `LANG=C.UTF-8`.

## Verify the signature

Every pushed image is signed, so this works for any `:NN-latest` tag — and,
preferably, for the `@sha256:…` digest you actually deploy:

```bash
cosign verify ghcr.io/openserbia/postgres-wolfi:18-latest \
  --certificate-identity-regexp 'https://github.com/openserbia/postgres-wolfi/.github/workflows/build.yml@.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Licensing

This repo's own work is MIT (`LICENSE`). Bundled components are attributed in
`THIRD_PARTY_LICENSES.md`; the CI-generated SBOM is the full per-package inventory.

## Project & docs

- [CONTRIBUTING.md](CONTRIBUTING.md) — how to contribute
- [SECURITY.md](SECURITY.md) — reporting vulnerabilities
- [GOVERNANCE.md](GOVERNANCE.md) — decisions and maintainership
- [CHANGELOG.md](CHANGELOG.md) — notable changes per release
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — image and pipeline design
- [docs/ROADMAP.md](docs/ROADMAP.md) — planned work
- [docs/assurance-case.md](docs/assurance-case.md) — security assurance argument
- [docs/releasing.md](docs/releasing.md) — release and tagging process
- [docs/bestpractices-badge.md](docs/bestpractices-badge.md) — Best Practices criteria mapping

## Migrating an existing cluster

Moving a **populated** cluster from a Debian/glibc `postgres` image to this one
is not a plain image swap: text-collation ordering is libc-dependent, so a
glibc→Wolfi move can trigger a collation-version mismatch and require a
`REINDEX`. The clean path is `pg_dumpall` → restore into a fresh cluster,
ideally with a libc-agnostic locale provider (`builtin C.UTF-8` or ICU). The
postmaster runs as uid:gid `70:70` — own the data volume accordingly.
