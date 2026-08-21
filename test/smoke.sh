#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 OpenSerbia
# SPDX-License-Identifier: MIT
# Smoke test for postgres-wolfi: boots the image on a throwaway volume, verifies
# init + basic SQL, that the server MAJOR matches the requested PG_MAJOR, and
# that NO process runs as root (layer-1 drop worked).
# Usage: test/smoke.sh <image-ref> [expected-major]
set -euo pipefail

IMAGE="${1:?usage: smoke.sh <image-ref> [expected-major]}"
EXPECT_MAJOR="${2:-}"
PW="smoke_$$"

# Identify the container and volume by the IDs Docker hands back, never by a name
# we compose ourselves. Several self-hosted runners share ONE Docker daemon while
# each sits in its own PID namespace, so a `$$`-derived name is NOT unique across
# concurrent matrix legs: two legs collided on `pgwolfi-smoke-1058`, the loser's
# cleanup then `docker rm -f`'d the winner's container, and both legs failed.
# Docker-assigned IDs cannot collide, and cleanup below only ever touches
# resources this run actually created.
CID=""
VOL=""
cleanup() {
  if [ -n "$CID" ]; then docker rm -f "$CID" >/dev/null 2>&1 || true; fi
  if [ -n "$VOL" ]; then docker volume rm "$VOL" >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT

VOL=$(docker volume create)
CID=$(docker run -d --memory 1g \
  -e POSTGRES_PASSWORD="$PW" \
  -v "$VOL":/var/lib/postgresql/data \
  "$IMAGE")
echo "container=${CID:0:12} volume=$VOL"

# The official entrypoint runs a TEMPORARY localhost-only server to execute the
# init scripts, then shuts it down and starts the real server. pg_isready can
# latch onto that temp server and report "ready" — SQL fired in that window dies
# with "the database system is shutting down" (a flaky CI failure). Gate on the
# entrypoint's post-init marker (always emitted, since this test always uses a
# fresh volume) BEFORE trusting pg_isready, so we only ever reach the real server.
echo "waiting for readiness..."
ready=0
for _ in $(seq 1 60); do
  if docker logs "$CID" 2>&1 | grep -q 'PostgreSQL init process complete; ready for start up.' \
     && docker exec "$CID" pg_isready -U postgres >/dev/null 2>&1; then
    ready=1; break
  fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then echo "FAIL: never became ready"; docker logs "$CID"; exit 1; fi

# Version-drift gate: assert the server's MAJOR matches what we asked apk to
# install. Minor/patch drift (e.g. 16.8 -> 16.9) is EXPECTED on Wolfi's rolling
# repo and must NOT fail — it's the security-patch channel — so we only print it
# for visibility and fail solely on a MAJOR mismatch.
echo "verifying server version..."
server_version=$(docker exec "$CID" psql -U postgres -tAc "SHOW server_version;" | tr -d '[:space:]')
server_major=$(docker exec "$CID" psql -U postgres -tAc "SHOW server_version_num;" | tr -d '[:space:]')
server_major=$(( server_major / 10000 ))
echo "server_version=$server_version (major=$server_major)"
if [ -n "$EXPECT_MAJOR" ] && [ "$server_major" != "$EXPECT_MAJOR" ]; then
  echo "FAIL: expected PostgreSQL major $EXPECT_MAJOR, got $server_version"; exit 1
fi

echo "running SQL..."
docker exec "$CID" psql -U postgres -v ON_ERROR_STOP=1 \
  -c "CREATE TABLE t(id serial primary key, name text);" \
  -c "INSERT INTO t(name) SELECT 'n'||g FROM generate_series(1,100) g;"
rows=$(docker exec "$CID" psql -U postgres -tAc "SELECT count(*) FROM t;")
if [ "$rows" != "100" ]; then echo "FAIL: expected 100 rows, got '$rows'"; exit 1; fi

echo "verifying no process runs as root (layer-1 drop)..."
roots=$(docker top "$CID" -o pid,uid,cmd | tail -n +2 | awk '$2==0' | wc -l)
if [ "$roots" -ne 0 ]; then echo "FAIL: $roots root process(es):"; docker top "$CID"; exit 1; fi

echo "SMOKE OK: $IMAGE (rows=$rows, root_procs=0)"
