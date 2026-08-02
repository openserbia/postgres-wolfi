<!--
SPDX-FileCopyrightText: 2026 OpenSerbia
SPDX-License-Identifier: MIT
-->
# Releasing

How `postgres-wolfi` releases are produced, marked, and verified. Releases are
**continuous and automated**: there is no manual "build the artifact" step.
Cutting a *marked* release (a GitHub Release) is an optional, human-driven
annotation on top of an image that CI already built and pushed.

## Cadence

The build workflow (`.github/workflows/build.yml`) runs:

- **weekly**, every **Monday 06:17 UTC** (so daily-patched Wolfi packages flow in);
- on **push to `main`**;
- on **manual dispatch** (`workflow_dispatch`).

The workflow fans out as a **matrix over the supported majors** (`NN` ∈ 16, 17,
18 — add 19 once Wolfi ships `postgresql-19`) **× arches** (`amd64`, `arm64`),
one leg per `(major, arch)`. Each leg runs **natively** on a self-hosted runner of
its architecture (routed by GitHub's built-in `X64` / `ARM64` labels). For a leg,
a successful run:

1. builds the image natively (`--build-arg PG_MAJOR=NN`),
2. scans → SBOMs → smoke-tests it, then
3. pushes a **per-arch scratch tag** `:NN-<arch>` and cosign-signs + SBOM-attests
   the resulting image **by digest**.

Pipeline order **per leg** is: build → Trivy scan (fails on CRITICAL; HIGH
reported, non-gating) → CycloneDX SBOM (syft, `sbom.cdx.json`) → smoke test →
push → cosign keyless sign → cosign attest SBOM. Legs are independent
(`fail-fast: false`): a leg that fails Trivy or the smoke test publishes nothing
and does not block the others — there is no broken release.

A final **`manifest` job** (per major) then assembles the two arch images into the
public **multi-arch list** — the rolling `:NN-latest` — with
`docker buildx imagetools create`, and cosign-signs the **manifest-list (index)
digest**. So a published `:NN-latest` is an amd64+arm64 manifest whose index is
signed and whose per-arch children are each signed and SBOM-attested.

The job assembles the list from the **digests** recorded by this run's build legs
(passed between jobs as `digest-<pg>-<arch>` artifacts, uploaded only after a leg
has fully passed), never from the `:NN-<arch>` tags. It **fails closed** if either
arch is missing, so a major whose arm64 leg failed publishes nothing rather than
silently reusing whatever the previous run left in the registry.

The published index digest is echoed to the job log and to the run summary as a
`Published PG NN` notice — **that is the pin handle for the build.**

> [!CAUTION]
> **Never enable GHCR's "delete untagged versions" retention on this package.**
> A per-arch image and the corresponding child of the `:NN-latest` manifest list
> are the **same manifest (one digest)** — the index references the child *by
> digest*. GHCR (and the GitHub Packages API) can only delete a whole *version*,
> not "untag while keeping the manifest".
>
> Every tag this project publishes is rolling, so **each build leaves the previous
> one untagged**: the old index and both its children stay in the registry, reachable
> only by digest. That is by design — it is what makes `@sha256:…` pins work — but it
> means pruning untagged versions would **break every digest pin any consumer has
> ever recorded**, not merely reclaim old junk. There is no retention policy that
> is safe to enable here.

## Version uniqueness

There are no semantic version numbers and no date tags. A release is identified
by exactly one thing: the **image digest** `sha256:…` (content-addressed).

The digest is not merely authoritative, it is the *only* identifier — which is
the point. **Signing and SBOM attestation are done by digest**, so the signature
and SBOM are bound to exact content; any tag would be a mutable alias that
carries none of that proof. A date tag in particular fails at its own job as soon
as two builds land on the same UTC day, silently resolving to the later one.

`:NN-latest` is a *channel*, not a version: it names "the current NN.x build",
and it moves. Always record the digest of any image you deploy, and deploy that
digest.

## Cutting a marked release (GitHub Release)

CI already publishes every build; a GitHub Release is for calling out a snapshot
worth pointing people at (a notable change, a security fix, a recommended pin).
It does **not** build or push anything.

1. Capture the **digest** of the build you are marking, for the major you are
   marking it on. Take it from the `Published PG NN` notice on the build run, or
   resolve the current one:

   ```bash
   docker buildx imagetools inspect ghcr.io/openserbia/postgres-wolfi:18-latest \
     --format '{{.Manifest.Digest}}'
   ```

   Do this **before** the next build publishes, or `:18-latest` will already have
   moved — the digest is the only handle, so capture it deliberately.

2. Update `CHANGELOG.md`: move the relevant `[Unreleased]` notes into a dated
   entry (`## [YYYY-MM-DD]`), keeping the `Added` / `Changed` / `Fixed` /
   `Security` subsections, and **record the digest in the entry**.
3. Draft a **GitHub Release** on a *git* tag named for the snapshot, e.g.
   `18-YYYYMMDD` (the major prefix keeps releases on different lines distinct).
   This is a git tag only — the project publishes no image tag of that name. In
   the body:
   - summarize the notable changes and any security fixes,
   - give the full pull-by-digest ref
     (`ghcr.io/openserbia/postgres-wolfi@sha256:…`) — this is the artifact the
     release *is*, since no image tag will keep pointing at it,
   - **link the matching `CHANGELOG.md` entry**.
4. Keep the title and notes terse and factual — no marketing.

Marked releases are optional and infrequent; the day-to-day distribution channel
is the GHCR tags, not GitHub Releases.

## Security-relevant releases

When a build remediates a vulnerability in this project's own artifacts (image
assembly, CI, packaging):

