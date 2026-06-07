# SPDX-FileCopyrightText: 2026 OpenSerbia
# SPDX-License-Identifier: MIT
# postgres-wolfi — PostgreSQL (major via PG_MAJOR build arg; 16/17/18) on
# Chainguard Wolfi (glibc, perl-free, daily-patched).
# Layer-1 non-root: the entrypoint starts as root, fixes PGDATA ownership, then
# gosu-drops to the postgres user (70:70) to run the postmaster. Fully-rootless
# (USER postgres) is a planned Phase-2 flip — see README.
# :latest is deliberate — wolfi-base is daily-patched; pinning would freeze out those patches.
# hadolint ignore=DL3007
FROM cgr.dev/chainguard/wolfi-base:latest

# PG_MAJOR selects the PostgreSQL major line. Default 18; the CI build matrix
# overrides it per image (--build-arg PG_MAJOR=16|17|18). Only majors Wolfi
# currently ships resolve — postgresql-{16,17,18} as of 2026-06; add 19 once
# Wolfi packages it.
ARG PG_MAJOR=18

# Wolfi packages: glibc, NO perl (the source of the Debian CRITs we're escaping).
# gosu ships in wolfi-base's repos; postgres/initdb land on /usr/bin.
# -contrib supplies the extensions the databases use (pg_stat_statements,
# pgcrypto, uuid-ossp, + citext/hstore/pg_trgm/... headroom) — without it a
# restore dies on the first CREATE EXTENSION.
# DL3018 (pin apk versions) suppressed: the package set is parameterized by PG_MAJOR and Wolfi's
# rolling repo IS the patch-delivery channel — pinning versions would freeze out security updates.
# hadolint ignore=DL3018
RUN apk add --no-cache postgresql-${PG_MAJOR} postgresql-${PG_MAJOR}-client postgresql-${PG_MAJOR}-contrib gosu tzdata bash

# Wolfi's postgresql-${PG_MAJOR} apk does NOT create a postgres user. Create it with the
# busybox addgroup/adduser already present (avoids pulling the heavier `shadow`).
RUN addgroup -g 70 postgres \
 && adduser -u 70 -G postgres -H -D -s /bin/sh postgres

ENV PGDATA=/var/lib/postgresql/data \
    LANG=C.UTF-8 \
    PG_MAJOR=$PG_MAJOR
RUN install -d -o postgres -g postgres -m 0700 "$PGDATA" \
 && install -d -o postgres -g postgres -m 0755 /docker-entrypoint-initdb.d

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 5432
STOPSIGNAL SIGINT
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["postgres"]
