# django_base_docker

Reusable Docker setup for local Django development. `docker-compose.yml` and
`docker/` sit next to your Django code so you can copy this repo into a new
project and replace the dummy site.

## Layout

```text
.
├── docker-compose.yml
├── docker/
├── django_project_folder/          # rename via DJANGO_PROJECT_FOLDER in .env
│   ├── requirements.txt            # installed at image build time
│   └── django_project/             # mounted at /app (manage.py lives here)
│       ├── manage.py
│       └── config/
└── .env
```

Compose mounts:

```text
./django_project_folder/django_project  →  /app
./django_project_folder/requirements.txt  (build arg only)
```

## What you get

| Service | Host URL (defaults) | Purpose |
|---------|---------------------|---------|
| `django_web` | http://localhost:8000 | Django runserver (code bind-mounted) |
| `db` | localhost:5433 | PostgreSQL 16 (container still uses 5432) |
| `pgadmin` | http://localhost:5050 | DB UI (`admin@admin.com` / `admin`) |
| `db_backup` | (volume `db_backups`) | Daily/weekly/monthly `pg_dump` (keep 4 / 2 / 2) |

## Quick start (dummy project)

```bash
cp .env.example .env
# optional: set USER_ID/GROUP_ID to $(id -u) / $(id -g)
docker compose up -d --build
```

Open http://localhost:8000 — you should see the dummy homepage.

If a port is already in use, change `DJANGO_PORT`, `POSTGRES_PORT`, or
`PGADMIN_PORT` in `.env` and run `docker compose up -d` again.

## Start a new Django project

Expected shape after setup:

```text
<DJANGO_PROJECT_FOLDER>/
  requirements.txt
  django_project/
    manage.py
    ...
```

### 1. Choose a folder name

In `.env`:

```bash
DJANGO_PROJECT_FOLDER=my_shop   # example — use your name
```

### 2. Create the folders and project

Remove the dummy (or keep it and use a different `DJANGO_PROJECT_FOLDER`):

```bash
rm -rf django_project_folder   # only if you are replacing the dummy
```

Create the outer folder **and** the inner `django_project` directory (Django requires
the destination to exist):

```bash
mkdir -p my_shop/django_project
```

Create the Django project so `manage.py` ends up in `my_shop/django_project/`:

```bash
docker run --rm \
  -v "$(pwd)/my_shop:/out" \
  -w /out \
  python:3.12-slim \
  bash -c "pip install --no-cache-dir Django==5.1.3 \
    && django-admin startproject config django_project \
    && chown -R $(id -u):$(id -g) django_project"
```

That produces:

```text
my_shop/
  django_project/
    manage.py
    config/
```

### 3. Add requirements

```bash
cat > my_shop/requirements.txt <<'EOF'
Django==5.1.3
psycopg2-binary==2.9.10
EOF
```

Add more packages here as the app grows. After changing this file, rebuild:

```bash
docker compose up -d --build
```

### 4. Wire Django to Postgres

In `my_shop/django_project/config/settings.py` (or your settings module), use env
vars matching compose:

```python
import os

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('POSTGRES_DB', 'django_db'),
        'USER': os.environ.get('POSTGRES_USER', 'postgres'),
        'PASSWORD': os.environ.get('POSTGRES_PASSWORD', 'postgres'),
        'HOST': os.environ.get('POSTGRES_HOST', 'db'),
        'PORT': os.environ.get('POSTGRES_PORT', '5432'),
    }
}

ALLOWED_HOSTS = os.environ.get('DJANGO_ALLOWED_HOSTS', '*').split(',')
```

### 5. Start the stack

```bash
docker compose up -d --build
```

Edit files under `my_shop/django_project/` on the host; the container picks up
changes via the bind mount.

## Docker usage

```bash
docker compose up -d
docker compose up -d --build
docker compose down
docker compose down -v   # also remove DB/pgAdmin/backup volumes
```

Project name comes from `COMPOSE_PROJECT_NAME` in `.env` (default `django_base`).

## Django container

```bash
docker compose exec django_web bash
```

Inside the container:

```bash
stop_django
start_django
python manage.py runserver 0.0.0.0:8000   # foreground
```

On start, the entrypoint waits for Postgres, runs `migrate`, then starts runserver
in the background while keeping the container alive.

## Database backups

`db_backup` uses the same `postgres:16` image and `docker/db_backup/backup.sh`.
Dumps are stored in the Docker volume `db_backups` (paths below are inside the
`db_backup` container).

### Schedule and retention

| Type | When | Keep |
|------|------|------|
| daily | every day at schedule time | 4 |
| weekly | Sundays | 2 |
| monthly | 1st of the month | 2 |
| manual | only when you pass a name | forever (until you delete it) |

Default schedule: `BACKUP_HOUR`:`BACKUP_MINUTE` (UTC), configurable in `.env`.

### List backups

```bash
docker compose exec db_backup ls -lah /backups/daily /backups/weekly /backups/monthly /backups/manual
```

### Run a scheduled-style backup now

Creates a daily dump and applies retention pruning (weekly/monthly only if today
matches those rules):

```bash
docker compose exec db_backup /usr/local/bin/backup.sh
```

### Named manual backup

Pass a name (letters, numbers, `.`, `_`, `-`). The file is written to
`/backups/manual/<name>.sql.gz` and is **never** auto-pruned.

```bash
# Create
docker compose exec db_backup /usr/local/bin/backup.sh before-migration

# List
docker compose exec db_backup ls -lah /backups/manual

# Remove when you no longer need it
docker compose exec db_backup rm /backups/manual/before-migration.sql.gz
```

If that name already exists, the script exits with an error — delete it first or
choose another name.

### Restore

Copy a dump out of the volume (or stream it), then load with `psql`. Prefer
stopping Django first so nothing writes during restore.

```bash
# Example: restore a named manual backup
docker compose exec django_web stop_django

docker compose exec -T db_backup cat /backups/manual/before-migration.sql.gz \
  | gunzip \
  | docker compose exec -T db psql -U postgres -d django_db

docker compose exec django_web start_django
```

Replace the path with a file under `/backups/daily/`, `/backups/weekly/`, or
`/backups/monthly/` as needed.
