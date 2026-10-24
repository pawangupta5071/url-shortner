# URL Shortener

A small FastAPI service that turns a long URL into a short code. Opening the short link redirects to the original address. Lookups are cached in Redis. Links can use a custom alias and an optional expiry time.

## API

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/api/health` | Health check. Returns `{"status":"ok"}`. |
| `POST` | `/api/v1/urls` | Create a short URL. |
| `GET` | `/{short_code}` | Redirect to the original URL. |

Interactive docs are at [http://localhost:8000/docs](http://localhost:8000/docs) while the server is running.

Create a short URL:

```bash
curl -X POST http://localhost:8000/api/v1/urls \
  -H "Content-Type: application/json" \
  -d '{"long_url":"https://example.com"}'
```

Optional fields:

- `custom_alias`: 1–32 characters, letters, numbers, `_`, and `-`
- `expires_at`: a timezone-aware datetime in the future, for example `2026-12-31T00:00:00Z`

`GET /{short_code}` responds with `302` and a `Location` header. Unknown codes return `404`. Expired codes return `410`.

## Configuration

Create a `.env` file in the project root:

```env
DATABASE_URL=postgresql+psycopg://postgres:postgres@localhost:5432/urlshortener
REDIS_URL=redis://localhost:6379/0
BASE_URL=http://localhost:8000
```

`BASE_URL` is the prefix used when the API builds a `short_url`.

## Setup with Docker

Docker runs Postgres 17 and Redis 7. The FastAPI app still runs on your machine.

```bash
docker compose up -d
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
alembic revision --autogenerate -m "initial tables"
alembic upgrade head
./runserver.sh
```

Skip the `alembic revision` command when `alembic/versions` already contains a migration. `alembic upgrade head` is enough.

Check the app:

```bash
curl http://localhost:8000/api/health
```

Stop the containers:

```bash
docker compose down
```

`docker compose down -v` also deletes the Postgres volume.

## Setup without Docker

`./setup.sh` is for a Mac where Postgres is provided by [Postgres.app](https://postgresapp.com/) and Redis is built from source into `.services/`. That path avoids compiling Postgres with Homebrew.

1. Install Postgres.app, move it to `/Applications`, and start the server.
2. From the project root, run:

```bash
./setup.sh
./runserver.sh
```

`./setup.sh` creates the `postgres` role and the `urlshortener` database, starts Redis, installs `psycopg` with a bundled `libpq` when needed, and applies migrations.

`./flush_services.sh` drops the `urlshortener` database and deletes the local Redis data. It asks you to type `flush` before doing that. Postgres.app stays running. Pass `--yes` to skip the prompt.

## Tests

```bash
source .venv/bin/activate
pytest
```