- record it under the **`Security`** subsection of the `CHANGELOG.md` entry; and
- publish (or update) a **GitHub Security Advisory** per
  [`SECURITY.md`](../SECURITY.md), crediting the reporter unless they ask to
  remain anonymous.

CRITICAL fixes are handled **out of the weekly cadence** (trigger a manual
dispatch). Vulnerabilities in *upstream* components (PostgreSQL, Wolfi packages,
`gosu`) are not separately advised by this project — they are pulled in on the
next rebuild — but a marked release may still note that a rebuild cleared a
specific upstream CVE.

> **Bus factor 1.** This project currently has a single active maintainer, so
> issuing an advisory and the corresponding release is a solo step. The process
> above is the intended model; there is no second reviewer gating a release
> today. Pinning by digest and verifying signatures (below) is how consumers
> get assurance independent of the maintainer.

## How consumers verify a release

Anyone can verify an image without trusting the registry:

1. **Signature** — keyless cosign (Sigstore / GitHub OIDC). Use the
   `cosign verify` invocation in the [README](../README.md#verify-the-signature);
   it checks the certificate identity is this repo's `build.yml` workflow and the
   OIDC issuer is GitHub. Verify the **digest** you intend to run, e.g.:

   ```bash
   cosign verify ghcr.io/openserbia/postgres-wolfi@sha256:<digest> \
     --certificate-identity-regexp 'https://github.com/openserbia/postgres-wolfi/.github/workflows/build.yml@.*' \
     --certificate-oidc-issuer https://token.actions.githubusercontent.com
   ```

2. **SBOM attestation** — the CycloneDX SBOM is attested to the image by digest.
   Pull and inspect it to audit every package and version:

   ```bash
   cosign verify-attestation ghcr.io/openserbia/postgres-wolfi@sha256:<digest> \
     --type cyclonedx \
     --certificate-identity-regexp 'https://github.com/openserbia/postgres-wolfi/.github/workflows/build.yml@.*' \
     --certificate-oidc-issuer https://token.actions.githubusercontent.com
   ```

A passing signature verification proves the image came from this project's CI
unmodified; the attested SBOM lets you confirm exactly what is inside it.
