#!/bin/bash
set -euo pipefail

# PostgreSQL dump backups with retention:
#   daily   -> keep 4
#   weekly  -> keep 2  (Sundays)
#   monthly -> keep 2  (1st of month)
#   manual  -> named dumps; kept until deleted by hand
#
# Usage:
#   backup.sh                  # scheduled / default retention run
#   backup.sh <name>           # named manual backup (never auto-pruned)

BACKUP_ROOT="${BACKUP_ROOT:-/backups}"
POSTGRES_HOST="${POSTGRES_HOST:-db}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_DB="${POSTGRES_DB:-django_db}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
# POSTGRES_PASSWORD must be set (via env / PGPASSWORD)

KEEP_DAILY="${BACKUP_KEEP_DAILY:-4}"
KEEP_WEEKLY="${BACKUP_KEEP_WEEKLY:-2}"
KEEP_MONTHLY="${BACKUP_KEEP_MONTHLY:-2}"

export PGPASSWORD="${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"

timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
day_name="$(date +%A)"          # Sunday, Monday, ...
day_of_month="$(date +%d)"      # 01..31

mkdir -p \
    "${BACKUP_ROOT}/daily" \
    "${BACKUP_ROOT}/weekly" \
    "${BACKUP_ROOT}/monthly" \
    "${BACKUP_ROOT}/manual"

dump_to() {
    local dest="$1"
    echo "[$(date -Is)] Dumping ${POSTGRES_DB} -> ${dest}"
    pg_dump \
        -h "${POSTGRES_HOST}" \
        -p "${POSTGRES_PORT}" \
        -U "${POSTGRES_USER}" \
        -d "${POSTGRES_DB}" \
        --no-owner \
        --no-acl \
        | gzip -c > "${dest}.tmp"
    mv "${dest}.tmp" "${dest}"
    echo "[$(date -Is)] Wrote $(du -h "${dest}" | awk '{print $1}')"
}

prune() {
    local dir="$1"
    local keep="$2"
    mapfile -t files < <(ls -1t "${dir}"/*.sql.gz 2>/dev/null || true)
    local count="${#files[@]}"
    if (( count > keep )); then
        local i
        for (( i = keep; i < count; i++ )); do
            echo "[$(date -Is)] Pruning ${files[$i]}"
            rm -f "${files[$i]}"
        done
    fi
}

# Named manual backup: kept forever until removed by hand
if [[ "${#}" -ge 1 ]]; then
    name="$1"
    if [[ ! "${name}" =~ ^[A-Za-z0-9._-]+$ ]]; then
        echo "Invalid name '${name}'. Use only letters, numbers, '.', '_' or '-'." >&2
        exit 1
    fi
    dest="${BACKUP_ROOT}/manual/${name}.sql.gz"
    if [[ -e "${dest}" ]]; then
        echo "Manual backup already exists: ${dest}" >&2
        echo "Remove it first, or choose another name." >&2
        exit 1
    fi
    dump_to "${dest}"
    echo "[$(date -Is)] Manual backup '${name}' saved (not auto-pruned)."
    exit 0
fi

# Always create a daily backup
dump_to "${BACKUP_ROOT}/daily/${POSTGRES_DB}_${timestamp}.sql.gz"
prune "${BACKUP_ROOT}/daily" "${KEEP_DAILY}"

# Weekly backup on Sunday
if [[ "${day_name}" == "Sunday" ]]; then
    dump_to "${BACKUP_ROOT}/weekly/${POSTGRES_DB}_${timestamp}.sql.gz"
    prune "${BACKUP_ROOT}/weekly" "${KEEP_WEEKLY}"
fi

# Monthly backup on the 1st
if [[ "${day_of_month}" == "01" ]]; then
    dump_to "${BACKUP_ROOT}/monthly/${POSTGRES_DB}_${timestamp}.sql.gz"
    prune "${BACKUP_ROOT}/monthly" "${KEEP_MONTHLY}"
fi

echo "[$(date -Is)] Backup run finished."
