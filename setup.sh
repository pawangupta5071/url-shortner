#!/usr/bin/env bash
# Idempotent local setup for this machine:
#   Postgres.app (already installed) + Redis built from source + Alembic.
# Safe to run again. Uses DATABASE_URL / REDIS_URL from .env.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

PG_BIN="/Applications/Postgres.app/Contents/Versions/latest/bin"
DB_NAME="urlshortener"
DB_USER="postgres"
DB_PASSWORD="postgres"

REDIS_VERSION="7.4.7"
REDIS_PREFIX="$ROOT/.services/redis"
REDIS_SRC="$ROOT/.services/src/redis-$REDIS_VERSION"
REDIS_DATA="$REDIS_PREFIX/data"
REDIS_PID="$REDIS_PREFIX/redis.pid"
PREBUILT_REDIS_SRC="/tmp/redis-$REDIS_VERSION"

log() {
  printf '\n==> %s\n' "$1"
}

die() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

if [[ ! -f .env ]]; then
  die ".env is missing. It must define DATABASE_URL and REDIS_URL."
fi

if [[ ! -x "$PG_BIN/psql" ]]; then
  die "Postgres.app was not found. Install it from https://postgresapp.com/downloads and move Postgres.app to /Applications."
fi
export PATH="$PG_BIN:$PATH"

log "Checking Postgres.app on localhost:5432"
if ! pg_isready -h localhost -p 5432 -q; then
  open -a Postgres
  ready=0
  for _ in $(seq 1 30); do
    if pg_isready -h localhost -p 5432 -q; then
      ready=1
      break
    fi
    sleep 1
  done
  if [[ "$ready" -ne 1 ]]; then
    die "Postgres is not accepting connections. Open Postgres.app and start the server, then rerun ./setup.sh."
  fi
fi

log "Creating role '${DB_USER}' and database '${DB_NAME}' if they do not exist"
# Postgres.app trusts the macOS user over the local socket.
role_exists="$(psql -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | tr -d '[:space:]')"
if [[ "$role_exists" != "1" ]]; then
  createuser -s "$DB_USER"
fi
psql -d postgres -c "ALTER ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASSWORD}';"

db_exists="$(psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | tr -d '[:space:]')"
if [[ "$db_exists" != "1" ]]; then
  createdb -O "$DB_USER" "$DB_NAME"
fi

log "Installing Redis ${REDIS_VERSION} under .services/redis if needed"
if [[ ! -x "$REDIS_PREFIX/bin/redis-server" ]]; then
  mkdir -p "$ROOT/.services/src"
  if [[ -d "$PREBUILT_REDIS_SRC" ]]; then
    make -C "$PREBUILT_REDIS_SRC" install PREFIX="$REDIS_PREFIX"
  else
    curl -fsSL -o "$ROOT/.services/src/redis.tar.gz" \
      "https://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz"
    tar -xzf "$ROOT/.services/src/redis.tar.gz" -C "$ROOT/.services/src"
    make -C "$REDIS_SRC" -j4
    make -C "$REDIS_SRC" install PREFIX="$REDIS_PREFIX"
  fi
fi

mkdir -p "$REDIS_DATA"
redis_managed=0
if [[ -f "$REDIS_PID" ]] && kill -0 "$(cat "$REDIS_PID")" 2>/dev/null; then
  redis_managed=1
fi
if [[ "$redis_managed" -ne 1 ]]; then
  if "$REDIS_PREFIX/bin/redis-cli" -h localhost -p 6379 ping 2>/dev/null | grep -q PONG; then
    log "Stopping the Redis already running on port 6379"
    "$REDIS_PREFIX/bin/redis-cli" -h localhost -p 6379 shutdown nosave || true
    for _ in $(seq 1 20); do
      if ! "$REDIS_PREFIX/bin/redis-cli" -h localhost -p 6379 ping >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done
  fi
  log "Starting Redis"
  "$REDIS_PREFIX/bin/redis-server" \
    --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$REDIS_DATA" \
    --dbfilename dump.rdb \
    --pidfile "$REDIS_PID" \
    --protected-mode yes
fi

log "Waiting for Redis on localhost:6379"
redis_ready=0
for _ in $(seq 1 30); do
  if "$REDIS_PREFIX/bin/redis-cli" -h localhost -p 6379 ping 2>/dev/null | grep -q PONG; then
    redis_ready=1
    break
  fi
  sleep 1
done
if [[ "$redis_ready" -ne 1 ]]; then
  die "Redis did not respond to PING on localhost:6379"
fi

log "Activating the project virtualenv"
if [[ ! -d .venv ]]; then
  python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate

if [[ -s requirements.txt ]]; then
  log "Installing Python dependencies"
  python -m pip install -r requirements.txt
fi

if ! python -c "import psycopg" >/dev/null 2>&1; then
  log "Installing psycopg with bundled libpq"
  python -m pip install "psycopg[binary]"
fi

if ! command -v uvicorn >/dev/null 2>&1; then
  log "Installing uvicorn"
  python -m pip install uvicorn
fi

if ! python -c "import alembic, sqlalchemy, psycopg" >/dev/null 2>&1; then
  die "alembic, sqlalchemy, and psycopg must be installed in .venv"
fi

log "Generating a migration if alembic/versions is empty"
shopt -s nullglob
migrations=(alembic/versions/*.py)
if (( ${#migrations[@]} == 0 )); then
  alembic revision --autogenerate -m "initial tables"
else
  printf 'Migrations already exist (%s). Skipping autogenerate.\n' "${#migrations[@]}"
fi

log "Applying migrations"
alembic upgrade head

log "Done"
printf 'Postgres: localhost:5432  database=%s  user=%s\n' "$DB_NAME" "$DB_USER"
printf 'Redis:    localhost:6379  data=%s\n' "$REDIS_DATA"
printf 'Start the app with: ./runserver.sh\n'
