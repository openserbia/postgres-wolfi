#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 OpenSerbia
# SPDX-License-Identifier: MIT
# Smoke test for postgres-wolfi: boots the image on a throwaway volume, verifies
# init scripts, basic SQL, that the server MAJOR matches the requested PG_MAJOR,
# that the data survives a new container on the same volume, and that NO process
# runs as root (layer-1 drop worked).
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
INITDIR=""
cleanup() {
  if [ -n "$CID" ]; then docker rm -f "$CID" >/dev/null 2>&1 || true; fi
  if [ -n "$VOL" ]; then docker volume rm "$VOL" >/dev/null 2>&1 || true; fi
  if [ -n "$INITDIR" ]; then rm -rf "$INITDIR"; fi
}
trap cleanup EXIT

# First boot runs these once. The directory must be traversable by uid 70
# (mode 0700 from mktemp is not). The restart mounts the same directory: a
# second run of 01-marker.sql would fail the primary key and the entrypoint
# would never reach the real server.
INITDIR=$(mktemp -d)
chmod 755 "$INITDIR"
cat > "$INITDIR/01-marker.sql" <<'EOF'
CREATE TABLE smoke_init(id int primary key, src text);
INSERT INTO smoke_init(id, src) VALUES (1, 'sql');
EOF
cat > "$INITDIR/02-marker.sh" <<'EOF'
#!/bin/sh
psql -v ON_ERROR_STOP=1 --username postgres --no-password --no-psqlrc \
  -c "INSERT INTO smoke_init(id, src) VALUES (2, 'sh');"
EOF
chmod 755 "$INITDIR/02-marker.sh"
cat > "$INITDIR/03-marker.sql" <<'EOF'
INSERT INTO smoke_init(id, src) VALUES (3, 'xz');
EOF
docker run --rm --entrypoint /usr/bin/xz \
  -v "$INITDIR":/work:ro \
  "$IMAGE" -c /work/03-marker.sql > "$INITDIR/03-marker.sql.xz"
rm -f "$INITDIR/03-marker.sql"

# The official entrypoint runs a TEMPORARY localhost-only server to execute the
# init scripts, then shuts it down and starts the real server. pg_isready can
# latch onto that temp server and report "ready" — SQL fired in that window dies
# with "the database system is shutting down" (a flaky CI failure). On first
# boot, gate on the post-init marker BEFORE trusting pg_isready. A restart has
# no temp server; gate on the skip-init line instead, and fail if init ran again.
wait_ready() {
  phase=$1
  ready=0
  echo "waiting for readiness ($phase)..."
  for _ in $(seq 1 60); do
    logs=$(docker logs "$CID" 2>&1 || true)
    if [ "$phase" = first ]; then
      marker=$(printf '%s\n' "$logs" | grep -c 'PostgreSQL init process complete; ready for start up.' || true)
    else
      if printf '%s\n' "$logs" | grep -q 'init process complete'; then
        echo "FAIL: restart re-ran initialization"
        printf '%s\n' "$logs"
        exit 1
      fi
      marker=$(printf '%s\n' "$logs" | grep -c 'Skipping initialization' || true)
    fi
    if [ "$marker" -ge 1 ] && docker exec "$CID" pg_isready -U postgres >/dev/null 2>&1; then
      ready=1
      break
    fi
    sleep 1
  done
  if [ "$ready" -ne 1 ]; then
    echo "FAIL: never became ready ($phase)"
    docker logs "$CID" || true
    exit 1
  fi
}

# pid 1 is the postmaster, running as uid 70. /proc/1/environ is mode 0400
# and this kernel will not let root read another process's environment
# (no CAP_SYS_PTRACE). Reading it as root made grep -c print 0 on an empty
# failure, and the check passed without seeing the variables. The postgres
# user owns pid 1, so it can read them.
assert_no_bootstrap_env() {
  label=$1
  envtext=$(docker exec -u postgres "$CID" sh -c "tr '\\0' '\\n' < /proc/1/environ") || {
    echo "FAIL: could not read the postmaster environment ($label)"
    exit 1
  }
  leaked=$(printf '%s\n' "$envtext" | grep -c '^POSTGRES_' || true)
  if [ "$leaked" != "0" ]; then
    echo "FAIL: $leaked POSTGRES_* variable(s) in the postmaster environment ($label)"
    exit 1
  fi
}

start_container() {
  CID=$(docker run -d --memory 1g \
    -e POSTGRES_PASSWORD="$PW" \
    -v "$VOL":/var/lib/postgresql/data \
    -v "$INITDIR":/docker-entrypoint-initdb.d:ro \
    "$IMAGE")
  echo "container=${CID:0:12} volume=$VOL"
}

