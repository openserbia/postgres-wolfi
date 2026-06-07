<!--
SPDX-FileCopyrightText: 2026 OpenSerbia
SPDX-License-Identifier: MIT
-->
# OpenSSF Best Practices — answer sheet

Paste-ready answers for registering `postgres-wolfi` at
<https://www.bestpractices.dev/> and filling its three-tier questionnaire
(passing → silver → gold).

## What this is

A per-criterion mapping from the OpenSSF Best Practices badge questionnaire to
the concrete evidence already in this repo. For each criterion the tables below
give a **Status** (Met / N/A / Unmet) and a one-line justification with an
evidence pointer.

- **Repo:** <https://github.com/openserbia/postgres-wolfi>
- **Image:** `ghcr.io/openserbia/postgres-wolfi`
- **Homepage / project docs:** the repo `README.md`
- **License:** MIT (`LICENSE`, "Copyright (c) 2026 OpenSerbia")
- **Primary maintainer:** GitHub `OCharnyshevich` (organization `openserbia`)

## How to use it

1. Register the project at <https://www.bestpractices.dev/projects/new>. This
   creates a numeric **PROJECT_ID**.
2. Walk the questionnaire group by group. For each criterion, paste the Status,
   the justification, and the evidence URL from the rows below.
3. **Evidence links must be absolute when pasted into the site.** Repo-relative
   paths below (e.g. `SECURITY.md`, `.github/workflows/build.yml`) must be turned
   into full URLs of the form
   `https://github.com/openserbia/postgres-wolfi/blob/main/<path>` before
   submission.
4. After saving, replace `PROJECT_ID` in the README badge line and uncomment it.

Note on scope: this is a **container image** project, not a compiled library.
Wherever a criterion assumes a classic source build, "build" = the OCI **image
build** (`Dockerfile` + `task build`), and "test" = the **smoke test**
(`test/smoke.sh`). The project ships **no cryptography of its own**; image
signing is delegated to cosign / Sigstore, so the crypto_* criteria are N/A and
marked as such with a reason.

---

## Passing (criteria/0)

### Basics

| Criterion | Status | Justification & evidence |
|-----------|--------|--------------------------|
| `description_good` | Met | README opens with a clear one-paragraph description (PostgreSQL 16/17/18 on Chainguard Wolfi, perl-free, daily-patched, Trivy-gated, cosign-signed). `README.md` |
| `interact` | Met | Contribution and interaction channel documented (GitHub Issues). `CONTRIBUTING.md` "How to interact" |
| `contribution` | Met | `CONTRIBUTING.md` documents the full workflow: devbox + Taskfile, `task ci` before PR, fork/branch, PR + checklist. |
| `contribution_requirements` | Met | Coding standards (hadolint, ShellCheck, SHA-pinned actions, Conventional Commits), test policy, and DCO are all stated. `CONTRIBUTING.md` "Coding standards" + "Test policy" + "DCO" |
| `floss_license` | Met | MIT, an OSI-approved FLOSS license. `LICENSE` |
| `license_location` | Met | License in the standard top-level `LICENSE` file; third-party attributions in `THIRD_PARTY_LICENSES.md`. |
| `documentation_basics` | Met | README + `docs/ARCHITECTURE.md` (design), `docs/releasing.md`, `docs/ROADMAP.md`, `docs/assurance-case.md`. |
| `documentation_interface` | Met | The image's interface is the env contract (`POSTGRES_PASSWORD`, `POSTGRES_USER`, `POSTGRES_DB`, `PGDATA`, `/docker-entrypoint-initdb.d`), tags, ports, and uid:gid — all documented. `README.md` "Runtime"; `docs/ARCHITECTURE.md` |
| `english` | Met | All docs, code comments, and commit history are in English. |
| `repo_public` | Met | Public, organization-owned repo. <https://github.com/openserbia/postgres-wolfi> |
| `repo_track` | Met | Git version control on GitHub; full commit history. |
| `repo_distributed` | Met | Git (a distributed VCS) on GitHub. |
| `repo_interim` | Met | Development happens on `main` with interim commits visible publicly; no long-lived hidden branches. |

### Change control / release

