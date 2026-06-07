<!--
SPDX-FileCopyrightText: 2026 OpenSerbia
SPDX-License-Identifier: MIT
-->
# Contributing to postgres-wolfi

Thanks for your interest. This is a small, security-focused container image
project: PostgreSQL images (majors 16, 17, 18) built on Chainguard Wolfi.
Contributions of any
size are welcome — bug reports, documentation fixes, hardening improvements, and
CI changes.

## How to interact

- **Questions / discussion / feedback:** open a
  [GitHub Issue](https://github.com/openserbia/postgres-wolfi/issues).
- **Bug reports:** open an Issue using the **Bug report** template. Include the
  image tag (`:NN-YYYYMMDD`, e.g. `:18-YYYYMMDD`), the `docker run` invocation, and `docker logs`
  output. The issue tracker is the searchable public archive of all reports.
- **Security vulnerabilities:** do **not** open a public Issue. Follow
  [`SECURITY.md`](SECURITY.md) for private reporting.

## Good first issues

Small, well-scoped tasks for new or casual contributors are labelled
[`good first issue`](https://github.com/openserbia/postgres-wolfi/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22).
If none are open and you want a starting point, comment on any issue and a
maintainer will help scope it.

## Development workflow

Tooling is pinned with [devbox](https://www.jetify.com/devbox) and orchestrated
with [Taskfile](https://taskfile.dev):

```bash
devbox shell        # go-task, trivy, syft, cosign at pinned versions
task build          # build :18-latest and :18-<date> (default; PG_MAJOR=17 etc. to switch)
task scan           # Trivy: fail on CRITICAL, report HIGH
task sbom           # generate CycloneDX SBOM
task smoke          # boot + SQL + non-root assertion
task ci             # build -> scan -> sbom -> smoke (no push)
```

Run `task ci` before opening a PR.

## Coding standards (requirements for acceptable contributions)

Contributions must comply with the project's coding standards. These are
enforced automatically in CI (see `.github/workflows/lint.yml`); run them
locally before pushing:

| Area        | Standard                                     | Tool                |
|-------------|----------------------------------------------|---------------------|
| Dockerfile  | [hadolint](https://github.com/hadolint/hadolint) defaults | `hadolint Dockerfile` |
| Shell       | [ShellCheck](https://www.shellcheck.net/) clean; `set -euo pipefail`; quote expansions | `shellcheck test/*.sh` |
| YAML / CI   | All third-party GitHub Actions **SHA-pinned** with a version comment | manual review |
| Commits     | [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `ci:`, `docs:`, `chore:`, `test:`) | — |

The vendored `docker-entrypoint.sh` is an exception: it is copied verbatim from
`docker-library/postgres` at a pinned commit and **must not be hand-edited**.
Refresh it deliberately by bumping the pin, re-downloading, and re-testing.

## Test policy

This project has a **mandatory** testing policy: as major new functionality is
added, automated tests that check that functionality **must** be added in the
same change. The test suite (`test/smoke.sh`) boots the image on a throwaway
volume and verifies init, basic SQL, and that no process runs as root. CI runs
it on every push and pull request. PRs that change runtime behaviour without a
corresponding test will be asked to add one.

For bug fixes, add a regression check where practical so the bug cannot
silently return.

## Pull requests & code review

1. Fork or branch, make your change, run `task ci`.
2. Sign off your commits (DCO — see below).
3. Open a PR with a clear description and a filled-out checklist.
4. PRs are reviewed against `.github/CODEOWNERS`. The project's goal is that
   every change is reviewed by someone other than its author; see
   [`GOVERNANCE.md`](GOVERNANCE.md) for the current review model and its limits.

## Developer Certificate of Origin (DCO)

All contributions are made under the [DCO](https://developercertificate.org/).
Certify that you wrote the patch (or have the right to submit it) by adding a
`Signed-off-by` line to each commit:

```bash
git commit -s -m "fix: ..."
```

This adds `Signed-off-by: Your Name <you@example.com>`, which must match the
commit author. By signing off you agree to the DCO and that your contribution is
licensed under this project's [MIT License](LICENSE).
