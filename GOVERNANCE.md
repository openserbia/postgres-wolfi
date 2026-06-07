<!--
SPDX-FileCopyrightText: 2026 OpenSerbia
SPDX-License-Identifier: MIT
-->
# Governance

## Overview

`postgres-wolfi` is a small, single-maintainer, security-focused container image
project under the [`openserbia`](https://github.com/openserbia) GitHub
organization. This document describes how decisions are made, who can do what,
and how the project is kept running. It is deliberately lightweight and matches
the project's actual size.

## Roles & responsibilities

### Maintainer

The maintainer has write/admin access to the repository and is accountable for
the integrity of the project and its releases. The maintainer may:

- review and merge pull requests;
- cut releases and move the `:NN-latest` tags / publish `:NN-YYYYMMDD` snapshots
  for each supported major (16, 17, 18);
- triage and handle security reports (see [`SECURITY.md`](SECURITY.md));
- steward the release identity: the keyless cosign signing flow and the GitHub
  Actions workflow OIDC identity used to sign and attest images;
- administer the repository (labels, branch protection, CI configuration,
  CODEOWNERS).

The project currently has a **single active maintainer** (bus factor 1); see
[Access & continuity](#access--continuity-succession--bus-factor).

### Contributor

Anyone who proposes a change is a contributor. Contributors may:

- open issues (bug reports, questions, proposals);
- open pull requests against the repository;
- review and comment on others' issues and PRs.

Contributors do not have merge rights. The contribution workflow, coding
standards, test policy, and DCO requirement are in
[`CONTRIBUTING.md`](CONTRIBUTING.md).

## Decision-making

Decisions are made by **lazy consensus**: a proposal on an issue or pull request
is assumed accepted if no one objects within a reasonable time. Discussion
happens in the open on the issue or PR.

- If consensus cannot be reached or a discussion is tied, the **maintainer
  decides**.
- **Significant changes** — anything affecting the runtime contract, the
  security or signing model, the tagging scheme, or the supported version line —
  are announced and discussed in a tracking **issue** before they are merged, so
  users have a chance to weigh in.

## Becoming a maintainer

A contributor may be invited to become a maintainer after a track record of
**sustained, quality contributions** (good PRs, useful reviews, reliable issue
triage). The process:

1. An existing maintainer extends an invitation.
2. Organization owners grant the new maintainer access to the repository.

Recruiting a second maintainer is an explicit roadmap goal (see below).

## Code review model

The **goal** is that **every change is reviewed by someone other than its
author**. Reviews are routed through [`.github/CODEOWNERS`](.github/CODEOWNERS),
and CI (build → Trivy scan → SBOM → smoke test) must pass before merge.

**Current limitation (stated honestly).** With only one active maintainer,
two-person review is not always possible:

- **External PRs** are always reviewed by the maintainer before merge — the
  author and reviewer are different people, so the goal holds.
- **The maintainer's own changes** sometimes have no second reviewer available.
  In that case **self-merge after a green CI run is unavoidable**. CI gating
  (Trivy on CRITICAL, smoke test, lint, SHA-pin review) is the compensating
  control, but it is not a substitute for a second human reviewer.

This gap closes as soon as a second maintainer is in place.

## Access & continuity (succession / bus factor)

**The real risk, plainly: the project's bus factor is currently 1.** A single
maintainer is the only person with merge and release authority. If that person
becomes unavailable, day-to-day maintenance stops until access is granted to
someone else.

What genuinely mitigates this today:

- **Org ownership.** The repository is owned by the `openserbia` organization,
  not by a personal account. **Organization owners can grant another person
  admin access without involving the current maintainer**, so the project can be
  handed over or recovered even if the maintainer disappears.
- **Keyless signing.** Releases are signed with **cosign keyless signing**
  (Sigstore) tied to the **GitHub Actions workflow OIDC identity**. There is
  **no personal, long-lived signing key** that can be lost, leaked, or that dies
  with one person — a new maintainer's pipeline produces valid signatures with no
  key handoff.
- **In-repo infrastructure.** Everything needed to build and release lives in
  the repo: `Dockerfile`, `Taskfile.yml`, the GitHub Actions workflows, and the
  `devbox.json` / `devbox.lock` tool pins. The project is **reproducible by
  anyone** who clones it.

**Roadmap.** Recruiting a second maintainer is an explicit goal, both to remove
the bus-factor-1 risk and to make consistent two-person review (the code-review
goal above) achievable for all changes.

## References

- [`CONTRIBUTING.md`](CONTRIBUTING.md) — how to contribute, coding standards,
  test policy, DCO.
- [`SECURITY.md`](SECURITY.md) — private vulnerability reporting and response.
- [`.github/CODEOWNERS`](.github/CODEOWNERS) — review routing.
