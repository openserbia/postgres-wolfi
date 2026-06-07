#!/usr/bin/env bash
# Smoke test for postgres-wolfi: boots the image on a throwaway volume, verifies
# init + basic SQL, and that NO process runs as root (layer-1 drop worked).
# Usage: test/smoke.sh <image-ref>
set -euo pipefail

IMAGE="${1:?usage: smoke.sh <image-ref>}"
CNAME="pgwolfi-smoke-$$"
VOL="pgwolfi-smoke-vol-$$"
PW="smoke_$$"

cleanup() {
  docker rm -f "$CNAME" >/dev/null 2>&1 || true
  docker volume rm "$VOL" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker volume create "$VOL" >/dev/null
docker run -d --name "$CNAME" --memory 1g \
  -e POSTGRES_PASSWORD="$PW" \
  -v "$VOL":/var/lib/postgresql/data \
  "$IMAGE" >/dev/null

echo "waiting for readiness..."
ready=0
for _ in $(seq 1 30); do
  if docker exec "$CNAME" pg_isready -U postgres >/dev/null 2>&1; then ready=1; break; fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then echo "FAIL: never became ready"; docker logs "$CNAME"; exit 1; fi

echo "running SQL..."
docker exec "$CNAME" psql -U postgres -v ON_ERROR_STOP=1 \
  -c "CREATE TABLE t(id serial primary key, name text);" \
  -c "INSERT INTO t(name) SELECT 'n'||g FROM generate_series(1,100) g;"
rows=$(docker exec "$CNAME" psql -U postgres -tAc "SELECT count(*) FROM t;")
if [ "$rows" != "100" ]; then echo "FAIL: expected 100 rows, got '$rows'"; exit 1; fi

echo "verifying no process runs as root (layer-1 drop)..."
roots=$(docker top "$CNAME" -o pid,uid,cmd | tail -n +2 | awk '$2==0' | wc -l)
if [ "$roots" -ne 0 ]; then echo "FAIL: $roots root process(es):"; docker top "$CNAME"; exit 1; fi

echo "SMOKE OK: $IMAGE (rows=$rows, root_procs=0)"
