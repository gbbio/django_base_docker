# django_base_docker

Docker Compose base for local Django development: Postgres, pgAdmin, Django, and DB backups.

## Layout

```text
django_project_folder/          ← DJANGO_PROJECT_FOLDER
  requirements.txt
  django_project/               ← DJANGO_APP_DIR → mounted at /app
    manage.py
    config/
```

## 1. Configure

```bash
cp .env.example .env
```

Edit `.env`:

```bash
COMPOSE_PROJECT_NAME=my_project
DJANGO_PROJECT_FOLDER=my_project
DJANGO_APP_DIR=django_project

# Host user (required — avoids root-owned files on the bind mount)
# Run: id -u   and   id -g
USER_ID=1000
GROUP_ID=1000

# Change ports if something else already uses them
DJANGO_PORT=8000
POSTGRES_PORT=5433
PGADMIN_PORT=5050
```

Create folders and requirements:

```bash
rm -rf django_project_folder          # remove dummy if present
mkdir -p my_project/django_project

cat > my_project/requirements.txt <<'EOF'
Django==5.1.3
psycopg2-binary==2.9.10
EOF
```

If you change `POSTGRES_PASSWORD`, also update `docker/pgadmin/pgpass` to match.

## 2. Start the stack

```bash
docker compose up -d --build
```

## 3. Create the Django project

Enter the container (workdir is `/app` = your empty `django_project` folder):

```bash
docker compose exec django_web bash
```

Inside the container:

```bash
django-admin startproject config .
```

Use `.` so `manage.py` is created in `/app` directly (not in a nested folder).

Then wire Postgres in `config/settings.py`:

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

Start Django (still inside the container, or from the host):

```bash
start_django
# or foreground:
python manage.py runserver 0.0.0.0:8000
```

```bash
stop_django
```

On container start, the entrypoint runs `migrate` and `runserver` automatically when `manage.py` exists. After creating the project the first time, recreate the web container once:

```bash
exit
docker compose up -d --force-recreate django_web
```

| Service | URL |
|---------|-----|
| Django | http://localhost:8000 (after you create the project below) |
| pgAdmin | http://localhost:5050 (`admin@admin.com` / `admin`) |
| Postgres | localhost:5433 |

Useful commands:

```bash
docker compose down
docker compose down -v              # also delete volumes
docker compose up -d --build        # after changing requirements.txt
```
## Django helpers

```bash
docker compose exec django_web bash
docker compose exec django_web start_django
docker compose exec django_web stop_django
```

## pgAdmin

Open http://localhost:5050 → **Servers → django_db** (pre-registered via `docker/pgadmin/servers.json`).

Server list is imported only on first start. To reload it:

```bash
docker compose down
docker volume rm ${COMPOSE_PROJECT_NAME:-django_base}_pgadmin_data
docker compose up -d
```

## Database backups

Service `db_backup` runs daily at `BACKUP_HOUR`:`BACKUP_MINUTE` (UTC). Keeps 4 daily, 2 weekly, 2 monthly. Named backups are never auto-deleted.

```bash
# List
docker compose exec db_backup ls -lah /backups/daily /backups/weekly /backups/monthly /backups/manual

# Run now (scheduled-style)
docker compose exec db_backup /usr/local/bin/backup.sh

# Named manual backup (kept until you delete it)
docker compose exec db_backup /usr/local/bin/backup.sh before-migration
docker compose exec db_backup rm /backups/manual/before-migration.sql.gz

# Restore example
docker compose exec django_web stop_django
docker compose exec -T db_backup cat /backups/manual/before-migration.sql.gz \
  | gunzip \
  | docker compose exec -T db psql -U postgres -d django_db
docker compose exec django_web start_django
```
