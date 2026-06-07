# postgres-wolfi

[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/openserbia/postgres-wolfi/badge)](https://scorecard.dev/viewer/?uri=github.com/openserbia/postgres-wolfi)

A self-built **PostgreSQL 18** container image on [Chainguard Wolfi](https://github.com/wolfi-dev)
(glibc, **no `perl`**, daily-patched packages). Built to escape the unfixable
Debian `perl` CRITs in the official `postgres:18` image while staying free
(no Chainguard subscription) and self-owned. Rebuilt weekly, Trivy-gated on
CRITICAL, cosign-signed, with a CycloneDX SBOM.

## Image

`ghcr.io/openserbia/postgres-wolfi`

| Tag            | Meaning                                                                                                          |
|----------------|------------------------------------------------------------------------------------------------------------------|
| `:18-latest`   | Rolling — newest build of the **18.x** line (only ever moves across *minor* bugfix releases, never a major jump) |
| `:18-YYYYMMDD` | Immutable — pin / rollback                                                                                       |

There is intentionally **no `:latest`** and **no bare `:18`** — a database must
never be pulled by an unbounded floating tag.

```bash
docker pull ghcr.io/openserbia/postgres-wolfi:18-latest
```

## Runtime

- **PostgreSQL 18.x**, postmaster runs **non-root** as user `postgres` (**uid:gid `70:70`**).
  The entrypoint starts as root, fixes `$PGDATA` ownership, then `gosu`-drops to `postgres`.
- Drop-in env contract with the official image (`POSTGRES_PASSWORD`, `POSTGRES_USER`,
  `POSTGRES_DB`, `PGDATA`, `/docker-entrypoint-initdb.d`) — the entrypoint is vendored
  from docker-library/postgres.
- `PGDATA=/var/lib/postgresql/data`, default `LANG=C.UTF-8`.

## Verify the signature

```bash
cosign verify ghcr.io/openserbia/postgres-wolfi:18-latest \
  --certificate-identity-regexp 'https://github.com/openserbia/postgres-wolfi/.github/workflows/build.yml@.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Licensing

This repo's own work is MIT (`LICENSE`). Bundled components are attributed in
`THIRD_PARTY_LICENSES.md`; the CI-generated SBOM is the full per-package inventory.

## Migrating an existing cluster

Moving a **populated** cluster from a Debian/glibc `postgres` image to this one
is not a plain image swap: text-collation ordering is libc-dependent, so a
glibc→Wolfi move can trigger a collation-version mismatch and require a
`REINDEX`. The clean path is `pg_dumpall` → restore into a fresh cluster,
ideally with a libc-agnostic locale provider (`builtin C.UTF-8` or ICU). The
postmaster runs as uid:gid `70:70` — own the data volume accordingly.
