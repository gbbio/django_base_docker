#!/bin/bash
set -e

wait_for_db() {
    echo "Waiting for database..."
    python - <<'PY'
import os, time, sys
import psycopg2

host = os.environ.get("POSTGRES_HOST", "db")
port = os.environ.get("POSTGRES_PORT", "5432")
dbname = os.environ.get("POSTGRES_DB", "django_db")
user = os.environ.get("POSTGRES_USER", "postgres")
password = os.environ.get("POSTGRES_PASSWORD", "postgres")

for attempt in range(30):
    try:
        psycopg2.connect(
            host=host, port=port, dbname=dbname, user=user, password=password
        ).close()
        print("Database is ready.")
        sys.exit(0)
    except psycopg2.OperationalError:
        time.sleep(1)

print("Database did not become ready in time.", file=sys.stderr)
sys.exit(1)
PY
}

if [ -f "manage.py" ]; then
    wait_for_db
    echo "Applying migrations..."
    python manage.py migrate --noinput
    echo "Starting Django development server..."
    python manage.py runserver 0.0.0.0:8000 &
else
    echo "No manage.py found in /app — skipping Django start."
fi

exec "$@"
