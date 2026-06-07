<!--
SPDX-FileCopyrightText: 2026 OpenSerbia
SPDX-License-Identifier: MIT
-->
# Roadmap

This is a direction-of-travel document, not a contract. Everything below is
**aspirational** and may be reordered, deferred, or dropped without notice. There
are no dated commitments and no SLA implied — the only standing guarantee is the
weekly rebuild described in `SECURITY.md`. `postgres-wolfi` currently has a
**single active maintainer** (bus factor 1), so throughput is whatever one person
can sustain in spare time.

Items are grouped by horizon, not by date: **Now** is in flight, **Near-term**
is next up, **Mid-term** is plausible within ~12 months, **Long-term** is
beyond that or gated on external events. Where an item changes how the image is
assembled or operated, it ties back to `docs/ARCHITECTURE.md`; where it changes
who decides or how decisions are made, it ties back to `GOVERNANCE.md`.

## Now (in flight)

- **Keep the weekly rebuild green.** The Monday 06:17 UTC build is the product;
  if it goes red it gets fixed before anything else here is touched. Failures
  flow through the same triage as a security report (`SECURITY.md`).
- **Track minor releases across the supported majors.** Roll each `:NN-latest`
  (`NN` ∈ 16, 17, 18) forward across its own `NN.x` bugfix releases via the weekly
  build matrix; never jump major lines on any of these tags. See the tag contract
  in `README.md`.
- **Keep pins current.** Actions are SHA-pinned and devbox tools are version-pinned;
  Dependabot proposes bumps and each is reviewed before merge. The pinning policy
  lives in `CONTRIBUTING.md`; the rationale (why pin by SHA / digest) belongs in
  `docs/ARCHITECTURE.md`.

## Near-term (next up)

- **Phase-2 fully-rootless image.** Move to `USER postgres` and drop the
  root-start → `gosu`-drop step where feasible, so the container never starts as
  root. This depends on a clean `$PGDATA` ownership story (uid:gid `70:70`) and
  may require operators to own the data volume up front; the trade-offs and the
  before/after privilege model belong in `docs/ARCHITECTURE.md`. Until this
  lands, the runtime is exactly as described in `README.md` and `SECURITY.md`.
- **Lint CI, gating.** Add `hadolint` (Dockerfile) and `shellcheck` (shell) to
  CI as a **blocking** check, wired into the existing Taskfile (`task ci`) so it
  runs locally too. Note: `docker-entrypoint.sh` is vendored verbatim and is
  exempt from local style fixes — see the vendoring rule in `CONTRIBUTING.md`.
- **Document reproducible-build verification.** Write up how a third party can
  rebuild from a pinned commit and check they get the same image, and what is
  vs. is not reproducible given upstream package drift. This is a
  `docs/ARCHITECTURE.md` topic, cross-linked from the verification steps in
  `README.md`.

## Mid-term (plausible within ~12 months)

- **Consider gating on HIGH.** Today Trivy fails the build only on CRITICAL while
  HIGH is reported non-gating (`SECURITY.md`). If the Wolfi base stays clean
  enough that HIGH findings are consistently actionable rather than noise,
  promote HIGH to a gating severity. This is a deliberate policy change, so it
  goes through whatever review process `GOVERNANCE.md` defines before the
  threshold moves.
- **Multi-arch builds — delivered.** `linux/arm64` now ships alongside `amd64`:
  each major's `:NN-latest`/`:NN-YYYYMMDD` is a manifest list, each arch built and
  smoke-tested natively on a self-hosted runner of that architecture (routed by
  GitHub's built-in `X64` / `ARM64` labels), signed and SBOM'd per-arch under the
  same tag contract (`docs/ARCHITECTURE.md`). Remaining follow-on here is
  build-cost / cache tuning and watching the arm64 leg's reliability under the
  weekly load.
- **Expand smoke tests.** Grow `test/smoke.sh` beyond "does it boot" to cover
  restart/persistence across container recreation and `/docker-entrypoint-initdb.d`
  init-script execution, so regressions in the data-volume and bootstrap paths
  are caught before push.

## Long-term (beyond ~12 months / externally gated)

- **PostgreSQL 19 line.** The weekly build is already a per-major matrix, so
  standing up a parallel `:19-*` line is a one-line addition (`"19"` to the
  matrix in `build.yml`) under the same immutable-snapshot + rolling-minor tag
  contract. It is gated entirely on Wolfi shipping a `postgresql-19` package
  (expected after upstream PG19 GA, ~autumn 2026); until then the leg would 404
  on `apk add`, so it stays out. The other lines continue independently per their
  support window in `SECURITY.md`.
- **SLSA provenance.** Add SLSA build-provenance attestation on top of the
  existing keyless cosign signatures and CycloneDX SBOM attestation, tightening
  the supply-chain story tracked by OpenSSF Scorecard.
- **Reduce bus factor.** Recruit a **second independent maintainer** so review and
  release no longer depend on one person, then open the project to outside
  contributors. The project is intentionally structured for two-person review,
  but that review is **not happening today** — there is one maintainer, so
  self-merge is the current reality. The target model, the honest current
  limitation, and how a second maintainer would be added all belong in
  `GOVERNANCE.md`.

## Out of scope (not planned)

These are explicit non-goals, recorded so they are not mistaken for "later":

- A `:latest` or bare `:NN` floating tag (e.g. bare `:18`) — see the tag
  rationale in `README.md`.
- Hardening of PostgreSQL *configuration* (`postgresql.conf`, `pg_hba.conf`, TLS,
  roles) — that is the operator's job, per the security model in `SECURITY.md`.
- Backports to any line other than the current supported one (`SECURITY.md`).

---

Have a different priority? Open an Issue or a Discussion (when enabled) — see
`CONTRIBUTING.md`. Security-sensitive items go through `SECURITY.md`, not here.