| Criterion | Status | Justification & evidence |
|-----------|--------|--------------------------|
| `version_unique` | Met | Each release is uniquely identified by an immutable `:18-YYYYMMDD` date tag **and** by image digest (`sha256:…`), which is authoritative. `docs/releasing.md` "Version uniqueness" |
| `version_semver` | N/A | Project deliberately does **not** use SemVer; it uses date-snapshot tags + digest. This is an allowed alternative (unique, documented versioning). `CHANGELOG.md` (explicit "does not use Semantic Versioning"); `docs/releasing.md` |
| `version_tags` | Met | Releases carry git/registry-visible identifiers: `:18-YYYYMMDD` tags plus optional GitHub Releases tagged `18-YYYYMMDD`. `docs/releasing.md` "Cutting a marked release" |
| `release_notes` | Met | `CHANGELOG.md` (Keep a Changelog format) records notable snapshots; marked GitHub Releases summarize changes + digest + link the CHANGELOG entry. `docs/releasing.md` |
| `release_notes_vulns` | Met | Security-relevant changes go under a `Security` subsection in `CHANGELOG.md` and (where applicable) a GitHub Security Advisory. `SECURITY.md`; `docs/releasing.md` "Security-relevant releases" |

### Reporting

| Criterion | Status | Justification & evidence |
|-----------|--------|--------------------------|
| `report_process` | Met | Bug/feature reporting via GitHub Issues with structured templates. `CONTRIBUTING.md`; `.github/ISSUE_TEMPLATE/bug_report.yml`, `feature_request.yml` |
| `report_tracker` | Met | GitHub Issues is the public issue tracker (enabled). <https://github.com/openserbia/postgres-wolfi/issues> |
| `report_responses` | Met | Maintainer triages/responds on Issues; SECURITY defines an acknowledge-within-14-days SLA for vuln reports. `SECURITY.md` "Response process" |
| `enhancement_responses` | Met | Enhancement requests are handled via Issues under lazy-consensus governance; significant changes get a tracking issue. `GOVERNANCE.md` "Decision-making" |
| `report_archive` | Met | The GitHub issue tracker is the searchable, public, persistent archive of reports. `CONTRIBUTING.md` ("searchable public archive") |

### Vulnerability reporting

| Criterion | Status | Justification & evidence |
|-----------|--------|--------------------------|
| `vulnerability_report_process` | Met | `SECURITY.md` documents the process and contact. |
| `vulnerability_report_private` | Met | Private reporting via GitHub Security Advisories; fallback email `charnyshevich.job@gmail.com`. `SECURITY.md` "Reporting a vulnerability" |
| `vulnerability_report_response` | Met | Acknowledge within 14 days, triage, remediate medium-or-higher well within 60 days, CRITICALs out of band. `SECURITY.md` "Response process" |

### Quality (build / test / warnings)

| Criterion | Status | Justification & evidence |
|-----------|--------|--------------------------|
| `build` | Met | Reproducible from-source image build: `docker build` driven by `task build`. `Dockerfile`; `Taskfile.yml` |
| `build_common_tools` | Met | Standard tooling: Docker, GitHub Actions, devbox, go-task — all common, FLOSS. `Taskfile.yml`; `.github/workflows/build.yml`; `devbox.json` |
| `build_floss_tools` | Met | The build (Docker, Wolfi apk, go-task) runs entirely on FLOSS tools. `Dockerfile`; `Taskfile.yml` |
| `test` | Met | `test/smoke.sh` boots the image on a throwaway volume and asserts init, SQL (100-row round-trip), and that no process runs as root. `test/smoke.sh` |
| `test_invocation` | Met | One documented command: `task smoke` / `./test/smoke.sh <image>`. `Taskfile.yml`; `CONTRIBUTING.md` |
| `test_most` | Met | The smoke test covers the project's core function (a working, non-root PostgreSQL container). For a thin assembly project this exercises the major behaviour; expansion is on the roadmap. `test/smoke.sh`; `docs/ROADMAP.md` "Expand smoke tests" |
| `test_continuous_integration` | Met | CI runs build → scan → sbom → smoke on every push and PR. `.github/workflows/build.yml`; `.github/workflows/lint.yml` |
| `test_policy` | Met | Mandatory written test policy: new functionality must add tests in the same change. `CONTRIBUTING.md` "Test policy" |
| `tests_are_added` | Met | Policy requires tests with new functionality and regression checks for bug fixes; enforced in review. `CONTRIBUTING.md`; `.github/PULL_REQUEST_TEMPLATE.md` (checklist item) |
| `test_policy_mandated` | Met (also a silver item) | The policy is explicitly **mandatory** ("must be added in the same change"). `CONTRIBUTING.md` |
| `warnings` | Met | hadolint (Dockerfile) and ShellCheck (`set -euo pipefail`, quoting) run in CI. `.github/workflows/lint.yml`; `CONTRIBUTING.md` |
| `warnings_fixed` | Met | Lint runs on every push/PR; ShellCheck-clean and hadolint-clean are required standards; Trivy CRITICAL gate fails the build. `.github/workflows/lint.yml`; `Taskfile.yml` (scan) |
| `warnings_strict` | Met | ShellCheck with `set -euo pipefail` and quoting enforced; hadolint defaults; SHA-pin review — strict by policy. `CONTRIBUTING.md` "Coding standards" |

