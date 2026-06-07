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

### Fixed

### Security
