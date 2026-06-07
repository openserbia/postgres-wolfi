<!--
SPDX-FileCopyrightText: 2026 OpenSerbia
SPDX-License-Identifier: MIT
-->
# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/).

This project does **not** use Semantic Versioning. Releases are date snapshots:
each dated entry below corresponds to a published
`ghcr.io/openserbia/postgres-wolfi:NN-YYYYMMDD` image (and the matching
`:NN-latest` rolling tag at that point), for each supported major `NN` ∈ 16, 17,
18. The image **digest** is the canonical identity of a
release; see [`docs/releasing.md`](docs/releasing.md). Most builds are routine
weekly rebuilds and are not given a dedicated entry — entries here mark
snapshots worth calling out (notable changes, security fixes).

Security fixes to this project's own artifacts are recorded under a `Security`
subsection and, where applicable, in a GitHub Security Advisory (see
[`SECURITY.md`](SECURITY.md)).

## [Unreleased]

### Added

- Multi-version build matrix: the `:16-*`, `:17-*`, and `:18-*` tag lines are now
  built, Trivy-scanned, smoke-tested, signed, and SBOM-attested in parallel on the
  weekly cadence — previously only `:18-*` was produced.
- Multi-arch images: each `:NN-latest` / `:NN-YYYYMMDD` tag is now a
  **`linux/amd64` + `linux/arm64`** manifest list. Each arch is built and
  smoke-tested **natively** on a self-hosted runner of its architecture (routed by
  GitHub's built-in `X64` / `ARM64` labels), signed and SBOM-attested per-arch by
  digest; a `manifest`
  job assembles the list and signs the index digest.

### Changed

- `Dockerfile` selects the PostgreSQL major via a `PG_MAJOR` build arg (default
  `18`) instead of hardcoding `18`, and now sets `PG_MAJOR` as a runtime env so the
  vendored entrypoint's major-aware checks resolve correctly.
- `Taskfile.yml` passes `--build-arg PG_MAJOR` through and accepts an override
  (`task ci PG_MAJOR=17`); the build workflow drives one major per matrix leg.
- Docs (`docs/releasing.md`, `docs/ARCHITECTURE.md`): documented that the per-arch
  `:NN-YYYYMMDD-<arch>` tags are load-bearing manifest-list children — deleting
  them, or enabling GHCR's *delete untagged versions* retention, breaks the
  multi-arch images — surfaced as a GitHub `[!CAUTION]` alert.
- CI: doc/meta-only pushes (`**/*.md`, `docs/**`, `LICENSE`, `.gitignore`,
  `.idea/**`) no longer trigger the image-build matrix or `lint` (`paths-ignore`
  on each `push` trigger). The weekly `schedule` rebuild and `workflow_dispatch`
  always build; `lint` keeps running unfiltered on every `pull_request`.
- CI: `packages: write` / `id-token: write` moved off the top-level `permissions`
  block (which every job inherited) onto only the `build`/`manifest` jobs that push
  to GHCR and cosign-sign — least privilege; the `setup` job is now read-only.
  Restores OpenSSF Scorecard **Token-Permissions** to 10/10.
- Added a deny-all `.dockerignore` (`*` then `!docker-entrypoint.sh`): the build
  context is now just the single COPYed file (~3.2 MB → 447 B) and a stray
  `COPY`/`ADD` can no longer bake `.git`, secrets, or SBOMs into a layer.
- `.gitignore`: ignore `.idea/`, `.devbox/`, `.code-review-graph/`, and untracked
  the IDE state files (`.idea/vcs.xml`, `.idea/workspace.xml`) that had been
  committed.

### Fixed

- Smoke test: gate readiness on the entrypoint's `PostgreSQL init process
  complete; ready for start up.` marker before trusting `pg_isready`, fixing a
  flaky `the database system is shutting down` failure caused by latching onto the
  temporary init server during first-boot. The test now also asserts the running
  server's **major** matches the requested `PG_MAJOR` (version-drift gate); minor
  drift (e.g. 16.8 → 16.14) is printed for visibility but does not fail.

### Security