### Security (crypto / delivery / vuln response)

| Criterion | Status | Justification & evidence |
|-----------|--------|--------------------------|
| `crypto_published` | N/A | Project ships no cryptographic functionality of its own. (Image signing is delegated to cosign/Sigstore, published FLOSS protocols.) `docs/assurance-case.md` sub-claim 5 |
| `crypto_call` | N/A | No own crypto; signing uses cosign/Sigstore rather than reimplementing primitives. `docs/assurance-case.md` |
| `crypto_floss` | N/A | No own crypto. cosign/Sigstore (the signing path) are FLOSS. |
| `crypto_keylength` | N/A | No own crypto; key parameters are cosign/Sigstore's, not this project's. |
| `crypto_working` | N/A | No broken/known-insecure crypto is used because the project uses none of its own. |
| `crypto_weaknesses` | N/A | No own crypto algorithms to assess. |
| `crypto_pfs` | N/A | No network crypto service is operated by this project. |
| `crypto_password_storage` | N/A | The image stores no passwords; `POSTGRES_PASSWORD` handling is the upstream entrypoint contract and the operator's responsibility. `SECURITY.md` "You cannot expect" |
| `crypto_random` | N/A | Project generates no security-sensitive random values of its own. |
| `delivery_mitm` | Met | Delivered from GHCR over TLS; every image is cosign keyless-signed (by digest) so substitution/MITM is detectable. `README.md` "Verify the signature"; `docs/assurance-case.md` sub-claim 5 |
| `delivery_unsigned` | Met | Releases are cryptographically signed (cosign keyless, Sigstore/GitHub OIDC); verify command published. `.github/workflows/build.yml` (Sign + attest); `README.md` |
| `vulnerabilities_fixed_60_days` | Met | Weekly rebuild pulls daily-patched Wolfi fixes; SECURITY commits to remediating medium-or-higher well within 60 days. `SECURITY.md` "Response process"; `.github/workflows/build.yml` (`cron: 17 6 * * 1`) |
| `vulnerabilities_critical_fixed` | Met | Trivy gates the build on CRITICAL (build fails, nothing is pushed); CRITICALs are also expedited out of the weekly cadence. `Taskfile.yml` (scan); `docs/assurance-case.md` sub-claim 3 |
| `no_leaked_credentials` | Met | No secrets in-repo; CI uses GitHub OIDC (`id-token: write`) for keyless signing and the ephemeral `GITHUB_TOKEN` for GHCR login. `.github/workflows/build.yml` |

### Analysis

| Criterion | Status | Justification & evidence |
|-----------|--------|--------------------------|
| `static_analysis` | Met | hadolint + ShellCheck in CI; Trivy image scan; OpenSSF Scorecard weekly. `.github/workflows/lint.yml`; `Taskfile.yml`; `.github/workflows/scorecard.yml` |
| `static_analysis_common_vulnerabilities` | Met | Trivy scans for known OS/library CVEs (CRITICAL gates the build); Scorecard checks supply-chain weaknesses. `Taskfile.yml`; `.github/workflows/scorecard.yml` |
| `static_analysis_fixed` | Met | CRITICAL Trivy findings fail the build before push; lint must pass on every PR. `.github/workflows/build.yml`; `.github/workflows/lint.yml` |
| `static_analysis_often` | Met | Runs on every push and PR (lint), every build (Trivy), and weekly (Scorecard + rebuild). |
| `dynamic_analysis` | N/A (SUGGESTED) | No fuzzer/DAST is run. The smoke test does exercise the running container (boot + SQL + non-root assertion), which is a behavioural runtime check. `test/smoke.sh` |

