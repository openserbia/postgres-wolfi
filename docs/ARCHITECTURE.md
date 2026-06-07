<!--
SPDX-FileCopyrightText: 2026 OpenSerbia
SPDX-License-Identifier: MIT
-->
# Architecture

High-level design of `postgres-wolfi`: what it is, how the image is assembled,
how privileges are dropped at runtime, and how the build/release pipeline keeps
the result verifiable. For operator-facing usage see [`README.md`](../README.md);
for the security model and reporting see [`SECURITY.md`](../SECURITY.md); for the
structured argument that the security claims hold see
[`docs/assurance-case.md`](assurance-case.md).

## Goal & threat model

The official `postgres:18` image is Debian-based and carries `perl`, which drags
in CRITICAL CVEs that have no upstream fix on that base. `postgres-wolfi` exists
to escape those while staying free (no Chainguard subscription) and self-owned.

Design goals, in priority order:

- **Reduce attack surface vs `postgres:18`.** Build on Chainguard Wolfi (glibc,
  daily-patched packages), ship **no `perl`**, and install only the minimal
  package set PostgreSQL needs. Fewer packages → fewer CVEs → smaller blast
  radius.
- **Keep the supply chain verifiable.** Every pushed image is Trivy-gated on
  CRITICAL, carries an attested CycloneDX SBOM, and is cosign-signed (keyless,
  Sigstore / GitHub OIDC) so a consumer can prove provenance.
- **Stay free and self-owned.** No paid base image, no vendor lock-in; the whole
  pipeline runs on a public repo plus a self-hosted runner.

In scope: the image assembly (packages, user/permission model), the
build/release CI, and the signing/SBOM pipeline. **Out of scope:** PostgreSQL
*configuration* hardening (`postgresql.conf`, `pg_hba.conf`, TLS, roles,
secrets) — that is the operator's responsibility. See `SECURITY.md` for the full
can/cannot-expect contract.

## Image composition

`FROM cgr.dev/chainguard/wolfi-base`, then a single `apk add` layer. The major
is selected by a **`PG_MAJOR` build arg** (default `18`); the CI matrix builds
one image per supported major (`16`, `17`, `18`), so the table below is written
in terms of `${PG_MAJOR}`:

| Package                       | Why                                                        |
|-------------------------------|-----------------------------------------------------------|
| `postgresql-${PG_MAJOR}`      | the server (`postgres`, `initdb`)                          |
| `postgresql-${PG_MAJOR}-client`| client tooling (`psql`, `pg_dump`, …)                     |
| `postgresql-${PG_MAJOR}-contrib`| bundled extensions (`pg_stat_statements`, `pgcrypto`, `uuid-ossp`, …) so `CREATE EXTENSION` and restores work |
| `gosu`                        | privilege drop in the entrypoint (no `setuid` shell)       |
| `tzdata`                      | time-zone database                                         |
| `bash`                        | required by the vendored entrypoint script                |

`PG_MAJOR` is also set as a runtime `ENV`, so the vendored entrypoint's
major-aware logic (data-layout / old-database checks) resolves correctly.

Wolfi's `postgresql-${PG_MAJOR}` apk does **not** create a `postgres` account, so the
image creates one explicitly with the busybox `addgroup`/`adduser` already
present (avoids pulling the heavier `shadow`):

- group `postgres` and user `postgres` at **uid:gid `70:70`** — matching the
  conventional Postgres uid so a data volume chowned for the official image
  stays usable.

Data and init layout:

- `PGDATA=/var/lib/postgresql/data`, created `0700` owned by `postgres`.
- `/docker-entrypoint-initdb.d` for first-boot init scripts (upstream contract).

The entrypoint is **vendored verbatim** from `docker-library/postgres` at a
pinned commit and copied to `/usr/local/bin/docker-entrypoint.sh`. It is never
hand-edited — only refreshed by deliberately bumping the pin — which preserves
drop-in compatibility with the official image's env contract (`POSTGRES_PASSWORD`,
`POSTGRES_USER`, `POSTGRES_DB`, `PGDATA`, `/docker-entrypoint-initdb.d`). The
provenance and license are recorded in `THIRD_PARTY_LICENSES.md`.

## Privilege model & entrypoint flow

The container starts as **root** only long enough to fix ownership of the data
directory (which may be a freshly-mounted volume), then permanently drops to the
unprivileged `postgres` user before the database ever runs:

```
container start (root)
        │
        ▼
docker-entrypoint.sh  ── fix ownership of $PGDATA ──┐
        │                                           │
        ▼                                           │
  gosu  postgres (70:70) ◄──────────────────────────┘
        │
        ▼
  postmaster runs NON-ROOT
```

