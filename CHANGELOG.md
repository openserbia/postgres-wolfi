<!--
SPDX-FileCopyrightText: 2026 OpenSerbia
SPDX-License-Identifier: MIT
-->
# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/).

This project does **not** use Semantic Versioning. The image **digest** is the
canonical — and only — identity of a release: each dated entry below corresponds
to the `ghcr.io/openserbia/postgres-wolfi` image published on that date for each
supported major `NN` ∈ 16, 17, 18, and records its `@sha256:…` digest. `:NN-latest`
is a rolling channel, not a version, and there is no `:NN-YYYYMMDD` image tag; see
[`docs/releasing.md`](docs/releasing.md). Most builds are routine weekly rebuilds
and are not given a dedicated entry — entries here mark snapshots worth calling
out (notable changes, security fixes).

Security fixes to this project's own artifacts are recorded under a `Security`
subsection and, where applicable, in a GitHub Security Advisory (see
[`SECURITY.md`](SECURITY.md)).

## [Unreleased]

### Added

- Multi-version build matrix: the `:16-*`, `:17-*`, and `:18-*` tag lines are now
  built, Trivy-scanned, smoke-tested, signed, and SBOM-attested in parallel on the
  weekly cadence — previously only `:18-*` was produced.
- Multi-arch images: each `:NN-latest` tag is now a
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
- Docs (`docs/releasing.md`, `docs/ARCHITECTURE.md`): documented that manifest-list
  children share one manifest digest with the per-arch images — so enabling GHCR's
  *delete untagged versions* retention breaks the multi-arch images and every
  recorded digest pin — surfaced as a GitHub `[!CAUTION]` alert.
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
- CI: the `main` branch ruleset now requires a pull request and a passing `lint`
  status check (pinned to the GitHub Actions app) before merge, on top of the
  existing signed-commit / linear-history / no-force-push rules. Organization-admin
  bypass is retained, so maintainer direct commits are unaffected; the PR + `lint`
  gate binds external contributors. Lifts OpenSSF Scorecard **Branch-Protection**.

### Fixed

- Smoke test: gate readiness on the entrypoint's `PostgreSQL init process
  complete; ready for start up.` marker before trusting `pg_isready`, fixing a
  flaky `the database system is shutting down` failure caused by latching onto the
  temporary init server during first-boot. The test now also asserts the running
  server's **major** matches the requested `PG_MAJOR` (version-drift gate); minor
  drift (e.g. 16.8 → 16.14) is printed for visibility but does not fail.
- CI: the `manifest` job now composes each multi-arch list **by digest**, from
  digest artifacts that a build leg uploads only after it has passed the CRITICAL
  scan + smoke gate, pushed, signed and SBOM-attested — and fails closed for any
  major missing either arch. It previously composed the list from the per-arch
  **tags** (then `:NN-YYYYMMDD-amd64` / `-arm64`), which made the "a broken major
  never yields a published manifest list" guarantee a no-op on same-day re-runs:
  `DATE` had day granularity, so an earlier run's per-arch tags were still in the
  registry and `imagetools` resolved them regardless. A run whose `arm64` legs
  failed the gate could therefore publish `:NN-latest` as a fresh `amd64` plus a
  **stale `arm64` from an earlier commit**, and still report green. Observed in
  run [`30256361638`](https://github.com/openserbia/postgres-wolfi/actions/runs/30256361638)
  (2026-07-27), where the `17-arm64` and `18-arm64` legs failed yet `manifest (17)`
  and `manifest (18)` both succeeded. No affected image reached users: the arm64
  children stitched in that run came from a fully-gated run 39 seconds earlier,
  and the weekly scheduled rebuild six minutes later republished all tags from a
  clean full-matrix run.

### Removed

- **The dated `:NN-YYYYMMDD` image tag is no longer published.** `:NN-latest` is
  now the only public tag per major, and a specific build is pinned by its
  `@sha256:…` **digest** — which is already what cosign signs and what the SBOM is
  attested to, making it the only reference that carries its own proof. A date tag
  was a second, weaker name for the same thing, and ambiguous by construction: two
  builds landing on the same UTC day silently collapsed onto one tag. The `setup`
  job that computed the shared date is gone, and the per-arch tags are now stable
  scratch pointers (`:NN-<arch>`, overwritten each run) rather than accumulating
  ~6 dated tags per week forever.

  **Consumer impact:** existing `:NN-YYYYMMDD` tags already in GHCR keep working;
  no new ones are created. If you pin by date tag, switch to a digest —
  `docker buildx imagetools inspect …:NN-latest --format '{{.Manifest.Digest}}'`.

  **Operational consequence:** because every published tag now rolls, each build
  leaves the previous index and its children **untagged but present**. That is what
  digest pins resolve to, so GHCR's *delete untagged versions* retention must stay
  disabled — enabling it would break every digest any consumer has recorded, not
  just old artifacts. Documented as a `[!CAUTION]` in `docs/releasing.md` and
  `docs/ARCHITECTURE.md`.

### Security
