#!/usr/bin/env bash
# Start the FastAPI app on http://localhost:8000
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if [[ ! -d .venv ]]; then
  printf 'error: .venv is missing. Run ./setup.sh first.\n' >&2
  exit 1
fi

# shellcheck disable=SC1091
source .venv/bin/activate

if ! command -v uvicorn >/dev/null 2>&1; then
  printf 'error: uvicorn is not installed in .venv. Run ./setup.sh first.\n' >&2
  exit 1
fi

exec uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
