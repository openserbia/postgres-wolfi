<!--
SPDX-FileCopyrightText: 2026 OpenSerbia
SPDX-License-Identifier: MIT
-->

## Description

<!-- What does this change do, and why? Link any related issue. -->

## Checklist

- [ ] Ran `task ci` locally (build, Trivy scan, SBOM, smoke) and it passes
- [ ] Added/updated automated tests for any new or changed runtime behaviour
- [ ] Any new third-party GitHub Action is SHA-pinned with a version comment
- [ ] PR title follows Conventional Commits
- [ ] Commits are DCO signed-off (`git commit -s`)
- [ ] Did NOT hand-edit the vendored `docker-entrypoint.sh`
- [ ] Updated `CHANGELOG.md` if the change is user-facing

Review follows `.github/CODEOWNERS` and `GOVERNANCE.md`.
