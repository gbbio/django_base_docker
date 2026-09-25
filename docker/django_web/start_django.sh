#!/bin/bash
set -e

if pgrep -f "manage.py runserver" > /dev/null; then
    echo "Django is already running."
    exit 0
fi

if [ ! -f "manage.py" ]; then
    echo "No manage.py found in $(pwd)."
    exit 1
fi

echo "Starting Django development server in background..."
nohup python manage.py runserver 0.0.0.0:8000 > /tmp/django_runserver.log 2>&1 &

sleep 1

if pgrep -f "manage.py runserver" > /dev/null; then
    echo "Django started on port 8000 inside the container."
    echo "From the host, use the DJANGO_PORT mapping (default http://localhost:8000)."
else
    echo "Failed to start Django. Last log lines:"
    tail -n 20 /tmp/django_runserver.log || true
    exit 1
fi
