#!/bin/bash
set -euo pipefail

# Runs backup.sh once a day at BACKUP_HOUR:BACKUP_MINUTE (UTC by default).

BACKUP_HOUR="${BACKUP_HOUR:-2}"
BACKUP_MINUTE="${BACKUP_MINUTE:-0}"
BACKUP_SCRIPT="${BACKUP_SCRIPT:-/usr/local/bin/backup.sh}"

echo "[$(date -Is)] db_backup started (schedule: daily at ${BACKUP_HOUR}:$(printf '%02d' "${BACKUP_MINUTE}"))."

last_run_day=""

while true; do
    now_hour="$(date +%-H)"
    now_minute="$(date +%-M)"
    today="$(date +%Y-%m-%d)"

    if [[ "${now_hour}" -eq "${BACKUP_HOUR}" \
       && "${now_minute}" -eq "${BACKUP_MINUTE}" \
       && "${last_run_day}" != "${today}" ]]; then
        "${BACKUP_SCRIPT}" || echo "[$(date -Is)] Scheduled backup failed."
        last_run_day="${today}"
    fi

    sleep 30
done
