#!/usr/bin/env bash
# Remove this project's local data:
#   drops the urlshortener database in Postgres.app
#   stops the Redis server started by setup.sh and deletes its data files
# Postgres.app itself stays installed and running. Migration files are kept.
#
#   ./flush_services.sh          asks for confirmation
#   ./flush_services.sh --yes    skips the prompt
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

PG_BIN="/Applications/Postgres.app/Contents/Versions/latest/bin"
DB_NAME="urlshortener"
REDIS_PREFIX="$ROOT/.services/redis"
REDIS_DATA="$REDIS_PREFIX/data"
REDIS_PID="$REDIS_PREFIX/redis.pid"
ASSUME_YES=0

if [[ "${1:-}" == "--yes" ]]; then
  ASSUME_YES=1
elif [[ $# -gt 0 ]]; then
  printf 'usage: ./flush_services.sh [--yes]\n' >&2
  exit 1
fi

log() {
  printf '\n==> %s\n' "$1"
}

die() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

printf 'This removes local data for this project.\n'
printf '  Postgres database: %s\n' "$DB_NAME"
printf '  Redis data:        %s\n' "$REDIS_DATA"
printf 'Postgres.app stays running. Migration files are kept.\n'

if [[ "$ASSUME_YES" -ne 1 ]]; then
  read -r -p "Type 'flush' to continue: " answer
  [[ "$answer" == "flush" ]] || die "Aborted."
fi

if [[ -x "$PG_BIN/psql" ]]; then
  export PATH="$PG_BIN:$PATH"
  if pg_isready -h localhost -p 5432 -q; then
    log "Dropping database ${DB_NAME}"
    psql -d postgres -v ON_ERROR_STOP=1 -c \
      "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DB_NAME}' AND pid <> pg_backend_pid();"
    dropdb --if-exists "$DB_NAME"
  else
    log "Postgres.app is not running. Skipping the database drop."
  fi
else
  log "Postgres.app was not found. Skipping the database drop."
fi

REDIS_CLI=""
if [[ -x "$REDIS_PREFIX/bin/redis-cli" ]]; then
  REDIS_CLI="$REDIS_PREFIX/bin/redis-cli"
elif [[ -x "/tmp/redis-7.4.7/src/redis-cli" ]]; then
  REDIS_CLI="/tmp/redis-7.4.7/src/redis-cli"
fi

if [[ -n "$REDIS_CLI" ]] && "$REDIS_CLI" -h localhost -p 6379 ping >/dev/null 2>&1; then
  log "Stopping Redis"
  "$REDIS_CLI" -h localhost -p 6379 shutdown nosave || true
  stopped=0
  for _ in $(seq 1 20); do
    if ! "$REDIS_CLI" -h localhost -p 6379 ping >/dev/null 2>&1; then
      stopped=1
      break
    fi
    sleep 1
  done
  if [[ "$stopped" -ne 1 ]]; then
    die "Redis is still running on localhost:6379. Data was not deleted."
  fi
elif [[ -f "$REDIS_PID" ]] && kill -0 "$(cat "$REDIS_PID")" 2>/dev/null; then
  log "Stopping Redis from its pid file"
  kill "$(cat "$REDIS_PID")" || true
else
  log "Redis is not running."
fi

if [[ -d "$REDIS_DATA" ]]; then
  log "Removing Redis data"
  rm -rf "$REDIS_DATA"
fi
rm -f "$REDIS_PID"

log "Done"
printf 'Run ./setup.sh to recreate the database and start Redis.\n'