`gosu` is used instead of a `setuid` helper so there is no privilege-escalation
surface left in the running container. The postmaster never holds root.

**Phase-2 plan:** flip to a fully-rootless image (`USER postgres`, no root phase
at all). That requires the data volume to arrive already owned by `70:70`, so it
is staged as a deliberate breaking change rather than folded in silently.

## Build & release pipeline

GitHub Actions, triggered **weekly (Monday 06:17 UTC)**, **on push to `main`**,
and **manually (workflow_dispatch)**. The build fans out as a **matrix over the
supported majors (`16`, `17`, `18`) × arches (`amd64`, `arm64`)** —
`fail-fast: false`, so one leg failing never aborts the others. Each leg builds
**natively** on a self-hosted runner of its architecture — routed by GitHub's
built-in `X64` / `ARM64` labels — so no QEMU is involved and the smoke test
exercises real hardware. Every stage below operates on that leg's built
image, and signing/attestation are done **by digest** (not by tag) so the
signature binds to exact bytes:

```
  docker build
        │
        ▼
  Trivy scan ───── CRITICAL? ──► FAIL build
        │  (HIGH reported, non-gating)
        ▼
  SBOM  (syft → CycloneDX, sbom.cdx.json)
        │
        ▼
  smoke test
        │
        ▼
  push → GHCR  (per-arch tag :NN-DATE-<arch>)
        │
        ▼
  cosign sign   (keyless, by digest)
        │
        ▼
  cosign attest (SBOM, by digest)
```

A CRITICAL finding fails the build, so a vulnerable image is never pushed. The
`ci` Taskfile target runs `build → scan → sbom → smoke` locally with **no push**,
mirroring everything up to the publish step.

Once all arch legs of a major succeed, a separate **`manifest` job** stitches the
per-arch images (`:NN-DATE-amd64`, `:NN-DATE-arm64`) into the public multi-arch
lists — the rolling `:NN-latest` and the immutable `:NN-YYYYMMDD` — with
`docker buildx imagetools create`, then cosign-signs the **manifest-list (index)
digest**. So `cosign verify :NN-latest` (which resolves to the index) passes,
and each arch child is independently signed and SBOM-attested. The arch-suffixed
date tags remain in the registry as the addressable per-arch handles.

## Supply-chain controls

- **Trivy CRITICAL gate** — build fails on any CRITICAL OS/library CVE; HIGH is
  reported for visibility but does not gate.
- **CycloneDX SBOM attested to the image** — `sbom.cdx.json` generated by syft
  and bound to the image via `cosign attest`, so consumers can audit every
  package/version against the exact artifact they pulled.
- **Keyless cosign signatures** — Sigstore with GitHub OIDC; no long-lived
  signing key to leak. Verify command is in `README.md`.
- **SHA-pinned Actions** — every third-party GitHub Action is pinned to a full
  commit SHA with a version comment, so a moved tag can't swap workflow code.
- **OpenSSF Scorecard** — runs weekly on a **GitHub-hosted `ubuntu-latest`**
  runner (not the self-hosted one) and publishes results; badge in `README.md`.
- **devbox-pinned tooling** — `go-task`, `trivy`, `syft`, and `cosign` versions
  are pinned in `devbox.json` / `devbox.lock` for reproducible local and CI runs.

## Tagging strategy

Published under `ghcr.io/openserbia/postgres-wolfi`:

Each supported major (`NN` ∈ 16, 17, 18) publishes its own tag pair:

| Tag             | Meaning                                                            |
|-----------------|-------------------------------------------------------------------|
| `:NN-latest`    | rolling — newest build of the **NN.x** line (minor bumps only)    |
| `:NN-YYYYMMDD`  | immutable — pin / rollback to an exact dated snapshot              |

There is intentionally **no `:latest`** and **no bare `:NN`**. A database must
not be pulled by an unbounded floating tag: `:latest` could silently cross a
major version, and a bare `:18` invites surprise jumps. `:NN-latest` is bounded
to that `NN.x` line for "track the current series", and `:NN-YYYYMMDD` gives an
immutable handle for pinning and rollback.

## Tooling map

Local workflow is **devbox** (pins the toolchain) + **Taskfile** (the tasks):

| Task   | Does                                                          |
|--------|--------------------------------------------------------------|
| `build`| build the image                                              |
| `scan` | Trivy scan (CRITICAL gate)                                   |
| `sbom` | generate the CycloneDX SBOM with syft                        |
| `smoke`| run the smoke test (`test/smoke.sh`)                         |
| `ci`   | `build → scan → sbom → smoke` (no push) — local mirror of CI |
