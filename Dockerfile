# postgres-wolfi — PostgreSQL 18 on Chainguard Wolfi (glibc, perl-free, daily-patched).
# Layer-1 non-root: the entrypoint starts as root, fixes PGDATA ownership, then
# gosu-drops to the postgres user (70:70) to run the postmaster. Fully-rootless
# (USER postgres) is a planned Phase-2 flip — see README.
FROM cgr.dev/chainguard/wolfi-base:latest

# Wolfi packages: glibc, NO perl (the source of the Debian CRITs we're escaping).
# gosu ships in wolfi-base's repos; postgres/initdb land on /usr/bin.
RUN apk add --no-cache postgresql-18 postgresql-18-client gosu tzdata bash

# Wolfi's postgresql-18 apk does NOT create a postgres user. Create it with the
# busybox addgroup/adduser already present (avoids pulling the heavier `shadow`).
RUN addgroup -g 70 postgres \
 && adduser -u 70 -G postgres -H -D -s /bin/sh postgres

ENV PGDATA=/var/lib/postgresql/data \
    LANG=C.UTF-8
RUN install -d -o postgres -g postgres -m 0700 "$PGDATA" \
 && install -d -o postgres -g postgres -m 0755 /docker-entrypoint-initdb.d

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 5432
STOPSIGNAL SIGINT
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["postgres"]
