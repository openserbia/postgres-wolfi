# postgres-wolfi

[![build](https://github.com/openserbia/postgres-wolfi/actions/workflows/build.yml/badge.svg)](https://github.com/openserbia/postgres-wolfi/actions/workflows/build.yml)
[![lint](https://github.com/openserbia/postgres-wolfi/actions/workflows/lint.yml/badge.svg)](https://github.com/openserbia/postgres-wolfi/actions/workflows/lint.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/openserbia/postgres-wolfi/badge)](https://scorecard.dev/viewer/?uri=github.com/openserbia/postgres-wolfi)
[![trivy](https://img.shields.io/badge/trivy-CRITICAL%20gate-blue?logo=trivy&logoColor=white)](SECURITY.md#what-you-can-and-cannot-expect-security-model)
[![cosign signed](https://img.shields.io/badge/cosign-signed-blueviolet?logo=sigstore&logoColor=white)](#verify-the-signature)
[![18 amd64](https://ghcr-badge.egpl.dev/openserbia/postgres-wolfi/size?tag=18-latest&label=18%20amd64&color=blue)](https://github.com/openserbia/postgres-wolfi/pkgs/container/postgres-wolfi)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
<!-- TODO: register at bestpractices.dev, then replace PROJECT_ID and uncomment -->
<!-- [![OpenSSF Best Practices](https://www.bestpractices.dev/projects/PROJECT_ID/badge)](https://www.bestpractices.dev/projects/PROJECT_ID) -->

A self-built **PostgreSQL 18** container image on [Chainguard Wolfi](https://github.com/wolfi-dev)
(glibc, **no `perl`**, daily-patched packages). Built to escape the unfixable
Debian `perl` CRITs in the official `postgres:18` image while staying free
(no Chainguard subscription) and self-owned. Rebuilt weekly, Trivy-gated on
CRITICAL, cosign-signed, with a CycloneDX SBOM.

## Image

`ghcr.io/openserbia/postgres-wolfi`

Each supported major publishes exactly one tag (`NN` ∈ `18`):

| Reference        | Meaning                                                                                                          |
|------------------|------------------------------------------------------------------------------------------------------------------|
| `:NN-latest`     | Rolling — newest build of the **NN.x** line (only ever moves across *minor* bugfix releases, never a major jump) |
| `@sha256:…`      | Immutable — pin / rollback to an exact build                                                                      |

Each major line moves independently; a new major gets its own `:NN-latest`.
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

### Retired: `:16-latest` and `:17-latest`

The 16 and 17 lines were retired on 2026-11-15. On 2026-06-08 Wolfi moved
`postgresql-16` and `postgresql-17` to Chainguard's paid enterprise repo, so the
public packages stopped at `16.14-r1` and `17.10-r1` and get no more security
fixes. Their last builds carry dozens of HIGH PostgreSQL CVEs that only the
next upstream minor release fixes.

The tags stay in the registry so existing deployments keep pulling, but they
are **no longer rebuilt** and will never be patched. Move to `:18-latest`
(a major upgrade: `pg_upgrade` or dump/restore).

Every tag is a **multi-arch manifest list** (`linux/amd64` + `linux/arm64`),
each architecture built and smoke-tested natively; `docker pull` resolves to your
platform automatically.

The size badges are the compressed `linux/amd64` image on that tag. The number
is the sum of the layer blobs in the published manifest, which is what
`docker pull` transfers on amd64. `linux/arm64` is slightly smaller.
`docker images` prints the uncompressed size, which is larger. The badge
follows the tag and changes when the weekly rebuild does.

The [package-count charts](https://github.com/openserbia/postgres-wolfi/blob/metrics/README.md)
track Wolfi `pkg:apk` components for each published rebuild. One amd64 chart
per major, one point per rebuild, and a table of both arches. A point is
added after each rebuild that passes the scan.

```bash
docker pull ghcr.io/openserbia/postgres-wolfi:18-latest
```

## Runtime

- **PostgreSQL 18.x**, postmaster runs
  **non-root** as user `postgres` (**uid:gid `70:70`**).
  The entrypoint starts as root, fixes `$PGDATA` ownership, then `gosu`-drops to `postgres`.
- Drop-in env contract with the official image (`POSTGRES_PASSWORD`, `POSTGRES_USER`,
  `POSTGRES_DB`, `PGDATA`, `/docker-entrypoint-initdb.d`) — the entrypoint is vendored
  from docker-library/postgres.
- `PGDATA=/var/lib/postgresql/data`, default `LANG=C.UTF-8`.
- **No JIT.** LLVM is left out (it was over half the image), so
  `pg_jit_available()` is `false` and queries run interpreted, as with `jit = off`.
  Most OLTP deployments turn JIT off anyway; if you rely on it, see
  [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#image-composition).

## Verify the signature

Every pushed image is signed, so this works for any `:NN-latest` tag — and,
preferably, for the `@sha256:…` digest you actually deploy:

```bash
cosign verify ghcr.io/openserbia/postgres-wolfi:18-latest \
  --certificate-identity-regexp 'https://github.com/openserbia/postgres-wolfi/.github/workflows/build.yml@.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

A local rebuild is not a byte-for-byte copy of that signed image. Wolfi's
package index moves on purpose. What a clone can and cannot reproduce is in
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#reproducing-a-build).

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