---

## Silver (criteria/1)

Silver adds project-management, governance, and stronger supply-chain criteria
on top of passing. **One MUST is currently unmet — see `code_of_conduct`.**

### Governance, contribution & continuity

| Criterion | Status | Justification & evidence |
|-----------|--------|--------------------------|
| `dco` | Met | DCO sign-off (`git commit -s`) is required and explained; enforced via PR checklist. `CONTRIBUTING.md` "DCO"; `.github/PULL_REQUEST_TEMPLATE.md` |
| `contribution_requirements` (silver) | Met | Contribution requirements (standards, test policy, DCO) are documented and enforced. `CONTRIBUTING.md` |
| `code_of_conduct` | **Unmet** | The maintainer has deliberately chosen **not** to adopt a code of conduct at this time; there is no `CODE_OF_CONDUCT.md`. This OpenSSF silver MUST is therefore **not satisfied**. Consequence: **silver cannot be fully passed** until a code of conduct is adopted, or the maintainer accepts this as a known gap. (Do not mark this Met.) |
| `governance` | Met | `GOVERNANCE.md` describes decision-making (lazy consensus → maintainer decides), roles, and maintainership. |
| `roles_responsibilities` | Met | Maintainer vs contributor roles and rights are spelled out. `GOVERNANCE.md` "Roles & responsibilities" |
| `access_continuity` | Met | Continuity plan: org-owned repo (owners can grant access without the current maintainer), keyless signing tied to workflow OIDC (no personal key to lose), all build/release infra in-repo. `GOVERNANCE.md` "Access & continuity" |
| `bus_factor` | **Unmet (honest gap)** | Bus factor is currently **1** (single active maintainer `OCharnyshevich`). Mitigations stated honestly: org ownership enables handover/recovery; signing is workflow-OIDC, not a personal key; the full pipeline is reproducible from the repo. Recruiting a second maintainer is an explicit roadmap goal. `GOVERNANCE.md` "Access & continuity"; `docs/ROADMAP.md` "Reduce bus factor" |

### Documentation

| Criterion | Status | Justification & evidence |
|-----------|--------|--------------------------|
| `documentation_architecture` | Met | `docs/ARCHITECTURE.md` — image composition, privilege model, pipeline, supply-chain controls, tagging. |
| `documentation_security` | Met | `SECURITY.md` (model, reporting, response) plus `docs/assurance-case.md` (structured argument with evidence). |
| `assurance_case` | Met | `docs/assurance-case.md` — top claim + seven evidence-linked sub-claims + residual risks. |
| `documentation_roadmap` | Met | `docs/ROADMAP.md` — Now / Near / Mid / Long-term + explicit out-of-scope. |
| `documentation_achievements` | Met | Achievements/posture documented: Trivy gate, cosign signing, SBOM attestation, Scorecard badge, non-root runtime. `README.md`; `docs/assurance-case.md` |
| `documentation_quick_start` | Met | README gives a one-line `docker pull` + runtime env contract. `README.md` "Image" / "Runtime" |
| `documentation_current` | Met | Docs cross-reference and track the actual pipeline/runtime (Phase-2 noted as planned, not shipped). `docs/ARCHITECTURE.md`; `docs/ROADMAP.md` |

### Quality, testing & dependencies

| Criterion | Status | Justification & evidence |
|-----------|--------|--------------------------|
| `dependency_monitoring` | Met | Dependabot watches GitHub Actions and the Docker base image weekly; bumps reviewed before merge. `.github/dependabot.yml`; `docs/ROADMAP.md` "Keep pins current" |
| `external_dependencies` | Met | Dependencies are explicit and pinned: Wolfi apk packages in the `Dockerfile`, tools pinned via `devbox.lock`, actions pinned by SHA, vendored entrypoint pinned by commit. `Dockerfile`; `devbox.lock`; `THIRD_PARTY_LICENSES.md` |
| `maintenance_or_update` | Met | Weekly automatic rebuild keeps the image patched; the standing guarantee in SECURITY. `.github/workflows/build.yml`; `SECURITY.md` |
| `test_statement_coverage80` | N/A (justified) | No statement-coverage tool meaningfully instruments a `Dockerfile` + a **vendored, never-edited** bash entrypoint — there is no compiled/own code unit to instrument. The behavioural coverage is `test/smoke.sh` (boot + SQL + non-root). Criterion is conditional on "if there is a coverage tool"; there isn't one that applies. `test/smoke.sh`; `CONTRIBUTING.md` (vendoring rule) |
| `test_policy_mandated` | Met | Test policy is mandatory in writing. `CONTRIBUTING.md` "Test policy" |
| `tests_documented_added` | Met | Adding tests with new functionality is documented and required; PR checklist enforces it. `CONTRIBUTING.md`; `.github/PULL_REQUEST_TEMPLATE.md` |

