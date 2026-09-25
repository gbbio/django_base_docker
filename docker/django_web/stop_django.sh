#!/bin/bash
# Stop Django development server running in the container

if pkill -f "manage.py runserver"; then
    echo "Django stopped successfully."
else
    echo "No Django runserver processes found."
fi