VOL=$(docker volume create)
start_container
wait_ready first

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

echo "verifying init scripts ran once..."
marker=$(docker exec "$CID" psql -U postgres -tAc "SELECT string_agg(src, ',' ORDER BY id) FROM smoke_init;")
if [ "$marker" != "sql,sh,xz" ]; then
  echo "FAIL: init marker is '$marker', want sql,sh,xz"
  docker logs "$CID" || true
  exit 1
fi

echo "running SQL..."
docker exec "$CID" psql -U postgres -v ON_ERROR_STOP=1 \
  -c "CREATE TABLE t(id serial primary key, name text);" \
  -c "INSERT INTO t(name) SELECT 'n'||g FROM generate_series(1,100) g;"
rows=$(docker exec "$CID" psql -U postgres -tAc "SELECT count(*) FROM t;")
if [ "$rows" != "100" ]; then echo "FAIL: expected 100 rows, got '$rows'"; exit 1; fi

# JIT is deliberately absent (the Dockerfile purges libLLVM). PostgreSQL only
# disables JIT cleanly when llvmjit.so is gone too; if the provider were left
# behind without libLLVM, any query crossing jit_above_cost would ERROR. Force
# that path with jit_above_cost=0 and require it to succeed.
echo "verifying JIT is unavailable and harmless..."
jit=$(docker exec "$CID" psql -U postgres -tAc "SELECT pg_jit_available();")
if [ "$jit" != "f" ]; then echo "FAIL: expected pg_jit_available() = f, got '$jit'"; exit 1; fi
docker exec "$CID" psql -U postgres -v ON_ERROR_STOP=1 -tA \
  -c "SET jit = on; SET jit_above_cost = 0; SELECT sum(id) FROM t;" >/dev/null

# Shared libraries the extensions link against survive the LLVM purge.
echo "verifying contrib extensions + XML load..."
docker exec "$CID" psql -U postgres -v ON_ERROR_STOP=1 -tA \
  -c 'CREATE EXTENSION pgcrypto; CREATE EXTENSION "uuid-ossp"; CREATE EXTENSION pg_trgm; CREATE EXTENSION xml2;' \
  -c "SELECT digest('x', 'sha256') IS NOT NULL, uuid_generate_v4() IS NOT NULL, xmlparse(document '<a/>') IS NOT NULL;" >/dev/null

# The entrypoint feeds *.sql.xz init scripts through xzcat.
echo "verifying xzcat (init-script decompression)..."
out=$(docker exec "$CID" sh -c 'printf "SELECT 1;" | xz | xzcat')
if [ "$out" != "SELECT 1;" ]; then echo "FAIL: xz/xzcat round-trip returned '$out'"; exit 1; fi

# The vendored entrypoint unsets POSTGRES_* before exec'ing the server, so the
# bootstrap password is not left readable in the postmaster's environment
# (/proc/<pid>/environ) or inherited by archive_command / COPY ... PROGRAM.
echo "verifying bootstrap credentials are not in the server environment..."
assert_no_bootstrap_env first

echo "verifying no process runs as root (layer-1 drop)..."
roots=$(docker top "$CID" -o pid,uid,cmd | tail -n +2 | awk '$2==0' | wc -l)
if [ "$roots" -ne 0 ]; then echo "FAIL: $roots root process(es):"; docker top "$CID"; exit 1; fi

echo "recreating the container on the same volume..."
docker rm -f "$CID" >/dev/null
start_container
wait_ready restart

rows=$(docker exec "$CID" psql -U postgres -tAc "SELECT count(*) FROM t;")
if [ "$rows" != "100" ]; then echo "FAIL: after restart expected 100 rows, got '$rows'"; exit 1; fi
marker=$(docker exec "$CID" psql -U postgres -tAc "SELECT string_agg(src, ',' ORDER BY id) FROM smoke_init;")
if [ "$marker" != "sql,sh,xz" ]; then echo "FAIL: after restart init marker is '$marker'"; exit 1; fi

echo "verifying bootstrap credentials are not in the restarted server environment..."
assert_no_bootstrap_env restart

echo "verifying no process runs as root after restart..."
roots=$(docker top "$CID" -o pid,uid,cmd | tail -n +2 | awk '$2==0' | wc -l)
if [ "$roots" -ne 0 ]; then echo "FAIL: $roots root process(es) after restart:"; docker top "$CID"; exit 1; fi

echo "SMOKE OK: $IMAGE (rows=$rows, init=$marker, root_procs=0)"