### Security & supply chain

| Criterion | Status | Justification & evidence |
|-----------|--------|--------------------------|
| `signed_releases` | Met | Every pushed image is cosign keyless-signed and its CycloneDX SBOM is cosign-attested, both **by digest**. `.github/workflows/build.yml` "Sign + attest"; `docs/releasing.md` |
| `build_reproducible` | **Partial / in progress (honest)** | Build is fully scripted and pinned (`Dockerfile`, `devbox.lock`, SHA-pinned actions, commit-pinned entrypoint), so a clean re-run is deterministic given the same upstream packages. **However**, Wolfi apk packages float to "current" at build time, so byte-identical reproducibility across days is **not** yet guaranteed; documenting/verifying reproducibility is an explicit roadmap item. Do not claim full reproducibility. `Dockerfile`; `devbox.lock`; `docs/ROADMAP.md` "Document reproducible-build verification" |
| `two_person_review` | **Unmet at the "all changes" level (SHOULD)** | Solo maintainer: **external PRs** are always reviewed by the maintainer (author ≠ reviewer, so the goal holds for those); the **maintainer's own changes** may self-merge after green CI because no second reviewer exists. CODEOWNERS routes review; CI gating is the compensating control. Stated honestly. `GOVERNANCE.md` "Code review model"; `.github/CODEOWNERS` |
| `static_analysis_common_vulnerabilities` (silver) | Met | Trivy (CVE scan, CRITICAL gate) + OpenSSF Scorecard (supply-chain). `Taskfile.yml`; `.github/workflows/scorecard.yml` |
| `hardened_site` / `sites_https` | Met | Project "sites" are GitHub + GHCR, both HTTPS/TLS only and outside this project's control to weaken. `README.md` (GHCR pull/verify over TLS) |
| `installation_common` | Met | Standard install path: `docker pull ghcr.io/openserbia/postgres-wolfi:18-latest`. `README.md` "Image" |
| `interfaces_current_tls` | Met | All network interfaces used for delivery/verification (GHCR, Sigstore, GitHub) use current TLS; the project operates no legacy-TLS endpoint. `README.md`; `docs/releasing.md` |
| `crypto_weaknesses` (silver) | N/A | No own crypto; delegated signing uses current Sigstore primitives. `docs/assurance-case.md` sub-claim 5 |
| `vulnerabilities_critical_fixed` (silver) | Met | Trivy CRITICAL gate blocks publication; CRITICALs expedited off-cadence. `Taskfile.yml`; `SECURITY.md` |
| `hardening` | Met | Trivy CRITICAL gate, SHA-pinned third-party actions, minimal least-privilege workflow `permissions`, keyless signing, minimal perl-free image, OpenSSF Scorecard. `.github/workflows/build.yml`; `.github/workflows/scorecard.yml`; `docs/assurance-case.md` sub-claim 7 |
| `installation_development_quick` | Met | `devbox shell` + `task ci` reproduces the full local pipeline; documented. `CONTRIBUTING.md` "Development workflow" |

---

## Gold (criteria/2) — what's ready and what's blocked

Gold layers in the strongest human-process and per-file criteria. Some are
already satisfied by repo contents; others **cannot** be honestly satisfied on a
single-maintainer repo today.

### READY now (file/process evidence already exists)

| Criterion | Status | Justification & evidence |
|-----------|--------|--------------------------|
| `code_review_standards` | Met | Review model + routing + checklist all documented. `GOVERNANCE.md` "Code review model"; `.github/CODEOWNERS`; `.github/PULL_REQUEST_TEMPLATE.md` |
| `copyright_per_file` | Met | Project-authored source files carry `SPDX-FileCopyrightText: 2026 OpenSerbia`. `Dockerfile`, `Taskfile.yml`, `test/smoke.sh`, the workflow files, and the docs all carry the SPDX header. |
| `license_per_file` | Met | Same files carry `SPDX-License-Identifier: MIT`. Note: the **vendored** `docker-entrypoint.sh` carries only `SPDX-License-Identifier: MIT` plus a vendoring provenance block (source + pinned commit + "(c) Docker, Inc."); it makes **no false OpenSerbia copyright claim**. `docker-entrypoint.sh`; `THIRD_PARTY_LICENSES.md` |
| `signed_releases` (gold) | Met | cosign keyless sign + CycloneDX attest, by digest, on every build. `.github/workflows/build.yml` |
| `installation_development_quick` (gold) | Met | `devbox shell` + `task ci`. `CONTRIBUTING.md` |
| `hardened_site` / `sites_https` (gold) | Met | GitHub + GHCR, TLS only. `README.md` |
| `dependency_monitoring` (gold) | Met | Dependabot (actions + docker). `.github/dependabot.yml` |
| `static_analysis_common_vulnerabilities` (gold) | Met | Trivy + Scorecard. `Taskfile.yml`; `.github/workflows/scorecard.yml` |
| `assurance_case` (gold) | Met | `docs/assurance-case.md` |

### HARD BLOCKERS (cannot be satisfied by files on a solo repo)

These require real people or coverage tooling that does not exist here. They are
listed so they are **not** quietly marked Met.

| Criterion | Status | Why it is blocked |
|-----------|--------|-------------------|
| `contributors_unassociated` | **Blocked** | Needs ≥2 significant contributors from ≥2 different organizations. Today: one contributor, one org. |
| `two_person_review` (gold MUST) | **Blocked** | Needs ≥50% of recent non-trivial changes reviewed by someone other than the author. With one maintainer, own-changes self-merge, so the threshold is not met. `GOVERNANCE.md` |
| `bus_factor` ≥ 2 | **Blocked** | Needs a genuine second maintainer. Bus factor is currently 1. `GOVERNANCE.md`; `docs/ROADMAP.md` "Reduce bus factor" |
| `test_statement_coverage90` | **Blocked / N/A** | Gold MUST. No statement-coverage tool meaningfully instruments a `Dockerfile` + vendored bash entrypoint; only behavioural coverage (`test/smoke.sh`) exists. |
| `test_branch_coverage80` | **Blocked / N/A** | Same reasoning — no applicable branch-coverage instrument for this artifact type. |

**Honesty note.** bestpractices.dev is **self-asserted**: the site will let you
mark these "Met" without proof. Doing so would be a false, publicly checkable
claim (the repo's contributor graph, review history, and absence of coverage
tooling are all inspectable). Leave the blocked items honest until real,
independent second contributors exist and (if it ever becomes meaningful)
coverage tooling is in place.

---

## What you must still do on GitHub (outside this repo's files)

- [ ] **Register the project** at <https://www.bestpractices.dev/projects/new>.
      This mints a numeric **PROJECT_ID**; then replace `PROJECT_ID` in the
      README badge line (`README.md`, currently commented out) and uncomment it.
- [ ] **Decide on the code of conduct.** Either adopt one to satisfy the silver
      `code_of_conduct` MUST, or formally accept that **silver stays incomplete**
      without it. (No `CODE_OF_CONDUCT.md` exists today — this is a deliberate
      choice, recorded here so the gap is not a surprise.)
- [ ] **Require organization 2FA** for the `openserbia` org (passing/silver
      expectation; not something a repo file can assert).
- [ ] **Add a `good first issue` label** to one or two real issues — `CONTRIBUTING.md`
      links to that filter, so it should return results.
- [ ] **Optionally enable GitHub Discussions** (currently off; `docs/ROADMAP.md`
      and `CONTRIBUTING.md` reference it as "when enabled").
- [ ] **Cut a tagged GitHub Release** pointing at a dated snapshot
      (`18-YYYYMMDD` + digest + linked CHANGELOG entry) to strengthen
      `release_notes` / `version_unique`. `docs/releasing.md`
- [ ] **Recruit a second independent contributor + reviewer** to unlock the gold
      human criteria (`contributors_unassociated`, `two_person_review`,
      `bus_factor`). `docs/ROADMAP.md` "Reduce bus factor"
